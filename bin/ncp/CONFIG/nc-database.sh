#!/usr/bin/env bash

# Data dir configuration script for NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/
#

# Prints a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function Print {
    printf '%s\n' "$@"
}

is_active() {
    local SRCDIR
    SRCDIR="$(grep datadir /etc/mysql/mariadb.conf.d/90-ncp.cnf | awk -F "= " '{ print $2 }')"
    [[ "$SRCDIR" != "/var/lib/mysql" ]]
}

tmpl_db_dir() {
    if is_active_app nc-database
    then find_app_param nc-database DBDIR
    fi
}

configure() {
    local SRCDIR
    SRCDIR="$(grep datadir /etc/mysql/mariadb.conf.d/90-ncp.cnf | awk -F "= " '{ print $2 }')"
    [[ -d "$SRCDIR" ]] || { echo -e "database directory $SRCDIR not found"; return 1; }
    
    [[ -d "$DBDIR" ]] && {
        [[ "$( find "$DBDIR" -maxdepth 0 -empty | wc -l )" == 0 ]] && {
            Print "$DBDIR is not empty"; return 1
        }
        rmdir "$DBDIR"
    }
    
    local BASEDIR="$(dirname "$DBDIR")"
    mkdir --parents "$BASEDIR"
    
    grep -q -e ext -e btrfs <(stat -fc%T "$BASEDIR") || { Print "Only ext/btrfs filesystems can hold the data directory (found '$(stat -fc%T "${BASEDIR}")"; return 1; }
    
    sudo -u mysql test -x "$BASEDIR" || { Print "ERROR: MySQL user does not have permission to access: $BASEDIR"; return 1; }
    
    [[ "$(stat -fc%d /)" == "$(stat -fc%d "$BASEDIR")" ]] && \
    Print "INFO: moving database to the SD card" "If you want to use an external mount make sure to set it up properly"
    
    save_maintenance_mode
    
    Print "Moving database to: $DBDIR"
    service mysql stop
    mv "$SRCDIR" "$DBDIR"
    install_template "mysql/90-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/90-ncp.cnf"
    service mysql start
    
    restore_maintenance_mode
}

install(){ :; }

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

