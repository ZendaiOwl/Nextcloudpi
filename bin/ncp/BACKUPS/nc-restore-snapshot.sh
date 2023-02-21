#!/usr/bin/env bash

#!/usr/bin/env bash
# Nextcloud restore backup
#
# Copyleft 2019 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at nextcloudpi.com
#

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

function install { :; }

function configure {
    [[ -d "$SNAPSHOT" ]] || { println "Directory not found: $SNAPSHOT"; return 1; }
    
    local DATADIR MOUNTPOINT
    DATADIR="$( get_nc_config_value datadirectory )" || {
        println "Error reading data directory. Is Nextcloud running?"; return 1
    }
    
    # file system check
    MOUNTPOINT="$( stat -c "%m" "$DATADIR" )" || return 1
    [[ "$( stat -fc%T "$MOUNTPOINT" )" != "btrfs" ]] && {
        println "Data directory is not in a BTRFS filesystem: $DATADIR"; return 1
    }
    
    # file system check
    btrfs subvolume show "$SNAPSHOT" &>/dev/null || {
        println "Not a BTRFS snapshot: $SNAPSHOT"; return 1
    }
    
    btrfs-snp "$MOUNTPOINT" autobackup 0 0 ../ncp-snapshots || return 1
    
    save_maintenance_mode
    btrfs subvolume delete   "$DATADIR" || return 1
    btrfs subvolume snapshot "$SNAPSHOT" "$DATADIR"
    restore_maintenance_mode
    ncp-scan
    
    println "Snapshot restored: $SNAPSHOT"
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

