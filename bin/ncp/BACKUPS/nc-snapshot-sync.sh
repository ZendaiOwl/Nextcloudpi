#!/usr/bin/env bash

# Sync Nextcloud BTRFS snapshots
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

# Prints a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function Print () {
    printf '%s\n' "$@"
}

function tmpl_get_destination () {
    (
        # shellcheck disable=SC1091
        . /usr/local/etc/library.sh
        find_app_param nc-snapshot-sync DESTINATION
    )
}

function tmpl_is_destination_local () {
    (
        # shellcheck disable=SC1091
        . /usr/local/etc/library.sh
        is_active_app nc-snapshot-sync || exit 1
        ! [[ "$(find_app_param nc-snapshot-sync DESTINATION)" =~ .*"@".*":".* ]]
    )
}

function is_active () {
    [[ "$ACTIVE" == "yes" ]]
}

function install () {
    local -r ARGS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    local -r URL='https://raw.githubusercontent.com/nachoparker/btrfs-sync/master/btrfs-sync'
    local -r FILE='/usr/local/bin/btrfs-sync'
    apt-get update  "${ARGS[@]}"
    apt-get install "${ARGS[@]}" pv openssh-client
    wget "$URL" -O "$FILE"
    chmod +x       "$FILE"
}

function configure () {
    [[ "$ACTIVE" != "yes" ]] && {
        rm --force /etc/cron.d/ncp-snapsync-auto
        service cron restart
        Print "Snapshot sync disabled"
        return 0
    }
    local NET DST SSH
    # checks
    [[ -d "$SNAPDIR" ]] || { Print "Directory not found: $SNAPDIR"; return 1; }
    if ! [[ -f /root/.ssh/id_rsa ]]
    then ssh-keygen -N "" -f /root/.ssh/id_rsa
    fi
    
    [[ "$DESTINATION" =~ : ]] && {
        NET="${DESTINATION//:.*/}"
        DST="${DESTINATION//.*:/}"
        #NET="$( sed 's|:.*||' <<<"$DESTINATION" )"
        #DST="$( sed 's|.*:||' <<<"$DESTINATION" )"
        SSH=(ssh -o "BatchMode=yes" "$NET")
        "${SSH[@]}" : || { Print "SSH non-interactive not properly configured"; return 1; }
    } || DST="$DESTINATION"

    [[ "$( "${SSH[@]}" stat -fc%T "$DST" )" != "btrfs" ]] && {
        Print "Not a BTRFS filesystem: $DESTINATION"
        return 1
    }
    
    [[ "$COMPRESSION" == "yes" ]] && ZIP="-z"
    
    echo "30  4  */$SYNCDAYS  *  *  root  /usr/local/bin/btrfs-sync -qd $ZIP \"$SNAPDIR\" \"$DESTINATION\"" > /etc/cron.d/ncp-snapsync-auto
    chmod 644 /etc/cron.d/ncp-snapsync-auto
    service cron restart
    (
        # shellcheck disable=SC1090
        . "${BINDIR}/SYSTEM/metrics.sh"
        reload_metrics_config
    )
    Print "Snapshot sync enabled"
}

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

