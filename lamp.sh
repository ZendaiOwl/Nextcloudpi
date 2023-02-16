#!/usr/bin/env bash

# Nextcloud LAMP base installation on Raspbian
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# Usage:
#
#   ./installer.sh lamp.sh <IP> (<img>)
#
# See installer.sh instructions for details
#
# Notes:
#   Upon each necessary restart, the system will cut the SSH session, therefore
#   it is required to save the state of the installation. See variable $STATE_FILE
#   It will be necessary to invoke this a number of times for a complete installation
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

# Prints a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function Print {
    printf '%s\n' "$@"
}

# A log that uses log levels for logging different outputs
# Log levels  | Colour
# -2: Debug   | CYAN='\e[1;36m'
# -1: Info    | BLUE='\e[1;34m'
#  0: Success | GREEN='\e[1;32m'
#  1: Warning | YELLOW='\e[1;33m'
#  2: Error   | RED='\e[1;31m'
function log {
    if [[ "$#" -gt 0 ]]
    then declare -r LOGLEVEL="$1" TEXT="${*:2}"
         if [[ "$LOGLEVEL" =~ [(-2)-2] ]]
         then case "$LOGLEVEL" in
                  -2) printf '\e[1;36mDEBUG\e[0m %s\n'   "$TEXT" >&2 ;;
                  -1) printf '\e[1;34mINFO\e[0m %s\n'    "$TEXT"     ;;
                   0) printf '\e[1;32mSUCCESS\e[0m %s\n' "$TEXT"     ;;
                   1) printf '\e[1;33mWARNING\e[0m %s\n' "$TEXT"     ;;
                   2) printf '\e[1;31mERROR\e[0m %s\n'   "$TEXT" >&2 ;;
              esac
         else log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"
         fi
  fi
}

#########################
# Bash - Test Functions #
#########################

# Check if user ID executing script is 0 or not
# Return codes
# 0: Is root
# 1: Not root
# 2: Invalid number of arguments
function isRoot {
    [[ "$#" -ne 0 ]] && return 2
    [[ "$EUID" -eq 0 ]]
}

# Checks if a user exists
# Return codes
# 0: Is a user
# 1: Not a user
# 2: Invalid number of arguments
function isUser {
    [[ "$#" -ne 1 ]] && return 2
    if id -u "$1" &>/dev/null
    then return 0
    else return 1
    fi
}

# Checks if a given path to a file exists
# Return codes
# 0: Path exist
# 1: No such path
# 2: Invalid number of arguments
function isPath {
    [[ "$#" -ne 1 ]] && return 2
    [[ -e "$1" ]]
}

# Checks if a given path is a regular file
# 0: Is a file
# 1: Not a file
# 2: Invalid number of arguments
function isFile {
    [[ "$#" -ne 1 ]] && return 2
    [[ -f "$1" ]]
}

# Checks if a given path is a readable file
# 0: Is readable
# 1: Not readable
# 2: Invalid number of arguments
function isReadable {
    [[ "$#" -ne 1 ]] && return 2
    [[ -r "$1" ]]
}

# Checks if a given path is a writable file
# 0: Is writable
# 1: Not writable
# 2: Invalid number of arguments
function isWritable {
    [[ "$#" -ne 1 ]] && return 2
    [[ -w "$1" ]]
}

# Checks if a given path is an executable file
# 0: Is executable
# 1: Not executable
# 2: Invalid number of arguments
function isExecutable {
    [[ "$#" -ne 1 ]] && return 2
    [[ -x "$1" ]]
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

# Checks if given path is a named pipe
# Return codes
# 0: Is a named pipe
# 1: Not a named pipe
# 2: Invalid number of arguments
function isPipe {
    [[ "$#" -ne 1 ]] && return 2
    [[ -p "$1" ]]
}

# Checks if the first given digit is greater than the second digit
# Return codes
# 0: Is greater
# 1: Not greater
# 2: Invalid number of arguments
function isGreater {
    [[ "$#" -ne 2 ]] && return 2
    [[ "$1" -gt "$2" ]]
}

# Checks if the first given digit is greater than or equal to the second digit
# Return codes
# 0: Is greater than or equal
# 1: Not greater than or equal
# 2: Invalid number of arguments
function isGreaterOrEqual {
    [[ "$#" -ne 2 ]] && return 2
    [[ "$1" -ge "$2" ]]
}

# Checks if the first given digit is less than the second digit
# Return codes
# 0: Is less
# 1: Not less
# 2: Invalid number of arguments
function isLess {
    [[ "$#" -ne 2 ]] && return 2
    [[ "$1" -lt "$2" ]]
}

# Checks if a given variable has been set and is a name reference
# Return codes
# 0: Is set name reference
# 1: Not set name reference
# 2: Invalid number of arguments
function isReference {
    [[ "$#" -ne 1 ]] && return 2
    [[ -R "$1" ]]
}

# Checks if a given path is a socket
# Return codes
# 0: Is a socket
# 1: Not a socket
# 2: Invalid number of arguments
function isSocket {
    [[ "$#" -ne 1 ]] && return 2
    [[ -S "$1" ]]
}

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Is set
# 1: Not set 
# 2: Invalid number of arguments
function isSet {
    [[ "$#" -ne 1 ]] && return 2
    [[ -v "$1" ]]
}

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Not set
# 1: Is set 
# 2: Invalid number of arguments
function notSet {
    [[ "$#" -ne 1 ]] && return 2
    [[ ! -v "$1" ]]
}

# Checks if 2 given digits are equal
# Return codes
# 0: Is equal
# 1: Not equal
# 2: Invalid number of arguments
function isEqual {
    [[ "$#" -ne 2 ]] && return 2
    [[ "$1" -eq "$2" ]]
}

# Checks if 2 given digits are not equal
# Return codes
# 0: Not equal
# 1: Is equal
# 2: Invalid number of arguments
function notEqual {
    [[ "$#" -ne 2 ]] && return 2
    [[ "$1" -ne "$2" ]]
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

# Checks if 2 given String variables do not match
# Return codes
# 0: Not a match
# 1: Is a match
# 2: Invalid number of arguments
function notMatch {
    [[ "$#" -ne 2 ]] && return 2
    [[ "$1" != "$2" ]]
}

# Checks if a given String is zero
# Return codes
# 0: Is zero
# 1: Not zero
# 2: Invalid number of arguments
function isZero {
    [[ "$#" -ne 1 ]] && return 2
    [[ -z "$1" ]]
}

# Checks if a given String is not zero
# Return codes
# 0: Not zero
# 1: Is zero
# 2: Invalid number of arguments
function notZero {
    [[ "$#" -ne 1 ]] && return 2
    [[ -n "$1" ]]
}

# Checks if a given variable is an array or not
# Return codes
# 0: Variable is an array
# 1: Variable is not an array
# 2: Missing argument: Variable to check
function isArray {
    if [[ "$#" -ne 1 ]]
    then return 2
    elif ! declare -a "$1" &>/dev/null
    then return 1
    else return 0
    fi
}

# Test if a function() is available
# Return codes
# 0: Available
# 1: Unvailable
# 2: Too many/few arguments
function isFunction {
    if [[ "$#" -eq 1 ]]
    then declare -r FUNC="$1"
         if declare -f "$FUNC" &>/dev/null
         then return 0
         else return 1
         fi
    else return 2
    fi
}

# Checks if a given pattern in a String
# Return codes
# 0: Has String pattern
# 1: No String pattern
# 2: Invalid number of arguments
function hasText {
    [[ "$#" -ne 2 ]] && return 2
    declare -r PATTERN="$1" STRING="$2"
    [[ "$STRING" == *"$PATTERN"* ]]
}

# Checks if a command exists on the system
# Return status codes
# 0: Command exists on the system
# 1: Command is unavailable on the system
# 2: Missing command argument to check
function hasCMD {
    if [[ "$#" -eq 1 ]]
    then declare -r CHECK="$1"
         if command -v "$CHECK" &>/dev/null
         then return 0
         else return 1
         fi
    else return 2
    fi
}

# Checks if a package exists on the system
# Return status codes
# 0: Package is installed
# 1: Package is not installed but is available in apt
# 2: Package is not installed and is not available in apt
# 3: Missing package argument to check
function hasPKG {
    if [[ "$#" -eq 1 ]]
    then declare -r CHECK="$1"
         if dpkg-query --status "$CHECK" &>/dev/null
         then return 0
         elif apt-cache show "$CHECK" &>/dev/null
         then return 1
         else return 2
         fi
    else return 3
    fi
}

############################
# Bash - Install Functions #
############################

# Update apt list and packages
# Return codes
# 0: Install completed
# 1: Coudn't update apt list
# 2: Invalid number of arguments
function updatePKG {
    if [[ "$#" -ne 0 ]]
    then log 2 "Invalid number of arguments, requires none"; return 2
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOUPDATE=(sudo apt-get "${OPTIONS[@]}" update) \
                    ROOTUPDATE=(apt-get "${OPTIONS[@]}" update)
        if isRoot
        then log -1 "Updating apt lists"
             if "${ROOTUPDATE[@]}" &>/dev/null
             then log 0 "Apt list updated"
             else log 2 "Couldn't update apt lists"; return 1
             fi
        else log -1 "Updating apt lists"
             if "${SUDOUPDATE[@]}" &>/dev/null
             then log 0 "Apt list updated"
             else log 2 "Couldn't update apt lists"; return 1
             fi
        fi
    fi
}

# Installs package(s) using the package manager and pre-configured options
# Return codes
# 0: Install completed
# 1: Coudn't update apt list
# 2: Error during installation
# 3: Missing package argument
function installPKG {
    if [[ "$#" -eq 0 ]]
    then log 2 "Requires: [PKG(s) to install]"; return 3
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOINSTALL=(sudo apt-get "${OPTIONS[@]}" install) \
                    ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
         declare -a PKG=(); IFS=' ' read -ra PKG <<<"$@"
        if isRoot
        then log -1 "Installing ${PKG[*]}"
             if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "${PKG[@]}"
             then log 0 "Installation completed"; return 0
             else log 2 "Something went wrong during installation"; return 2
             fi
        else log -1 "Installing ${PKG[*]}"
             if DEBIAN_FRONTEND=noninteractive "${SUDOINSTALL[@]}" "${PKG[@]}"
             then log 0 "Installation completed"; return 0
             else log 2 "Something went wrong during installation"; return 1
             fi
        fi
    fi
}

function install {
    set -x
    local -r DBPID_FILE='/run/mysqld/mysqld.pid' \
             DBSOCKET='/run/mysqld/mysqld.sock' \
             DBDAEMON='/run/mysqld' \
             DBUSER='mysql' \
             PHPDAEMON='/run/php' \
             PHPREPO='https://packages.sury.org/php' \
             PHPREPO_GPGKEY='https://packages.sury.org/php/apt.gpg' \
             PHPAPTLIST='/etc/apt/sources.list.d/php.list' \
             MYCNF_FILE='/root/.my.cnf'

    # MariaDB password
    local DBPASSWD="default" DBPID
    
    # Setup apt repository for php 8
    wget -O '/etc/apt/trusted.gpg.d/php.gpg' "$PHPREPO_GPGKEY"
    echo "deb ${PHPREPO}/ ${RELEASE%-security} main" > "$PHPAPTLIST"
    updatePKG
    installPKG apt-utils cron curl apache2

    ls -l '/var/lock' || true
    # Fix missing lock directory
    mkdir --parents '/run/lock'
    apache2ctl -V || true

    # Create systemd users to keep uids persistent between containers
    if ! isUser systemd-resolve
    then addgroup --quiet --system systemd-journal
         adduser  --quiet -u 180 --system --group --no-create-home --home /run/systemd \
                  --gecos "systemd Network Management" systemd-network
         adduser  --quiet -u 181 --system --group --no-create-home --home /run/systemd \
                  --gecos "systemd Resolver" systemd-resolve
    fi
    
    install_with_shadow_workaround --no-install-recommends systemd
    installPKG php"$PHPVER" php"$PHPVER"-{curl,gd,fpm,cli,opcache,mbstring,xml,zip,fileinfo,ldap,intl,bz2,mysql}

    mkdir --parents "$PHPDAEMON"

    Print "[mysqld]" "[client]" "password=$DBPASSWD" > "$MYCNF_FILE"
    #Print "[client]" "password=$DBPASSWD" > /root/.my.cnf
    chmod 600 "$MYCNF_FILE"

    debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password password $DBPASSWD"
    debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password_again password $DBPASSWD"
    
    installPKG mariadb-server
    
    mkdir --parents "$DBDAEMON"
    chown "$DBUSER" "$DBDAEMON"

    ####################
    # CONFIGURE APACHE #
    ####################
    
    install_template "apache2/http2.conf.sh" "/etc/apache2/conf-available/http2.conf" "--defaults"

    ##################
    # CONFIGURE PHP7 #
    ##################

    install_template "php/opcache.ini.sh" "/etc/php/${PHPVER}/mods-available/opcache.ini" "--defaults"

    a2enmod http2
    a2enconf http2
    a2enmod proxy_fcgi setenvif
    a2enconf php"$PHPVER"-fpm
    a2enmod rewrite
    a2enmod headers
    a2enmod dir
    a2enmod mime
    a2enmod ssl

    Print "ServerName localhost" >> '/etc/apache2/apache2.conf'


    ################################
    # CONFIGURE LAMP FOR NEXTCLOUD #
    ################################
    
    # Self-signed certificates
    installPKG ssl-cert

    install_template "mysql/90-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/90-ncp.cnf" "--defaults"
    install_template "mysql/91-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/91-ncp.cnf" "--defaults"

  # Start MariaDB if it's not already running
  if ! isFile "$DBPID_FILE"
  then log -1 "Starting MariaDB"
       mysqld &
       declare -x DBPID="$!"
  fi

  # Wait for MariaDB to start
  while :
  do isSocket "$DBSOCKET" && break
     sleep 1
  done

  if ! cd /tmp
  then log 2 "Failed to change directory to: /tmp"; exit 1
  fi
  
  mysql_secure_installation <<EOF
$DBPASSWD
y
$DBPASSWD
$DBPASSWD
y
y
y
y
EOF
}

function configure { :; }


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

