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
         else log 2 "Invalid log level: [ Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2 ]"
         fi
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
function update_apt {
    if [[ "$#" -ne 0 ]]
    then log 2 "Invalid number of arguments, requires none"; return 2
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOUPDATE=(sudo apt-get "${OPTIONS[@]}" update) \
                    ROOTUPDATE=(apt-get "${OPTIONS[@]}" update)
         if [[ "$EUID" -eq 0 ]]
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
# 0: Install completed
# 1: Error during installation
# 2: Missing package argument
function install_package {
    if [[ "$#" -eq 0 ]]
    then log 2 "Requires: [PKG(s)]"; return 2
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOINSTALL=(sudo apt-get "${OPTIONS[@]}" install) \
                    ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
         if [[ "$EUID" -eq 0 ]]
         then log -1 "Installing $*"
              if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "$@"
              then log 0 "Installation complete"; return 0
              else log 2 "Something went wrong during installation"; return 1
              fi
         else log -1 "Installing $*"
              if DEBIAN_FRONTEND=noninteractive "${SUDOINSTALL[@]}" "$@"
              then log 0 "Installation complete"; return 0
              else log 2 "Something went wrong during installation"; return 1
              fi
         fi
    fi
}

function add_install_variable
{
  declare -x -a INSTALL_VARIABLES; INSTALL_VARIABLES+=("$@")
  if [[ "${INSTALL_VARIABLES[*]}" != *'INSTALL_VARIABLES'* ]]
  then add_install_variable INSTALL_VARIABLES
  fi
}

function clean_install_variables
{
  unset "${INSTALL_VARIABLES[@]}"
}

function clean_install_tmp {
    [[ ! -v TMPDIR ]]    && { log 2 "Variable not set: TMPDIR"; return 1; }
    cd - || { log 2 "Unable to change directory to: -"; return 1; }
    ! [[ -d "$TMPDIR" ]] && { log 2 "Directory not found: TMPDIR"; return 1; }
    if [[ "$EUID" -eq 0 ]]
    then rm --recursive --force "$TMPDIR"
    else sudo rm --recursive --force "$TMPDIR"
    fi
}

function clean_install_script {
  log -1 "Cleaning up from install script"
  [[ -v TMPDIR && -d "$TMP" ]]    && { clean_install_tmp; }
  [[ -f '/.ncp-image' ]]          && { rm '/.ncp-image'; }
  #[[ -v DBPID && -n "$DBPID" ]]   && { log -1 "Shutting down MariaDB [$DBPID]";  sudo kill "$DBPID";  }
  #[[ -v DB_PID && -n "$DB_PID" ]] && { log -1 "Shutting down MariaDB [$DB_PID]"; sudo kill "$DB_PID"; }
  #[[ -v db_pid && -n "$db_pid" ]] && { log -1 "Shutting down MariaDB [$db_pid]"; sudo kill "$db_pid"; }
  [[ -v INSTALL_VARIABLES ]]      && { clean_install_variables; }
  
  log 0 "Cleaned up from install script"
}


########################
###### Variables #######
########################


[[ "$EUID" -ne 0 ]] && { log 2 "Must be run as root or with sudo, try: 'sudo ./${BASH_SOURCE[0]##*/}'"; exit 1; }

if [[ -v DBG && -n "$DBG" ]]
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
add_install_variable OWNER REPO BRANCH URL LIBRARY \
                     NCPCFG DBNAME NCP_TEMPLATES_DIR TMPDIR

# Trap cleanup function() for install.sh
trap 'clean_install_script' EXIT SIGHUP SIGABRT SIGINT


########################
##### Installation #####
########################


# Add to PATH if needed
if [[ "$PATH" != *'/usr/local/sbin:/usr/sbin:/sbin:'* ]]
then PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
else PATH="$PATH"
fi; export PATH

# Check for existing MariaDB/MySQL install
[[ "$(command -v mysqld &>/dev/null; printf '%i\n' "$?")" -eq 0 ]] && {
    log 1 "Existing MySQL configuration will be changed"
    if [[ -v DBNAME ]]; then
        if mysql -e 'use '"$DBNAME"'' &>/dev/null
        then log 2 "Database exists: $DBNAME"; exit 1
        fi
    else
        if mysql -e 'use nextcloud' &>/dev/null
        then log 2 "Database exists: nextcloud"; exit 1
        fi
    fi
}

if [[ -v APT_IS_UPDATED && "$APT_IS_UPDATED" -eq 1 ]]; then
    log -2 "Skipping apt update"
else update_apt # Update apt list
fi

# Install packages
install_package git \
                ca-certificates \
                sudo \
                jq \
                lsb-release \
                wget \
                curl \
                apt-utils \
                apt-transport-https

# Get installation/build code from repository
if [[ -z "$CODE_DIR" || ! -v CODE_DIR ]]; then
    CODE_DIR="$TMPDIR"/"$REPO"
    log -1 "Fetching build code to: $CODE_DIR"
    if ! git clone -b "$BRANCH" "$URL" "$CODE_DIR"; then
        log 2 "Failed to clone repository: $URL"; exit 1
    fi
    add_install_variable CODE_DIR
fi

# Change directory to the code directory in the temporary directory
if [[ -v CODE_DIR && -d "$CODE_DIR" ]]
then cd "$CODE_DIR" || { log 2 "Failed changing directory to: $CODE_DIR"; exit 1; }
fi

# Install NextcloudPi
log -1 "Installing NextcloudPi"

# shellcheck disable=SC1090
if [[ -f "$LIBRARY" ]]
then source "$LIBRARY"
else log 2 "File not found: $LIBRARY"; exit 1
fi

if [[ -f "$NCPCFG" ]] # Check so NextcloudPi configuration file exists
then if ! check_distro "$NCPCFG" # Check so the distribution is supported by the script
     then log 2 "Distro not supported"
          cat '/etc/issue' || { log 2 "Failed to read file: /etc/issue"; }
          exit 1
     fi
else log 2 "File not found: $NCPCFG"; exit 1
fi

# Mark the build as an image build for other scripts in the installation/build flow
touch '/.ncp-image' || { log 2 "Failed to create file: /.ncp-image"; exit 1; }

# Create the local NextcloudPi configuration directory
if ! mkdir --parents '/usr/local/etc/ncp-config.d'
then log 2 "Failed creating directory: /usr/local/etc/ncp-config.d"; exit 1
fi

# Check so the local & build configuration directories exists and
# the nextcloud configuration file as well then copy it.
if [[ -d 'etc/ncp-config.d' ]]
then if [[ -d '/usr/local/etc/ncp-config.d' ]]
     then if [[ -f 'etc/ncp-config.d/nc-nextcloud.cfg' ]]
          then cp 'etc/ncp-config.d/nc-nextcloud.cfg' '/usr/local/etc/ncp-config.d/nc-nextcloud.cfg' || { log 2 "Failed to copy file: nc-nextcloud.cfg"; exit 1; }
          fi
     else log 2 "Directory not found: /usr/local/etc/ncp-config.d"; exit 1
     fi
else log 2 "Directory not found: etc/ncp-config.d"; exit 1
fi

if [[ -f "$LIBRARY" ]]
then cp "$LIBRARY" '/usr/local/etc/library.sh' || { log 2 "Failed to copy file: $LIBRARY"; exit 1; }
     LIBRARY='/usr/local/etc/library.sh'
     declare -x -g LIBRARY
fi

if [[ -f "$NCPCFG" ]]
then cp "$NCPCFG" '/usr/local/etc/ncp.cfg' || { log 2 "Failed to copy file: ncp.cfg $NCPCFG"; exit 1; }
     NCPCFG='/usr/local/etc/ncp.cfg'
     declare -x -g NCPCFG
fi

if [[ -d "$NCP_TEMPLATES_DIR" ]]
then cp -r "$NCP_TEMPLATES_DIR" '/usr/local/etc/' || { log 2 "Failed to copy templates: $NCP_TEMPLATES_DIR"; exit 1; }
     NCP_TEMPLATES_DIR='/usr/local/etc/ncp-templates'
     declare -x -g NCP_TEMPLATES_DIR
else log 2 "Directory not found: $NCP_TEMPLATES_DIR"; exit 1
fi

if [[ -f 'lamp.sh' ]]
then install_app 'lamp.sh'
else log 2 "File not found: lamp.sh"; exit 1
fi

if [[ -f 'bin/ncp/CONFIG/nc-nextcloud.sh' ]]
then install_app 'bin/ncp/CONFIG/nc-nextcloud.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-nextcloud.sh"; exit 1
fi

if [[ -f 'bin/ncp/CONFIG/nc-nextcloud.sh' ]]
then run_app_unsafe 'bin/ncp/CONFIG/nc-nextcloud.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-nextcloud.sh"; exit 1
fi

# armbian overlay is ro
if [[ -f '/usr/local/etc/ncp-config.d/nc-nextcloud.cfg' ]]
then rm '/usr/local/etc/ncp-config.d/nc-nextcloud.cfg'
else log 2 "File not found: /usr/local/etc/ncp-config.d/nc-nextcloud.cfg"; exit 1
fi

# TODO this shouldn't be necessary, but somehow it's needed. FIXME
systemctl restart mysqld

if [[ -f 'ncp.sh' ]]
then install_app 'ncp.sh'
else log 2 "File not found: ncp.sh"; exit 1
fi

if [[ -f 'bin/ncp/CONFIG/nc-init.sh' ]]
then run_app_unsafe 'bin/ncp/CONFIG/nc-init.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-init.sh"; exit 1
fi

log -1 "Moving data directory to: /opt/ncdata"
df -h
mkdir --parents '/opt/ncdata'

if [[ ! -f '/usr/local/etc/ncp-config.d/nc-datadir.cfg' ]]
then REMOVE_DATADIR_CFG='true'
     if [[ -f 'etc/ncp-config.d/nc-datadir.cfg' ]]
     then if ! cp 'etc/ncp-config.d/nc-datadir.cfg' '/usr/local/etc/ncp-config.d/nc-datadir.cfg'
          then log 2 "Failed to copy file: nc-datadir.cfg | To: /usr/local/etc/ncp-config.d/nc-datadir.cfg"; exit 1
          fi
     else log 2 "File not found: etc/ncp-config.d/nc-datadir.cfg"; exit 1
     fi
fi

if [[ -f 'bin/ncp/CONFIG/nc-datadir.sh' ]]
then DISABLE_FS_CHECK=1 NCPCFG="/usr/local/etc/ncp.cfg" run_app_unsafe 'bin/ncp/CONFIG/nc-datadir.sh'
else log 2 "File not found: bin/ncp/CONFIG/nc-datadir.sh"; exit 1
fi

if [[ "$REMOVE_DATADIR_CFG" == 'true' ]]
then if [[ -f '/usr/local/etc/ncp-config.d/nc-datadir.cfg' ]]
     then if ! rm '/usr/local/etc/ncp-config.d/nc-datadir.cfg'
          then log 2 "Failed to remove file: /usr/local/etc/ncp-config.d/nc-datadir.cfg"; exit 1
          fi
     else log 2 "File not found: /usr/local/etc/ncp-config.d/nc-datadir.cfg"; exit 1
     fi
fi

if [[ -f '/.ncp-image' ]]
then rm '/.ncp-image' || log 2 "Failed to remove file: /.ncp-image"; exit 1
fi

# Skip on Armbian / Vagrant / LXD
if [[ -n "$CODE_DIR" ]]
then if [[ -f '/usr/local/bin/ncp-provisioning.sh' ]]
     then bash '/usr/local/bin/ncp-provisioning.sh'
     else log 2 "File not found: /usr/local/bin/ncp-provisioning.sh"; exit 1
     fi
fi

cd - || { log 2 "Failed to change directory to: -"; exit 1; }

if [[ -d "$TMPDIR" ]]
then rm --recursive --force "$TMPDIR"
else log 2 "Directory not found: $TMPDIR"; exit 1
fi

trap - EXIT SIGHUP SIGILL SIGABRT SIGINT

IP="$(get_ip)"

log 0 "Completed installation"

printf '%s\n' "
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
