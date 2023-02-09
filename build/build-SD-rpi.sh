#!/usr/bin/env bash

# Batch creation of NextcloudPi image
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# Usage: ./batch.sh <DHCP QEMU image IP>
#

if [[ -z "$DBG" ]]; then
  set -e
elif [[ -n "$DBG" ]]; then
  set -e"$DBG"
fi

if [[ ! -f 'build/buildlib.sh' ]]; then
  echo "File not found: build/buildlib.sh"
  exit 1
fi

# shellcheck disable=SC1090
source build/buildlib.sh

log -1 "Build NCP Raspberry Pi"

URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64-lite.img.xz"
SIZE=4G                     # Raspbian image size
#CLEAN=0                    # Pass this envvar to skip cleaning download cache
IMG="${IMG:-NextcloudPi_RPi_$( date  "+%m-%d-%y" ).img}"
TAR=output/"$( basename "$IMG" .img ).tar.bz2"

##############################################################################

if isFile "$TAR"; then
  echo "File exists: $TAR"
  exit 0
fi
if findFullProcess qemu-arm-static; then
  log 2 "qemu-arm-static already running"
  exit 1
fi
if findFullProcess qemu-aarch64-static; then
  log 2 "qemu-aarch64-static already running"
  exit 1
fi
## preparations

IMG=tmp/"$IMG"

trap 'cleanChroot' EXIT SIGHUP SIGILL SIGABRT
# tmp cache output
prepareDirectories
downloadRaspberryOS "$URL" "$IMG"
resizeIMG           "$IMG" "$SIZE"
# PARTUUID has changed after resize
updateBootUUID      "$IMG"

# Make sure we don't accidentally disable first run wizard
if isRoot; then
  rm --force ncp-web/{wizard.cfg,ncp-web.cfg}
else
  sudo rm --force ncp-web/{wizard.cfg,ncp-web.cfg}
fi

## BUILD NCP

prepareChrootRPi "$IMG"

if isRoot; then
  mkdir raspbian_root/tmp/ncp-build
else
  sudo mkdir raspbian_root/tmp/ncp-build
fi

if isRoot; then
  rsync -Aax --exclude-from .gitignore --exclude *.img --exclude *.bz2 . raspbian_root/tmp/ncp-build
else
  sudo rsync -Aax --exclude-from .gitignore --exclude *.img --exclude *.bz2 . raspbian_root/tmp/ncp-build
fi

if isRoot; then
  PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
  chroot raspbian_root /bin/bash <<'EOFCHROOT'
    set -ex

    # allow oldstable
    apt-get update --allow-releaseinfo-change

    # As of 10-2018 this upgrades raspi-kernel and messes up wifi and BTRFS
    #apt-get upgrade -y
    #apt-get dist-upgrade -y

    # As of 03-2018, you dont get a big kernel update by doing
    # this, so better be safe. Might uncomment again in the future
    #$APTINSTALL rpi-update
    #echo -e "y\n" | PRUNE_MODULES=1 rpi-update

    # this image comes without resolv.conf ??
    echo 'nameserver 1.1.1.1' >> /etc/resolv.conf

    # install NCP
    cd /tmp/ncp-build || exit 1
    systemctl daemon-reload
    CODE_DIR="$PWD" bash install.sh

    # work around dhcpcd Raspbian bug
    # https://lb.raspberrypi.org/forums/viewtopic.php?t=230779
    # https://github.com/nextcloud/nextcloudpi/issues/938
    apt-get update
    apt-get install -y --no-install-recommends haveged
    systemctl enable haveged.service

    # harden SSH further for Raspbian
    sed -i 's|^#PermitRootLogin .*|PermitRootLogin no|' /etc/ssh/sshd_config

    # cleanup
    source etc/library.sh && runAppUnsafe post-inst.sh
    rm /etc/resolv.conf
    rm -rf /tmp/ncp-build
EOFCHROOT
else
  PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
  sudo chroot raspbian_root /bin/bash <<'EOFCHROOT'
    set -ex

    # allow oldstable
    apt-get update --allow-releaseinfo-change

    # As of 10-2018 this upgrades raspi-kernel and messes up wifi and BTRFS
    #apt-get upgrade -y
    #apt-get dist-upgrade -y

    # As of 03-2018, you dont get a big kernel update by doing
    # this, so better be safe. Might uncomment again in the future
    #$APTINSTALL rpi-update
    #echo -e "y\n" | PRUNE_MODULES=1 rpi-update

    # this image comes without resolv.conf ??
    echo 'nameserver 1.1.1.1' >> /etc/resolv.conf

    # install NCP
    cd /tmp/ncp-build || exit 1
    systemctl daemon-reload
    CODE_DIR="$PWD" bash install.sh

    # work around dhcpcd Raspbian bug
    # https://lb.raspberrypi.org/forums/viewtopic.php?t=230779
    # https://github.com/nextcloud/nextcloudpi/issues/938
    apt-get update
    apt-get install -y --no-install-recommends haveged
    systemctl enable haveged.service

    # harden SSH further for Raspbian
    sed -i 's|^#PermitRootLogin .*|PermitRootLogin no|' /etc/ssh/sshd_config

    # cleanup
    source etc/library.sh && runAppUnsafe post-inst.sh
    rm /etc/resolv.conf
    rm -rf /tmp/ncp-build
EOFCHROOT
fi

if isRoot; then
  log -1 "Image created: $(basename $IMG)"
  basename "$IMG" | tee raspbian_root/usr/local/etc/ncp-baseimage
else
  log -1 "Image created: $(sudo basename $IMG)"
  sudo basename "$IMG" | sudo tee raspbian_root/usr/local/etc/ncp-baseimage
fi

log -1 "Cleaning chroot"

# Gets executed when trap is triggered by exit
#cleanChroot

## Pack IMG
[[ "$*" =~ .*" --pack ".* ]] && { log -1 "Packing image"; packImage "$IMG" "$TAR"; }

log 0 "Complete"

exit 0

## test

#setStaticIP "$IMG" "$IP"
#test_image    "$IMG" "$IP" # TODO fix tests

# upload
#createTorrent "$TAR"
#uploadFTP "$( basename "$TAR" .tar.bz2 )"


# License
#
# This script is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA  02111-1307  USA
