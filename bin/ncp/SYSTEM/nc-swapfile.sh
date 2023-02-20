#!/usr/bin/env bash

# Data dir configuration script for NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/
#

# prtlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function prtln {
    printf '%s\n' "$@"
}

function is_active () {
    local DIR
    DIR="$( swapon -s | sed -n 2p | awk '{ print $1 }' )"
    [[ "$DIR" != "" ]] && [[ "$DIR" != '/var/swap' ]]
}

function configure () {
    local ORIG DSTDIR
    ORIG="$(swapon | tail -1 | awk '{ print $1 }')"
    DSTDIR="$(dirname "$SWAPFILE")"
    [[ "$ORIG" == "$SWAPFILE" ]] && { prtln "Nothing to do";                return 0; }
    [[ -d "$SWAPFILE"         ]] && { prtln "Is a directory: $SWAPFILE";    return 1; }
    [[ -d "$DSTDIR"           ]] || { prtln "Directory not found: $DSTDIR"; return 1; }
    
    [[ "$( stat -fc%T "$DSTDIR" )" == "btrfs" ]] && {
        prtln "BTRFS doesn't support swapfiles. You can still use nc-zram"
        return 1
    }

    if [[ "$(stat -fc%d /)" == "$(stat -fc%d "$DSTDIR")" ]]
    then prtln "Moving swapfile to another place in the same SD card" \
               "If you want to use an external mount, make sure it is properly set up"
    fi
    
    sed -i "s|#\?CONF_SWAPFILE=.*|CONF_SWAPFILE=$SWAPFILE|" '/etc/dphys-swapfile'
    sed -i "s|#\?CONF_SWAPSIZE=.*|CONF_SWAPSIZE=$SWAPSIZE|" '/etc/dphys-swapfile'
    grep -q vm.swappiness '/etc/sysctl.conf' || prtln "vm.swappiness = 10" >> '/etc/sysctl.conf' && sysctl --load &>/dev/null

    if dphys-swapfile setup && dphys-swapfile swapon
    then if [[ -f "$ORIG" ]] && swapoff "$ORIG"
         then rm --force "$ORIG"
              prtln "Successfully moved: swapfile"
              return 0
         fi
    fi

    prtln "Failed to move: swapfile"
    return 1
}

function install () {
    if [[ "$(stat -fc%T /var)" != "btrfs" ]]
    then apt_install dphys-swapfile
    fi
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

