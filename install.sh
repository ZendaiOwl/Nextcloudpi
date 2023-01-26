#!/usr/bin/env bash
# A log function that uses log levels for logging different outputs
# Log levels
# -2: Debug
# -1: Info
#  0: Success
#  1: Warning
#  2: Error
function log() {
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

# Checks if user running script is root or not
# Return codes
# 0: Is root
# 1: Not root
function isRoot() {
  if [[ "$EUID" -eq 0 ]]
  then
    return 0
  else
    return 1
  fi
}

# Unsets variables used during installation for cleanup
function unsetInstallVariables() {
  unset TMPDIR OPTIONS APTUPDATE APTINSTALL \
        PACKAGES BRANCH CODE_DIR REPO_URL LIB NCP_CFG \
        IMG_BUILD ISSUE NCP_CFG_DIR ETC_DIR BUILD_NC_CFG OPT_DATA_DIR \
        DATADIR_CFG BUILD_DATADIR_CFG SCRIPT_LAMP SCRIPT_NEXTCLOUD \
        VARIABLES SCRIPT_NCP SCRIPT_INIT SCRIPT_PROVISIONING SCRIPT_DATADIR \
        REPO_HOST OWNER REPOSITORY
  [[ -n "$REMOVE_DATADIR_CFG" ]] && unset REMOVE_DATADIR_CFG
}

#BRANCH="${BRANCH:-main}"
#BRANCH="${BRANCH:-master}"
REPO_HOST='github.com'
OWNER='ZendaiOwl'
REPOSITORY='nextcloudpi'
BRANCH="${BRANCH:-refactor}"

if [[ -n "$DBG" ]]
then
  set -e"$DBG"
else
  set -e
fi

#REPO_URL='https://github.com/nextcloud/nextcloudpi.git'
REPO_URL="https://${REPO_HOST}/${OWNER}/${REPOSITORY}.git"

TMPDIR="$(mktemp --directory /tmp/nextcloudpi.XXXXXX || (log 2 "Failed to create temporary directory" >&2 ; exit 1))"
CODE_DIR="${TMPDIR}/nextcloudpi"

IMG_BUILD='/.ncp-image'
ISSUE='/etc/issue'

NCP_TEMPLATES_DIR='etc/ncp-templates'
ETC_DIR='/usr/local/etc'
OPT_DATA_DIR='/opt/ncdata'
NCP_CFG_DIR="${ETC_DIR}/ncp-config.d"
DATADIR_CFG="${NCP_CFG_DIR}/nc-datadir.cfg"
NC_CFG="${NCP_CFG_DIR}/nc-nextcloud.cfg"
BUILD_DATADIR_CFG='etc/ncp-config.d/nc-datadir.cfg'

NCP_CFG='etc/ncp-cfg'
LIB='etc/Library.sh'
VARIABLES='etc/Variables.sh'
BUILD_NC_CFG='etc/ncp-config.d/nc-nextcloud.cfg'

OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
APTUPDATE=(apt-get "${OPTIONS[@]}" update)
APTINSTALL=(apt-get "${OPTIONS[@]}" install)

PACKAGES=(git ca-certificates sudo lsb-release wget)

SCRIPT_LAMP='Lamp.sh'
SCRIPT_NEXTCLOUD='bin/ncp/CONFIG/Nextcloud.sh'
SCRIPT_NCP='ncp.sh'
SCRIPT_INIT='bin/ncp/CONFIG/nc-init.sh'
SCRIPT_DATADIR='bin/ncp/CONFIG/nc-datadir.sh'
SCRIPT_PROVISIONING='/usr/local/bin/ncp-provisioning.sh'

# 0) EXIT    1) SIGHUP	 2) SIGINT	 3) SIGQUIT
# 4) SIGILL  5) SIGTRAP 6) SIGABRT	15) SIGTERM
trap 'rm --recursive --force "$TMPDIR"; unsetInstallVariables' EXIT SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

if ! isRoot
then
  log 2 "Must be run as 'root' user or with 'sudo'"
  exit 1
fi

export PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"

if type mysqld &>/dev/null
then
  log 1 "Existing MySQL configuration will be changed"
  if mysql -e 'use nextcloud' &>/dev/null
  then
    log 2 "Database 'nextcloud' already exists"
    exit 1
  fi
fi

# Update
"${APTUPDATE[@]}"

# Install packages
"${APTINSTALL[@]}" "${PACKAGES[@]}"

if [[ "$CODE_DIR" == "" ]]
then
  log -1 "Getting code from git repository"
  git clone --branch "$BRANCH" "$REPO_URL" "$CODE_DIR"
fi

cd "$CODE_DIR" || exit 1
log -1 "Installing NextcloudPi"

# shellcheck disable=SC1090
source "$LIB"
# shellcheck disable=SC1090
source "$VARIABLES"

if ! checkDistro "$NCP_CFG"
then
  log 2 "Distribution is not supported"
  cat "$ISSUE"
  exit 1
fi

# Indicate IMG build
touch "$IMG_BUILD"

log -1 "Creating NCP Config directory"
mkdir --parents "$NCP_CFG_DIR"

log -1 "Copying files"
cp              "$BUILD_NC_CFG"      "$NCP_CFG_DIR"
cp              "$NCP_CFG"           "${ETC_DIR}/"
cp              "$LIB"               "${ETC_DIR}/"
cp --recursive  "$NCP_TEMPLATES_DIR" "${ETC_DIR}/"

installApp      "$SCRIPT_LAMP"
installApp      "$SCRIPT_NEXTCLOUD"
runAppUnsafe    "$SCRIPT_NEXTCLOUD"

# Armbian overlay is ro
rm "$NC_CFG"

# TODO this shouldn't be necessary, but somehow it's needed in Debian 9.6. Fixme
#systemctl restart mysqld 

installApp      "$SCRIPT_NCP"
runAppUnsafe    "$SCRIPT_INIT"

log -1 "Moving data directory to a more sensible location"
df -h
mkdir --parents "$OPT_DATA_DIR"

if [[ ! -f "$DATADIR_CFG" ]]
then
  REMOVE_DATADIR_CFG=true
  cp "$BUILD_DATADIR_CFG" "$DATADIR_CFG"
fi

DISABLE_FS_CHECK=1 NCPCFG="/usr/local/etc/ncp.cfg" runAppUnsafe "$SCRIPT_DATADIR"

if [[ -n "$REMOVE_DATADIR_CFG" ]]
then
  rm "$DATADIR_CFG"
fi

rm "$IMG_BUILD"

# Skip on Armbian/Vagrant/LXD
if [[ "$CODE_DIR" == "" ]]
then
  bash "$SCRIPT_PROVISIONING"
fi

cd - || return 1

log -1 "Removing temporary directory: $TMPDIR"
rm --recursive --force "$TMPDIR"

IP="$(getIP)"

log 0 "Installation complete"

echo -e "1. Go to ↓
\thttps://${IP}/
\thttps://nextcloudpi.local/
\tAlso https://nextcloudpi.lan/ or https://nextcloudpi/ on Windows/Mac\n
Activate your instance of Nextcloud & save the auto generated passwords.
You may review or reset them anytime by using 'nc-admin' and 'nc-passwd'.\n
2. Type 'sudo ncp-config' to further configure NCP or access the admin web interface on https://${IP}:4443/\n
- NOTE -
You'll have to add an exception to bypass your browser warning when you first load the activation & :4443 page.
Run letsencrypt for a certificate to get rid of the warning if you have a (sub)domain available.\n"
