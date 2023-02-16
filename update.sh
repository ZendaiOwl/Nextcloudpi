#!/usr/bin/env bash

# Updater for NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/
#

# This is placed here so the script doesn't fail should someone update from
# an old NextcloudPi version and source a library.sh without the log function

# Prints a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function Print {
    printf '%s\n' "$@"
}

# A log that uses log levels for logging different outputs
# Log levels  | Colour
# -2: Debug   | CYAN='\e[1;36m'
# -1: Info    | BLUE='\e[1;34m'
#  0: Success | GREEN='\e[1;32m'
#  1: Warning | YELLOW='\e[1;33m'
#  2: Error   | RED='\e[1;31m'
function log {
    if [[ "$#" -gt 0 ]]
    then declare -r LOGLEVEL="$1" TEXT="${*:2}"
         if [[ "$LOGLEVEL" =~ [(-2)-2] ]]
         then case "$LOGLEVEL" in
                  -2) printf '\e[1;36mDEBUG\e[0m %s\n'   "$TEXT" >&2 ;;
                  -1) printf '\e[1;34mINFO\e[0m %s\n'    "$TEXT"     ;;
                   0) printf '\e[1;32mSUCCESS\e[0m %s\n' "$TEXT"     ;;
                   1) printf '\e[1;33mWARNING\e[0m %s\n' "$TEXT"     ;;
                   2) printf '\e[1;31mERROR\e[0m %s\n'   "$TEXT" >&2 ;;
              esac
         else log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"
         fi
  fi
}

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Is set
# 1: Not set 
# 2: Invalid number of arguments
function isSet {
    [[ "$#" -ne 1 ]] && return 2
    [[ -v "$1" ]]
}

CONFDIR='/usr/local/etc/ncp-config.d'
UPDATESDIR='updates'
ETC_LIBRARY='etc/library.sh'
LOCAL_LIBRARY='/usr/local/etc/library.sh'

# shellcheck disable=SC1090
source "$LOCAL_LIBRARY"

if isSet DBG
then set -e"$DBG"
else set -e
fi

if is_docker
then log 1 "Docker images should be updated by replacing the container with the latest docker image.
Refer to the documentation for instructions at: https://docs.nextcloudpi.com or on the forum: https://help.nextcloud.com
If you are sure that you know what you are doing, you can still execute the update script by running it like the example below.
Ex: ALLOW_UPDATE_SCRIPT=1 ncp-update"
[[ "$ALLOW_UPDATE_SCRIPT" == "1" ]] || exit 1
fi


# These options doesn't make much sense to have in a docker container
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

# in docker, just remove the volume for this
if is_docker
then EXCL_DOCKER+="
nc-nextcloud
nc-init
"

# better use a designated container
EXCL_DOCKER+="
samba
"
fi

# Check if apt or apt-get is running
if pgrep -x "apt|apt-get" &>/dev/null
then log 2 "Apt is currently running. Try again later"; exit 1
fi

if ! cp "$ETC_LIBRARY" "$LOCAL_LIBRARY"
then log 2 "Failed to copy file: $ETC_LIBRARY"; exit 1
fi

# shellcheck disable=SC1090
source "$LOCAL_LIBRARY"

mkdir --parents "$CONFDIR"

# prevent installing some ncp-apps in the containerized versions
if is_docker || is_lxc
then for OPT in $EXCL_DOCKER
     do touch "$CONFDIR"/"$OPT".cfg
     done
fi

# copy all files in bin and etc
cp --recursive bin/* '/usr/local/bin/'
find 'etc' -maxdepth 1 -type f ! -path 'etc/ncp.cfg' -exec cp '{}' '/usr/local/etc' \;
cp --no-clobber 'etc/ncp.cfg' '/usr/local/etc/ncp.cfg'
cp --recursive  'etc/ncp-templates' '/usr/local/etc/'

# install new entries of ncp-config and update others
for FILE in etc/ncp-config.d/* # Skip directories
do if isDirectory "$FILE"
   then continue
   elif ! isFile "$FILE"
   then continue
   fi
   if ! isFile /usr/local/"$FILE"
   then install_app "$(basename "$FILE" .cfg)" # Install new NextcloudPi apps
   fi

  # keep saved cfg values
  if isFile /usr/local/"$FILE"
  then LENGTH="$(jq '.params | length' /usr/local/"$FILE")"
       for (( i = 0; i < "$LENGTH"; i++ ))
       do ID="$(jq -r ".params[$i].id" /usr/local/"$FILE")"
          VAL="$(jq -r ".params[$i].value" /usr/local/"$FILE")"
          for (( j = 0; j < "$LENGTH"; j++ ))
          do NEW_ID="$(jq -r ".params[$j].id" "$FILE")"
             if isMatch "$NEW_ID" "$ID"
             then CFG="$(jq ".params[$j].value = \"$VAL\"" "$FILE")"; break
             fi
          done
        Print "$CFG" > "$FILE"
        done
  fi

  # Configure if active by default
  if ! isFile /usr/local/"$FILE"
  then if isMatch "$(jq -r ".params[0].id" "$FILE")" "ACTIVE" && \
          isMatch "$(jq -r ".params[0].value" "$FILE")" "yes"
       then if ! cp "$FILE" /usr/local/"$FILE"
            then log 2 "Failed to copy file: $FILE"; exit 1
            fi
        run_app "$(basename "$FILE" .cfg)"
        fi
  fi
  
  if ! cp "$FILE" /usr/local/"$FILE"
  then log 2 "Failed to copy file: $FILE"; exit 1
  fi
  
done

# update NCVER in ncp.cfg and nc-nextcloud.cfg (for nc-autoupdate-nc and nc-update-nextcloud)
LOCAL_NCP_CONFIG='/usr/local/etc/ncp.cfg'
NCP_CONFIG='etc/ncp.cfg'
NC_VERSION="$(jq -r '.nextcloud_version' "$NCP_CONFIG")"
CFG="$(jq ".nextcloud_version = \"$NC_VERSION\"" "$LOCAL_NCP_CONFIG")"
Print "$CFG" > "$LOCAL_NCP_CONFIG"

NEXTCLOUD_CONFIG='etc/ncp-config.d/nc-nextcloud.cfg'
LOCAL_NEXTCLOUD_CONFIG='/usr/local/etc/ncp-config.d/nc-nextcloud.cfg'
CFG="$(jq ".params[0].value = \"$NC_VERSION\"" "$NEXTCLOUD_CONFIG")"
Print "$CFG" > "$LOCAL_NEXTCLOUD_CONFIG"

# install localization files
cp -rT etc/ncp-config.d/l10n "$CONFDIR"/l10n

# these files can contain sensitive information, such as passwords
chown -R root:www-data "$CONFDIR"
chmod 660 "$CONFDIR"/*
chmod 750 "$CONFDIR"/l10n

# install web interface
cp --recursive ncp-web            '/var/www/'
chown -R www-data:www-data        '/var/www/ncp-web'
chmod 770                         '/var/www/ncp-web'

# install NC app
rm --recursive --force            '/var/www/ncp-app'
cp --recursive ncp-app            '/var/www/'

# install ncp-previewgenerator
rm --recursive --force            '/var/www/ncp-previewgenerator'
cp -r ncp-previewgenerator        '/var/www/'
chown -R www-data:                '/var/www/ncp-previewgenerator'

# copy NC app to nextcloud directory and enable it
rm --recursive --force            '/var/www/nextcloud/apps/nextcloudpi'
cp --recursive '/var/www/ncp-app' '/var/www/nextcloud/apps/nextcloudpi'
chown -R www-data:                '/var/www/nextcloud/apps/nextcloudpi'

# remove unwanted ncp-apps for containerized versions
if is_docker || is_lxc
then for OPT in $EXCL_DOCKER
     do rm "$CONFDIR"/"$OPT".cfg
        find '/usr/local/bin/ncp' -name "${OPT}.sh" -exec rm '{}' \;
     done
fi

# update services for docker
if is_docker
then cp build/docker/{lamp/010lamp,nextcloud/020nextcloud,nextcloudpi/000ncp} '/etc/services-enabled.d'
fi

# only live updates from here
[[ -f '/.ncp-image' ]] && exit 0

# update old images
./run_update_history.sh "$UPDATESDIR"

# update to the latest NC version
is_active_app nc-autoupdate-nc && run_app nc-autoupdate-nc

start_notify_push

# Refresh ncp config values
# shellcheck disable=SC1090
source "$LIBRARY"

# check dist-upgrade
if ! check_distro "$NCPCFG" \
&& ! check_distro "$NCP_CONFIG"
then NEW_PHP_VERSION="$(jq -r '.php_version' "$NCP_CONFIG")"
     NEW_RELEASE="$(jq -r '.release'         "$NCP_CONFIG")"

     CFG="$(jq ".php_version   = \"$NEW_PHP_VERSION\"" "$NCPCFG")"
     CFG="$(jq ".release       = \"$NEW_RELEASE\""     "$NCPCFG")"
     Print "$CFG" > '/usr/local/etc/ncp-recommended.cfg'

     [[ -f '/.dockerenv' ]] && \
        MSG="Update to $NEW_RELEASE available. Get the latest container to upgrade" || \
        MSG="Update to $NEW_RELEASE available. Type 'sudo ncp-dist-upgrade' to upgrade"
        Print "$MSG"
        notify_admin "New distribution available" "$MSG"
        wall "$MSG"
        cat > '/etc/update-motd.d/30ncp-dist-upgrade' <<EOF
#!/usr/bin/env bash
NEW_CFG=/usr/local/etc/ncp-recommended.cfg
[[ -f "\$NEW_CFG" ]] || exit 0
echo -e "$MSG"
EOF
        chmod +x '/etc/update-motd.d/30ncp-dist-upgrade'
fi

# TODO: Change this to use find instead of ls
# Remove redundant opcache configuration.
# Related to https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=815968
# Bug #416 reappeared after we moved to php7.3 and debian buster packages.
[[ "$( ls -l /etc/php/"$PHPVER"/fpm/conf.d/*-opcache.ini 2>/dev/null |  wc -l )" -gt 1 ]] \
&& rm "$( ls /etc/php/"$PHPVER"/fpm/conf.d/*-opcache.ini | tail -1 )"

[[ "$( ls -l /etc/php/"$PHPVER"/cli/conf.d/*-opcache.ini 2>/dev/null |  wc -l )" -gt 1 ]] \
&& rm "$( ls /etc/php/"$PHPVER"/cli/conf.d/*-opcache.ini | tail -1 )"

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
