#!/usr/bin/env bash

##########################
####### FUNCTIONS ########
##########################

# A log function that uses log levels for logging different outputs
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

# Checks if user running script is root or not
# Return codes
# 0: Is root
# 1: Not root
function isRoot {
  if [[ "$EUID" -eq 0 ]]
  then
    return 0
  else
    return 1
  fi
}

# Checks if a command exists on the system
# Return status codes
# 0: Command exists on the system
# 1: Command is unavailable on the system
# 2: Missing command argument to check
function hasCMD {
  if [[ "$#" -eq 1 ]]
  then
    local -r CHECK="$1"
    if command -v "$CHECK" &>/dev/null
    then
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
function hasPKG {
  if [[ "$#" -eq 1 ]]
  then
    local -r CHECK="$1"
    if dpkg-query --status "$CHECK" &>/dev/null
    then
      return 0
    elif apt-cache show "$CHECK" &>/dev/null
    then
      return 1
    else
      return 2
    fi
  else
    return 3
  fi
}

# Checks for a running process
# Return codes
# 0: Running process exists
# 1: No such running process
# 2: Missing argument: process
# 3: Missing command: pgrep
function checkProcess {
  if hasCMD pgrep
  then
    if [[ "$#" -eq 1 ]]
    then
      local -r PROCESS="$1"
      if pgrep "$PROCESS" &>/dev/null
      then
        return 0
      else
        return 1
      fi
    else
      log 2 "Requires argument: process"
      return 2
    fi
  else
    log 2 "Command not found: pgrep"
    return 3
  fi
}

# Checks for a running process
# Return codes
# 0: Running process exists
# 1: No such running process
# 2: Missing argument: process
# 3: Missing command: pgrep
function checkFullProcess {
  if hasCMD pgrep
  then
    if [[ "$#" -eq 1 ]]
    then
      local -r PROCESS="$1"
      if pgrep --full "$PROCESS" &>/dev/null
      then
        return 0
      else
        return 1
      fi
    else
      log 2 "Requires argument: process"
      return 2
    fi
  else
    log 2 "Command not found: pgrep"
    return 3
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
  then
    log 2 "Requires: [PKG(s) to install]"
    return 3
  else
    local -r PKG=("$@") OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    local -r SUDOUPDATE=(sudo apt-get "${OPTIONS[@]}" update) \
             SUDOINSTALL=(sudo apt-get "${OPTIONS[@]}" install) \
             ROOTUPDATE=(apt-get "${OPTIONS[@]}" update) \
             ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
    if ! isRoot
    then
      if "${SUDOUPDATE[@]}" &>/dev/null
      then
        log 0 "Apt list updated"
      else
        log 2 "Couldn't update apt lists"
        return 1
      fi
      log -1 "Installing ${PKG[*]}"
      if DEBIAN_FRONTEND=noninteractive "${SUDOINSTALL[@]}" "${PKG[@]}"
      then
        log 0 "Installation completed"
        return 0
      else
        log 2 "Something went wrong during installation"
        return 2
      fi
    else
      if "${ROOTUPDATE[@]}" &>/dev/null
      then
        log 0 "Apt list updated"
      else
        log 2 "Couldn't update apt lists"
        return 1
      fi
      log -1 "Installing ${PKG[*]}"
      if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "${PKG[@]}"
      then
        log 0 "Installation completed"
        return 0
      else
        log 2 "Something went wrong during installation"
        return 1
      fi
    fi
  fi
}

function installWithWorkaroundShadow {
  # Subshell to trap trap :P
  (
    local RESTORE_SHADOW=true
    [[ -L /etc/shadow ]] || RESTORE_SHADOW=false
    [[ "$RESTORE_SHADOW" == "false" ]] || {
      trap "mv /etc/shadow /data/etc/shadow; ln -s /data/etc/shadow /etc/shadow" EXIT SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM
      rm /etc/shadow
      cp /data/etc/shadow /etc/shadow
    }
    installPKG "$@"
    [[ "$RESTORE_SHADOW" == "false" ]] || {
      mv /etc/shadow /data/etc/shadow
      ln -s /data/etc/shadow /etc/shadow
    }
    trap - EXIT
  )
}

# Install configuration templates
function installTemplate {
  local TEMPLATE="${1?}" TARGET="${2?}" BACKUP \
        NCP_TEMPLATES='/usr/local/etc/ncp-templates'
  BACKUP="$(mktemp)"

  log -1 "Installing template: $TEMPLATE"
  mkdir --parents "$(dirname "$TARGET")"
  
  if [[ -f "$TARGET" ]] && cp --archive "$TARGET" "$BACKUP"
  then
    if [[ "${3:-}" == "--defaults" ]]
    then
      { bash "${NCP_TEMPLATES}/$TEMPLATE" --defaults > "$TARGET"; } 2>&1
    else
      { bash "${NCP_TEMPLATES}/$TEMPLATE" > "$TARGET"; } 2>&1 || \
        if [[ "${3:-}" == "--allow-fallback" ]]
        then
          { bash "${NCP_TEMPLATES}/$TEMPLATE" --defaults > "$TARGET"; } 2>&1
        fi
    fi
  else
    log 2 "Could not generate $TARGET from $TEMPLATE. Rolling back.."
    mv "$BACKUP" "$TARGET"
    return 1
  fi
  
  if [[ -e "$BACKUP" ]]
  then
    rm "$BACKUP"
  fi
}

# Install NextcloudPi app
function installApp {
  local NCP_APP="$1" SCRIPT
  # $1 can be either an installed app name or an app script
  if [[ -f "$NCP_APP" ]]
  then
    SCRIPT="$NCP_APP"
    NCP_APP="$(basename "$SCRIPT" .sh)"
  else
    SCRIPT="$(find "$BINDIR" -name "$NCP_APP".sh | head -1)"
  fi
  # Install
  unset install
  # shellcheck disable=SC1090
  source "$SCRIPT"
  log -1 "Installing $NCP_APP"
  # Subshell for installation
  ( install )
}

# Configures an app
function configureApp {
  local -r NCP_APP="$1" BACKTITLE="NextcloudPi configuration installer"
  local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg" RET='1' LENGTH PARAMETERS \
        ID IDs VALUE VALUES INDEX
  declare -a PARAMETERS IDs VALUES
  
  # Checks
  if ! hasPKG dialog
  then
    log 2 "Please install [dialog] for interactive configuration"
    return 1
  fi
  
  [[ ! -f "$CFG_FILE" ]] && return 0;

  LENGTH="$(jq '.params | length' "$CFG_FILE")"
  [[ "$LENGTH" -eq 0 ]] && return

  # Read config parameters
  for ((i = 0; i < LENGTH; i++))
  do
    local ID="$(   jq -r ".params[$i].id"    "$CFG_FILE")"
    local VALUE="$(jq -r ".params[$i].value" "$CFG_FILE")"
    local IDs+=("$ID")
    local VALUES+=("$VALUE")
    local INDEX=$((i+1))
    PARAMETERS+=("$ID" "$INDEX" 1 "$VALUE" "$INDEX" 15 60 120)
  done

  # dialog
  local DIALOG_OK=0 DIALOG_CANCEL=1 DIALOG_ERROR=254 DIALOG_ESC=255 \
        RES=0 DIALOG_VALUE RETURN_VALUES CFG
  declare -a RETURN_VALUES
  
  while [[ "$RES" != 1 && "$RES" != 250 ]]
  do
    DIALOG_VALUE="$(dialog --ok-label "Start" \
                    --no-lines --backtitle "$BACKTITLE" \
                    --form "Enter configuration for $NCP_APP" \
                    20 70 0 "${PARAMETERS[@]}" \
                    3>&1 1>&2 2>&3)"
    RES="$?"

    case "$RES" in
      "$DIALOG_CANCEL")
        break
        ;;
      "$DIALOG_OK")
        while read VAL
        do
          RETURN_VALUES+=("$VAL")
        done <<<"$DIALOG_VALUE"

        for ((i = 0; i < LENGTH; i++))
        do
          # Check for invalid characters
          grep -q '[\\&#;'"'"'`|*?~<>^"()[{}$&[:space:]]' <<< "${RETURN_VALUES[$i]}" && {
            echo "Invalid characters in field: ${IDs[$i]}"
            return 1
          }
          CFG="$(jq ".params[$i].value = \"${RETURN_VALUES[$i]}\"" "$CFG_FILE")"
        done
        RET=0
        break
        ;;
      "$DIALOG_ERROR")
        log 2 "$VAL"
        break
        ;;
      "$DIALOG_ESC")
        log -1 "Pressed ESC"
        break
        ;;
      *)
        log -1 "Return code: $RES"
        break
        ;;
    esac
  done

  echo "$CFG" > "$CFG_FILE"
  printf '\033[2J' && tput cup 0 0             # clear screen, don't clear scroll, cursor on top
  return "$RET"
}

function runApp {
  local NCP_APP="$1" SCRIPT
  SCRIPT="$(find "$BINDIR" -name "$NCP_APP".sh | head -1)"

  if [[ ! -f "$SCRIPT" ]]
  then
    log 2 "File not found: $SCRIPT"
    return 1
  fi

  runAppUnsafe "$SCRIPT"
}

# Receives a script file and runs it without security checks
# Return codes
# 1: Script file not found
# 2: Config file not found
function runAppUnsafe {
  local -r SCRIPT="$1" LOG='/var/log/ncp.log'
  local NCP_APP CFG LENGTH VAR VAL RET
  NCP_APP="$(basename "$SCRIPT" .sh)"
  local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"

  if [[ ! -f "$SCRIPT" ]]
  then
    log 1 "File not found: $SCRIPT"
    return 1
  fi
  if isRoot
  then
    touch                          "$LOG"
    chmod 640                      "$LOG"
    chown root:www-data            "$LOG"
  else
    sudo touch                     "$LOG"
    sudo chmod 640                 "$LOG"
    sudo chown root:www-data       "$LOG"
  fi
  
  log -1 "Running: $NCP_APP"
  echo "[ $NCP_APP ] ($(date))" >> "$LOG"
  # Read script
  unset configure
  # shellcheck disable=SC1090
  source "$SCRIPT"

  # Read config parameters
  if [[ ! -f "$CFG_FILE" ]]
  then
    log 2 "File not found: $CFG_FILE"
    return 2
  else
    LENGTH="$(jq '.params | length' "$CFG_FILE")"
    for ((I = 0; I < LENGTH; I++))
    do
      VAR="$(jq -r ".params[$I].id"    "$CFG_FILE")"
      VAL="$(jq -r ".params[$I].value" "$CFG_FILE")"
      eval "$VAR=$VAL"
    done
    # Run
    (configure) 2>&1 | tee -a "$LOG"
    RET="${PIPESTATUS[0]}"
    echo "" >> "$LOG"
    clearPasswordFields "$CFG_FILE"
    return "$RET"
  fi
}

# Finds the parameter number for an app
# 0: Index found
# 1: Index not found
function findAppParameterIndex() {
  local SCRIPT="${1?}" PARAM_ID="${2?}" NCP_APP CFG LENGTH ID_PARAM
  NCP_APP="$(basename "$SCRIPT" .sh)"
  local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"
  if [[ -f "$CFG_FILE" ]]
  then
    LENGTH="$(jq '.params | length' "$CFG_FILE")"
    for ((INDEX = 0; INDEX < LENGTH; INDEX++))
    do
      ID_PARAM="$(jq -r ".params[$i].id" "$CFG_FILE")"
      if [[ "$PARAM_ID" == "$ID_PARAM" ]]
      then
        echo "$INDEX"
        return 0
      fi
    done
  else
    return 1
  fi
}

# Finds the parameter value for an app
# 0: Parameter value found
# 1: Parameter value not found
function findAppParameter {
  local SCRIPT="${1?}" PARAM_ID="${2?}"
  local NCP_APP PARAM_INDEX
  NCP_APP="$(basename "$SCRIPT" .sh)"
  local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"

  if PARAM_INDEX="$(findAppParameterIndex "$SCRIPT" "$PARAM_ID")"
  then
    jq -r ".params[$PARAM_INDEX].value" "$CFG_FILE"
    return 0
  else
    return 1
  fi
}

# Sets a parameter in the config file
# 0: Parameter found and value set
# 1: Parameter not found
# 2: Invalid characters in parameter value
function setAppParameter {
  local SCRIPT="${1?}" PARAM_ID="${2?}" PARAM_VALUE="${3?}" \
        NCP_APP CFG LENGTH PARAM_FOUND
  NCP_APP="$(basename "$SCRIPT" .sh)"
  local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"

  grep -q '[\\&#;'"'"'`|*?~<>^"()[{}$&[:space:]]' <<< "${PARAM_VALUE}" && {
    echo "Invalid characters in field: $PARAM_VALUE"
    return 2
  }

  LENGTH="$(jq '.params | length' "$CFG_FILE")"
  PARAM_FOUND=false

  for (( i = 0 ; i < LENGTH ; i++ )); do
    # check for invalid characters
    [[ "$(jq -r ".params[$i].id" "$CFG_FILE")" == "$PARAM_ID" ]] && {
      CFG="$(jq ".params[$i].value = \"$PARAM_VALUE\"" "$CFG_FILE")"
      PARAM_FOUND=true
    }
  done
  
  if [[ "$PARAM_FOUND" == "false" ]]
  then
    log 1 "Did not find parameter: [$PARAM_ID] in configuration of app: [$(basename "$SCRIPT" .sh)]"
    return 1
  fi
  echo "$CFG" > "$CFG_FILE"
  return 0
}

# Set nextcloudpi config
function set_ncpcfg {
  local NAME="${1}" VALUE="${2}" CFG
  CFG="$(jq '.' "$NCPCFG")"
  CFG="$(jq ".$NAME = \"$VALUE\"" <<<"$CFG")"
  echo "$CFG" > "$NCPCFG"
}


# Checks if an app is active or not
function isActiveApp {
  local NCP_APP="$1" BIN_DIR="${2:-.}" LENGTH VAR VAL
  local SCRIPT="${BIN_DIR}/${NCP_APP}.sh"
  local CFG_FILE="${CFGDIR}/${NCP_APP}.cfg"

  [[ -f "$SCRIPT" ]] || SCRIPT="$(find "$BINDIR" -name "$NCP_APP".sh | head -1)"
  [[ -f "$SCRIPT" ]] || { log 2 "File not found: $SCRIPT"; return 1; }

  # function
  unset is_active
  # shellcheck disable=SC1090
  source "$SCRIPT"
  [[ "$(type -t is_active)" == function ]] && {
    # read cfg parameters
    [[ -f "$CFG_FILE" ]] && {
      LENGTH="$(jq '.params | length' "$CFG_FILE")"
      for (( i = 0 ; i < LENGTH ; i++ )); do
        VAR="$(jq -r ".params[$i].id"    "$CFG_FILE")"
        VAL="$(jq -r ".params[$i].value" "$CFG_FILE")"
        eval "$VAR=$VAL"
      done
    }
    is_active
    return "$?";
  }

  # Config
  [[ -f "$CFG_FILE" ]] || return 1
  [[ "$(jq -r ".params[0].id"    "$CFG_FILE")" == "ACTIVE" ]] && \
  [[ "$(jq -r ".params[0].value" "$CFG_FILE")" == "yes"    ]] && \
  return 0
}

# A function to set Nextcloud domain
function setNextcloudDomain {
  local DOMAIN="${1?}" PROTOCOL URL
  DOMAIN="$(sed 's|http.\?://||;s|\(/.*\)||' "$DOMAIN")"
  if ! ping -c1 -w1 -q "$DOMAIN" &>/dev/null
  then
    unset DOMAIN
  fi
  if [[ "$DOMAIN" == "" ]] || is_an_ip "$DOMAIN"
  then
    log 1 "No domain found. Defaulting to hostname: $(hostname)"
    DOMAIN="$(hostname)"
  fi
  PROTOCOL="$(ncc config:system:get overwriteprotocol)" || true
  [[ "$PROTOCOL" == "" ]] && PROTOCOL="https"
  URL="${PROTOCOL}://${DOMAIN%*/}"
  [[ "$2" == "--no-trusted-domain" ]] || ncc config:system:set trusted_domains 3 --value="${DOMAIN%*/}"
  ncc config:system:set overwrite.cli.url --value="${URL}/"
  
  if is_ncp_activated && is_app_enabled notify_push
  then
    ncc config:system:set trusted_proxies 11 --value="127.0.0.1"
    ncc config:system:set trusted_proxies 12 --value="::1"
    ncc config:system:set trusted_proxies 13 --value="${DOMAIN}"
    ncc config:system:set trusted_proxies 14 --value="$(dig +short "${DOMAIN}")"
    sleep 5 # this seems to be required in the VM for some reason. We get `http2 error: protocol error` after ncp-upgrade-nc
    for ATTEMPT in {1..5}
    do
      echo "Setup notify_push (attempt ${ATTEMPT}/5)"
      ncc notify_push:setup "${URL}/push" && break
      sleep 10
    done
  fi
}

function startNotifyPush {
    pgrep notify_push &>/dev/null && return
    if [[ -f /.docker-image ]]; then
      NEXTCLOUD_URL=https://localhost sudo -E -u www-data "/var/www/nextcloud/apps/notify_push/bin/${ARCH}/notify_push" --allow-self-signed /var/www/nextcloud/config/config.php &>/dev/null &
    else
      systemctl enable --now notify_push
    fi
    sleep 5 # apparently we need to make sure we wait until the database is written or something
}

# Downloads Raspberry Pi OS
function downloadRPiOS {
  local -r URL="$1" IMGFILE="$2" ARGS=(--verbose --reflink=auto)
  local -r IMG_CACHE='cache/raspios_lite.img' ZIP_CACHE='cache/raspios_lite.xz'
  mkdir -p cache
  log -1 "Downloading RPi OS"
  if [[ -f "$IMG_CACHE" ]]
  then
    log -1 "Download skipped, file exists: $IMG_CACHE"
    cp "${ARGS[@]}" "$IMG_CACHE" "$IMGFILE"
    return 0
  elif [[ -f "$ZIP_CACHE" ]]
  then
    log -1 "Download skipped, file exists: $ZIP_CACHE"
    cp "${ARGS[@]}" "$ZIP_CACHE" "$IMGFILE"
    return 0
  else
    wget "$URL" -nv -O "$ZIP_CACHE" || return 1
  fi
  unxz -k -c "$ZIP_CACHE" > "$IMG_CACHE"
  cp "${ARGS[@]}" "$IMG_CACHE" "$IMGFILE"
}

# Mount RPi OS for chroot
function mountRPi {
  local -r IMG="$1" MOUNT_POINT='raspbian_root'
  [[ ! -f "$IMG" ]] && {
    log 2 "IMG file not found: $IMG"
    return 1
  }
  [[ -e "$MOUNT_POINT" ]] && {
    log 2 "Mount point already exists: $MOUNT_POINT"
    return 1
  }
  local -r SECTOR="$(fdisk -l "$IMG" | grep 'Linux' | awk '{print $2}')"
  local -r OFFSET=$((SECTOR * 512))
  log -1 "Creating mount point: $MOUNT_POINT"
  mkdir --parents "$MOUNT_POINT"
  if isRoot
  then
    mount "$IMG" -o offset="$OFFSET" "$MOUNT_POINT" || return 1
  else
    sudo mount "$IMG" -o offset="$OFFSET" "$MOUNT_POINT" || return 1
  fi
  log -1 "RPi OS IMG mounted at: $MOUNT_POINT"
}

# Mounts RPi IMG Boot partition
function mountRPiBoot {
  local -r IMG="$1" MOUNT_POINT='raspbian_boot'
  [[ ! -f "$IMG" ]] && {
    log 2 "IMG file not found: $IMG"
    return 1
  }
  [[ -e "$MOUNT_POINT" ]] && {
    log 2 "Mount point already exists: $MOUNT_POINT"
    return 1
  }
  local SECTOR
  SECTOR="$(fdisk -l "$IMG" | grep 'FAT32' | awk '{print $2}')"
  local OFFSET=$((SECTOR * 512))
  mkdir --parents "$MOUNT_POINT"
  if isRoot
  then
    mount "$IMG" -o offset="$OFFSET" "$MOUNT_POINT" || return 1
  else
    sudo mount "$IMG" -o offset="$OFFSET" "$MOUNT_POINT" || return 1
  fi
  log 0 "RPi OS IMG Mounted at: $MOUNT_POINT"
}

# Unmounts the IMG mounted for chroot
function unmountRPi {
  local -r RPI_ROOT='raspbian_root' RPI_BOOT='raspbian_boot'
  [[ -d "$RPI_ROOT" ]] && { { sudo umount -l "$RPI_ROOT"; rmdir "$RPI_ROOT"; } || return 1; }
  [[ -d "$RPI_BOOT" ]] && { { sudo umount -l "$RPI_BOOT"; rmdir "$RPI_BOOT"; } || return 1; }
  if ! [[ -d "$RPI_ROOT" || -d "$RPI_BOOT" ]]
  then
    log -1 "Mount points not found: $RPI_ROOT & $RPI_BOOT"
    return 0
  fi
  log 0 "RPi OS IMG Umounted"
}


# sets DEV
function resizeIMG {
  local -r IMG="$1" SIZE="$2"
  local DEV
  log -1 "Resizing IMG"
  
  if hasCMD fallocate
  then
    if isRoot
    then
      fallocate -l"$SIZE" "$IMG"
    else
      sudo fallocate -l"$SIZE" "$IMG"
    fi
  else
    log 2 "Missing command: fallocate"
    exit 1
  fi
  
  if hasCMD parted
  then
    if isRoot
    then
      parted      "$IMG" -- resizepart 2 -1s
    else
      sudo parted "$IMG" -- resizepart 2 -1s
    fi
  else
    log 2 "Missing command: parted"
    log -1 "Attempting to install"
    if ! installPKG parted
    then
      exit 1
    fi
  fi
  
  if hasCMD losetup
  then
    if isRoot
    then
      DEV="$(losetup -f)"
    else
      DEV="$(sudo losetup -f)"
    fi
  else
    log 2 "Missing command: losetup"
    log -1 "Attempting to install"
    if ! installPKG mount
    then
      exit 1
    fi
  fi
  
  mountRPi "$IMG"
  
  if hasCMD resize2fs
  then
    if isRoot
    then
      resize2fs -f "$DEV"
    else
      sudo resize2fs -f "$DEV"
    fi
  else
    log 2 "Missing command: resize2fs"
    exit 1
  fi
  
  log 0 "IMG Resized"
  unmountRPi
}


# Cleanup after chroot on Raspberry Pi OS
function cleanChrootRPi {
  local -r RPI_ROOT='raspbian_root'
  if isRoot
  then
    rm --force          "${RPI_ROOT}/usr/bin/qemu-aarch64-static"
    rm --force          "${RPI_ROOT}/usr/sbin/policy-rc.d"
    umount --lazy       "${RPI_ROOT}/{proc,sys,dev/pts,dev}"
  else
    sudo rm --force     "${RPI_ROOT}/usr/bin/qemu-aarch64-static"
    sudo rm --force     "${RPI_ROOT}/usr/sbin/policy-rc.d"
    sudo umount --lazy  "${RPI_ROOT}/{proc,sys,dev/pts,dev}"
  fi  
  unmountRPi
}

# Creates & prepares directories for chroot
function prepareDirectories {
  local -r DIRS=(tmp output cache)
  [[ ! "$CLEAN" == "0" ]] && {
    log -1 "Removing download cache: ${DIRS[2]}"
    rm --recursive --force "${DIRS[2]}"
  }

  log -1 "Removing: ${DIRS[0]}"
  rm --recursive --force "${DIRS[0]}"
  
  log -1 "Creating directories: ${DIRS[*]}"
  mkdir --parents "${DIRS[@]}"
}

# Prepare RPi OS chroot
function prepareChrootRPi {
  local -r IMG="$1" RPI_ROOT='raspbian_root'
  mountRPi "$IMG" || return 1
  
  if isRoot
  then
    mount -t proc proc                "${RPI_ROOT}/proc/"
    mount -t sysfs sys                "${RPI_ROOT}/sys/"
    mount -o bind /dev                "${RPI_ROOT}/dev/"
    mount -o bind /dev/pts            "${RPI_ROOT}/dev/pts"
    if [[ -f "qemu-aarch64-static" ]]
    then
      cp qemu-aarch64-static          "${RPI_ROOT}/usr/bin/"
    else
      cp /usr/bin/qemu-aarch64-static "${RPI_ROOT}/usr/bin"
    fi
    # Prevent services from auto-starting
    bash -c "echo -e '#!/bin/sh\nexit 101' > ${RPI_ROOT}/usr/sbin/policy-rc.d"
    chmod +x "${RPI_ROOT}/usr/sbin/policy-rc.d"
  else
    sudo mount -t proc proc     "${RPI_ROOT}/proc/"
    sudo mount -t sysfs sys     "${RPI_ROOT}/sys/"
    sudo mount -o bind /dev     "${RPI_ROOT}/dev/"
    sudo mount -o bind /dev/pts "${RPI_ROOT}/dev/pts"
    if [[ -f "qemu-aarch64-static" ]]
    then
      sudo cp qemu-aarch64-static "${RPI_ROOT}/usr/bin/"
    else
      sudo cp /usr/bin/qemu-aarch64-static "${RPI_ROOT}/usr/bin"
    fi
    # Prevent services from auto-starting
    sudo bash -c "echo -e '#!/bin/sh\nexit 101' > ${RPI_ROOT}/usr/sbin/policy-rc.d"
    sudo chmod +x "${RPI_ROOT}/usr/sbin/policy-rc.d"
  fi
}

# Updates the UUID of the Boot partition
function updateBootUUID {
  local -r IMG="$1" RPI_ROOT='raspbian_root'
  local PTUUID
  
  if isRoot
  then
    PTUUID="$(blkid -o export "$IMG" | grep 'PTUUID' | sed 's|.*=||')"
  else
    PTUUID="$(sudo blkid -o export "$IMG" | grep 'PTUUID' | sed 's|.*=||')"
  fi
  
  log -1 "Updating boot partition UUID"
  mountRPi "$IMG" || return 1
  
  if isRoot
  then
  bash -c "cat > ${RPI_ROOT}/etc/fstab" <<EOF
PARTUUID=${PTUUID}-01  /boot           vfat    defaults          0       2
PARTUUID=${PTUUID}-02  /               ext4    defaults,noatime  0       1
EOF
  else
  sudo bash -c "cat > ${RPI_ROOT}/etc/fstab" <<EOF
PARTUUID=${PTUUID}-01  /boot           vfat    defaults          0       2
PARTUUID=${PTUUID}-02  /               ext4    defaults,noatime  0       1
EOF
  fi
  
  unmountRPi
  mountRPiBoot "$IMG"
  
  if isRoot
  then
    bash -c "sed -i 's|root=[^[:space:]]*|root=PARTUUID=${PTUUID}-02 |' $RPI_ROOT/cmdline.txt"
  else
    sudo bash -c "sed -i 's|root=[^[:space:]]*|root=PARTUUID=${PTUUID}-02 |' $RPI_ROOT/cmdline.txt"
  fi
  
  unmountRPi
}

# Packs the finished RPi OS IMG
function packIMG {
  local -r IMG="$1" TAR="$2"
  local DIR IMGNAME
  DIR="$(dirname  "$IMG")"
  IMGNAME="$(basename "$IMG")"
  log -1 "Packing IMG: $IMG → $TAR"
  tar -C "$DIR" -cavf "$TAR" "$IMGNAME"
  log 0 "Created: $TAR"
}

# Clears the password fields during NCP app installation
function clearPasswordFields {
  local -r CFG_FILE="$1"
  local CFG LENGTH TYPE VAL
  LENGTH="$(jq '.params | length' "$CFG_FILE")"
  for (( i = 0 ; i < LENGTH ; i++ )); do
    TYPE="$(jq -r ".params[$i].type"  "$CFG_FILE")"
    VAL="$( jq -r ".params[$i].value" "$CFG_FILE")"
    [[ "$TYPE" == "password" ]] && VAL=""
    CFG="$(jq -r ".params[$i].value=\"$VAL\"" "$CFG_FILE")"
  done
  echo "$CFG" > "$CFG_FILE"
}

# Checks if build/install is LXC
function isLXC {
  grep --quiet container=lxc /proc/1/environ &>/dev/null
}

# Gets a configuration value
function getNextcloudConfigValue {
  sudo -u www-data php -r "include(\"/var/www/nextcloud/config/config.php\"); \
                           echo(\$CONFIG[\"${1?Missing required argument: \
                           config key}\"]);"
  #ncc config:system:get "${1?Missing required argument: config key}"
}

# Get Nextcloud version
function getNextcloudVersion {
  if hasCMD ncc
  then
    ncc status | grep "version:" | awk '{print $3}'
  else
    log 2 "Missing command: ncc"
  fi
}

function is_more_recent_than {
  local VERSION_A="$1" VERSION_B="$2" \
        MAJOR_A MINOR_A PATCH_A MAJOR_B MINOR_B PATCH_B

  MAJOR_A="$(cut -d. -f1 <<<"$VERSION_A")"
  MINOR_A="$(cut -d. -f2 <<<"$VERSION_A")"
  PATCH_A="$(cut -d. -f3 <<<"$VERSION_A")"

  MAJOR_B="$(cut -d. -f1 <<<"$VERSION_B")"
  MINOR_B="$(cut -d. -f2 <<<"$VERSION_B")"
  PATCH_B="$(cut -d. -f3 <<<"$VERSION_B")"

  # Compare version A with version B
  # Return true if A is more recent than B
  if [[ "$MAJOR_B" -gt "$MAJOR_A" ]]
  then
    return 1
  elif [[ "$MAJOR_B" -eq "$MAJOR_A" && "$MINOR_B" -gt "$MINOR_A" ]]
  then
    return 1
  elif [[ "$MAJOR_B" -eq "$MAJOR_A" && "$MINOR_B" -eq "$MINOR_A" && "$PATCH_B" -ge "$PATCH_A" ]]
  then
    return 1
  fi
  return 0
}

function clearOPCache {
  local DATA_DIR
  DATA_DIR="$(getNextcloudConfigValue datadirectory)"
  ! [[ -d "${data_dir:-/var/www/nextcloud/data}/.opcache" ]] || {
    log -1 "Clearing opcache..."
    log -1 "This can take some time. Please don't interrupt the process/close your browser tab."
    rm --recursive --force "${DATA_DIR:-/var/www/nextcloud/data}"/.opcache/* \
                           "${DATA_DIR:-/var/www/nextcloud/data}"/.opcache/.[!.]*
    log 0 "Cleared opcache"
  }
  service php"$PHP_VERSION"-fpm reload
}

# Checks if the distribution is supported
function checkDistro {
  local -r NCP_CFG="${1:-$NCPCFG}"
  local SUPPORTED
  SUPPORTED="$(jq -r '.release' "$NCP_CFG")"
  if hasCMD lsb_release
  then
    if grep -q "$SUPPORTED" <(lsb_release -sc)
    then
      return 0
    else
      return 1
    fi
  else
    log 2 "Missing command: lsb_release"
    exit 2
  fi
}

# Gets IP-address
function getIP {
  local IFACE
  IFACE="$(ip r | grep "default via" | awk '{ print $5 }' | head -1)"
  ip a show dev "$IFACE" | grep 'global' | grep -oP '\d{1,3}(.\d{1,3}){3}' | head -1
}

# # # # # # # # # # # Work In Progress Below This Line # # # # # # # # # 

function sshPi {
  local -r IP="$1" ARGS=("${@:2}")
  local SSH=(ssh -q  -o UserKnownHostsFile=/dev/null \
                     -o StrictHostKeyChecking=no \
                     -o ServerAliveInterval=20 \
                     -o ConnectTimeout=20 \
                     -o LogLevel=quiet)
  "${SSH[@]}" "$PIUSER"@"$IP" "${ARGS[@]}"
}

function waitSSH {
  if [[ "$#" -ne 1 ]]
  then
    log 2 "Requires argument: [IP]"
  else
    local -r IP="$1"
    log -1 "Waiting for SSH to be up on $IP"
    while true; do
      sshPi "$IP" : && break
      sleep 1
    done
    echo "SSH is up"
  fi
}

# Launches QEMU with Raspbian IMG
function launchQEMU {
  if [[ "$#" -ne 1 ]]
  then
    log 2 "Requires argument: [IMG]"
  elif [[ ! -f "$1" ]]
  then
    log 2 "Image file not found: $1"
    return 1
  else
    local -r IMG="$1"
    test -d qemu-raspbian-network || git clone https://github.com/nachoparker/qemu-raspbian-network.git
    sed -i '30s/NO_NETWORK=1/NO_NETWORK=0/' qemu-raspbian-network/qemu-pi.sh
    sed -i '35s/NO_GRAPHIC=0/NO_GRAPHIC=1/' qemu-raspbian-network/qemu-pi.sh
    echo "Starting QEMU image $IMG"
    ( cd qemu-raspbian-network && sudo ./qemu-pi.sh ../"$IMG" 2>/dev/null )
  fi
}


# $IMG    is the source image
# $IP     is the IP of the QEMU images
# $IMGOUT will contain the name of the generated image
function launchQEMUInstall {
  if [[ "$#" -ne 2 ]]
  then
    log 2 "Requires arguments: [IMG] [IP]"
    return 1
  elif [[ ! -f "$1" ]]
  then
    log 2 "File not found: $1"
     return 1
  else
    local -r IMG="$1" IP="$2" TIME="$(date +%s)" ARGS=(--reflink=auto --verbose)
    local -r IMGOUT="${IMG}-${TIME}"
    if ! cp "${ARGS[@]}" "$IMG" "$IMGOUT"
    then
      log 2 "Copy failed: $IMG → $IMGOUT"
      return 1
    fi
    
    if checkProcess qemu-system-aarch64
    then
      log 2 "QEMU is already running"
      return 1
    fi
    log -1 "Launching QEMU"
    launchQEMU "$IMGOUT" &
    sleep 10
    waitSSH "$IP"
    qemulaunchInstallation "$IP" || return 1 # uses $INSTALLATION_CODE
    wait
    echo "$IMGOUT generated successfully"
  fi
}

function launchInstallation {
  local -r IP="$1"
  [[ "$INSTALLATION_CODE"  == "" ]] && { log 2 "Need to run config first";     return 1; }
  [[ "$INSTALLATION_STEPS" == "" ]] && { log 2 "No installation instructions"; return 1; }
  local PREINST_CODE="
set -e$DBG
sudo su
set -e$DBG
"
  log -1 "Launching installation"
  echo -e "$PREINST_CODE\n$INSTALLATION_CODE\n$INSTALLATION_STEPS" | sshPi "$IP" || { log 2 "Installation to $IP failed"; return 1; }
}

# Starts the installtion in QEMU
function qemulaunchInstallation {
  local -r IP="$1"
  [[ "$NO_CFG_STEP"  != "1" ]] && local CFG_STEP=configure
  [[ "$NO_CLEANUP"   != "1" ]] && local CLEANUP_STEP="if [[ \$(type -t cleanup) == function ]]; then cleanup; fi"
  [[ "$NO_HALT_STEP" != "1" ]] && local HALT_STEP="nohup halt &>/dev/null &"
  local INSTALLATION_STEPS="
install
$CFG_STEP
$CLEANUP_STEP
$HALT_STEP
"
  # uses $INSTALLATION_CODE
  launchInstallation "$IP"
}

# Returns true once mysql can connect.
function pingMySQL {
  local DBCONF='/root/.my.cnf'
  local DBPASSWD="$(grep 'password' "$DBCONF" | sed 's|password=||')" \
        DBNAME='nextcloud' \
        DBADMIN='ncadmin'
  mysqladmin ping --host="$DBNAME" --user="$DBADMIN" --password="$DBPASSWD" > /dev/null 2>&1
}

##########################
####### VARIABLES ########
##########################

function unsetVariables() {
  unset LOCAL LOCAL_ETC LOCAL_BIN HTML_DIR SOURCES_LIST
  [[ -n "$ARCH" ]]                     && unset ARCH
  [[ -n "$INIT_SYSTEM" ]]              && unset INIT_SYSTEM
  [[ -z "$SYSTEMD_PAGER" ]]            && unset SYSTEMD_PAGER
  [[ -n "$NEXTCLOUD_VERSION_LATEST" ]] && unset NEXTCLOUD_VERSION_LATEST
  [[ -n "$PHP_VERSION" ]]              && unset PHP_VERSION
  [[ -n "$RELEASE" ]]                  && unset RELEASE
  [[ -n "$NEXTCLOUD_VERSION" ]]        && unset NCVER
  [[ -n "$GIT_VERSION" ]]              && unset GIT_VERSION
  [[ -n "$DBG" ]]                      && unset DBG
}

LOCAL='/usr/local'
LOCAL_ETC="${LOCAL}/etc"
LOCAL_BIN="${LOCAL}/bin"
HTML_DIR='/var/www'
SOURCES_LIST='/etc/apt/sources.list'

# 0) EXIT    1) SIGHUP	 2) SIGINT	 3) SIGQUIT
# 4) SIGILL  5) SIGTRAP 6) SIGABRT	15) SIGTERM
trap 'unsetVariables' EXIT SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGTERM

[[ -d "${LOCAL_ETC}/ncp-config.d" ]] && { export CFGDIR="${LOCAL_ETC}/ncp-config.d"; }
[[ -d "${LOCAL_BIN}/ncp" ]]          && { export BINDIR="${LOCAL_BIN}/ncp"; }
[[ -d "${HTML_DIR}/nextcloud" ]]     && { export NCDIR="${HTML_DIR}/nextcloud"; }
[[ -f "${LOCAL_BIN}/ncc" ]]          && { export ncc="${LOCAL_BIN}/ncc"; }

[[ -z "$CFGDIR" ]]                   && { log 2 "Directory not found: ${LOCAL_ETC}/ncp-config.d" >&2; exit 1; }
[[ -z "$BINDIR" ]]                   && { log 2 "Directory not found: ${LOCAL_BIN}/ncp" >&2;          exit 1; }
[[ -z "$NCDIR" ]]                    && { log 2 "Directory not found: ${HTML_DIR}/nextcloud" >&2;     exit 1; }
[[ -z "$ncc" ]]                      && { log 2 "File not found: ${LOCAL_BIN}/ncc" >&2;               exit 1; }

#[[ -f "etc/ncp.cfg" ]]               && export NCPCFG="etc/ncp.cfg"
#[[ -f "${ETC}/ncp.cfg" ]]            && export NCPCFG="${ETC}/ncp.cfg"
#[[ -f "${LOCAL_ETC}/ncp.cfg" ]]      && export NCPCFG="${LOCAL_ETC}/ncp.cfg"

export NCPCFG="${NCPCFG:-etc/ncp.cfg}"
[[ -z "$NCPCFG" ]]                   && { log 2 "File not found: ncp.cfg" >&2; exit 1; }

ARCH="$(dpkg --print-architecture)"
[[ "$ARCH" =~ ^(armhf|arm)$ ]]       && ARCH='armv7'
[[ "$ARCH" == "arm64" ]]             && ARCH='aarch64'
[[ "$ARCH" == "amd64" ]]             && ARCH='x86_64'
export ARCH

# Prevent systemd pager from blocking script execution
export SYSTEMD_PAGER=

if [[ "$(ps -p 1 --no-headers -o "%c")" == "systemd" ]] && ! [[ -d "/run/systemd/system" ]]
then
  INIT_SYSTEM="chroot"
elif [[ -d "/run/systemd/system" ]]
then
  INIT_SYSTEM="systemd"
elif [[ "$(ps -p 1 --no-headers -o "%c")" == "run-parts.sh" ]]
then
  INIT_SYSTEM="docker"
else
  INIT_SYSTEM="unknown"
fi

export INIT_SYSTEM

if ! hasCMD jq
then
  if ! installPKG jq
  then
    exit 1
  fi
fi

NEXTCLOUD_VERSION_LATEST="$(jq -r '.nextcloud_version'  "$NCPCFG")"
PHP_VERSION="$(             jq -r '.php_version'        "$NCPCFG")"
RELEASE="$(                 jq -r '.release'            "$NCPCFG")"

if grep -Eh '^deb ' "$SOURCES_LIST" | grep "${RELEASE}-security" > /dev/null
then
  RELEASE="${RELEASE}-security"
fi

export NEXTCLOUD_VERSION_LATEST
export PHP_VERSION
export RELEASE

if hasCMD ncc
then
  NEXTCLOUD_VERSION="$(ncc status 2>/dev/null | grep "version:" | awk '{ print $3 }')"
  export NEXTCLOUD_VERSION
else
  log 2 "Command not found: ncc" >&2
  exit 1
fi

if [[ -d '.git' ]]
then
  GIT_VERSION="$(git describe --tags --always)"
  GIT_VERSION="${VERSION%-*-*}"
  DBG='x'
  export GIT_VERSION
  export DBG
fi

