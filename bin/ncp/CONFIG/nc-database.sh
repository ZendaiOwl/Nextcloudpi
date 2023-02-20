#!/usr/bin/env bash

# Data dir configuration script for NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/
#

# print_lines a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function print_line {
    printf '%s\n' "$@"
}

function is_active () {
    local SRCDIR
    SRCDIR="$(grep 'datadir' '/etc/mysql/mariadb.conf.d/90-ncp.cnf' | awk -F "= " '{ print $2 }')"
    [[ "$SRCDIR" != '/var/lib/mysql' ]]
}

function tmpl_db_dir () {
    if is_active_app 'nc-database'
    then find_app_param 'nc-database' 'DBDIR'
    fi
}

function configure () {
    local SRCDIR BASEDIR
    SRCDIR="$(grep 'datadir' '/etc/mysql/mariadb.conf.d/90-ncp.cnf' | awk -F "= " '{ print $2 }')"
    if [[ ! -d "$SRCDIR" ]]
    then print_line "Database directory not found: $SRCDIR"
         return 1
    fi

    if [[ -d "$DBDIR" ]]
    then if [[ "$( find "$DBDIR" -maxdepth 0 -empty | wc -l )" -eq 0 ]]
         then print_line "Directory is not empty: $DBDIR"
              return 1
         fi
         if ! rmdir "$DBDIR"
         then print_line "Failed to remove database directory: $DBDIR"
              return 1
         fi
    fi
    
    BASEDIR="$(dirname "$DBDIR")"
    mkdir --parents "$BASEDIR"
    
    if ! grep -q -e ext -e btrfs <(stat -fc%T "$BASEDIR")
    then print_line "Only ext/btrfs filesystems can hold the data directory. (Found: '$(stat -fc%T "${BASEDIR}")"
         return 1
    fi
    if ! sudo -u mysql test -x "$BASEDIR"
    then print_line "ERROR: MySQL user does not have permissions to execute in: $BASEDIR"
         return 1
    fi

    if [[ "$(stat -fc%d /)" == "$(stat -fc%d "$BASEDIR")" ]]
    then print_line "Moving database to the SD card"
         print_line "If you want to use an external mount make sure to set it up properly"
    fi
    
    save_maintenance_mode
    
    print_line "Moving database to: $DBDIR"
    service mysql stop
    mv "$SRCDIR" "$DBDIR"
    install_template 'mysql/90-ncp.cnf.sh' '/etc/mysql/mariadb.conf.d/90-ncp.cnf'
    service mysql start
    
    restore_maintenance_mode
}

function install () { :; }

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

