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

# print_lines a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function print_line {
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
    then if [[ "$1" =~ [(-2)-2] ]]
         then case "$1" in
                  -2) printf '\e[1;36mDEBUG\e[0m %s\n'   "${*:2}" >&2 ;;
                  -1) printf '\e[1;34mINFO\e[0m %s\n'    "${*:2}"     ;;
                   0) printf '\e[1;32mSUCCESS\e[0m %s\n' "${*:2}"     ;;
                   1) printf '\e[1;33mWARNING\e[0m %s\n' "${*:2}"     ;;
                   2) printf '\e[1;31mERROR\e[0m %s\n'   "${*:2}" >&2 ;;
              esac
         else log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"
         fi
  fi
}

############################
# Bash - Install Functions #
############################

# Update apt list and packages
# Return codes
# 0: install_pkg completed
# 1: Coudn't update apt list
# 2: Invalid number of arguments
function update_apt {
    if [[ "$#" -ne 0 ]]
    then log 2 "Invalid number of arguments, requires none"; return 2
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOUPDATE=(sudo apt-get "${OPTIONS[@]}" update) \
                    ROOTUPDATE=(apt-get "${OPTIONS[@]}" update)
         if is_root
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

# Install package(s) using the package manager and pre-configured options
# Return codes
# 0: install_pkg completed
# 1: Error during installation
# 2: Missing package argument
function install_package {
    if [[ "$#" -eq 0 ]]
    then log 2 "Requires: [PKG(s)]"; return 2
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOINSTALL=(sudo apt-get "${OPTIONS[@]}" install) \
                    ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
         if is_root
         then log -1 "install_pkging $*"
              if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "$@"
              then log 0 "install_pkgation complete"; return 0
              else log 2 "Something went wrong during installation"; return 1
              fi
         else log -1 "install_pkging $*"
              if DEBIAN_FRONTEND=noninteractive "${SUDOINSTALL[@]}" "$@"
              then log 0 "install_pkgation complete"; return 0
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
    print_line "deb ${PHPREPO}/ ${RELEASE%-security} main" > "$PHPAPTLIST"
    update_apt
    install_package apt-utils cron curl apache2

    ls -l '/var/lock' || true
    # Fix missing lock directory
    mkdir --parents '/run/lock'
    apache2ctl -V || true

    # Create systemd users to keep uids persistent between containers
    if ! id --user 'systemd-resolve' &>/dev/null
    then addgroup --quiet --system 'systemd-journal'
         adduser  --quiet -u 180 --system --group --no-create-home --home '/run/systemd' \
                  --gecos "systemd Network Management" 'systemd-network'
         adduser  --quiet -u 181 --system --group --no-create-home --home '/run/systemd' \
                  --gecos "systemd Resolver" 'systemd-resolve'
    fi
    
    install_with_shadow_workaround --no-install-recommends systemd
    install_package php"$PHPVER" php"$PHPVER"-{curl,gd,fpm,cli,opcache,mbstring,xml,zip,fileinfo,ldap,intl,bz2,mysql}

    mkdir --parents "$PHPDAEMON"

    print_line "[mysqld]" "[client]" "password=$DBPASSWD" > "$MYCNF_FILE"
    #print_line "[client]" "password=$DBPASSWD" > /root/.my.cnf
    chmod 600 "$MYCNF_FILE"

    debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password password $DBPASSWD"
    debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password_again password $DBPASSWD"
    
    install_package mariadb-server
    
    mkdir --parents "$DBDAEMON"
    chown "$DBUSER" "$DBDAEMON"

    ####################
    # CONFIGURE APACHE #
    ####################
    
    install_template "apache2/http2.conf.sh" "/etc/apache2/conf-available/http2.conf" '--defaults'

    ##################
    # CONFIGURE PHP7 #
    ##################

    install_template "php/opcache.ini.sh" "/etc/php/${PHPVER}/mods-available/opcache.ini" '--defaults'

    a2enmod http2
    a2enconf http2
    a2enmod proxy_fcgi setenvif
    a2enconf php"$PHPVER"-fpm
    a2enmod rewrite
    a2enmod headers
    a2enmod dir
    a2enmod mime
    a2enmod ssl

    print_line "ServerName localhost" >> '/etc/apache2/apache2.conf'


    ################################
    # CONFIGURE LAMP FOR NEXTCLOUD #
    ################################
    
    # Self-signed certificates
    install_package ssl-cert

    install_template "mysql/90-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/90-ncp.cnf" '--defaults'
    install_template "mysql/91-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/91-ncp.cnf" '--defaults'

  # Start MariaDB if it's not already running
  if [[ ! -f "$DBPID_FILE" ]]
  then log -1 "Starting MariaDB"
       mysqld &
       declare -x DBPID="$!"
  fi

  # Wait for MariaDB to start
  while :
  do [[ -S "$DBSOCKET" ]] && break
     sleep 1
  done

  if ! cd '/tmp'
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

