#!/usr/bin/env bash

# Nextcloud BTRFS snapshots
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

# prtlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function prtln () {
    printf '%s\n' "$@"
}

function install () {
    local -r URL='https://raw.githubusercontent.com/nachoparker/btrfs-snp/master/btrfs-snp'
    local -r FILE='/usr/local/bin/btrfs-snp'
    wget "$URL" -O "$FILE"
    chmod +x       "$FILE"
}

function configure () {
    save_maintenance_mode
    
    local DATADIR MOUNTPOINT
    DATADIR="$( get_nc_config_value datadirectory )" || {
        prtln "Error reading data directory. Is Nextcloud running?"
        return 1
    }
    
    # file system check
    MOUNTPOINT="$( stat -c "%m" "$DATADIR" )" || return 1
    [[ "$( stat -fc%T "$MOUNTPOINT" )" != "btrfs" ]] && {
        prtln "Not a BTRFS filesystem: $MOUNTPOINT"; return 1
    }
    
    btrfs-snp "$MOUNTPOINT" manual "$LIMIT" 0 ../ncp-snapshots
    
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

