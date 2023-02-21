#!/usr/bin/env bash

# Sync Nextcloud datafolder through rsync
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

function install {
    local -r ARGS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    apt-get update  "${ARGS[@]}"
    apt-get install "${ARGS[@]}" rsync openssh-client
}

function configure {
    save_maintenance_mode
    
    local DATADIR
    DATADIR="$( get_nc_config_value datadirectory )" || {
        println "Error reading data directory. Is Nextcloud running and configured?"
        return 1;
    }
    
    rsync -ax -e "ssh -p $PORTNUMBER" --delete "$DATADIR" "$DESTINATION"
    
    restore_maintenance_mode
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

