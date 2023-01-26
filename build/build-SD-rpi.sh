#!/bin/bash

# Batch creation of NextcloudPi image
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# Usage: ./batch.sh <DHCP QEMU image IP>
#

function unsetRPiVariables() {
  unset URL SIZE IMG TAR TMP_IMG_PATH RPI_ROOT \
        TMP_BUILD RSYNC_ARGS SHELL BASE_IMG
}

URL='https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64-lite.img.xz'
SIZE='4G'
#CLEAN='0'
IMG="NextcloudPi_RPi_$(date +%m-%d-%y).img"
TAR="output/$(basename "$IMG" .img).tar.bz2"
TMP_IMG_PATH="tmp/$IMG"
TMP_BUILD="${RPI_ROOT}/tmp/ncp-build"
RPI_ROOT='raspbian_root'
BASE_IMG="${RPI_ROOT}/usr/local/etc/ncp-baseimage"
SHELL='/bin/bash'
RSYNC_ARGS=(-Aax --exclude-from .gitignore --exclude *.img --exclude *.bz2 .)

if [[ -n "$DBG" ]]
then
  set -e"$DBG"
else
  set -e
fi

# 0) EXIT    1) SIGHUP	 2) SIGINT	 3) SIGQUIT
# 4) SIGILL  5) SIGTRAP 6) SIGABRT	15) SIGTERM
trap 'unsetRPiVariables' EXIT SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGTERM

# shellcheck disable=SC1091
source Library.sh

log -1 "Building NCP Raspberry Pi SD-Card IMG"

[[ -f "$TAR" ]] && {
  log -1 "File already exists: $TAR"
  exit 0
}

if checkFullProcess qemu-arm-static
then
  log 2 "Process already running: qemu-arm-static"
  exit 1
fi

if checkFullProcess qemu-aarch64-static
then
  log 2 "Process already running: qemu-aarch64-static"
  exit 1
fi

trap cleanChrootRPi EXIT

prepareDirectories
downloadRPiOS  "$URL"          "$TMP_IMG_PATH"
resizeIMG      "$TMP_IMG_PATH" "$SIZE"
updateBootUUID "$TMP_IMG_PATH"

# make sure we don't accidentally disable first run wizard
if [[ -d 'ncp-web' ]]
then
  if isRoot
  then
    rm --force      ncp-web/{wizard.cfg,ncp-web.cfg}
  else
    sudo rm --force ncp-web/{wizard.cfg,ncp-web.cfg}
  fi
fi

## BUILD NCP

prepareChrootRPi "$IMG"
mkdir            "$TMP_BUILD"

if hasCMD rsync
then
  if isRoot
  then
    rsync      "${RSYNC_ARGS[@]}" "$TMP_BUILD"
  else
    sudo rsync "${RSYNC_ARGS[@]}" "$TMP_BUILD"
  fi
else
  log 2 "Missing command: rsync"
fi

if isRoot
then
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  chroot "$RPI_ROOT" "$SHELL" <<'EOFCHROOT'
    set -ex

    # Allow oldstable
    apt-get update --allow-releaseinfo-change

    # As of 03-2018, you dont get a big kernel update by doing
    # this, so better be safe. Might uncomment again in the future
    #$APTINSTALL rpi-update
    #echo -e "y\n" | PRUNE_MODULES=1 rpi-update

    # This image comes without resolv.conf ??
    echo 'nameserver 1.1.1.1' >> /etc/resolv.conf

    # Install NCP
    cd /tmp/ncp-build || exit 1
    systemctl daemon-reload
    CODE_DIR="$PWD" bash Install.sh

    # work around dhcpcd Raspbian bug
    # https://lb.raspberrypi.org/forums/viewtopic.php?t=230779
    # https://github.com/nextcloud/nextcloudpi/issues/938
    apt-get update
    apt-get install -y --no-install-recommends haveged
    systemctl enable haveged.service

    # harden SSH further for Raspbian
    sed -i 's|^#PermitRootLogin .*|PermitRootLogin no|' /etc/ssh/sshd_config

    # cleanup
    source etc/library.sh && runApp_unsafe post-inst.sh
    rm /etc/resolv.conf
    rm -rf /tmp/ncp-build
EOFCHROOT
else
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  sudo chroot "$RPI_ROOT" "$SHELL" <<'EOFCHROOT'
    set -ex

    # Allow oldstable
    apt-get update --allow-releaseinfo-change

    # As of 03-2018, you dont get a big kernel update by doing
    # this, so better be safe. Might uncomment again in the future
    #$APTINSTALL rpi-update
    #echo -e "y\n" | PRUNE_MODULES=1 rpi-update

    # This image comes without resolv.conf ??
    echo 'nameserver 1.1.1.1' >> /etc/resolv.conf

    # Install NCP
    cd /tmp/ncp-build || exit 1
    systemctl daemon-reload
    CODE_DIR="$PWD" bash Install.sh

    # work around dhcpcd Raspbian bug
    # https://lb.raspberrypi.org/forums/viewtopic.php?t=230779
    # https://github.com/nextcloud/nextcloudpi/issues/938
    apt-get update
    apt-get install -y --no-install-recommends haveged
    systemctl enable haveged.service

    # harden SSH further for Raspbian
    sed -i 's|^#PermitRootLogin .*|PermitRootLogin no|' /etc/ssh/sshd_config

    # cleanup
    source etc/library.sh && runApp_unsafe post-inst.sh
    rm /etc/resolv.conf
    rm -rf /tmp/ncp-build
EOFCHROOT
fi

if isRoot
then
  basename "$IMG" | tee "$BASE_IMG"
else
  basename "$IMG" | sudo tee "$BASE_IMG"
fi

trap '' EXIT

CleanChroot_RPi

## pack
[[ "$*" =~ .*" --pack ".* ]] && packIMG "$IMG" "$TAR"

exit 0
