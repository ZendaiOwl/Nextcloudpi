#!/usr/bin/env bash

# Library to install software on Raspbian ARM through QEMU
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at ownyourbits.com
#

#DBG=x

VERSION="$(git describe --tags --always)"
VERSION="${VERSION%-*-*}"
export VERSION

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

# Checks if given path is a directory 
# Return codes
# 0: Is a directory
# 1: Not a directory
# 2: Invalid number of arguments
function isDirectory {
    [[ "$#" -ne 1 ]] && return 2
    [[ -d "$1" ]]
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

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Is set
# 1: Not set 
# 2: Invalid number of arguments
function isSet {
    [[ "$#" -ne 1 ]] && return 2
    [[ -v "$1" ]]
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
    if [[ "$#" -eq 1 ]]; then declare -r CHECK="$1"
        if dpkg-query --status "$CHECK" &>/dev/null; then return 0
        elif apt-cache show "$CHECK" &>/dev/null; then return 1
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

# Checks for a running process
# Return codes
# 0: Running process exists
# 1: No such running process
# 2: Missing argument: process
# 3: Missing command: pgrep
function findProcess {
    if hasCMD pgrep &>/dev/null
    then if [[ "$#" -eq 1 ]]
         then declare -r PROCESS="$1"
              if pgrep "$PROCESS" &>/dev/null
              then return 0
              else return 1
              fi
         else return 2
         fi
    else return 3
    fi
}

# Checks for a running process
# Return codes
# 0: Running process exists
# 1: No such running process
# 2: Missing argument: process
# 3: Missing command: pgrep
function findFullProcess {
    if hasCMD pgrep &>/dev/null
    then if [[ "$#" -eq 1 ]]
         then local -r PROCESS="$1"
              if pgrep --full "$PROCESS" &>/dev/null
              then return 0
              else return 1
              fi
         else log 2 "Requires argument: process"; return 2
         fi
    else log 2 "Command not found: pgrep"; return 3
    fi
}

#
# Return codes
# 1: Copying failed
# 2: Invalid argument #2: [IP]
# 3: File not found: [IMG]
function launch_install_qemu {
    [[ "$#" -lt 2 ]] && return 1
    local IMG="$1" IP="$2" IMGOUT
    if isZero "$IP"
    then log 2 "Invalid argument #2: [IP]"; return 2
    elif ! isFile "$IMG"
    then log 2 "File not found: $IMG"; return 3
    fi
    IMGOUT="${IMG}-$( date +%s )"
    if ! cp --reflink=auto -v "$IMG" "$IMGOUT"
    then log 2 "Copying IMG failed"; return 1
    fi
    if hasCMD pgrep
    then if findProcess qemu-system-aarch64
         then log 2 "QEMU is already running"; return 1
         fi
    else log 2 "Missing command: pgrep"; return 1
    fi
    # TODO
    launch_qemu "$IMGOUT" &
    sleep 10
    wait_SSH "$IP"
    launch_installation_qemu "$IP" || return 1 # uses $INSTALLATION_CODE
    wait
    log -1 "Image generated successfully: $IMGOUT"
}


# Return codes
# 1: Invalid number of arguments
# 2: File not found: [IMG]
# 3: Missing command: sed
function launch_qemu {
    [[ "$#" -lt 1 ]] && return 1
    local IMG="$1"
    if ! isFile "$IMG"
    then log 2 "File not found: $IMG"; return 2
    fi
    
    if ! isDirectory qemu-raspbian-network
    then git clone https://github.com/nachoparker/qemu-raspbian-network.git
    fi
    
    if hasCMD sed
    then sed -i '30s/NO_NETWORK=1/NO_NETWORK=0/' qemu-raspbian-network/qemu-pi.sh
         sed -i '35s/NO_GRAPHIC=0/NO_GRAPHIC=1/' qemu-raspbian-network/qemu-pi.sh
    else log 2 "Missing command: sed"; return 3
    fi
    log -1 "Starting QEMU image: $IMG"  
    ( cd qemu-raspbian-network && sudo ./qemu-pi.sh ../"$IMG" 2>/dev/null )
}

# TODO: NEEDS TO BE REWORKED - PI USER NO LONGER EXISTS
function ssh_pi {
    [[ "$#" -lt 1 ]] && return 1
    local IP="$1" ARGS=("${@:2}") \
          PIUSER="${PIUSER:-pi}" \
          PIPASS="${PIPASS:-raspberry}" \
          SSHPASS SSH RET
    SSH=( ssh -q  -o UserKnownHostsFile=/dev/null\
                -o StrictHostKeyChecking=no\
                -o ServerAliveInterval=20\
                -o ConnectTimeout=20\
                -o LogLevel=quiet )
    type sshpass &>/dev/null && SSHPASS=( sshpass -p"$PIPASS" )
    if [[ "${SSHPASS[*]}" == "" ]]
    then "${SSH[@]}" "$PIUSER"@"$IP" "${ARGS[@]}";
    else "${SSHPASS[@]}" "${SSH[@]}" "$PIUSER"@"$IP" "${ARGS[@]}"; RET="$?"
         if [[ "$RET" -eq 5 ]]
         then "${SSH[@]}" "$PIUSER"@"$IP" "${ARGS[@]}"; return "$?"
         fi; return "$RET"
    fi
}

# Return codes
# 1: Invalid number of arguments
function wait_SSH {
    [[ "$#" -lt 1 ]] && return 1
    local IP="$1"; log -1 "Waiting for SSH on: $IP"
    while true
    do ssh_pi "$IP" : && break
       sleep 1
    done; log -1 "SSH is up"
}

# Return codes
# 1: Invalid number of arguments
# 2: Needs to run configuration first
# 3: No installation instructions available
# 4: SSH installation to QEMU target failed
function launch_installation {
    [[ "$#" -lt 1 ]] && return 1
    local IP="$1"
    if isZero "$INSTALLATION_CODE"
    then log 2 "Configuration is required to be run first"; return 2
    elif isZero "$INSTALLATION_STEPS"
    then log 2 "No installation instructions provided"; return 3
    fi
    local PREINST_CODE="
set -e$DBG
sudo su
set -e$DBG
"
    log 2 "Launching installation"
    if ! ssh_pi "$IP" "$PREINST_CODE" "$INSTALLATION_CODE" "$INSTALLATION_STEPS"
    then log 2 "SSH installation failed to QEMU target at: $IP"; return 4
    fi
}

# Return codes
# 1: Invalid number of arguments
function launch_installation_qemu
{
    [[ "$#" -lt 1 ]] && return 1
    local -r IP="$1" MATCH="1"
    local CFG_STEP CLEANUP_STEP HALT_STEP INSTALLATION_STEPS
    
    if notMatch "$NO_CFG_STEP" "$MATCH"
    then CFG_STEP=configure
    fi
    if notMatch "$NO_CLEANUP" "$MATCH"
    then CLEANUP_STEP="if [[ \$( type -t cleanup ) == function ]];then cleanup; fi"
    fi
    if notMatch "$NO_HALT_STEP" "$MATCH"
    then HALT_STEP="nohup halt &>/dev/null &"
    fi
    
    INSTALLATION_STEPS="
install
$CFG_STEP
$CLEANUP_STEP
$HALT_STEP
"
  # Uses $INSTALLATION_CODE
  launch_installation "$IP"
}

# Return codes
# 1: Invalid number of arguments
function launch_installation_online {
    [[ "$#" -lt 1 ]] && return 1
    local -r IP="$1" MATCH="1"
    local CFG_STEP INSTALLATION_STEPS
    if notMatch "$NO_CFG_STEP" "$MATCH"
    then CFG_STEP=configure
    fi
    INSTALLATION_STEPS="
install
$CFG_STEP
"
    # Uses $INSTALLATION_CODE
    launch_installation "$IP"
}

function prepare_dirs {
    local DIRS=(tmp output cache)
    if notMatch "$CLEAN" "0"
    then rm --recursive --force "${DIRS[2]}"
    fi
    rm --recursive --force "${DIRS[0]}"
    mkdir --parents "${DIRS[@]}"
}

# Return codes
# 1: Missing argument: [IMG]
# 2: File not found: [IMG]
# 3: Mountpoint already exists
# 4: Failed to mount IMG at mountpoint
function mount_raspbian {
    [[ "$#" -lt 1 ]] && return 1
    local -r IMG="$1" MP='raspbian_root'
    local SECTOR OFFSET
    if ! isFile "$IMG"
    then log 2 "File not found: $IMG"; return 2
    elif isPath "$MP"
    then log 2 "Mountpoint already exists"; return 3
    fi
    log -1 "Mounting: $MP"
    if ! hasCMD fdisk
    then installPKG fdisk
    fi
    
    if isRoot
    then SECTOR="$( fdisk -l "$IMG" | grep Linux | awk '{ print $2 }' )"
    else SECTOR="$( sudo fdisk -l "$IMG" | grep Linux | awk '{ print $2 }' )"
    fi
    log -1 "Sector: $SECTOR"
    OFFSET=$(( "$SECTOR" * 512 ))
    log -1 "Offset: $OFFSET"
    log -1 "Mountpoint: $MP"
    mkdir --parents "$MP"
    
    if isRoot
    then if ! mount "$IMG" -o offset="$OFFSET" "$MP"
         then log 2 "Failed to mount IMG at: $MP"; return 4
         fi
    else if ! sudo mount "$IMG" -o offset="$OFFSET" "$MP"
         then log 2 "Failed to mount IMG at: $MP"; return 4
         fi
    fi; log 0 "IMG is mounted at: $MP"
}

# Return codes
# 1: Missing argument: [IMG]
# 2: File not found: [IMG]
# 3: Mountpoint already exists
# 4: Failed to mount IMG at mountpoint
function mount_raspbian_boot {
    [[ "$#" -lt 1 ]] && return 1
    local IMG="$1" MP='raspbian_boot' SECTOR OFFSET
    if ! isFile "$IMG"
    then log 2 "File not found: $IMG"; return 2
    elif isPath "$MP"
    then log 2 "Mountpoint already exists"; return 3
    fi; log -1 "Mounting: $MP"
    if isRoot
    then SECTOR="$( fdisk -l "$IMG" | grep FAT32 | awk '{ print $2 }' )"
    else SECTOR="$( sudo fdisk -l "$IMG" | grep FAT32 | awk '{ print $2 }' )"
    fi; log -1 "Sector: $SECTOR"
    OFFSET=$(( "$SECTOR" * 512 ))
    log -1 "Offset: $OFFSET"; log -1 "Mountpoint: $MP"
    mkdir -p "$MP"
    if isRoot
    then if ! mount "$IMG" -o offset="$OFFSET" "$MP"
         then log 2 "Failed to mount IMG at: $MP"; return 4
    fi
    else if ! sudo mount "$IMG" -o offset="$OFFSET" "$MP"
         then log 2 "Failed to mount IMG at: $MP"; return 4
         fi
    fi; log 0 "IMG is mounted at: $MP"
}

# Return codes
# 0: Nothing to unmount OR Unmounted IMG
# 1: Could not unmount directory: Root
# 2: Could not remove directory: Root
# 3: Could not unmount directory: Boot
# 4: Could not remove directory: Boot
function umount_raspbian {
    local -r ROOTDIR="${ROOTDIR:-raspbian_root}" \
             BOOTDIR="${BOOTDIR:-raspbian_boot}"
    log -1 "Unmounting IMG"
    if ! isDirectory "$ROOTDIR" && ! isDirectory "$BOOTDIR"
    then log -1 "Nothing to unmount"; return 0
    fi
    if isDirectory "$ROOTDIR"
    then if isRoot
         then if ! umount --lazy "$ROOTDIR"
              then log 2 "Could not unmount: $ROOTDIR"; return 1
              fi
              if ! rmdir "$ROOTDIR"
              then log 2 "Could not remove: $ROOTDIR"; return 2
              fi
         else if ! sudo umount --lazy "$ROOTDIR"
              then log 2 "Could not unmount: $ROOTDIR"; return 1
              fi
              if ! sudo rmdir "$ROOTDIR"
              then log 2 "Could not remove: $ROOTDIR"; return 2
              fi
         fi
    fi
    if isDirectory "$BOOTDIR"
    then if isRoot
         then if ! umount --lazy "$BOOTDIR"
              then log 2 "Could not unmount: $BOOTDIR"; return 3
              fi
              if ! rmdir "$BOOTDIR"; then log 2 "Could not remove: $BOOTDIR"; return 4; fi
         else if ! sudo umount --lazy "$BOOTDIR"
              then log 2 "Could not unmount: $BOOTDIR"; return 3
              fi
              if ! sudo rmdir "$BOOTDIR"
              then log 2 "Could not remove: $BOOTDIR"; return 4
              fi
         fi
    fi; log 0 "Unmounted IMG"; return 0
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
# 3: File not found: /usr/bin/qemu-aarch64-static
function prepare_chroot_raspbian {
    local -r IMG="$1" \
            ROOTDIR="${ROOTDIR:-raspbian_root}"
    if ! mount_raspbian "$IMG"
    then return 2
    fi
    if isRoot
    then mount -t proc proc          "$ROOTDIR"/proc/
         mount -t sysfs sys          "$ROOTDIR"/sys/
         mount -o bind /dev          "$ROOTDIR"/dev/
         mount -o bind /dev/pts      "$ROOTDIR"/dev/pts
    else sudo mount -t proc proc     "$ROOTDIR"/proc/
         sudo mount -t sysfs sys     "$ROOTDIR"/sys/
         sudo mount -o bind /dev     "$ROOTDIR"/dev/
         sudo mount -o bind /dev/pts "$ROOTDIR"/dev/pts
    fi
    
    if isFile 'qemu-aarch64-static'
    then if isRoot
         then cp qemu-aarch64-static "$ROOTDIR"/usr/bin/qemu-aarch64-static
         else sudo cp qemu-aarch64-static "$ROOTDIR"/usr/bin/qemu-aarch64-static
         fi
    else if isFile '/usr/bin/qemu-aarch64-static'
         then if isRoot
              then cp /usr/bin/qemu-aarch64-static "$ROOTDIR"/usr/bin/qemu-aarch64-static
              else sudo cp /usr/bin/qemu-aarch64-static "$ROOTDIR"/usr/bin/qemu-aarch64-static
              fi
         else log 2 "File not found: /usr/bin/qemu-aarch64-static"; return 3
         fi
    fi
    
    # Prevent services from auto-starting
    if isRoot
    then bash -c "echo -e '#!/bin/sh\nexit 101' > ${ROOTDIR}/usr/sbin/policy-rc.d"
         chmod +x "$ROOTDIR"/usr/sbin/policy-rc.d
    else sudo bash -c "echo -e '#!/bin/sh\nexit 101' > ${ROOTDIR}/usr/sbin/policy-rc.d"
         sudo chmod +x "$ROOTDIR"/usr/sbin/policy-rc.d
    fi
}

function clean_chroot_raspbian {
    local -r ROOTDIR="${ROOTDIR:-raspbian_root}"; log -1 "Cleaning chroot"
    if isRoot
    then rm --force    "$ROOTDIR"/usr/bin/qemu-aarch64-static
         rm --force    "$ROOTDIR"/usr/sbin/policy-rc.d
         #umount --lazy "$ROOTDIR"/{proc,sys,dev/pts,dev}
    else sudo rm --force    "$ROOTDIR"/usr/bin/qemu-aarch64-static
         sudo rm --force    "$ROOTDIR"/usr/sbin/policy-rc.d
         #sudo umount --lazy "$ROOTDIR"/{proc,sys,dev/pts,dev}
    fi
    umount_raspbian
}

# Sets DEV
# Return codes
# 1: Invalid number of arguments
function resize_image {
    [[ "$#" -lt 2 ]] && return 1
    local IMG="$1" SIZE="$2" DEV; log -1 "Resize: $IMG"
    
    if ! hasCMD fallocate
    then installPKG util-linux
    fi
    
    if ! hasCMD parted
    then installPKG parted
    fi
    
    if ! hasCMD resize2fs
    then installPKG e2fsprogs
    fi
    
    if isRoot
    then log -1 "fallocate"; fallocate -l"$SIZE" "$IMG"
         log -1 "parted";    parted "$IMG" -- resizepart 2 -1s
         log -1 "losetup";   DEV="$( losetup -f )"
    else log -1 "fallocate"; sudo fallocate -l"$SIZE" "$IMG"
         log -1 "parted";    sudo parted "$IMG" -- resizepart 2 -1s
         log -1 "losetup";   DEV="$( sudo losetup -f )"
    fi; log -1 "Mount: $IMG"; mount_raspbian "$IMG"
    
    if isRoot
    then log -1 "resize2fs"; resize2fs -f "$DEV"
    else log -1 "resize2fs"; sudo resize2fs -f "$DEV"
    fi; log 0 "Resized: $IMG"; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
# 3: Failed to mount IMG boot
function update_boot_uuid {
    [[ "$#" -lt 1 ]] && return 1
    local -r IMG="$1" \
             ROOTDIR="${ROOTDIR:-raspbian_root}" \
             BOOTDIR="${BOOTDIR:-raspbian_boot}"
    local PTUUID
    if isRoot
    then PTUUID="$(blkid -o export "$IMG" | grep PTUUID | sed 's|.*=||')"
    else PTUUID="$(sudo blkid -o export "$IMG" | grep PTUUID | sed 's|.*=||')"
    fi; log -1 "Updating IMG Boot UUID's"
    
    if ! mount_raspbian "$IMG"
    then log 2 "Failed to mount IMG root"; return 2
    fi
    if isRoot
    then bash -c "cat > ${ROOTDIR}/etc/fstab" <<EOF
PARTUUID=${PTUUID}-01  /boot           vfat    defaults          0       2
PARTUUID=${PTUUID}-02  /               ext4    defaults,noatime  0       1
EOF
    else sudo bash -c "cat > ${ROOTDIR}/etc/fstab" <<EOF
PARTUUID=${PTUUID}-01  /boot           vfat    defaults          0       2
PARTUUID=${PTUUID}-02  /               ext4    defaults,noatime  0       1
EOF
    fi; umount_raspbian
    if ! mount_raspbian_boot "$IMG"
    then log 2 "Failed to mount IMG boot"; return 3
    fi
    
    if isRoot
    then bash -c "sed -i 's|root=[^[:space:]]*|root=PARTUUID=${PTUUID}-02 |' ${BOOTDIR}/cmdline.txt"
    else sudo bash -c "sed -i 's|root=[^[:space:]]*|root=PARTUUID=${PTUUID}-02 |' ${BOOTDIR}/cmdline.txt"
    fi; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG boot
# 3: Failed to create SSH file in IMG boot
function prepare_sshd_raspbian {
    [[ "$#" -lt 1 ]] && return 1
    local -r IMG="$1" BOOTDIR="${BOOTDIR:-raspbian_boot}"
    if ! mount_raspbian_boot "$IMG"
    then log 2 "Failed to mount IMG boot"; return 2
    fi
    # Enable SSH
    if isRoot
    then if ! touch "$BOOTDIR"/ssh
         then log 2 "Failed to create SSH file in IMG boot"; return 3;
         fi
    else if ! sudo touch "$BOOTDIR"/ssh
         then log 2 "Failed to create SSH file in IMG boot"; return 3
         fi
    fi; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
function set_static_IP {
    [[ "$#" -lt 2 ]] && return 1
    local -r IMG="$1" IP="$2" ROOTDIR="${ROOTDIR:-raspbian_root}"
    if ! mount_raspbian "$IMG"
    then log 2 "Failed to mount IMG root"; return 2
    fi
    
    if isRoot
    then bash -c "cat > ${ROOTDIR}/etc/dhcpcd.conf" <<EOF
interface eth0
static ip_address=$IP/24
static routers=192.168.0.1
static domain_name_servers=8.8.8.8

# Local loopback
auto lo
iface lo inet loopback
EOF
    else sudo bash -c "cat > ${ROOTDIR}/etc/dhcpcd.conf" <<EOF
interface eth0
static ip_address=$IP/24
static routers=192.168.0.1
static domain_name_servers=8.8.8.8

# Local loopback
auto lo
iface lo inet loopback
EOF
    fi; umount_raspbian
}

# Return codes
# 1: Failed to mount IMG root
# 2: Copy to image failed
function copy_to_image {
    [[ "$#" -lt 2 ]] && return 1
    local IMG="$1" DST="$2" SRC=("${@:3}") ROOTDIR="${ROOTDIR:-raspbian_root}"
    if ! mount_raspbian "$IMG"
    then log 2 "Failed to mount IMG root"; return 1
    fi
    if isRoot
    then if ! cp --reflink=auto -v "${SRC[@]}" "$ROOTDIR"/"$DST"
         then log 2 "Copy to image failed"; return 2
         fi
    else if ! sudo cp --reflink=auto -v "${SRC[@]}" "$ROOTDIR"/"$DST"
         then log 2 "Copy to image failed"; return 2
         fi
    fi; sync; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
function deactivate_unattended_upgrades {
    [[ "$#" -lt 1 ]] && return 1
    local -r IMG="$1" ROOTDIR="${ROOTDIR:-raspbian_root}"
    if ! mount_raspbian "$IMG"
    then log 2 "Failed to mount IMG root"; return 2
    fi
    if ! isFile "$ROOTDIR"/etc/apt/apt.conf.d/20ncp-upgrades
    then log 1 "Directory not found: ${ROOTDIR}/etc/apt/apt.conf.d/20ncp-upgrades"
    else if isRoot
         then rm --force "$ROOTDIR"/etc/apt/apt.conf.d/20ncp-upgrades
         else sudo rm --force "$ROOTDIR"/etc/apt/apt.conf.d/20ncp-upgrades
         fi
    fi; umount_raspbian
}

# Return codes
# 0: Success
# 1: Invalid number of arguments
# 2: Copy failed
# 3: Download failed from URL
# 4: Missing command: unxz
function download_raspbian {
    [[ "$#" -lt 2 ]] && return 1
    local -r URL="$1" IMGFILE="$2" \
             IMG_CACHE='cache/raspios_lite.img' \
             ZIP_CACHE='cache/raspios_lite.xz'
    log -1 "Downloading Raspberry Pi OS"
    mkdir --parents cache
    if isFile "$IMG_CACHE"
    then log -1 "File exists: $IMG_CACHE"; log -1 "Skipping download"
         if ! cp -v --reflink=auto "$IMG_CACHE" "$IMGFILE"
         then log 2 "Copy failed, from $IMG_CACHE to $IMGFILE"; return 2
         fi; return 0
    elif isFile "$ZIP_CACHE"
    then log -1 "File exists: $ZIP_CACHE"; log -1 "Skipping download"
    else if ! wget "$URL" -nv -O "$ZIP_CACHE"
         then log 2 "Download failed from: $URL"; return 3
         fi
    fi
    
    if hasCMD unxz
    then unxz -k -c "$ZIP_CACHE" > "$IMG_CACHE"
         if ! cp -v --reflink=auto "$IMG_CACHE" "$IMGFILE"
         then log 2 "Copy failed, from $IMG_CACHE to $IMGFILE"; return 2
         fi
    else log 2 "Missing command: unxz"; return 4
    fi
}

# Return codes
# 0: Success
# 1: Invalid number of arguments
# 2: Failed packing image
function pack_image {
    [[ "$#" -lt 2 ]] && return 1
    local -r IMG="$1" TAR="$2"
    local DIR IMGNAME
    DIR="$( dirname  "$IMG" )"
    IMGNAME="$( basename "$IMG" )"
    log -1 "Packing image: $IMG → $TAR"
    if isRoot
    then if tar -C "$DIR" -cavf "$TAR" "$IMGNAME"
         then log 0 "$TAR packed successfully"; return 0
         else log 2 "Failed packing IMG: $TAR"; return 2
         fi
    else if sudo tar -C "$DIR" -cavf "$TAR" "$IMGNAME"
         then log 0 "$TAR packed successfully"; return 0
         else log 2 "Failed packing IMG: $TAR"; return 2
         fi
    fi
}

# Return codes
# 0: Success
# 1: Invalid number of arguments
function create_torrent {
    [[ "$#" -lt 1 ]] && return 1
    local -r TAR="$1"
    local IMGNAME DIR
    log -1 "Creating torrent"
    if ! isFile "$TAR"
    then log 2 "File not found: $TAR"; return 1
    fi
    IMGNAME="$( basename "$TAR" .tar.bz2 )"
    DIR="torrent/$IMGNAME"
    if isDirectory "$DIR"
    then log 2 "Directory already exists: $DIR"; return 1
    fi
    mkdir --parents torrent/"$IMGNAME" && cp -v --reflink=auto "$TAR" torrent/"$IMGNAME"
    md5sum "$DIR"/*.bz2 > "$DIR"/md5sum
    createtorrent -a udp://tracker.opentrackr.org -p 1337 -c "NextcloudPi. Nextcloud ready to use image" "$DIR" "$DIR".torrent
    transmission-remote -w "$PWD"/torrent -a "$DIR".torrent
}

function generate_changelog {
    git log --graph --oneline --decorate \
            --pretty=format:"[%<(13)%D](https://github.com/nextcloud/nextcloudpi/commit/%h) (%ad) %s" --date=short | \
            grep 'tag: v' | \
            sed '/HEAD ->\|origin/s|\[.*\(tag: v[0-9]\+\.[0-9]\+\.[0-9]\+\).*\]|[\1]|' | \
            sed 's|* \[tag: |\n[|' > changelog.md
}

# Return codes
# 0: Success OR Skip
# 1: Invalid number of arguments
# 2: File not found: $IMGNAME
# 3: Failed to change directory to: torrent
# 4: Directory not found
function upload_ftp {
    [[ "$#" -lt 1 ]] && return 1
    local -r IMGNAME="$1"
    local RET
    log -1 "Upload FTP: $IMGNAME"
    if ! isFile torrent/"$IMGNAME"/"$IMGNAME".tar.bz2
    then log 2 "File not found: $IMGNAME"; return 2
    fi
    if isZero "$FTPPASS"
    then log 2 "No FTP password was found, variable not set, skipping upload"; return 0
    fi
    
    if isDirectory torrent
    then if ! cd torrent
         then log 2 "Failed to change directory"; return 3
         fi
    else log 2 "Directory not found:  torrent/$IMGNAME"; return 4
    fi
    
    ftp -np ftp.ownyourbits.com <<EOF
user root@ownyourbits.com $FTPPASS
mkdir testing
mkdir testing/$IMGNAME
cd testing/$IMGNAME
binary
rm  $IMGNAME.torrent
put $IMGNAME.torrent
bye
EOF
    if ! cd -
    then log 2 "Failed to change directory to: -"; return 3
    fi
    if isDirectory torrent/"$IMGNAME"
    then if ! cd torrent/"$IMGNAME"
         then log 2 "Failed to change directory to: torrent/$IMGNAME"; return 3
         fi
    else log 2 "Directory not found:  torrent/$IMGNAME"; return 4
    fi

    ftp -np ftp.ownyourbits.com <<EOF
user root@ownyourbits.com $FTPPASS
cd testing/$IMGNAME
binary
rm  $IMGNAME.tar.bz2
put $IMGNAME.tar.bz2
rm  md5sum
put md5sum
bye
EOF
    RET="$?"
    if ! cd -
    then log 2 "Failed to change directory to: -"; return 3
    fi; return "$RET"
}

function upload_images {
    if ! isDirectory output
    then log 2 "Directory not found: output"
         log 1 "No uploads available"; return
    fi
    if isZero "$FTPPASS"
    then log 2 "No FTP password was found, variable not set, skipping upload"; return 0
    fi
    mkdir --parents archive
    for IMG in output/*.tar.bz2
    do upload_ftp "$(basename "$IMG" .tar.bz2)" && mv "$IMG" archive
    done
}

function upload_docker {
    export DOCKER_CLI_EXPERIMENTAL='enabled'
    local -r OWNER='ownyourbits'
    
    docker push "$OWNER"/nextcloudpi-x86:latest
    docker push "$OWNER"/nextcloudpi-x86:"$VERSION"
    docker push "$OWNER"/nextcloud-x86:latest
    docker push "$OWNER"/nextcloud-x86:"$VERSION"
    docker push "$OWNER"/lamp-x86:latest
    docker push "$OWNER"/lamp-x86:"$VERSION"
    docker push "$OWNER"/debian-ncp-x86:latest
    docker push "$OWNER"/debian-ncp-x86:"$VERSION"
    
    docker push "$OWNER"/nextcloudpi-armhf:latest
    docker push "$OWNER"/nextcloudpi-armhf:"$VERSION"
    docker push "$OWNER"/nextcloud-armhf:latest
    docker push "$OWNER"/nextcloud-armhf:"$VERSION"
    docker push "$OWNER"/lamp-armhf:latest
    docker push "$OWNER"/lamp-armhf:"$VERSION"
    docker push "$OWNER"/debian-ncp-armhf:latest
    docker push "$OWNER"/debian-ncp-armhf:"$VERSION"
    
    docker push "$OWNER"/nextcloudpi-arm64:latest
    docker push "$OWNER"/nextcloudpi-arm64:"$VERSION"
    docker push "$OWNER"/nextcloud-arm64:latest
    docker push "$OWNER"/nextcloud-arm64:"$VERSION"
    docker push "$OWNER"/lamp-arm64:latest
    docker push "$OWNER"/lamp-arm64:"$VERSION"
    docker push "$OWNER"/debian-ncp-arm64:latest
    docker push "$OWNER"/debian-ncp-arm64:"$VERSION"
    
    # Docker multi-arch
    docker manifest create --amend "$OWNER"/nextcloudpi:"$VERSION" \
                           --amend "$OWNER"/nextcloudpi-x86:"$VERSION" \
                           --amend "$OWNER"/nextcloudpi-armhf:"$VERSION" \
                           --amend "$OWNER"/nextcloudpi-arm64:"$VERSION"
    
    docker manifest create --amend "$OWNER"/nextcloudpi:latest \
                           --amend "$OWNER"/nextcloudpi-x86:latest \
                           --amend "$OWNER"/nextcloudpi-armhf:latest \
                           --amend "$OWNER"/nextcloudpi-arm64:latest
    
    docker manifest annotate "$OWNER"/nextcloudpi:"$VERSION" "$OWNER"/nextcloudpi-x86:"$VERSION"   --os linux --arch amd64
    docker manifest annotate "$OWNER"/nextcloudpi:"$VERSION" "$OWNER"/nextcloudpi-armhf:"$VERSION" --os linux --arch arm
    docker manifest annotate "$OWNER"/nextcloudpi:"$VERSION" "$OWNER"/nextcloudpi-arm64:"$VERSION" --os linux --arch arm64
    
    docker manifest annotate "$OWNER"/nextcloudpi:latest "$OWNER"/nextcloudpi-x86:latest   --os linux --arch amd64
    docker manifest annotate "$OWNER"/nextcloudpi:latest "$OWNER"/nextcloudpi-armhf:latest --os linux --arch arm
    docker manifest annotate "$OWNER"/nextcloudpi:latest "$OWNER"/nextcloudpi-arm64:latest --os linux --arch arm64
    
    docker manifest push -p "$OWNER"/nextcloudpi:"$VERSION"
    docker manifest push -p "$OWNER"/nextcloudpi:latest
}

function is_docker {
    (
        if isDirectory build/docker
        then if ! cd build/docker
             then log 2 "Failed to change directory to: build/docker" ; return 3
             fi
        else log 2 "Directory not found: build/docker"; return 4
        fi
        docker compose down
        docker volume rm docker_ncdata
        docker compose up -d
        sleep 30
        ../../tests/activation_tests.py
        ../../tests/nextcloud_tests.py
        ../../tests/system_tests.py
        docker compose down
    )
}

function is_lxc {
    local IP
    lxc stop ncp || true
    lxc start ncp
    # shellcheck disable=SC2016
    lxc exec ncp -- bash -c 'while [ "$(systemctl is-system-running 2>/dev/null)" != "running" ] && [ "$(systemctl is-system-running 2>/dev/null)" != "degraded" ]; do :; done'
    IP="$(lxc exec ncp -- bash -c 'source /usr/local/etc/library.sh && get_ip')"
    tests/activation_tests.py "$IP"
    tests/nextcloud_tests.py  "$IP"
    tests/system_tests.py
    lxc stop ncp
}

function test_vm {
    local IP
    virsh --connect qemu:///system shutdown ncp-vm &>/dev/null || true
    virsh --connect qemu:///system start ncp-vm
    while [[ "$IP" == "" ]]
    do IP="$(virsh --connect qemu:///system domifaddr ncp-vm | grep ipv4 | awk '{ print $4 }' | sed 's|/24||' )"
       sleep 0.5
    done
    tests/activation_tests.py "$IP"
    tests/nextcloud_tests.py  "$IP"
    #tests/system_tests.py
    virsh --connect qemu:///system shutdown ncp-vm
}

# License
#
# This script is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either VERSION 2 of the License, or
# (at your option) any later VERSION.
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
