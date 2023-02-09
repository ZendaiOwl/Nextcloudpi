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
           printf "${RED}ERROR${Z} %s\n" "$TEXT"
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
function noMatch {
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

#OWNER="${OWNER:-nextcloud}"
#REPO="${REPO:-nextcloudpi}"
#BRANCH="${BRANCH:-master}"
OWNER="${OWNER:-ZendaiOwl}"
REPO="${REPO:-nextcloudpi}"
BRANCH="${BRANCH:-Refactoring}"
#DBG=x

[[ -n "$DBG" ]] && set -e"$DBG"
[[ -z "$DBG" ]] && set -e

TMPDIR="$(mktemp -d /tmp/nextcloudpi.XXXXXX || (echo "Failed to create temp dir. Exiting" >&2 ; exit 1) )"
trap "rm -rf \"${TMPDIR}\"" EXIT SIGHUP SIGILL SIGABRT

if ! isRoot; then
  log 2 "Must be run as root or with sudo. Try 'sudo $0'"
  exit 1
fi

export PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"

# Check installed software
if hasCMD mysqld; then
  log 1 "Existing MySQL configuration will be changed"
  if mysql -e 'use nextcloud' &>/dev/null; then
    log 2 "Database exists: nextcloud"
    exit 1
  fi
fi

# Get dependencies
installPKG git ca-certificates sudo lsb-release wget

# get install code
if isMatch "$CODE_DIR" ""; then
  log -1 "Fetching build code"
  CODE_DIR="$TMPDIR"/"$REPO"
  git clone -b "$BRANCH" https://github.com/"$OWNER"/"$REPO".git "$CODE_DIR"
fi
cd "$CODE_DIR"

# install NCP
log -1 "Installing NextcloudPi"

if isFile 'etc/library.sh'; then
  # shellcheck disable=SC1090
  source etc/library.sh
else
  log 2 "File not found: etc/library.sh"
  exit 1
fi

if isFile 'etc/ncp.cfg'; then
  if ! checkDistro etc/ncp.cfg; then
    log 2 "Distro not supported"
    cat /etc/issue
    exit 1
  fi
else
  log 2 "File not found: etc/ncp.cfg"
  exit 1
fi

# indicate that this will be an image build
touch /.ncp-image

mkdir --parents /usr/local/etc/ncp-config.d/
cp etc/ncp-config.d/nc-nextcloud.cfg /usr/local/etc/ncp-config.d/
cp etc/library.sh /usr/local/etc/
cp etc/ncp.cfg /usr/local/etc/

cp -r etc/ncp-templates /usr/local/etc/
installApp    lamp.sh
installApp    bin/ncp/CONFIG/nc-nextcloud.sh
runAppUnsafe bin/ncp/CONFIG/nc-nextcloud.sh
rm /usr/local/etc/ncp-config.d/nc-nextcloud.cfg    # armbian overlay is ro
systemctl restart mysqld # TODO this shouldn't be necessary, but somehow it's needed in Debian 9.6. Fixme
installApp    ncp.sh
runAppUnsafe bin/ncp/CONFIG/nc-init.sh
log -1 'Moving data directory to a more sensible location'
df -h
mkdir -p /opt/ncdata
[[ -f "/usr/local/etc/ncp-config.d/nc-datadir.cfg" ]] || {
  should_rm_datadir_cfg=true
  cp etc/ncp-config.d/nc-datadir.cfg /usr/local/etc/ncp-config.d/nc-datadir.cfg
}
DISABLE_FS_CHECK=1 NCPCFG="/usr/local/etc/ncp.cfg" runAppUnsafe bin/ncp/CONFIG/nc-datadir.sh
[[ -z "$should_rm_datadir_cfg" ]] || rm /usr/local/etc/ncp-config.d/nc-datadir.cfg
rm /.ncp-image

# skip on Armbian / Vagrant / LXD ...
[[ "$CODE_DIR" != "" ]] || bash /usr/local/bin/ncp-provisioning.sh

cd -
rm -rf "$TMPDIR"

IP="$(getIP)"

echo "Done.

First: Visit https://$IP/  https://nextcloudpi.local/ (also https://nextcloudpi.lan/ or https://nextcloudpi/ on windows and mac)
to activate your instance of NC, and save the auto generated passwords. You may review or reset them
anytime by using nc-admin and nc-passwd.
Second: Type 'sudo ncp-config' to further configure NCP, or access ncp-web on https://$IP:4443/
Note: You will have to add an exception, to bypass your browser warning when you
first load the activation and :4443 pages. You can run letsencrypt to get rid of
the warning if you have a (sub)domain available.
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
