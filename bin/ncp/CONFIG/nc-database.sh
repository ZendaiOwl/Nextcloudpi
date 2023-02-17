#!/usr/bin/env bash

# Data dir configuration script for NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/
#

# Prints a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function Print {
    printf '%s\n' "$@"
}

# Checks if given path is a directory 
# Return codes
# 0: Is a directory
# 1: Not a directory
# 2: Invalid number of arguments
function isDirectory {
    [[ "$#" -ne 1 ]] && return 2
    [[ -d "$1" ]]
}

# Checks if 2 given String variables match
# Return codes
# 0: Is a match
# 1: Not a match
# 2: Invalid number of arguments
function isMatch {
    [[ "$#" -ne 2 ]] && return 2
    [[ "$1" == "$2" ]]
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
    if ! isDirectory "$SRCDIR"
    then Print "Database directory not found: $SRCDIR"
         return 1
    fi

    if isDirectory "$DBDIR"
    then if isEqual "$( find "$DBDIR" -maxdepth 0 -empty | wc -l )" 0
         then Print "Directory is not empty: $DBDIR"
              return 1
         fi
         if ! rmdir "$DBDIR"
         then Print "Failed to remove database directory: $DBDIR"
              return 1
         fi
    fi
    
    BASEDIR="$(dirname "$DBDIR")"
    mkdir --parents "$BASEDIR"
    
    if ! grep -q -e ext -e btrfs <(stat -fc%T "$BASEDIR")
    then Print "Only ext/btrfs filesystems can hold the data directory. (Found: '$(stat -fc%T "${BASEDIR}")"
         return 1
    fi
    if ! sudo -u mysql test -x "$BASEDIR"
    then Print "ERROR: MySQL user does not have permissions to execute in: $BASEDIR"
         return 1
    fi

    if isMatch "$(stat -fc%d /)" "$(stat -fc%d "$BASEDIR")"
    then Print "Moving database to the SD card"
         Print "If you want to use an external mount make sure to set it up properly"
    fi
    
    save_maintenance_mode
    
    Print "Moving database to: $DBDIR"
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

