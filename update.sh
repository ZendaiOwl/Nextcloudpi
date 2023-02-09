#!/usr/bin/env bash

# Updater for NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/
#

CONFDIR='/usr/local/etc/ncp-config.d'
UPDATESDIR='updates'
LIBRARY='/usr/local/etc/library.sh'

# shellcheck disable=SC1090
source "$LIBRARY"

set -e"$DBG"


if isDocker
then
  echo "WARNING: Docker images should be updated by replacing the container from the latest docker image" \
    "(refer to the documentation for instructions: https://docs.nextcloudpi.com)." \
    "If you are sure that you know what you are doing, you can still execute the update script by running it like this:"
  echo "> ALLOW_UPDATE_SCRIPT=1 ncp-update"
  [[ "$ALLOW_UPDATE_SCRIPT" == "1" ]] || exit 1
fi


# don't make sense in a docker container
EXCL_DOCKER="
nc-autoupdate-ncp
nc-update
nc-automount
nc-format-USB
nc-datadir
nc-database
nc-ramlogs
nc-swapfile
nc-static-IP
nc-wifi
UFW
nc-snapshot
nc-snapshot-auto
nc-snapshot-sync
nc-restore-snapshot
nc-audit
nc-hdd-monitor
nc-hdd-test
nc-zram
SSH
fail2ban
NFS
"

if isDocker; then
# in docker, just remove the volume for this
EXCL_DOCKER+="
nc-nextcloud
nc-init
"

# better use a designated container
EXCL_DOCKER+="
samba
"
fi

# check running apt or apt-get
pgrep -x "apt|apt-get" &>/dev/null && { echo "apt is currently running. Try again later";  exit 1; }

cp etc/library.sh "$LIBRARY"

# shellcheck disable=SC1090
source "$LIBRARY"

mkdir -p "$CONFDIR"

# prevent installing some ncp-apps in the containerized versions
if isDocker || isLXC; then
  for opt in $EXCL_DOCKER; do
    touch "$CONFDIR"/"$opt".cfg
  done
fi

# copy all files in bin and etc
cp -r bin/* /usr/local/bin/
find etc -maxdepth 1 -type f ! -path etc/ncp.cfg -exec cp '{}' /usr/local/etc \;
cp -n etc/ncp.cfg /usr/local/etc/ncp.cfg
cp -r etc/ncp-templates /usr/local/etc/

# install new entries of ncp-config and update others
for file in etc/ncp-config.d/*; do
  [ -f "$file" ] || continue;    # skip dirs

  # install new ncp_apps
  [ -f /usr/local/"$file" ] || {
    installApp "$(basename "$file" .cfg)"
  }

  # keep saved cfg values
  [ -f /usr/local/"$file" ] && {
    len="$(jq '.params | length' /usr/local/"$file")"
    for (( i = 0 ; i < len ; i++ )); do
      id="$(jq -r ".params[$i].id" /usr/local/"$file")"
      val="$(jq -r ".params[$i].value" /usr/local/"$file")"

      for (( j = 0 ; j < len ; j++ )); do
        idnew="$(jq -r ".params[$j].id" "$file")"
        [ "$idnew" == "$id" ] && {
          cfg="$(jq ".params[$j].value = \"$val\"" "$file")"
          break
        }
      done

      echo "$cfg" > "$file"
    done
  }

  # configure if active by default
  [ -f /usr/local/"$file" ] || {
    [[ "$(jq -r ".params[0].id"    "$file")" == "ACTIVE" ]] && \
    [[ "$(jq -r ".params[0].value" "$file")" == "yes"    ]] && {
      cp "$file" /usr/local/"$file"
      runApp "$(basename "$file" .cfg)"
    }
  }

  cp "$file" /usr/local/"$file"

done

# update NCVER in ncp.cfg and nc-nextcloud.cfg (for nc-autoupdate-nc and nc-update-nextcloud)
LOCAL_NCP_CONFIG='/usr/local/etc/ncp.cfg'
NCP_CONFIG='etc/ncp.cfg'
verNextcloud="$(jq -r '.nextcloud_version' "$NCP_CONFIG")"
cfg="$(jq ".nextcloud_version = \"$verNextcloud\"" "$LOCAL_NCP_CONFIG")"
echo "$cfg" > "$LOCAL_NCP_CONFIG"

NEXTCLOUD_CONFIG='etc/ncp-config.d/nc-nextcloud.cfg'
LOCAL_NEXTCLOUD_CONFIG='/usr/local/etc/ncp-config.d/nc-nextcloud.cfg'
cfg="$(jq ".params[0].value = \"$verNextcloud\"" "$NEXTCLOUD_CONFIG")"
echo "$cfg" > "$LOCAL_NEXTCLOUD_CONFIG"

# install localization files
cp -rT etc/ncp-config.d/l10n "$CONFDIR"/l10n

# these files can contain sensitive information, such as passwords
chown -R root:www-data "$CONFDIR"
chmod 660 "$CONFDIR"/*
chmod 750 "$CONFDIR"/l10n

# install web interface
cp -r ncp-web /var/www/
chown -R www-data:www-data /var/www/ncp-web
chmod 770                  /var/www/ncp-web

# install NC app
rm -rf /var/www/ncp-app
cp -r ncp-app /var/www/

# install ncp-previewgenerator
rm -rf /var/www/ncp-previewgenerator
cp -r ncp-previewgenerator /var/www/
chown -R www-data:         /var/www/ncp-previewgenerator

# copy NC app to nextcloud directory and enable it
rm -rf /var/www/nextcloud/apps/nextcloudpi
cp -r /var/www/ncp-app /var/www/nextcloud/apps/nextcloudpi
chown -R www-data:     /var/www/nextcloud/apps/nextcloudpi

# remove unwanted ncp-apps for containerized versions
if isDocker || isLXC; then
  for opt in $EXCL_DOCKER; do
    rm "$CONFDIR"/"$opt".cfg
    find /usr/local/bin/ncp -name "$opt.sh" -exec rm '{}' \;
  done
fi

# update services for docker
if isDocker; then
  cp build/docker/{lamp/010lamp,nextcloud/020nextcloud,nextcloudpi/000ncp} /etc/services-enabled.d
fi

# only live updates from here
[[ -f /.ncp-image ]] && exit 0

# update old images
./run_update_history.sh "$UPDATESDIR"

# update to the latest NC version
isAppActive nc-autoupdate-nc && runApp nc-autoupdate-nc

startNotifyPush

# Refresh ncp config values
# shellcheck disable=SC1090
source "$LIBRARY"

# check dist-upgrade
checkDistro "$NCPCFG" && checkDistro "$NCP_CONFIG" || {
  php_ver_new="$(jq -r '.php_version'   "$NCP_CONFIG")"
  release_new="$(jq -r '.release'       "$NCP_CONFIG")"

  cfg="$(jq '.php_version   = "'$php_ver_new'"' "$NCPCFG")"
  cfg="$(jq '.release       = "'$release_new'"' "$NCPCFG")"
  echo "$cfg" > /usr/local/etc/ncp-recommended.cfg

  [[ -f /.dockerenv ]] && \
    msg="Update to $release_new available. Get the latest container to upgrade" || \
    msg="Update to $release_new available. Type 'sudo ncp-dist-upgrade' to upgrade"
  echo "$msg"
  notifyAdmin "New distribution available" "$msg"
  wall "$msg"
  cat > /etc/update-motd.d/30ncp-dist-upgrade <<EOF
#!/usr/bin/env bash
new_cfg=/usr/local/etc/ncp-recommended.cfg
[[ -f "\${new_cfg}" ]] || exit 0
echo -e "${msg}"
EOF
chmod +x /etc/update-motd.d/30ncp-dist-upgrade
}

# Remove redundant opcache configuration.
# Related to https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=815968
# Bug #416 reappeared after we moved to php7.3 and debian buster packages.
[[ "$( ls -l /etc/php/"${PHPVER}"/fpm/conf.d/*-opcache.ini 2> /dev/null |  wc -l )" -gt 1 ]] && rm "$( ls /etc/php/"${PHPVER}"/fpm/conf.d/*-opcache.ini | tail -1 )"
[[ "$( ls -l /etc/php/"${PHPVER}"/cli/conf.d/*-opcache.ini 2> /dev/null |  wc -l )" -gt 1 ]] && rm "$( ls /etc/php/"${PHPVER}"/cli/conf.d/*-opcache.ini | tail -1 )"

exit 0

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
