#!/usr/bin/env bash

# A log that uses log levels for logging different outputs
# Log levels
# -2: Debug
# -1: Info
#  0: Success
#  1: Warning
#  2: Error
function log
{
  if [[ "$#" -gt 0 ]]; then
    local -r LOGLEVEL="$1" TEXT="${*:2}" Z='\e[0m'
    if [[ "$LOGLEVEL" =~ [(-2)-2] ]]; then
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

# Test if a function() is available
# Return codes
# 0: Available
# 1: Unvailable
# 2: Too many/few arguments
function isFunction
{
  if [[ "$#" -eq 1 ]]
  then
    local -r FUNC="$1"
    if declare -f "$FUNC" &>/dev/null
    then
      return 0
    else
      return 1
    fi
  else
    return 2
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

# Checks if a given path to a file exists
# Return codes
# 0: Path exist
# 1: No such path
# 2: Invalid number of arguments
function isPath

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

# Checks if the first given digit is greater than the second
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

# Checks if the first given digit is less than the second
# Return codes
# 0: Is less
# 1: Not less
# 2: Invalid number of arguments
function isLess
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" -lt "$2" ]]
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
function noMatch
{
  [[ "$#" -ne 2 ]] && return 2
  [[ "$1" != "$2" ]]
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

# Checks if a given variable is an array or not
# Return codes
# 0: Variable is an array
# 1: Variable is not an array
# 2: Missing argument: Variable to check
function isArray
{
  if [[ "$#" -ne 1 ]]
  then
    log 2 "Requires: [The variable to check if it's an array or not]"
    return 2
  elif ! declare -a "$1" &>/dev/null
  then
    log -1 "Not an array: $1"
    return 1
  else
    log -1 "Is an array: $1"
    return 0
  fi
}

# Checks if a command exists on the system
# Return status codes
# 0: Command exists on the system
# 1: Command is unavailable on the system
# 2: Missing command argument to check
function hasCMD
{
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

# Checks if a package exists on the system
# Return status codes
# 0: Package is installed
# 1: Package is not installed but is available in apt
# 2: Package is not installed and is not available in apt
# 3: Missing package argument to check
function hasPKG
{
  if [[ "$#" -eq 1 ]]; then
    local -r CHECK="$1"
    if dpkg-query --status "$CHECK" &>/dev/null; then
      return 0
    elif apt-cache show "$CHECK" &>/dev/null; then
      return 1
    else
      return 2
    fi
  else
    return 3
  fi
}

# Installs package(s) using the package manager and pre-configured options
# Return codes
# 0: Install completed
# 1: Coudn't update apt list
# 2: Error during installation
# 3: Missing package argument
function installPKG
{
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

function addUnsetVariable
{
  UNSETVAR+=("$@")
  declare -x -a UNSETVAR
}

function cleanupVariables
{
  unset "${UNSETVAR[@]}"
  unset UNSETVAR
}

function createTmpDirectory
{
  declare -x -g TMPDIR
  if isRoot; then
    TMPDIR="$(mktemp -d /tmp/nextcloudpi.XXXXXX || ( log 2 "Failed to create a temporary directory" >&2; exit 1; ))"
  else
    TMPDIR="$(sudo mktemp -d /tmp/nextcloudpi.XXXXXX || ( log 2 "Failed to create a temporary directory" >&2; exit 1; ))"
  fi
  #trap 'cd -; rm -rf "$TMPDIR"; unset TMPDIR' EXIT SIGHUP SIGILL SIGABRT SIGINT
}

function cleanupCodeDir
{
  cd - || return 1
  if isSet CODE_DIR; then
    log -1 "Removing code directory: $CODE_DIR"
    if isRoot; then
      rm --recursive --force "$CODE_DIR"
      unset CODE_DIR
    else
      sudo rm --recursive --force "$CODE_DIR"
      unset CODE_DIR
    fi
  else
    log 2 "No code directory set to CODE_DIR variable"
    return 2
  fi
}

function cleanupTempDirectory
{
  if isSet TMPDIR; then
    cd - || return 1
    log -1 "Removing tmp directory: $TMPDIR"
    rm --recursive --force "$TMPDIR"
    unset TMPDIR
  else
    log 2 "No tmp directory to cleanup"
  fi
}

function cleanupFunctionsLibrary
{
  if isSet TMPDIR; then
    cleanupTempDirectory
  fi
  if isSet CODE_DIR; then
    cleanupCodeDir
  fi
  cleanupVariables
}

function setOwner
{
  declare -x -g OWNER
  if isEqual "$#" 1; then
    OWNER="$1"
  else
    OWNER="${OWNER:-ZendaiOwl}"
  fi
  addUnsetVariable OWNER
}

function setRepository
{
  declare -x -g REPO
  if isEqual "$#" 1; then
    REPO="$1"
  else
    REPO="${REPO:-nextcloudpi}"
  fi
  addUnsetVariable REPO
}

function setBranch
{
  declare -x BRANCH
  if isEqual "$#" 1; then
    BRANCH="$1"
  else
    BRANCH="${BRANCH:-Refactoring}"
  fi
  addUnsetVariable BRANCH
}

# Fetch build code
function fetchBuildCode
{
  if isEqual "$#" 3; then
    setOwner "$1"
    setRepository "$2"
    setBranch "$3"
  elif isEqual "$#" 4; then
    setOwner "$1"
    setRepository "$2"
    setBranch "$3"
    local -r DIRECTORY="$4"
  else
    setOwner
    setRepository
    setBranch
  fi
  
  # Get installation code from repository
  if isZero "$CODE_DIR"; then
    if isSet DIRECTORY; then
      CODE_DIR="$DIRECTORY"/"$REPO"
    elif isSet TMPDIR; then
      CODE_DIR="$TMPDIR"/"$REPO"
    else
      createTmpDirectory
      CODE_DIR="$TMPDIR"/"$REPO"
    fi
    log -1 "Code directory for build: $CODE_DIR"
    declare -x CODE_DIR
  fi
  log -1 "Cloning repository: $REPO"
  git clone -b "$BRANCH" https://github.com/"$OWNER"/"$REPO".git "$CODE_DIR"
  log 0 "Cloned repository to: $CODE_DIR"
}

function basePackages
{
  if ! isSet ADDED_BASE_PACKAGES; then
    ADDED_BASE_PACKAGES=1
    PACKAGES+=(
      git
      ca-certificates
      sudo
      lsb-release
      wget
      libzip2
      curl
      bc
      dialog
      psmisc
      procps
      zip
      unzip
      xz-utils
      apt-utils
      apt-transport-https
      binutils
    )
    declare -x -g ADDED_BASE_PACKAGES
    declare -x -a PACKAGES
    addUnsetVariable PACKAGES ADDED_BASE_PACKAGES
    log 0 "Base packages added to global variable PACKAGES"
  fi
}

function addPackages
{
  log -1 "Adding packages: $*"
  PACKAGES+=("$@")
  declare -x -a PACKAGES
  log 0 "Added packages"
}

# Installs packages stored in the PACKAGES array variable
# Return codes
# 1: Array variable not set: PACKAGES
function installPackages
{
  if isSet PACKAGES; then
    installPKG "${PACKAGES[@]}"
  else
    log 2 "No packages found for installation" 1>&2
    return 1
  fi
}

# Appends '/usr/local/sbin:/usr/sbin:/sbin' to PATH
function appendPath
{
  PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
  export PATH
}

# Checks for MariaDB installation
# Return codes
# 0: No such database: nextcloud
# 1: Database exists: nextcloud
# 2: Missing command: Database command, default: MySQL
function hasDatabase
{
  local CMD1="${1:-mysqld}" CMD2="${2:-mysql}"
  # Check for installed software
  if hasCMD "$CMD1"; then
    log 1 "Existing MySQL configuration will be changed"
    if "$CMD2" -e 'use nextcloud' &>/dev/null; then
      log 2 "Database exists: nextcloud"
      return 1
    else
      return 0
    fi
  else
    return 2
  fi
}



#trap 'cleanupFunctionsLibrary' EXIT SIGILL SIGHUP SIGABRT SIGINT

