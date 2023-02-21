#!/usr/bin/env bash

#
# NextcloudPi scheduled datadir BTRFS snapshots
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
    local -r URL='https://raw.githubusercontent.com/nachoparker/btrfs-snp/master/btrfs-snp'
    local -r FILE='/usr/local/bin/btrfs-snp'
    wget "$URL" -O "$FILE"
    chmod +x       "$FILE"
}

function configure {
    [[ "$ACTIVE" != "yes" ]] && {
        rm --force '/etc/cron.hourly/btrfs-snp'
        println "Automatic snapshots disabled"
        return 0
    }
    
    cat > '/etc/cron.hourly/btrfs-snp' <<EOF
#!/usr/bin/env bash

source /usr/local/etc/library.sh

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

DATADIR="\$(get_nc_config_value datadirectory)" || {
    println "Error reading data directory. Is Nextcloud running and configured?"
    exit 1
}

# file system check
MOUNTPOINT="\$(stat -c "%m" "\$DATADIR")" || return 1
[[ "\$( stat -fc%T "\$MOUNTPOINT" )" != "btrfs" ]] && {
    println "Not a BTRFS filesystem: \$MOUNTPOINT"
    exit 1
}

/usr/local/bin/btrfs-snp \$MOUNTPOINT hourly  24 3600    ../ncp-snapshots
/usr/local/bin/btrfs-snp \$MOUNTPOINT daily    7 86400   ../ncp-snapshots
/usr/local/bin/btrfs-snp \$MOUNTPOINT weekly   4 604800  ../ncp-snapshots
/usr/local/bin/btrfs-snp \$MOUNTPOINT monthly 12 2592000 ../ncp-snapshots
EOF
    chmod 755 '/etc/cron.hourly/btrfs-snp'
    println "Automatic snapshots enabled"
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

