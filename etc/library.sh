#!/usr/bin/env bash

# NextcloudPi function library
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#

############################
# Bash - Utility Functions #
############################

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

# Checks for the ncc command
# Return status codes
# 0: ncc command found
# 1: File exists
# 2: Too many arguments
function hasCMD_NCC {
  declare -r NCC_SCRIPTFILE='/usr/local/bin/ncc'
  if notEqual "$#" 0
  then return 2
  else if hasCMD ncc
  then return 0
       elif isFile "$NCC_SCRIPTFILE"
       then return 1
       fi
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

########################
# Bash - NCP Functions #
########################

function apt_install {
    apt-get update --allow-releaseinfo-change
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Dpkg::Options::=--force-confdef -o Dpkg::Options::="--force-confold" "$@"
}

function install_with_shadow_workaround {
    # Subshell to trap trap :P
    (
        RESTORE_SHADOW=true
        [[ -L /etc/shadow ]] || RESTORE_SHADOW=false
        [[ "$RESTORE_SHADOW" == "false" ]] || {
            trap "mv /etc/shadow /data/etc/shadow; ln -s /data/etc/shadow /etc/shadow" EXIT SIGINT SIGABRT SIGHUP
            rm /etc/shadow; cp /data/etc/shadow /etc/shadow
        }
        if isRoot
        then DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes "$@"
        else DEBIAN_FRONTEND=noninteractive sudo apt-get install --assume-yes "$@"
        fi
        [[ "$RESTORE_SHADOW" == "false" ]] || {
            mv /etc/shadow /data/etc/shadow; ln -s /data/etc/shadow /etc/shadow
        }
        trap - EXIT SIGINT SIGABRT SIGHUP
    )
}

# Return codes
function is_more_recent_than {
    local -r VERSION_A="$1" VERSION_B="$2"
    local MAJOR_A MINOR_A PATCH_A MAJOR_B MINOR_B PATCH_B
    
    MAJOR_A="$(cut -d. -f1 <<<"$VERSION_A")"
    MINOR_A="$(cut -d. -f2 <<<"$VERSION_A")"
    PATCH_A="$(cut -d. -f3 <<<"$VERSION_A")"
    
    MAJOR_B="$(cut -d. -f1 <<<"$VERSION_B")"
    MINOR_B="$(cut -d. -f2 <<<"$VERSION_B")"
    PATCH_B="$(cut -d. -f3 <<<"$VERSION_B")"
    
    # Compare version A with version B
    # Versioning ex. 25.0.3 or 24.9.5 etc
    # Returns a 1 if B is greater than A
    if isGreater "$MAJOR_B" "$MAJOR_A"
    then return 1
    elif isEqual "$MAJOR_B" "$MAJOR_A" && \
         isGreater "$MINOR_B" "$MINOR_A"
    then return 1
    elif isEqual "$MAJOR_B" "$MAJOR_A" && \
         isEqual "$MINOR_B" "$MINOR_A" && \
         isGreaterOrEqual "$PATCH_B" "$PATCH_A"
    then return 1
    fi
    return 0
}

# Return codes
function install_app {
    local NCP_APP="$1" SCRIPT 
    
    # $1 can be either an installed app name or an app script
    if [[ -f "$NCP_APP" ]]
    then SCRIPT="$NCP_APP"; NCP_APP="$(basename "$SCRIPT" .sh)"
    else SCRIPT="$(find "$BINDIR" -name "$NCP_APP".sh | head -1)"
    fi
    
    unset install
    # shellcheck disable=SC1090
    source "$SCRIPT"; log -1 "Installing: $NCP_APP"
    ( install ); log 0 "Installed: $NCP_APP"
}

# Return codes
# 2: Missing package: dialog
# 3: Failed to install: dialog
function configure_app {
    local -r NCP_APP="$1"
    local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
    local BACKTITLE="NextcloudPi installer configuration" \
          RET=1 CFG LENGTH VAR VAL IDX VALUE \
          PARAMETERS=() VARIABLES=() VALUES=() RETURN_VALUES=()
    # Dialog
    local DIALOG_OK=0 \
          DIALOG_CANCEL=1 \
          DIALOG_ERROR=254 \
          DIALOG_ESC=255 \
          RES=0
    log -1 "Configuring app: $NCP_APP"
    # Checks
    if ! hasPKG dialog
    then log 1 "Missing package: dialog"; log -1 "Attempting to install: dialog"
         if ! installPKG dialog
         then log 2 "Failed! Please install dialog manually"; return 3
         fi
    fi
    if ! isFile "$CFG_FILE"
    then log 1 "No configuration file for: $NCP_APP"; return 0
    fi
    
    LENGTH="$(jq  '.params | length' "$CFG_FILE")"
    if isEqual "$LENGTH" 0
    then return
    fi
    
    # Read config parameters
    for (( i = 0; i < "$LENGTH"; i++ )); do
        VAR="$(jq -r ".params[$i].id" "$CFG_FILE")"
        VAL="$(jq -r ".params[$i].value" "$CFG_FILE")"
        VARIABLES+=("$VAR")
        VALUES+=("$VAL")
        IDX=$(("$i"+1))
        PARAMETERS+=("$VAR" "$IDX" 1 "$VAL" "$IDX" 15 60 120)
    done
    
    while [[ "$RES" != 1 ]] && [[ "$RES" != 250 ]]
    do VALUE="$( dialog --ok-label "Start" \
                            --no-lines --backtitle "$BACKTITLE" \
                            --form "Enter configuration for $NCP_APP" \
                            20 70 0 "${PARAMETERS[@]}" \
                    3>&1 1>&2 2>&3 )"
        RES="$?"
        case "$RES" in
            "$DIALOG_CANCEL") break ;;
                "$DIALOG_OK")
                while read -r VAL
                do RETURN_VALUES+=("$VAL")
                done <<<"$VALUE"
                    for (( i = 0 ; i < "$LENGTH" ; i++ )) # Check for invalid characters
                    do if grep -q '[\\&#;'"'"'`|*?~<>^"()[{}$&[:space:]]' <<< "${RETURN_VALUES[$i]}"
                       then log 2 "Invalid characters in field: ${VARIABLES[$i]}"; return 1
                       fi
                       CFG="$(jq ".params[$i].value = \"${RETURN_VALUES[$i]}\"" "$CFG_FILE")"
                    done
                    RET=0
                    break ;;
            "$DIALOG_ERROR") log 2 "$VALUE"; break ;;
              "$DIALOG_ESC") log -1 "ESC pressed."; break ;;
                          *) log -1 "Return code was: $RES"; break ;;
        esac
    done
    
    Print "$CFG" > "$CFG_FILE"
    printf '\033[2J' && tput cup 0 0             # clear screen, don't clear scroll, cursor on top
    log 0 "Configured app: $NCP_APP"; return "$RET"
}

# Return codes
function persistent_cfg {
    local SRC="$1" DST="${2:-/data/etc/$( basename "$SRC" )}"
    log -1 "Persisting configuration"
    # Trick to disable in dev docker
    if isPath '/changelog.md'
    then return
    fi
    mkdir --parents "$(dirname "$DST")"
    if ! isPath "$DST"
    then log -1 "Making $SRC persistent"; mv "$SRC" "$DST"
    fi
    rm --recursive --force "$SRC"
    ln -s "$DST" "$SRC"; log 0 "Persist configuration is complete"
}

# Return codes
function cleanup_script {
    local SCRIPT="$1"
    log -1 "Cleanup script: $SCRIPT"; unset cleanup
    # shellcheck disable=SC1090
    log -1 "Source: $SCRIPT"; source "$SCRIPT"
    if isMatch "$(type -t cleanup)" "function"
    then log -1 "Cleanup function found: $SCRIPT"; cleanup; return "$?"
    fi
    return 0
}

function check_distro {
    local CFG="${1:-$NCPCFG}" SUPPORTED
    SUPPORTED="$(jq -r '.release' "$CFG")"
    log -1 "Checking support for distro"
    if grep -q "$SUPPORTED" <(lsb_release -sc)
    then log 0 "Supported"; return 0
    else log 2 "Not supported"; return 1
    fi
}

# Return codes
# 1: File not found: $CFG_FILE
function clear_password_fields {
    local -r CFG_FILE="$1"
    local LENGTH TYPE VAL
    if ! isFile "$CFG_FILE"
    then log 2 "File not found: $CFG_FILE"; return 1
    fi
    LENGTH="$(jq '.params | length' "$CFG_FILE")"
    for (( i = 0 ; i < "$LENGTH" ; i++ ))
    do TYPE="$(jq -r ".params[$i].type" "$CFG_FILE")"
       VAL="$(jq -r ".params[$i].value" "$CFG_FILE")"
       if isMatch "$TYPE" "password"
       then VAL=""
        fi
        CFG="$(jq -r ".params[$i].value=\"$VAL\"" "$CFG_FILE")"
    done
    Print "$CFG" > "$CFG_FILE"
}

# Return codes
# 1: Missing command: a2query
function is_ncp_activated {
    if hasCMD a2query
    then (! a2query -s ncp-activation -q)
    else log 2 "Missing command: a2query"; return 1
    fi
}

function is_active_app {
    local NCP_APP="$1" BINDIR="${2:-$BINDIR}"
    local SCRIPT="${BINDIR}/${NCP_APP}.sh"
    local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
    local LENGTH VAL VAR ID VALUE
    
    if ! isFile "$SCRIPT"
    then SCRIPT="$(find "$BINDIR" -name "$NCP_APP".sh | head -1)"
    fi
    if ! isFile "$SCRIPT"
    then log 2 "File not found: $NCP_APP"; return 1
    fi
    
    # Function
    unset is_active
    
    #shellcheck disable=SC1090
    source "$SCRIPT"
    if isMatch "$( type -t is_active )" "function" # Read config parameters
    then if isFile "$CFG_FILE"
         then LENGTH="$(jq '.params | length' "$CFG_FILE")"
              for (( i = 0; i < "$LENGTH"; i++ ))
              do VAR="$(jq -r ".params[$i].id" "$CFG_FILE")"
                 VAL="$(jq -r ".params[$i].value" "$CFG_FILE")"
                 eval "$VAR=$VAL"
              done
         fi
         is_active; return "$?";
    fi
    
    # Config
    if ! isFile "$CFG_FILE"
    then log 2 "File not found: $CFG_FILE"; return 1
    fi
    
    ID="$(jq -r ".params[0].id" "$CFG_FILE")"
    VALUE="$(jq -r ".params[0].value" "$CFG_FILE")"
    
    if isMatch "$ID" "ACTIVE" && isMatch "$VALUE" "yes"
    then return 0
    fi
}

# Return codes
function is_app_enabled {
    local -r APP="$1"
    ncc app:list | sed '0,/Disabled/!d' | grep -q "$APP"
}

# Return codes
# 1: Invalid number of arguments
function info_app {
    [[ "$#" -ne 1 ]] && return 1
    local -r NCP_APP="$1"
    local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
    local INFO INFOTITLE
    
    if isFile "$CFG_FILE"
    then INFO="$(jq -r '.info' "$CFG_FILE")"
         INFOTITLE="$(jq -r '.infotitle' "$CFG_FILE")"
    fi
    
    if isZero "$INFO" || isMatch "$INFO" "null"
    then return 0
    fi
    if isZero "$INFOTITLE" || isMatch "$INFOTITLE" "null"
    then INFOTITLE="Info"
    fi
    
    whiptail --yesno \
             --backtitle "NextcloudPi configuration" \
             --title "$INFOTITLE" \
             --yes-button "I understand" \
             --no-button "Go back" \
             "$INFO" 20 90
}

# Return codes
function is_an_ip {
    local -r IP_OR_DOMAIN="$1"
    grep -oPq '\d{1,3}(.\d{1,3}){3}' <<<"$IP_OR_DOMAIN"
}

function get_ip {
    local IFACE
    IFACE="$(ip r | grep "default via" | awk '{ print $5 }' | head -1)"
    ip a show dev "$IFACE" | grep 'global' | grep -oP '\d{1,3}(.\d{1,3}){3}' | head -1
}

function is_docker {
    isFile /.dockerenv || isFile /.docker-image || isEqual "$DOCKERBUILD" 1
}

function is_lxc {
    grep -q container=lxc /proc/1/environ &>/dev/null
}

# Return codes
# 1: Missing command: ncc
function nc_version {
    if hasCMD ncc
    then ncc status | grep "version:" | awk '{ print $3 }'
    else log 2 "Missing command: ncc"; return 1
    fi
}

# Return codes
# 2: Missing command: ncc
function set-nc-domain {
    local DOMAIN="${1?}" PROTOCOL URL
    DOMAIN="$(sed 's|http.\?://||;s|\(/.*\)||' <<<"$DOMAIN")"
    if ! ping -c1 -w1 -q "$DOMAIN" &>/dev/null
    then unset DOMAIN
    fi
    if [[ "$DOMAIN" == "" ]] || is_an_ip "$DOMAIN"
    then log 1 "No domain found. Defaulting to hostname: $(hostname)"
         DOMAIN="$(hostname)"
    fi
    
    if ! PROTOCOL="$(ncc config:system:get overwriteprotocol)"
    then true
    fi
    if isZero "$PROTOCOL"
    then PROTOCOL="https"
    fi
    URL="${PROTOCOL}://${DOMAIN%*/}"
    if notMatch "$2" "--no-trusted-domain"
    then if hasCMD ncc
         then ncc config:system:set trusted_domains 3 --value="${DOMAIN%*/}"
              ncc config:system:set overwrite.cli.url --value="${URL}/"
              if is_ncp_activated && is_app_enabled notify_push
              then ncc config:system:set trusted_proxies 11 --value="127.0.0.1"
                   ncc config:system:set trusted_proxies 12 --value="::1"
                   ncc config:system:set trusted_proxies 13 --value="$DOMAIN"
                   ncc config:system:set trusted_proxies 14 --value="$(dig +short "$DOMAIN")"
                   sleep 5 # this seems to be required in the VM for some reason.
                   # We get `http2 error: protocol error` after ncp-upgrade-nc
                   for ATTEMPT in {1..5}
                   do log -1 "Setup notify_push (attempt ${ATTEMPT}/5)"
                      ncc notify_push:setup "${URL}/push" && break
                      sleep 10
                   done
              fi
         else log 2 "Missing command: ncc"; return 2
         fi
    fi
}

function start_notify_push {
    pgrep notify_push &>/dev/null && return
    if isFile /.docker-image
    then NEXTCLOUD_URL=https://localhost sudo -E -u www-data "/var/www/nextcloud/apps/notify_push/bin/${ARCH}/notify_push" --allow-self-signed /var/www/nextcloud/config/config.php &>/dev/null &
    else systemctl enable --now notify_push
    fi
    sleep 5 # apparently we need to make sure we wait until the database is written or something
}

# Return codes
function notify_admin {
    local HEADER="$1" MSG="$2" ADMINS
    ADMINS="$(mysql -u root nextcloud -Nse "select uid from oc_group_user where gid='admin';")"
    if isZero "$ADMINS"
    then log 2 "Admin user(s) not found" >&2; return 0
    fi
    while read -r ADMIN
    do if ! ncc notification:generate "$ADMIN" "$HEADER" -l "$MSG"
       then true
       fi
    done <<<"$ADMINS"
}

# Return codes
function run_app {
    local NCP_APP="$1" SCRIPT
    SCRIPT="$(find "$BINDIR" -name "$NCP_APP".sh | head -1)"
    if ! isFile "$SCRIPT"
    then log 2 "File not found: $SCRIPT"; return 1
    fi
    run_app_unsafe "$SCRIPT"
}

# Return codes
function run_app_unsafe {
    local -r SCRIPT="$1" LOG='/var/log/ncp.log'
    local NCP_APP CFG_FILE LENGTH VAR VAL RET
        
    NCP_APP="$(basename "$SCRIPT" .sh)"
    CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
    
    if ! isFile "$SCRIPT"
    then log 2 "File not found: $SCRIPT"; return 1
    fi
    
    touch               "$LOG"
    chmod 640           "$LOG"
    chown root:www-data "$LOG"
    
    log -1 "Running: $NCP_APP"
    echo " [ $NCP_APP ] ($(date))" >> "$LOG"
    log -1 "Reading script: $NCP_APP"
    # Read script
    unset configure
    log -1 "Sourcing script: $NCP_APP"
    # shellcheck disable=SC1090
    source "$SCRIPT"
    
    # Read config parameters
    if isFile "$CFG_FILE"
    then log -1 "Reading config parameters: $NCP_APP"
         LENGTH="$(jq '.params | length' "$CFG_FILE")"
         for (( i = 0; i < "$LENGTH"; i++ ))
         do VAR="$(jq -r ".params[$i].id" "$CFG_FILE")"
            VAL="$(jq -r ".params[$i].value" "$CFG_FILE")"
            eval "$VAR=$VAL"
         done
    fi
    
    # Run
    log -1 "Executing configure: $NCP_APP"
    ( configure ) 2>&1 | tee -a "$LOG"; RET="${PIPESTATUS[0]}"
    
    Print "" >> "$LOG"
    
    if isFile "$CFG_FILE"
    then log -1 "Clearing password fields: $NCP_APP"
         clear_password_fields "$CFG_FILE"
    fi
    log 0 "Completed: $NCP_APP"; return "$RET"
}

# Return codes
# 1: File not found: $SCRIPT
function find_app_param_num {
    local SCRIPT="${1?}" PARAM_ID="${2?}" \
                         NCP_APP CFG_FILE \
                         LENGTH VAL VAR P_ID
    NCP_APP="$(basename "$SCRIPT" .sh)"
    CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
    if isFile "$CFG_FILE"
    then LENGTH="$(jq '.params | length' "$CFG_FILE")"
         for (( i = 0 ; i < "$LENGTH" ; i++ ))
         do P_ID="$(jq -r ".params[$i].id" "$CFG_FILE")"
            if isMatch "$PARAM_ID" "$P_ID"
            then echo "$i"; return 0
            fi
         done
    else log 2 "File not found: $SCRIPT"; return 1
    fi
}

function find_app_param {
    local -r SCRIPT="${1?}" PARAM_ID="${2?}"
    local NCP_APP CFG_FILE P_NUM
    NCP_APP="$(basename "$SCRIPT" .sh)"
    CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
    
    if ! P_NUM="$(find_app_param_num "$SCRIPT" "$PARAM_ID")"
    then log 2 "Parameter index not found: $SCRIPT"; return 1
    fi
    if ! isFile "$CFG_FILE"
    then log 2 "File not found: $CFG_FILE"; return 2
    fi
    jq -r ".params[$P_NUM].value" "$CFG_FILE"
}

function set_app_param {
    local SCRIPT="${1?}" PARAM_ID="${2?}" PARAM_VALUE="${3?}"
    local NCP_APP CFG LENGTH PARAM_FOUND
    NCP_APP="$(basename "$SCRIPT" .sh)"
    local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
    
    if grep -q '[\\&#;'"'"'`|*?~<>^"()[{}$&[:space:]]' <<< "$PARAM_VALUE"
    then log 2 "Invalid characters in field ${VARIABLES[$i]}"; return 1
    fi
    if ! isFile "$CFG_FILE"
    then log 2 "File not found: $CFG_FILE"; return 2
    fi
    
    LENGTH="$(jq  '.params | length' "$CFG_FILE")"
    PARAM_FOUND=false
    
    for (( i = 0; i < "$LENGTH"; i++ )) # check for invalid characters
    do if isMatch "$(jq -r ".params[$i].id" "$CFG_FILE")" "$PARAM_ID"
       then PARAM_FOUND=true
            CFG="$(jq ".params[$i].value = \"$PARAM_VALUE\"" "$CFG_FILE")"
        fi
    done
    if notMatch "$PARAM_FOUND" "true"
    then log 2 "Did not find parameter: $PARAM_ID when configuring app: $(basename "$SCRIPT" .sh)"; return 1
    fi
    Print "$CFG" > "$CFG_FILE"
}

# Return codes
function install_template {
    local -r TEMPLATE="${1?}" TARGET="${2?}"
    local BACKUP
    BACKUP="$(mktemp)"
    
    log -1 "Installing template: $TEMPLATE"
    
    mkdir --parents "$(dirname "$TARGET")"
    if isFile "$TARGET"
    then cp -a "$TARGET" "$BACKUP"
    fi
    {
        if [[ "${3:-}" == "--defaults" ]]
        then { bash -C /usr/local/etc/ncp-templates/"$TEMPLATE" --defaults > "$TARGET"; } 2>&1
        else { bash -C /usr/local/etc/ncp-templates/"$TEMPLATE" > "$TARGET"; } 2>&1 || \
               if [[ "${3:-}" == "--allow-fallback" ]]
               then { bash -C /usr/local/etc/ncp-templates/"$TEMPLATE" --defaults > "$TARGET"; } 2>&1
               fi
        fi
    } || {
        log 2 "Could not generate: $TARGET From template: $TEMPLATE. Rolling back.."
        mv "$BACKUP" "$TARGET"; return 1
    }
    rm "$BACKUP"
}

function save_maintenance_mode
{
    unset NCP_MAINTENANCE_MODE
    if hasCMD ncc
    then if grep -q 'enabled' <(ncc maintenance:mode)
         then export NCP_MAINTENANCE_MODE="on" || true
         fi
         ncc maintenance:mode --on
    else if grep -q enabled <("$ncc" maintenance:mode)
         then export NCP_MAINTENANCE_MODE="on" || true
         fi
         "$ncc" maintenance:mode --on
    fi
}

function restore_maintenance_mode
{
    if hasCMD ncc
    then if notZero "${NCP_MAINTENANCE_MODE:-}"
         then ncc maintenance:mode --on
         else ncc maintenance:mode --off
         fi
    else if notZero "${NCP_MAINTENANCE_MODE:-}"
         then ${ncc} maintenance:mode --on
         else ${ncc} maintenance:mode --off
         fi
    fi
}

function needs_decrypt
{
    local ACTIVE
    ACTIVE="$(find_app_param_num nc-encrypt ACTIVE)"
    (! is_active_app nc-encrypt) && isMatch "$ACTIVE" "yes"
}

function set_ncpcfg {
    local NAME="${1}" VALUE="${2}" CFG
    CFG="$(jq ".$NAME = \"$VALUE\"" "$NCPCFG")"
    Print "$CFG" > "$NCPCFG"
}

function get_ncpcfg
{
    local NAME="${1}"
    if isFile "$NCPCFG"
    then jq -r ".$NAME" "$NCPCFG"
    else log 2 "File not found: $NCPCFG"; return 1
    fi
}

function get_nc_config_value
{
    sudo -u www-data php -r "include(\"/var/www/nextcloud/config/config.php\"); echo(\$CONFIG[\"${1?Missing required argument: config key}\"]);"
    #ncc config:system:get "${1?Missing required argument: config key}"
}

function clear_opcache
{
    # shellcheck disable=SC2155
    local DATA_DIR="$(get_nc_config_value datadirectory)"
    if isDirectory "${DATA_DIR:-/var/www/nextcloud/data}/.opcache"
    then log -1 "Clearing opcache"
         log -1 "This can take some time, please don't interrupt by closing or refreshing your browser tab"
         rm --recursive --force "${DATA_DIR:-/var/www/nextcloud/data}/.opcache"/* "${DATA_DIR:-/var/www/nextcloud/data}/.opcache"/.[!.]*
         log 0 "Cleared opcache"
    fi
    service php"$PHPVER"-fpm reload
}

########################
###### VARIABLES #######
########################

LIBRARY="$(Print "${BASH_SOURCE[0]}")"
if isSet LIBRARY
then log -2 "LIBRARY: $LIBRARY"
fi

CFGDIR="${CFGDIR:-etc/ncp-config.d}"
if isDirectory "$CFGDIR"
then CFGDIR="$CFGDIR"
elif isDirectory '/usr/local/etc/ncp-config.d'
then CFGDIR='/usr/local/etc/ncp-config.d'
else log 2 "Directory not found: ncp-config.d"; return 1
fi

log -2 "CFGDIR: $CFGDIR"; export CFGDIR

BINDIR="${BINDIR:-/usr/local/bin/ncp}"
log -2 "BINDIR: $BINDIR"; export BINDIR

NCDIR="${NCDIR:-/var/www/nextcloud}"
log -2 "NCDIR: $NCDIR"; export NCDIR

ncc="${ncc:-/usr/local/bin/ncc}"
log -2 "ncc: $ncc"; export ncc

# if isFile "$ncc"; then
#   ncc="$ncc"
# fi

NCPCFG="${NCPCFG:-etc/ncp.cfg}"
if isFile "$NCPCFG"
then NCPCFG="$NCPCFG"
elif isFile '/usr/local/etc/ncp.cfg'
then NCPCFG='/usr/local/etc/ncp.cfg'
elif isFile 'ncp.cfg'
then NCPCFG='ncp.cfg'
else log 2 "File not found: ncp.cfg"; return 1
fi

log -2 "NCPCFG: $NCPCFG"; export NCPCFG

if ! hasCMD dpkg
then log 2 "Missing command: dpkg"; return 1
else ARCH="$(dpkg --print-architecture)"
fi

if [[ "$ARCH" =~ ^(armhf|arm)$ ]]
then ARCH='armv7'
elif isMatch "$ARCH" "arm64"
then ARCH='aarch64'
elif isMatch "$ARCH" "amd64"
then ARCH='x86_64'
fi

DETECT_DOCKER="$(ps -p 1 --no-headers -o "%c")"

if isMatch "$(ps -p 1 --no-headers -o "%c")" "systemd" \
&& ! isDirectory "/run/systemd/system"
then INIT_SYSTEM="chroot"
elif isDirectory "/run/systemd/system"
then INIT_SYSTEM="systemd"
elif isMatch "$DETECT_DOCKER" "run-parts.sh"
then INIT_SYSTEM="docker"
else INIT_SYSTEM="unknown"
fi

unset DETECT_DOCKER

if ! hasCMD jq
then if ! installPKG jq
     then return 1
     fi
fi

NCLATESTVER="$(jq -r '.nextcloud_version' "$NCPCFG")"
PHPVER="$(     jq -r '.php_version'       "$NCPCFG")"
RELEASE="$(    jq -r '.release'           "$NCPCFG")"
CFGRELEASE="$RELEASE"

# The default security repository in bullseye is bullseye-security
if grep -Eh '^deb ' /etc/apt/sources.list | grep "${RELEASE}-security" > /dev/null
then RELEASE="${RELEASE}-security"
fi

if hasCMD ncc
then NCVER="$(ncc status 2>/dev/null | grep "version:" | awk '{ print $3 }')"
     log -2 "Found command: ncc"; log -2 "NCVER: $NCVER"
     export NCVER
elif isSet NCVER
then log -2 "NCVER: $NCVER"
fi

# Prevent systemd pager from blocking script execution
export SYSTEMD_PAGER=
log -2 "ARCH: $ARCH";               export ARCH
log -2 "INIT_SYSTEM: $INIT_SYSTEM"; export INIT_SYSTEM
log -2 "NCLATESTVER: $NCLATESTVER"; export NCLATESTVER
log -2 "PHPVER: $PHPVER";           export PHPVER
log -2 "RELEASE: $RELEASE";         export RELEASE


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

