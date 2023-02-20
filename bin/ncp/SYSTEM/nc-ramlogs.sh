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
  systemctl -q is-active log2ram &>/dev/null || systemctl -q is-active armbian-ramlog &>/dev/null
}

function install () {
    VERSION='1.5.2'
    if [[ -d '/var/log.hdd' ]] || [[ -d '/var/hdd.log' ]]
    then prtln "log2ram detected, not installing"
         return
    fi
    if ! cd '/tmp'
    then prtln "Failed to change directory to: /tmp"; return 1
    fi
    curl -Lo log2ram.tar.gz https://github.com/azlux/log2ram/archive/"$VERSION".tar.gz
    tar xf 'log2ram.tar.gz'
    if ! cd log2ram-"$VERSION"
    then prtln "Failed to change directory to: log2ram-$VERSION"; return 1
    fi
    sed -i '/systemctl -q is-active log2ram/d' 'install.sh'
    sed -i '/systemctl enable log2ram/d'       'install.sh'
    chmod +x 'install.sh' && sudo './install.sh'
    if ! cd ..
    then prtln "Failed to change directory to: .."; return 1
    fi
    rm --recursive log2ram-"$VERSION" 'log2ram.tar.gz'
    rm '/etc/cron.daily/log2ram' '/usr/local/bin/uninstall-log2ram.sh'
}

function configure () {
    if [[ -f '/lib/systemd/system/armbian-ramlog.service' ]]
    then local RAMLOG='armbian-ramlog'
    else local RAMLOG='log2ram'
    fi
    
    if [[ "$ACTIVE" != "yes" ]]
    then systemctl disable "$RAMLOG"
         systemctl stop    "$RAMLOG"
         prtln "Logs in SD. Reboot to take effect"
         return
    fi
    
    systemctl enable "$RAMLOG"
    systemctl start  "$RAMLOG"
    
    prtln "Logs in RAM. Reboot to take effect"
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
