#!/usr/bin/env bash

# NFS server for Raspbian 
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at: https://ownyourbits.com
#

# prtlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function prtln () {
    printf '%s\n' "$@"
}

function install () {
    local -r ARGS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    apt-get update  "${ARGS[@]}"
    apt-get install "${ARGS[@]}" nfs-kernel-server 
    systemctl disable nfs-kernel-server
    systemctl mask nfs-blkmap
}

function configure () {
    if [[ "$ACTIVE" != "yes" ]]
    then service nfs-kernel-server stop
         systemctl disable nfs-kernel-server
         prtln "NFS disabled"
         return
    fi
    
    # CHECKS
    ################################
    id    "$USER"  &>/dev/null || { echo "user $USER does not exist"  ; return 1; }
    id -g "$GROUP" &>/dev/null || { echo "group $GROUP does not exist"; return 1; }
    [[ -d "$DIR" ]] || { prtln "Directory not found: $DIR. Creating"; mkdir --parents "$DIR"; }
    if [[ "$( stat -fc%d / )" == "$( stat -fc%d "$DIR" )" ]]
    then prtln "INFO: mounting a in the SD card" "If you want to use an external mount, make sure it is properly set up"
    fi
    # CONFIG
    ################################
    cat > /etc/exports <<EOF
"$DIR" "$SUBNET"(rw,sync,all_squash,anonuid="$(id -u "$USER")",anongid="$(id -g "$GROUP")",no_subtree_check)
EOF

    systemctl enable rpcbind
    systemctl enable nfs-kernel-server
    service nfs-kernel-server restart
    prtln "Enabled: NFS"
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
