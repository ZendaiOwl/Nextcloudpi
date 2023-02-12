#!/usr/bin/env bash

# NextcloudPi installation script
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# Usage: ./install.sh
#
# more details at https://ownyourbits.com

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
function isRoot
{
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

# Checks if a given path to a file exists
# Return codes
# 0: Path exist
# 1: No such path
# 2: Invalid number of arguments
function isPath
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -e "$1" ]]
}

# Checks if a given path is a regular file
# 0: Is a file
# 1: Not a file
# 2: Invalid number of arguments
function isFile
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -f "$1" ]]
}

# Checks if a given path is a readable file
# 0: Is readable
# 1: Not readable
# 2: Invalid number of arguments
function isReadable
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -r "$1" ]]
}

# Checks if a given path is a writable file
# 0: Is writable
# 1: Not writable
# 2: Invalid number of arguments
function isWritable
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -w "$1" ]]
}

# Checks if a given path is an executable file
# 0: Is executable
# 1: Not executable
# 2: Invalid number of arguments
function isExecutable
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -x "$1" ]]
}

# Checks if given path is a directory 
# Return codes
# 0: Is a directory
# 1: Not a directory
# 2: Invalid number of arguments
function isDirectory
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -d "$1" ]]
}

# Checks if given path is a named pipe
# Return codes
# 0: Is a named pipe
# 1: Not a named pipe
# 2: Invalid number of arguments
function isPipe
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -p "$1" ]]
}

# Checks if a given path is a socket
# Return codes
# 0: Is a socket
# 1: Not a socket
# 2: Invalid number of arguments
function isSocket
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -S "$1" ]]
}

# Checks if the first given digit is greater than the second digit
# Return codes
# 0: Is greater
# 1: Not greater
# 2: Invalid number of arguments
function isGreater
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" -gt "$2" ]]
}

# Checks if the first given digit is greater than or equal to the second digit
# Return codes
# 0: Is greater than or equal
# 1: Not greater than or equal
# 2: Invalid number of arguments
function isGreaterOrEqual
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" -ge "$2" ]]
}

# Checks if the first given digit is less than the second digit
# Return codes
# 0: Is less
# 1: Not less
# 2: Invalid number of arguments
function isLess
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" -lt "$2" ]]
}

# Checks if a given variable has been set and is a name reference
# Return codes
# 0: Is set name reference
# 1: Not set name reference
# 2: Invalid number of arguments
function isReference
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -R "$1" ]]
}

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Is set
# 1: Not set 
# 2: Invalid number of arguments
function isSet
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -v "$1" ]]
}

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Not set
# 1: Is set 
# 2: Invalid number of arguments
function notSet
{
  [[ "$#" -ne 1 ]] && return 2
  [[ ! -v "$1" ]]
}

# Checks if 2 given digits are equal
# Return codes
# 0: Is equal
# 1: Not equal
# 2: Invalid number of arguments
function isEqual
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" -eq "$2" ]]
}

# Checks if 2 given digits are not equal
# Return codes
# 0: Not equal
# 1: Is equal
# 2: Invalid number of arguments
function notEqual
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" -ne "$2" ]]
}

# Checks if 2 given String variables match
# Return codes
# 0: Is a match
# 1: Not a match
# 2: Invalid number of arguments
function isMatch
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" == "$2" ]]
}

# Checks if 2 given String variables do not match
# Return codes
# 0: Not a match
# 1: Is a match
# 2: Invalid number of arguments
function notMatch
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" != "$2" ]]
}

# Checks if a given String is zero
# Return codes
# 0: Is zero
# 1: Not zero
# 2: Invalid number of arguments
function isZero
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -z "$1" ]]
}

# Checks if a given String is not zero
# Return codes
# 0: Not zero
# 1: Is zero
# 2: Invalid number of arguments
function notZero
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -n "$1" ]]
}

# Checks if a given pattern exists in a String
# Return codes
# 0: Has String pattern
# 1: No String pattern
# 2: Invalid number of arguments
function hasText
{
  [[ "$#" -ne 2 ]] && return 2
  local -r PATTERN="$1" STRING="$2"
  [[ "$STRING" == *"$PATTERN"* ]]
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
# 4: Not running as root/sudo
function installPKG {
  if [[ "$#" -eq 0 ]]; then
    log 2 "Requires: [PKG(s) to install]"
    return 3
  elif [[ "$EUID" -ne 0 ]]; then
    log 2 "Requires root privileges"
    return 4 
  else
    local -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    local -r ROOTUPDATE=(apt-get "${OPTIONS[@]}" update) \
             ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
    local PKG=()
    IFS=' ' read -ra PKG <<<"$@"
    
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
}

function add_install_variables
{
  declare -x -a INSTALL_VARIABLES
  INSTALL_VARIABLES+=("$@")
  if ! hasText 'INSTALL_VARIABLES' "${INSTALL_VARIABLES[@]}"; then
    add_install_variables INSTALL_VARIABLES
  fi
}

function clean_install_variables
{
  unset "${INSTALL_VARIABLES[@]}"
}

function clean_install_tmp
{
  if ! isSet TMPDIR; then
    log 2 "Variable not set: TMPDIR"
    return 1
  elif ! cd -; then
    log 2 "Unable to change directory to: -"
    return 1
  elif ! isDirectory "$TMPDIR"; then
    log 2 "Directory not found: TMPDIR"
    return 1
  else
    if isRoot; then
      rm --recursive --force "$TMPDIR"
    else
      sudo rm --recursive --force "$TMPDIR"
    fi
  fi
}

function clean_install_script
{
  log -1 "Cleaning up from install script"
  if isSet TMPDIR; then
    if isDirectory "$TMP"; then
      clean_install_tmp
    fi
  fi
  if isSet INSTALL_VARIABLES; then
    clean_install_variables
  fi
  if isFile '/.ncp-image'; then
    rm /.ncp-image
  fi
  log 0 "Cleaned up from install script"
}


########################
##### Installation #####
########################

# (${BASH_SOURCE[0]##*/})

if ! isRoot; then
  log 2 "Must be run as root or with sudo, try: 'sudo ./${BASH_SOURCE[0]##*/}'"
  exit 1
fi

if isSet DBG && notZero "$DBG"; then
  set -e"$DBG"
else
  set -e
fi

#OWNER="${OWNER:-nextcloud}"
#REPO="${REPO:-nextcloudpi}"
#BRANCH="${BRANCH:-master}"
OWNER="${OWNER:-ZendaiOwl}"
REPO="${REPO:-nextcloudpi}"
BRANCH="${BRANCH:-Refactoring}"
URL="https://github.com/${OWNER}/${REPO}"
LIBRARY="${LIBRARY:-etc/library.sh}"
NCPCFG="${NCPCFG:-etc/ncp.cfg}"
NCP_TEMPLATES_DIR="${NCPTEMPLATES:-etc/ncp-templates}"
DBNAME='nextcloud'

TMPDIR="$(mktemp -d /tmp/"$REPO".XXXXXX || ({ log 2 "Failed to create temp directory"; exit 1; }))"

add_install_variables OWNER REPO BRANCH URL LIBRARY NCPCFG DBNAME NCP_TEMPLATES_DIR TMPDIR

trap 'clean_install_script' EXIT SIGHUP SIGILL SIGABRT SIGINT

# if ! hasText '/usr/local/sbin:/usr/sbin:/sbin:' "$PATH"; then
#   PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
# fi

# Only add the part that's needed

if ! hasText '/sbin:' "$PATH"; then
  PATH="/sbin:$PATH"
fi

if ! hasText '/usr/sbin:' "$PATH"; then
  PATH="/usr/sbin:$PATH"
fi

if ! hasText '/usr/local/sbin:' "$PATH"; then
  PATH="/usr/local/sbin:$PATH"
fi

export PATH

# Check installed software
if hasCMD mysqld; then
  log 1 "Existing MySQL configuration will be changed"
  if isSet DBNAME; then
    if mysql -e 'use '"$DBNAME"'' &>/dev/null; then
      log 2 "Database exists: $DBNAME"
      exit 1
    fi
  else
    if mysql -e 'use nextcloud' &>/dev/null; then
      log 2 "Database exists: nextcloud"
      exit 1
    fi
  fi
fi

# Get dependencies
installPKG git \
           ca-certificates \
           sudo \
           lsb-release \
           wget \
           curl \
           apt-utils \
           apt-transport-https

# get install code
if isZero "$CODE_DIR" || ! isSet CODE_DIR; then
  log -1 "Fetching build code"
  CODE_DIR="$TMPDIR"/"$REPO"
  git clone -b "$BRANCH" "$URL" "$CODE_DIR"
  add_install_variables CODE_DIR
fi

if isSet CODE_DIR; then
  if isDirectory "$CODE_DIR"; then
    if ! cd "$CODE_DIR"; then
      log 2 "Failed to change directory to: $CODE_DIR"
      exit 1
    fi
  fi 
fi

# install NCP
log -1 "Installing NextcloudPi"

if isFile "$LIBRARY"; then
  # shellcheck disable=SC1091
  source "$LIBRARY"
else
  log 2 "File not found: $LIBRARY"
  exit 1
fi

if isFile "$NCPCFG"; then
  if ! check_distro "$NCPCFG"; then
    log 2 "Distro not supported"
    if ! cat /etc/issue; then
      log 2 "Failed to read file: /etc/issue"
      exit 1
    fi
    exit 1
  fi
else
  log 2 "File not found: $NCPCFG"
  exit 1
fi

# indicate that this will be an image build
if ! touch /.ncp-image; then
  log 2 "Failed creating file: /.ncp-image"
  exit 1
fi

if ! mkdir --parents /usr/local/etc/ncp-config.d; then
  log 2 "Failed creating directory: /usr/local/etc/ncp-config.d"
  exit 1
fi

if isDirectory 'etc/ncp-config.d'; then
  if isDirectory '/usr/local/etc/ncp-config.d'; then
    if isFile 'etc/ncp-config.d/nc-nextcloud.cfg'; then
      if ! cp etc/ncp-config.d/nc-nextcloud.cfg /usr/local/etc/ncp-config.d/nc-nextcloud.cfg; then
        log 2 "Failed to copy file: nc-nextcloud.cfg"
        exit 1
      fi
    fi
  else
    log 2 "Directory not found: /usr/local/etc/ncp-config.d"
    exit 1
  fi
else
  log 2 "Directory not found: etc/ncp-config.d"
  exit 1
fi

if isFile "$LIBRARY"; then
  if cp "$LIBRARY" /usr/local/etc/library.sh; then
    LIBRARY='/usr/local/etc/library.sh'
    log -2 "LIBRARY: $LIBRARY"
  else
    log 2 "Failed to copy file: library.sh $LIBRARY"
    exit 1
  fi
fi

# log 2 "(${BASH_SOURCE[0]##*/}) "

if isFile "$NCPCFG"; then
  if cp "$NCPCFG" /usr/local/etc/ncp.cfg; then
    NCPCFG='/usr/local/etc/ncp.cfg'
    log -2 "NCPCFG: $NCPCFG"
  else
    log 2 "Failed to copy file: ncp.cfg $NCPCFG"
    exit 1
  fi
fi

if isDirectory "$NCP_TEMPLATES_DIR"; then
  if cp -r "$NCP_TEMPLATES_DIR" /usr/local/etc/; then
    NCP_TEMPLATES_DIR='/usr/local/etc/ncp-templates'
    log -2 "NCP_TEMPLATES_DIR: $NCP_TEMPLATES_DIR"
  else
    log 2 "Failed to copy templates: $NCP_TEMPLATES_DIR"
    exit 1
  fi
else
  log 2 "Directory not found: $NCP_TEMPLATES_DIR"
  exit 1
fi

# cp etc/library.sh /usr/local/etc/
# cp etc/ncp.cfg /usr/local/etc/
# cp -r etc/ncp-templates /usr/local/etc/

( install_app lamp.sh )

( install_app bin/ncp/CONFIG/nc-nextcloud.sh )

( run_app_unsafe bin/ncp/CONFIG/nc-nextcloud.sh )

rm /usr/local/etc/ncp-config.d/nc-nextcloud.cfg    # armbian overlay is ro

systemctl restart mysqld # TODO this shouldn't be necessary, but somehow it's needed in Debian 9.6. Fixme

( install_app ncp.sh )

( run_app_unsafe bin/ncp/CONFIG/nc-init.sh )

log -1 "Moving data directory to a more sensible location"
df -h
mkdir --parents /opt/ncdata

[[ -f "/usr/local/etc/ncp-config.d/nc-datadir.cfg" ]] || {
  should_rm_datadir_cfg=true
  cp etc/ncp-config.d/nc-datadir.cfg /usr/local/etc/ncp-config.d/nc-datadir.cfg
}

DISABLE_FS_CHECK=1 NCPCFG="/usr/local/etc/ncp.cfg" run_app_unsafe bin/ncp/CONFIG/nc-datadir.sh

[[ -z "$should_rm_datadir_cfg" ]] || rm /usr/local/etc/ncp-config.d/nc-datadir.cfg

rm /.ncp-image

# skip on Armbian / Vagrant / LXD ...
[[ "$CODE_DIR" != "" ]] || bash /usr/local/bin/ncp-provisioning.sh

if ! cd -; then
  log 2 "Unable to change directory to: -"
  exit 1
fi

rm --recursive --force "$TMPDIR"

trap - EXIT SIGHUP SIGILL SIGABRT SIGINT

IP="$(get_ip)"

log 0 "Completed installation"

printf '%s\n' "
Visit:
- https://$IP/
- https://nextcloudpi.local/
- Windows/Mac: https://nextcloudpi.lan/ or https://nextcloudpi/

Activate your instance of NC and save the auto generated passwords.
You may review or reset them anytime by using 'nc-admin' and 'nc-passwd'."

printf '%s\n' "Type 'sudo ncp-config' to further configure NCP or access ncp-web on https://$IP:4443/
Note: You will have to add an exception to bypass the browser warning when you first access the activation page and the :4443 page.
You can run letsencrypt to get rid of the warning if you have a (sub)domain available.
"

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
