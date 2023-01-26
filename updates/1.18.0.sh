#!/bin/bash

set -e

## BACKWARD FIXES ( for older images )

source /usr/local/etc/library.sh # sets NEXTCLOUD_VERSION_LATEST PHP_VERSION RELEASE

# all images

# restore sources in stretch
sed -i "s/buster/$RELEASE/g" /etc/apt/sources.list.d/* &>/dev/null || true

# restore smbclient after dist upgrade
apt_install php${PHP_VERSION}-gmp

# Update modsecurity config file only if user is already in buster and
# modsecurity is used.
# https://github.com/nextcloud/nextcloudpi/issues/959
isActiveApp modsecurity && runApp modsecurity

# fix armbian disabling unattended-upgrades
isActiveApp unattended-upgrades && runApp unattended-upgrades

# groupfolders fix
installApp nc-backup

# docker images only
[[ -f /.docker-image ]] && {
  :
}

# for non docker images
[[ ! -f /.docker-image ]] && {
  # fix fail2ban with UFW
  mkdir -p /etc/systemd/system/fail2ban.service.d/
  cat > /etc/systemd/system/fail2ban.service.d/touch-ufw-log.conf <<EOF
[Service]
ExecStartPre=/bin/touch /var/log/ufw.log
EOF
}

exit 0
