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

# A log that uses log levels for logging different outputs
# Log levels
# -2: Debug
# -1: Info
#  0: Success
#  1: Warning
#  2: Error
function log {
  if [[ "$#" -gt 0 ]]
  then
    local -r LOGLEVEL="$1" TEXT="${*:2}" Z='\e[0m'
    if [[ "$LOGLEVEL" =~ [(-2)-2] ]]
    then
      case "$LOGLEVEL" in
        -2)
           local -r CYAN='\e[1;36m'
           printf "${CYAN}DEBUG${Z} %s\n" "$TEXT"
           ;;
        -1)
           local -r BLUE='\e[1;34m'
           printf "${BLUE}INFO${Z} %s\n" "$TEXT"
           ;;
         0)
           local -r GREEN='\e[1;32m'
           printf "${GREEN}SUCCESS${Z} %s\n" "$TEXT"
           ;;
         1)
           local -r YELLOW='\e[1;33m'
           printf "${YELLOW}WARNING${Z} %s\n" "$TEXT"
           ;;
         2)
           local -r RED='\e[1;31m'
           printf "${RED}ERROR${Z} %s\n" "$TEXT" 1>&2
           ;;
      esac
    else
      log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"
    fi
  fi
}

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
function isUser
{
  [[ "$#" -ne 1 ]] && return 2
  if id -u "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Checks if a user does not exist
# Return codes
# 0: Not a user
# 1: Is a user
# 2: Invalid number of arguments
function notUser
{
  [[ "$#" -ne 1 ]] && return 2
  if ! id -u "$1" &>/dev/null; then
    return 0
  else
    return 1
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

# Checks if a given String is zero
# Return codes
# 0: Is zero
# 1: Not zero
# 2: Invalid number of arguments
function isZero {
  [[ "$#" -ne 1 ]] && return 2
  [[ -z "$1" ]]
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

# Checks if a given String is not zero
# Return codes
# 0: Not zero
# 1: Is zero
# 2: Invalid number of arguments
function notZero {
  [[ "$#" -ne 1 ]] && return 2
  [[ -n "$1" ]]
}

# Checks if a command exists on the system
# Return status codes
# 0: Command exists on the system
# 1: Command is unavailable on the system
# 2: Missing command argument to check
function hasCMD {
  if [[ "$#" -eq 1 ]]; then
    local -r CHECK="$1"
    if command -v "$CHECK" &>/dev/null; then
      return 0
    else
      return 1
    fi
  else
    return 2
  fi
}

# Installs package(s) using the package manager and pre-configured options
# Return codes
# 0: Install completed
# 1: Coudn't update apt list
# 2: Error during installation
# 3: Missing package argument
function installPKG {
  if [[ "$#" -eq 0 ]]; then
    log 2 "Requires: [PKG(s) to install]"
    return 3
  else
    local -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    local -r SUDOUPDATE=(sudo apt-get "${OPTIONS[@]}" update) \
             SUDOINSTALL=(sudo apt-get "${OPTIONS[@]}" install) \
             ROOTUPDATE=(apt-get "${OPTIONS[@]}" update) \
             ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
    local PKG=()
    IFS=' ' read -ra PKG <<<"$@"
    if [[ ! "$EUID" -eq 0 ]]; then
      log -1 "Updating apt lists"
      if "${SUDOUPDATE[@]}" &>/dev/null; then
        log 0 "Apt list updated"
      else
        log 2 "Couldn't update apt lists"
        return 1
      fi
      log -1 "Installing ${PKG[*]}"
      if DEBIAN_FRONTEND=noninteractive "${SUDOINSTALL[@]}" "${PKG[@]}"; then
        log 0 "Installation completed"
        return 0
      else
        log 2 "Something went wrong during installation"
        return 2
      fi
    else
      log -1 "Updating apt lists"
      if "${ROOTUPDATE[@]}" &>/dev/null; then
        log 0 "Apt list updated"
      else
        log 2 "Couldn't update apt lists"
        return 1
      fi
      log -1 "Installing ${PKG[*]}"
      if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "${PKG[@]}"; then
        log 0 "Installation completed"
        return 0
      else
        log 2 "Something went wrong during installation"
        return 1
      fi
    fi
  fi
}

function install
{
    set -x
    local -r DBPID_FILE='/run/mysqld/mysqld.pid' \
             DBSOCKET='/run/mysqld/mysqld.sock' \
             DBDAEMON='/run/mysqld' \
             DBUSER='mysql' \
             PHPDAEMON='/run/php' \
             PHPREPO='https://packages.sury.org/php' \
             PHPREPO_GPGKEY='https://packages.sury.org/php/apt.gpg' \
             PHPAPTLIST='/etc/apt/sources.list.d/php.list'
    # MariaDB password
    local DBPASSWD="default"
    # Setup apt repository for php 8
    wget -O /etc/apt/trusted.gpg.d/php.gpg "$PHPREPO_GPGKEY"
    echo "deb ${PHPREPO}/ ${RELEASE%-security} main" > "$PHPAPTLIST"
    installPKG apt-utils cron curl ssl-cert apache2
    ls -l /var/lock || true
    # Fix missing lock directory
    mkdir --parents /run/lock
    apache2ctl -V || true

    # Create systemd users to keep uids persistent between containers
    if ! id -u systemd-resolve &>/dev/null; then
      addgroup --quiet --system systemd-journal
      adduser --quiet -u 180 --system --group --no-create-home --home /run/systemd \
        --gecos "systemd Network Management" systemd-network
      adduser --quiet -u 181 --system --group --no-create-home --home /run/systemd \
        --gecos "systemd Resolver" systemd-resolve
    fi
    install_with_shadow_workaround --no-install-recommends systemd
    installPKG php"$PHPVER" php"$PHPVER"-{curl,gd,fpm,cli,opcache,mbstring,xml,zip,fileinfo,ldap,intl,bz2,mysql}

    mkdir --parents "$PHPDAEMON"

    echo -e "[client]\npassword=$DBPASSWD" > /root/.my.cnf
    chmod 600 /root/.my.cnf

    debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password password $DBPASSWD"
    debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password_again password $DBPASSWD"
    installPKG mariadb-server
    mkdir --parents "$DBDAEMON"
    chown "$DBUSER" "$DBDAEMON"

    # CONFIGURE APACHE
    ##########################################

    install_template apache2/http2.conf.sh /etc/apache2/conf-available/http2.conf --defaults

    # CONFIGURE PHP7
    ##########################################

    install_template "php/opcache.ini.sh" "/etc/php/${PHPVER}/mods-available/opcache.ini" --defaults

    a2enmod http2
    a2enconf http2
    a2enmod proxy_fcgi setenvif
    a2enconf php"$PHPVER"-fpm
    a2enmod rewrite
    a2enmod headers
    a2enmod dir
    a2enmod mime
    a2enmod ssl

    echo "ServerName localhost" >> /etc/apache2/apache2.conf


    # CONFIGURE LAMP FOR NEXTCLOUD
    ##########################################

    install_template "mysql/90-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/90-ncp.cnf" --defaults

    install_template "mysql/91-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/91-ncp.cnf" --defaults

  # launch mariadb if not already running
  if ! [[ -f "$DBPID_FILE" ]]; then
    log -1 "Starting MariaDB"
    mysqld &
  fi

  # wait for mariadb
  while :; do
    [[ -S "$DBSOCKET" ]] && break
    sleep 1
  done

  cd /tmp
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

configure() { :; }


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

