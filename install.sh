#!/usr/bin/env bash

# NextcloudPi installation script
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# Usage: ./install.sh
#
# more details at https://ownyourbits.com

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

function add_install_variable
{
  declare -x -a INSTALL_VARIABLES; INSTALL_VARIABLES+=("$@")
  if ! hasText 'INSTALL_VARIABLES' "${INSTALL_VARIABLES[@]}"
  then add_install_variable INSTALL_VARIABLES
  fi
}

function clean_install_variables
{
  unset "${INSTALL_VARIABLES[@]}"
}

function clean_install_tmp
{
    if ! isSet TMPDIR
    then log 2 "Variable not set: TMPDIR"; return 1
    elif ! cd -
    then log 2 "Unable to change directory to: -"; return 1
    elif ! isDirectory "$TMPDIR"
    then log 2 "Directory not found: TMPDIR"; return 1
    else if isRoot
         then rm --recursive --force "$TMPDIR"
         else sudo rm --recursive --force "$TMPDIR"
         fi
    fi
}

function clean_install_script
{
  log -1 "Cleaning up from install script"
  if isSet TMPDIR
  then if isDirectory "$TMP"
       then clean_install_tmp
       fi
  fi
  if isSet INSTALL_VARIABLES
  then clean_install_variables
  fi
  if isFile '/.ncp-image'
  then rm /.ncp-image
  fi; log 0 "Cleaned up from install script"
}


########################
###### Variables #######
########################


if ! isRoot
then log 2 "Must be run as root or with sudo, try: 'sudo ./${BASH_SOURCE[0]##*/}'"; exit 1
fi

if isSet DBG && notZero "$DBG"
then set -e"$DBG"
else set -e
fi

# Repository owner
#OWNER="${OWNER:-nextcloud}"
OWNER="${OWNER:-ZendaiOwl}"

# Repository name
#REPO="${REPO:-nextcloudpi}"
REPO="${REPO:-nextcloudpi}"

# Repository branch
#BRANCH="${BRANCH:-master}"
BRANCH="${BRANCH:-Refactoring}"

# URL to the code repository
URL="https://github.com/${OWNER}/${REPO}"

# Library files with functions()
LIBRARY="${LIBRARY:-etc/library.sh}"

# Config file for nextcloudpi with version numbers
NCPCFG="${NCPCFG:-etc/ncp.cfg}"

# NextcloudPi template directory
NCP_TEMPLATES_DIR="${NCPTEMPLATES:-etc/ncp-templates}"

# Database name for Nextcloud
DBNAME='nextcloud'

# Temporary directory for storing the repository code during build
TMPDIR="$(mktemp -d /tmp/"$REPO".XXXXXX || ({ log 2 "Failed to create temp directory"; exit 1; }))"

# Add variables to be unset during cleanup to free up memory
# allocation and not leave dangling variables in the system environment
add_install_variable OWNER REPO BRANCH URL LIBRARY NCPCFG DBNAME NCP_TEMPLATES_DIR TMPDIR

# Trap cleanup function() for install.sh
trap 'clean_install_script' EXIT SIGHUP SIGILL SIGABRT SIGINT


########################
##### Installation #####
########################


# Add to PATH if needed
if ! hasText '/usr/local/sbin:/usr/sbin:/sbin:' "$PATH"
then PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
else PATH="$PATH"
fi; export PATH

# Check for existing MariaDB/MySQL install
if hasCMD mysqld
then log 1 "Existing MySQL configuration will be changed"
     if isSet DBNAME
     then if mysql -e 'use '"$DBNAME"'' &>/dev/null
          then log 2 "Database exists: $DBNAME"; exit 1
          fi
     else if mysql -e 'use nextcloud' &>/dev/null
          then log 2 "Database exists: nextcloud"; exit 1
          fi
     fi
fi

# Update apt list
updatePKG

# Install packages
installPKG git \
           ca-certificates \
           sudo \
           jq \
           lsb-release \
           wget \
           curl \
           apt-utils \
           apt-transport-https

# Get installation/build code from repository
if isZero "$CODE_DIR" || ! isSet CODE_DIR
then CODE_DIR="$TMPDIR"/"$REPO"
     log -1 "Fetching build code to: $CODE_DIR"
     if ! git clone -b "$BRANCH" "$URL" "$CODE_DIR"
     then log 2 "Failed to clone repository: $URL"; exit 1
     fi; add_install_variable CODE_DIR
fi

# Change directory to the code directory in the temporary directory
if isSet CODE_DIR
then if isDirectory "$CODE_DIR"
     then if ! cd "$CODE_DIR"
          then log 2 "Failed changing directory to: $CODE_DIR"; exit 1
          fi
     fi
fi

# Install NextcloudPi
log -1 "Installing NextcloudPi"

# shellcheck disable=SC1091
if isFile "$LIBRARY"
then source "$LIBRARY"
else log 2 "File not found: $LIBRARY"; exit 1
fi

if isFile "$NCPCFG" # Check so NextcloudPi configuration file exists
then if ! check_distro "$NCPCFG" # Check so the distribution is supported by the script
     then log 2 "Distro not supported"
          if ! cat '/etc/issue'
          then log 2 "Failed to read file: /etc/issue"
          fi; exit 1
     fi
else log 2 "File not found: $NCPCFG"; exit 1
fi

# Mark the build as an image build for other scripts in the installation/build flow
if ! touch '/.ncp-image'
then log 2 "Failed to create file: /.ncp-image"; exit 1
fi

# Create the local NextcloudPi configuration directory
if ! mkdir --parents '/usr/local/etc/ncp-config.d'
then log 2 "Failed creating directory: /usr/local/etc/ncp-config.d"; exit 1
fi

# Check so the local & build configuration directories exists and
# the nextcloud configuration file as well then copy it.
if isDirectory 'etc/ncp-config.d'
then if isDirectory '/usr/local/etc/ncp-config.d'
     then if isFile 'etc/ncp-config.d/nc-nextcloud.cfg'
          then if ! cp 'etc/ncp-config.d/nc-nextcloud.cfg' '/usr/local/etc/ncp-config.d/nc-nextcloud.cfg'
               then log 2 "Failed to copy file: nc-nextcloud.cfg"; exit 1
               fi
          else log 2 "File not found: etc/ncp-config.d/nc-nextcloud.cfg"; exit 1
          fi
     else log 2 "Directory not found: /usr/local/etc/ncp-config.d"; exit 1
     fi
else log 2 "Directory not found: etc/ncp-config.d"; exit 1
fi

if isFile "$LIBRARY"
then if ! cp "$LIBRARY" '/usr/local/etc/library.sh'
     then log 2 "Failed to copy file: $LIBRARY"; exit 1
     fi
     LIBRARY='/usr/local/etc/library.sh'
     declare -x -g LIBRARY
fi

if isFile "$NCPCFG"
then if ! cp "$NCPCFG" '/usr/local/etc/ncp.cfg'
     then log 2 "Failed to copy file: ncp.cfg $NCPCFG"; exit 1
     fi
     NCPCFG='/usr/local/etc/ncp.cfg'
     declare -x -g NCPCFG
fi

if isDirectory "$NCP_TEMPLATES_DIR"
then if ! cp -r "$NCP_TEMPLATES_DIR" '/usr/local/etc/'
     then log 2 "Failed to copy templates: $NCP_TEMPLATES_DIR"; exit 1
     fi
     NCP_TEMPLATES_DIR='/usr/local/etc/ncp-templates'
     declare -x -g NCP_TEMPLATES_DIR
else log 2 "Directory not found: $NCP_TEMPLATES_DIR"; exit 1
fi

if isFile 'lamp.sh'
then install_app 'lamp.sh'
else log 2 "File not found: lamp.sh"; exit 1
fi

if isFile 'bin/ncp/CONFIG/nc-nextcloud.sh'
then install_app 'bin/ncp/CONFIG/nc-nextcloud.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-nextcloud.sh"; exit 1
fi

if isFile 'bin/ncp/CONFIG/nc-nextcloud.sh'
then run_app_unsafe 'bin/ncp/CONFIG/nc-nextcloud.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-nextcloud.sh"; exit 1
fi

# armbian overlay is ro
if isFile '/usr/local/etc/ncp-config.d/nc-nextcloud.cfg'
then rm '/usr/local/etc/ncp-config.d/nc-nextcloud.cfg'
else log 2 "File not found: /usr/local/etc/ncp-config.d/nc-nextcloud.cfg"; exit 1
fi

# TODO this shouldn't be necessary, but somehow it's needed. FIXME
systemctl restart mysqld

if isFile 'ncp.sh'
then install_app 'ncp.sh'
else log 2 "File not found: ncp.sh"; exit 1
fi

if isFile 'bin/ncp/CONFIG/nc-init.sh'
then run_app_unsafe 'bin/ncp/CONFIG/nc-init.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-init.sh"; exit 1
fi

log -1 "Moving data directory to: /opt/ncdata"
df -h
mkdir --parents '/opt/ncdata'

if ! isFile "/usr/local/etc/ncp-config.d/nc-datadir.cfg"
then should_rm_datadir_cfg=true
     if isFile 'etc/ncp-config.d/nc-datadir.cfg'
     then if ! cp 'etc/ncp-config.d/nc-datadir.cfg' '/usr/local/etc/ncp-config.d/nc-datadir.cfg'
          then log 2 "Failed to copy file: nc-datadir.cfg | To: /usr/local/etc/ncp-config.d/nc-datadir.cfg"; exit 1
          fi
     else log 2 "File not found: etc/ncp-config.d/nc-datadir.cfg"; exit 1
     fi
fi

if isFile 'bin/ncp/CONFIG/nc-datadir.sh'
then DISABLE_FS_CHECK=1 NCPCFG="/usr/local/etc/ncp.cfg" run_app_unsafe 'bin/ncp/CONFIG/nc-datadir.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-datadir.sh"; exit 1
fi

if notZero "$should_rm_datadir_cfg"
then if isFile '/usr/local/etc/ncp-config.d/nc-datadir.cfg'
     then rm '/usr/local/etc/ncp-config.d/nc-datadir.cfg'
     else log 2 "File not found: /usr/local/etc/ncp-config.d/nc-datadir.cfg"; exit 1
     fi
fi

if isFile '/.ncp-image'
then rm '/.ncp-image'
fi

# Skip on Armbian / Vagrant / LXD
if notZero "$CODE_DIR"
then if isFile '/usr/local/bin/ncp-provisioning.sh'
     then bash '/usr/local/bin/ncp-provisioning.sh'
     else log 2 "File not found: /usr/local/bin/ncp-provisioning.sh"; exit 1
     fi
fi

if ! cd -
then log 2 "Failed to change directory to: -"; exit 1
fi

if isDirectory "$TMPDIR"
then rm --recursive --force "$TMPDIR"
else log 2 "Directory not found: $TMPDIR"; exit 1
fi

trap - EXIT SIGHUP SIGILL SIGABRT SIGINT

IP="$(get_ip)"

log 0 "Completed installation"

Print "
Visit:
- https://$IP/
- https://nextcloudpi.local/
- Windows/Mac: https://nextcloudpi.lan/ or https://nextcloudpi/

Activate your instance of NC and save the auto generated passwords.
You may review or reset them anytime by using 'nc-admin' and 'nc-passwd'.

Type 'sudo ncp-config' to further configure NCP or access ncp-web on https://$IP:4443/
Note: You will have to add an exception to bypass the certificate warning when you first access the activation & :4443 page.
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
