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

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

# A log that uses log levels for logging different outputs
# Return codes
# 1: Invalid log level
# 2: Invalid number of arguments
# Log level   | colour
# -2: Debug   | CYAN='\e[1;36m'
# -1: Info    | BLUE='\e[1;34m'
#  0: Success | GREEN='\e[1;32m'
#  1: Warning | YELLOW='\e[1;33m'
#  2: Error   | RED='\e[1;31m'
function log {
    if [[ "$#" -gt 0 ]]; then
        if [[ "$1" =~ [(-2)-2] ]]; then
            case "$1" in
                -2) printf '\e[1;36mDEBUG\e[0m %s\n'   "${*:2}" >&2 ;;
                -1) printf '\e[1;34mINFO\e[0m %s\n'    "${*:2}"     ;;
                 0) printf '\e[1;32mSUCCESS\e[0m %s\n' "${*:2}"     ;;
                 1) printf '\e[1;33mWARNING\e[0m %s\n' "${*:2}"     ;;
                 2) printf '\e[1;31mERROR\e[0m %s\n'   "${*:2}" >&2 ;;
            esac
        else log 2 "Invalid log level: [ Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2 ]"
             return 1
        fi
    else log 2 "Invalid number of arguments: [ $#/1+ ]"
         return 2 
    fi
}

CONFDIR='/usr/local/etc/ncp-config.d'
UPDATESDIR='updates'
ETC_LIBRARY='etc/library.sh'
LOCAL_LIBRARY='/usr/local/etc/library.sh'

# shellcheck disable=SC1090
source "$LOCAL_LIBRARY"

if [[ -v DBG && -n "$DBG" ]]; then
    set -e"$DBG"
else
    set -e
fi

if is_docker; then
    log 1 "Docker images should be updated by replacing the container with the latest docker image.
Refer to the documentation for instructions at: https://docs.nextcloudpi.com or on the forum: https://help.nextcloud.com
If you are sure that you know what you are doing, you can still execute the update script by running it like the example below.
Ex: ALLOW_UPDATE_SCRIPT=1 ncp-update"
    [[ "$ALLOW_UPDATE_SCRIPT" == "1" ]] || {
        exit 1
    }
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
if is_docker; then
    EXCL_DOCKER+="
nc-nextcloud
nc-init
"
    # better use a designated container
    EXCL_DOCKER+="
samba
"
fi

# Check if apt or apt-get is running
if pgrep -x "apt|apt-get" &>/dev/null; then
    log 2 "Apt is currently running. Try again later"
    exit 1
fi

cp "$ETC_LIBRARY" "$LOCAL_LIBRARY" || {
    log 2 "Failed to copy file: $ETC_LIBRARY"
    exit 1
}

# shellcheck disable=SC1090
source "$LOCAL_LIBRARY"

mkdir --parents "$CONFDIR"

# prevent installing some ncp-apps in the containerized versions
if is_docker || is_lxc; then
    for OPT in $EXCL_DOCKER; do
        touch "$CONFDIR"/"$OPT".cfg
    done
fi

# copy all files in bin and etc
cp --recursive bin/* '/usr/local/bin/'
find 'etc' -maxdepth 1 -type f ! -path 'etc/ncp.cfg' -exec cp '{}' '/usr/local/etc' \;
cp --no-clobber 'etc/ncp.cfg' '/usr/local/etc/ncp.cfg'
cp --recursive  'etc/ncp-templates' '/usr/local/etc/'

# install new entries of ncp-config and update others
for FILE in etc/ncp-config.d/*; do # Skip directories
    [[ -d "$FILE" ]] && { continue; }
    [[ ! -f "$FILE" ]] && { continue; }
    # Install new NextcloudPi apps
    [[ ! -f /usr/local/"$FILE" ]] && {
        install_app "$(basename "$FILE" .cfg)"
    }

    # keep saved cfg values
    if [[ -f /usr/local/"$FILE" ]]; then
        LENGTH="$(jq '.params | length' /usr/local/"$FILE")"
        for (( i = 0; i < "$LENGTH"; i++ )); do
            ID="$(jq -r ".params[$i].id" /usr/local/"$FILE")"
            VAL="$(jq -r ".params[$i].value" /usr/local/"$FILE")"
            for (( j = 0; j < "$LENGTH"; j++ )); do
                NEW_ID="$(jq -r ".params[$j].id" "$FILE")"
                if [[ "$NEW_ID" == "$ID" ]]; then
                    CFG="$(jq ".params[$j].value = \"$VAL\"" "$FILE")"
                    break
                fi
            done
            println "$CFG" > "$FILE"
        done
    fi

    # Configure if active by default
    if [[ ! -f /usr/local/"$FILE" ]]; then
        if [[ "$(jq ".params[0].id" "$FILE")" == "ACTIVE" ]] \
        && [[ "$(jq ".params[0].value" "$FILE")" == "yes" ]]; then
            cp "$FILE" /usr/local/"$FILE" || {
                log 2 "Failed to copy file: $FILE"
                exit 1
            }
            run_app "$(basename "$FILE" .cfg)"
        fi
    fi
    cp "$FILE" /usr/local/"$FILE" || {
        log 2 "Failed to copy file: $FILE"
        exit 1
    }
done

# update NCVER in ncp.cfg and nc-nextcloud.cfg (for nc-autoupdate-nc and nc-update-nextcloud)
LOCAL_NCP_CONFIG='/usr/local/etc/ncp.cfg'
NCP_CONFIG='etc/ncp.cfg'
NC_VERSION="$(jq -r '.nextcloud_version' "$NCP_CONFIG")"
CFG="$(jq ".nextcloud_version = \"$NC_VERSION\"" "$LOCAL_NCP_CONFIG")"
println "$CFG" > "$LOCAL_NCP_CONFIG"

NEXTCLOUD_CONFIG='etc/ncp-config.d/nc-nextcloud.cfg'
LOCAL_NEXTCLOUD_CONFIG='/usr/local/etc/ncp-config.d/nc-nextcloud.cfg'
CFG="$(jq ".params[0].value = \"$NC_VERSION\"" "$NEXTCLOUD_CONFIG")"
println "$CFG" > "$LOCAL_NEXTCLOUD_CONFIG"

# install localization files
cp -rT 'etc/ncp-config.d/l10n'      "$CONFDIR"/l10n

# these files can contain sensitive information, such as passwords
chown --recursive 'root':'www-data' "$CONFDIR"
chmod 660 "$CONFDIR"/*
chmod 750 "$CONFDIR"/l10n

# install web interface
cp --recursive 'ncp-web'            '/var/www/'
chown -R 'www-data':'www-data'      '/var/www/ncp-web'
chmod 770                           '/var/www/ncp-web'

# install NC app
rm --recursive --force              '/var/www/ncp-app'
cp --recursive 'ncp-app'            '/var/www/'

# install ncp-previewgenerator
rm --recursive --force              '/var/www/ncp-previewgenerator'
cp --recursive ncp-previewgenerator '/var/www/'
chown --recursive 'www-data':       '/var/www/ncp-previewgenerator'

# copy NC app to nextcloud directory and enable it
rm --recursive --force              '/var/www/nextcloud/apps/nextcloudpi'
cp --recursive '/var/www/ncp-app'   '/var/www/nextcloud/apps/nextcloudpi'
chown --recursive 'www-data':       '/var/www/nextcloud/apps/nextcloudpi'

# remove unwanted ncp-apps for containerized versions
if is_docker || is_lxc; then
    for OPT in $EXCL_DOCKER; do
        rm "$CONFDIR"/"$OPT".cfg
        find '/usr/local/bin/ncp' -name "${OPT}.sh" -exec rm '{}' \;
     done
fi

# update services for docker
if is_docker; then
    cp build/docker/{lamp/010lamp,nextcloud/020nextcloud,nextcloudpi/000ncp} '/etc/services-enabled.d'
fi

# only live updates from here
[[ -f '/.ncp-image' ]] && {
    exit 0
}

# update old images
./run_update_history.sh "$UPDATESDIR"

# update to the latest NC version
is_active_app 'nc-autoupdate-nc' && {
    run_app 'nc-autoupdate-nc'
}

start_notify_push

# Refresh ncp config values
# shellcheck disable=SC1090
source "$LIBRARY"

# check dist-upgrade
if ! check_distro "$NCPCFG" \
&& ! check_distro "$NCP_CONFIG"; then
    NEW_PHP_VERSION="$(jq -r '.php_version' "$NCP_CONFIG")"
    NEW_RELEASE="$(jq -r '.release'         "$NCP_CONFIG")"

    CFG="$(jq ".php_version   = \"$NEW_PHP_VERSION\"" "$NCPCFG")"
    CFG="$(jq ".release       = \"$NEW_RELEASE\""     "$NCPCFG")"
    println "$CFG" > '/usr/local/etc/ncp-recommended.cfg'

    if [[ -f '/.dockerenv' ]]; then
        MSG="Update to $NEW_RELEASE available. Get the latest container to upgrade"
    else
        MSG="Update to $NEW_RELEASE available. Type 'sudo ncp-dist-upgrade' to upgrade"
    fi
        
        println "$MSG"
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
[[ "$( ls -l /etc/php/"$PHPVER"/fpm/conf.d/*-opcache.ini 2>/dev/null |  wc -l )" -gt 1 ]] && {
    rm "$( ls /etc/php/"$PHPVER"/fpm/conf.d/*-opcache.ini | tail -1 )"
}

[[ "$( ls -l /etc/php/"$PHPVER"/cli/conf.d/*-opcache.ini 2>/dev/null |  wc -l )" -gt 1 ]] && {
    rm "$( ls /etc/php/"$PHPVER"/cli/conf.d/*-opcache.ini | tail -1 )"
}

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
