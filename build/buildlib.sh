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

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

# A log that uses log levels for logging different outputs
# Return codes
# 1: Invalid log level
# 2: Invalid number of arguments
# Log level   | colour
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
              return 1
         fi
    else log 2 "Invalid number of arguments: $#/1+"
         return 2 
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
function is_root {
    [[ "$#" -ne 0 ]] && { return 2; }
    [[ "$EUID" -eq 0 ]]
}

# Checks if a given path to a file exists
# Return codes
# 0: Path exist
# 1: No such path
# 2: Invalid number of arguments
function is_path {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ -e "$1" ]]
}

# Checks if a given path is a regular file
# 0: Is a file
# 1: Not a file
# 2: Invalid number of arguments
function is_file {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ -f "$1" ]]
}

# Checks if given path is a directory 
# Return codes
# 0: Is a directory
# 1: Not a directory
# 2: Invalid number of arguments
function is_directory {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ -d "$1" ]]
}

# Checks if a given path is a socket
# Return codes
# 0: Is a socket
# 1: Not a socket
# 2: Invalid number of arguments
function is_socket {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ -S "$1" ]]
}

# Checks if 2 given digits are equal
# Return codes
# 0: Is equal
# 1: Not equal
# 2: Invalid number of arguments
function is_equal {
    [[ "$#" -ne 2 ]] && { return 2; }
    [[ "$1" -eq "$2" ]]
}

# Checks if 2 given digits are not equal
# Return codes
# 0: Not equal
# 1: Is equal
# 2: Invalid number of arguments
function not_equal {
    [[ "$#" -ne 2 ]] && { return 2; }
    [[ "$1" -ne "$2" ]]
}

# Checks if 2 given String variables match
# Return codes
# 0: Is a match
# 1: Not a match
# 2: Invalid number of arguments
function is_match {
    [[ "$#" -ne 2 ]] && { return 2; }
    [[ "$1" == "$2" ]]
}

# Checks if 2 given String variables do not match
# Return codes
# 0: Not a match
# 1: Is a match
# 2: Invalid number of arguments
function not_match {
    [[ "$#" -ne 2 ]] && { return 2; }
    [[ "$1" != "$2" ]]
}

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Is set
# 1: Not set 
# 2: Invalid number of arguments
function is_set {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ -v "$1" ]]
}

# Checks if a given String is zero
# Return codes
# 0: Is zero
# 1: Not zero
# 2: Invalid number of arguments
function is_zero {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ -z "$1" ]]
}

# Checks if a given String is not zero
# Return codes
# 0: Not zero
# 1: Is zero
# 2: Invalid number of arguments
function not_zero {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ -n "$1" ]]
}

# Checks if a given pattern in a String
# Return codes
# 0: Has String pattern
# 1: No String pattern
# 2: Invalid number of arguments
# $1: [Pattern]
# $2: [String]
# Pattern has to be the right-hand variable in the test expression
function has_text {
    [[ "$#" -ne 2 ]] && { return 2; }
    [[ "$2" == *"$1"* ]]
}

# Checks if a command exists on the system
# Return status codes
# 0: Command exists on the system
# 1: Command is unavailable on the system
# 2: Invalid argument(s)
# $1: Command
function has_cmd {
    [[ "$#" -ne 1 ]] && { return 2; }
    [[ "$(command -v "$1" &>/dev/null; print_int "$?")" -eq 0 ]]
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
    then log 2 "Invalid number of arguments: $#/0"; return 2
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

# Installs package(s) using the package manager and pre-configured options
# Return codes
# 0: Install completed
# 1: Error during installation
# 2: Missing package argument
function install_package {
    if [[ "$#" -eq 0 ]]
    then log 2 "Requires: [ PKG(s) ]"; return 2
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOINSTALL=(sudo apt-get "${OPTIONS[@]}" install) \
                    ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
         declare -a PKG=(); IFS=' ' read -ra PKG <<<"$@"
         if is_root
         then log -1 "Installing ${PKG[*]}"
              if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "${PKG[@]}"
              then log 0 "Installation complete"; return 0
              else log 2 "Something went wrong during installation"; return 1
              fi
         else log -1 "Installing ${PKG[*]}"
              if DEBIAN_FRONTEND=noninteractive "${SUDOINSTALL[@]}" "${PKG[@]}"
              then log 0 "Installation complete"; return 0
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
function find_process {
    [[ "$#" -ne 1 ]]  && { log 2 "Requires argument: process"; return 2; }
    ! has_cmd 'pgrep' && { log 2 "Command not found: pgrep"; return 3; }
    [[ "$(pgrep "$1" &>/dev/null; print_int "$?")" -eq 0 ]]
}

# Checks for a running process
# Return codes
# 0: Running process exists
# 1: No such running process
# 2: Missing argument: process
# 3: Missing command: pgrep
function find_full_process {
    [[ "$#" -ne 1 ]]  && { log 2 "Requires argument: process"; return 2; }
    ! has_cmd 'pgrep' && { log 2 "Command not found: pgrep"; return 3; }
    [[ "$(pgrep --full "$1" &>/dev/null; print_int "$?")" -eq 0 ]]
}

#
# Return codes
# 1: Copying failed
# 2: Invalid argument #2: [IP]
# 3: File not found: [IMG]
function launch_install_qemu {
    [[ "$#" -lt 2 ]] && { return 1; }
    local IMG="$1" IP="$2" IMGOUT
    is_zero "$IP"    && { log 2 "Invalid argument #2: [IP]"; return 2; }
    ! is_file "$IMG" && { log 2 "File not found: $IMG"; return 3; }
    IMGOUT="${IMG}-$( date +%s )"
    cp --reflink=auto -v "$IMG" "$IMGOUT" && { log 2 "Copying IMG failed"; return 1; }
    ! has_cmd 'pgrep'                     && { log 2 "Missing command: pgrep"; return 1; }
    find_process 'qemu-system-aarch64'    && { log 2 "QEMU is already running"; return 1; }
    # TODO
    launch_qemu "$IMGOUT" &
    sleep 10
    wait_ssh "$IP"
    launch_installation_qemu "$IP" || { return 1; } # uses $INSTALLATION_CODE
    wait
    log -1 "Image generated successfully: $IMGOUT"
}


# Return codes
# 1: Invalid number of arguments
# 2: File not found: [IMG]
# 3: Missing command: sed
function launch_qemu {
    [[ "$#" -lt 1 ]] && { return 1; }
    local IMG="$1"
    ! is_file "$IMG" && { log 2 "File not found: $IMG"; return 2; }
    
    if ! is_directory 'qemu-raspbian-network'
    then git clone 'https://github.com/nachoparker/qemu-raspbian-network.git'
    fi
    
    ! has_cmd 'sed' && { log 2 "Missing command: sed"; return 3; }
    sed -i '30s/NO_NETWORK=1/NO_NETWORK=0/' 'qemu-raspbian-network/qemu-pi.sh'
    sed -i '35s/NO_GRAPHIC=0/NO_GRAPHIC=1/' 'qemu-raspbian-network/qemu-pi.sh'
    log -1 "Starting QEMU image: $IMG"  
    ( cd 'qemu-raspbian-network' && sudo ./qemu-pi.sh ../"$IMG" 2>/dev/null )
}

# TODO: NEEDS TO BE REWORKED - PI USER NO LONGER EXISTS
# Can be reused by changing the username and password in the
# PIUSER & PIPASS variables
function ssh_pi {
    [[ "$#" -lt 1 ]] && { return 1; }
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
function wait_ssh {
    [[ "$#" -lt 1 ]] && { return 1; }
    local IP="$1"; log -1 "Waiting for SSH on: $IP"
    while true
    do ssh_pi "$IP" : && { break; }
       sleep 1
    done; log -1 "SSH is up"
}

# Return codes
# 1: Invalid number of arguments
# 2: Needs to run configuration first
# 3: No installation instructions available
# 4: SSH installation to QEMU target failed
function launch_installation {
    [[ "$#" -lt 1 ]] && { return 1; }
    local IP="$1"
    is_zero "$INSTALLATION_CODE"  && { log 2 "Configuration is required to be run first"; return 2; }
    is_zero "$INSTALLATION_STEPS" && { log 2 "No installation instructions provided"; return 3; }
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
    [[ "$#" -lt 1 ]] && { return 1; }
    local -r IP="$1" MATCH="1"
    local CFG_STEP CLEANUP_STEP HALT_STEP INSTALLATION_STEPS
    
    not_match "$NO_CFG_STEP"  "$MATCH" && { CFG_STEP='configure'; }
    not_match "$NO_CLEANUP"   "$MATCH" && { CLEANUP_STEP="if [[ \$( type -t cleanup ) == function ]];then cleanup; fi"; }
    not_match "$NO_HALT_STEP" "$MATCH" && { HALT_STEP="nohup halt &>/dev/null &"; }
    
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
    [[ "$#" -lt 1 ]] && { return 1; }
    local -r IP="$1" MATCH="1"
    local CFG_STEP INSTALLATION_STEPS
    not_match "$NO_CFG_STEP" "$MATCH" && { CFG_STEP='configure'; }
    INSTALLATION_STEPS="
install
$CFG_STEP
"
    # Uses $INSTALLATION_CODE
    launch_installation "$IP"
}

function prepare_dirs {
    local DIRS=(tmp output cache)
    is_equal "$CLEAN" 1 && { rm --recursive --force "${DIRS[2]}"; }
    rm --recursive --force "${DIRS[0]}"
    mkdir --parents "${DIRS[@]}"
}

# Return codes
# 1: Missing argument: [IMG]
# 2: File not found: [IMG]
# 3: Mountpoint already exists
# 4: Failed to mount IMG at mountpoint
function mount_raspbian {
    [[ "$#" -lt 1 ]] && { return 1; }
    local -r IMG="$1" MP='raspbian_root'
    ! is_file "$IMG" && { log 2 "File not found: $IMG"; return 2; }
    is_path   "$MP"  && { log 2 "Mountpoint already exists"; return 3; }
    local SECTOR OFFSET

    log -1 "Mounting: $MP"
    
    ! has_cmd fdisk && { install_package fdisk; }
    
    if is_root
    then SECTOR="$( fdisk -l "$IMG" | grep Linux | awk '{ print $2 }' )"
    else SECTOR="$( sudo fdisk -l "$IMG" | grep Linux | awk '{ print $2 }' )"
    fi
    log -1 "Sector: $SECTOR"
    OFFSET=$(( "$SECTOR" * 512 ))
    log -1 "Offset: $OFFSET"
    log -1 "Mountpoint: $MP"
    mkdir --parents "$MP"
    
    if is_root
    then mount "$IMG" -o offset="$OFFSET" "$MP"      || { log 2 "Failed to mount IMG at: $MP"; return 4; }
    else sudo mount "$IMG" -o offset="$OFFSET" "$MP" && { log 2 "Failed to mount IMG at: $MP"; return 4; }
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
    ! is_file "$IMG" && { log 2 "File not found: $IMG"; return 2; }
    is_path   "$MP"  && { log 2 "Mountpoint already exists"; return 3; }
    log -1 "Mounting: $MP"
    if is_root
    then SECTOR="$( fdisk -l "$IMG" | grep FAT32 | awk '{ print $2 }' )"
    else SECTOR="$( sudo fdisk -l "$IMG" | grep FAT32 | awk '{ print $2 }' )"
    fi; log -1 "Sector: $SECTOR"
    OFFSET=$(( "$SECTOR" * 512 ))
    log -1 "Offset: $OFFSET"; log -1 "Mountpoint: $MP"
    mkdir --parents "$MP"
    if is_root
    then mount "$IMG" -o offset="$OFFSET" "$MP"      && { log 2 "Failed to mount IMG at: $MP"; return 4; }
    else sudo mount "$IMG" -o offset="$OFFSET" "$MP" && { log 2 "Failed to mount IMG at: $MP"; return 4; }
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
    if ! is_directory "$ROOTDIR" && ! is_directory "$BOOTDIR"
    then log -1 "Nothing to unmount"; return 0
    fi
    is_directory "$ROOTDIR" && {
         if is_root
         then
            umount --lazy "$ROOTDIR" || { log 2 "Could not unmount: $ROOTDIR"; return 1; }
            rmdir "$ROOTDIR"         || { log 2 "Could not remove: $ROOTDIR"; return 2; }
         else
            sudo umount --lazy "$ROOTDIR" || { log 2 "Could not unmount: $ROOTDIR"; return 1; }
            sudo rmdir "$ROOTDIR"         || { log 2 "Could not remove: $ROOTDIR"; return 2; }
         fi
    }
    is_directory "$BOOTDIR" && {
         if is_root
         then
            umount --lazy "$BOOTDIR" || { log 2 "Could not unmount: $BOOTDIR"; return 3; }
            rmdir "$BOOTDIR"         || { log 2 "Could not remove: $BOOTDIR"; return 4; }
         else
            sudo umount --lazy "$BOOTDIR" || { log 2 "Could not unmount: $BOOTDIR"; return 3; }
            sudo rmdir "$BOOTDIR"         || { log 2 "Could not remove: $BOOTDIR"; return 4; }
         fi
    }; log 0 "Unmounted IMG"; return 0
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
# 3: File not found: /usr/bin/qemu-aarch64-static
function prepare_chroot_raspbian {
    local -r IMG="$1" \
            ROOTDIR="${ROOTDIR:-raspbian_root}"
    mount_raspbian "$IMG" || { return 2; }
    if is_root
    then mount -t proc proc          "$ROOTDIR"/proc/
         mount -t sysfs sys          "$ROOTDIR"/sys/
         mount -o bind /dev          "$ROOTDIR"/dev/
         mount -o bind /dev/pts      "$ROOTDIR"/dev/pts
    else sudo mount -t proc proc     "$ROOTDIR"/proc/
         sudo mount -t sysfs sys     "$ROOTDIR"/sys/
         sudo mount -o bind /dev     "$ROOTDIR"/dev/
         sudo mount -o bind /dev/pts "$ROOTDIR"/dev/pts
    fi
    
    if is_file 'qemu-aarch64-static'; then
        if is_root
        then cp 'qemu-aarch64-static' "$ROOTDIR"/usr/bin/qemu-aarch64-static
        else sudo cp 'qemu-aarch64-static' "$ROOTDIR"/usr/bin/qemu-aarch64-static
        fi
    elif is_file '/usr/bin/qemu-aarch64-static'; then
        if is_root
        then cp '/usr/bin/qemu-aarch64-static' "$ROOTDIR"/usr/bin/qemu-aarch64-static
        else sudo cp '/usr/bin/qemu-aarch64-static' "$ROOTDIR"/usr/bin/qemu-aarch64-static
        fi
    else log 2 "File not found: /usr/bin/qemu-aarch64-static"; return 3
    fi
    
    # Prevent services from auto-starting
    if is_root; then
        bash -c "echo -e '#!/bin/sh\nexit 101' > ${ROOTDIR}/usr/sbin/policy-rc.d"
        chmod +x "$ROOTDIR"/usr/sbin/policy-rc.d
    else
        sudo bash -c "echo -e '#!/bin/sh\nexit 101' > ${ROOTDIR}/usr/sbin/policy-rc.d"
        sudo chmod +x "$ROOTDIR"/usr/sbin/policy-rc.d
    fi
}

function clean_chroot_raspbian {
    local -r ROOTDIR="${ROOTDIR:-raspbian_root}"; log -1 "Cleaning chroot"
    if is_root; then
        rm --force         "$ROOTDIR"/usr/bin/qemu-aarch64-static
        rm --force         "$ROOTDIR"/usr/sbin/policy-rc.d
        #umount --lazy     "$ROOTDIR"/{proc,sys,dev/pts,dev}
    else
        sudo rm --force    "$ROOTDIR"/usr/bin/qemu-aarch64-static
        sudo rm --force    "$ROOTDIR"/usr/sbin/policy-rc.d
        #sudo umount --lazy "$ROOTDIR"/{proc,sys,dev/pts,dev}
    fi
    umount_raspbian
}

# Sets DEV
# Return codes
# 1: Invalid number of arguments
function resize_image {
    [[ "$#" -lt 2 ]] && { return 1; }
    local IMG="$1" SIZE="$2" DEV; log -1 "Resize: $IMG"
    
    ! has_cmd 'fallocate' && { install_package 'util-linux'; }
    ! has_cmd 'parted'    && { install_package 'parted'; }
    ! has_cmd 'resize2fs' && { install_package 'e2fsprogs'; }
    
    if is_root; then
        log -1 "fallocate";  fallocate -l"$SIZE" "$IMG"
        log -1 "parted";     parted "$IMG" -- resizepart 2 -1s
        log -1 "losetup";    DEV="$( losetup -f )"
    else
        log -1 "fallocate";  sudo fallocate -l"$SIZE" "$IMG"
        log -1 "parted";     sudo parted "$IMG" -- resizepart 2 -1s
        log -1 "losetup";    DEV="$( sudo losetup -f )"
    fi; log -1 "Mount: $IMG"; mount_raspbian "$IMG"
    
    if is_root
    then log -1 "resize2fs";   resize2fs -f "$DEV"
    else log -1 "resize2fs";   sudo resize2fs -f "$DEV"
    fi; log 0 "Resized: $IMG"; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
# 3: Failed to mount IMG boot
function update_boot_uuid {
    [[ "$#" -lt 1 ]] && { return 1; }
    local -r IMG="$1" \
             ROOTDIR="${ROOTDIR:-raspbian_root}" \
             BOOTDIR="${BOOTDIR:-raspbian_boot}"
    local PTUUID
    if is_root
    then PTUUID="$(blkid -o export "$IMG" | grep PTUUID | sed 's|.*=||')"
    else PTUUID="$(sudo blkid -o export "$IMG" | grep PTUUID | sed 's|.*=||')"
    fi; log -1 "Updating IMG Boot UUID's"
    
    mount_raspbian "$IMG" || { log 2 "Failed to mount IMG root"; return 2; }
    
    if is_root
    then bash -c "cat > ${ROOTDIR}/etc/fstab" <<EOF
PARTUUID=${PTUUID}-01  /boot           vfat    defaults          0       2
PARTUUID=${PTUUID}-02  /               ext4    defaults,noatime  0       1
EOF
    else sudo bash -c "cat > ${ROOTDIR}/etc/fstab" <<EOF
PARTUUID=${PTUUID}-01  /boot           vfat    defaults          0       2
PARTUUID=${PTUUID}-02  /               ext4    defaults,noatime  0       1
EOF
    fi
    umount_raspbian
    mount_raspbian_boot "$IMG" || { log 2 "Failed to mount IMG boot"; return 3; }
    
    if is_root
    then bash -c "sed -i 's|root=[^[:space:]]*|root=PARTUUID=${PTUUID}-02 |' ${BOOTDIR}/cmdline.txt"
    else sudo bash -c "sed -i 's|root=[^[:space:]]*|root=PARTUUID=${PTUUID}-02 |' ${BOOTDIR}/cmdline.txt"
    fi; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG boot
# 3: Failed to create SSH file in IMG boot
function prepare_sshd_raspbian {
    [[ "$#" -lt 1 ]] && { return 1; }
    local -r IMG="$1" BOOTDIR="${BOOTDIR:-raspbian_boot}"
    mount_raspbian_boot "$IMG"     || { log 2 "Failed to mount IMG boot"; return 2; }
    # Enable SSH
    if is_root
    then touch "$BOOTDIR"/ssh      || { log 2 "Failed to create SSH file in IMG boot"; return 3; ]
    else sudo touch "$BOOTDIR"/ssh || { log 2 "Failed to create SSH file in IMG boot"; return 3; }
    fi; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
function set_static_IP {
    [[ "$#" -lt 2 ]] && { return 1; }
    local -r IMG="$1" IP="$2" ROOTDIR="${ROOTDIR:-raspbian_root}"
    mount_raspbian "$IMG" || { log 2 "Failed to mount IMG root"; return 2; }
    
    if is_root
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
    [[ "$#" -lt 2 ]] && { return 1; }
    local IMG="$1" DST="$2" SRC=("${@:3}") ROOTDIR="${ROOTDIR:-raspbian_root}"
    mount_raspbian "$IMG" || { log 2 "Failed to mount IMG root"; return 1; }
    if is_root
    then cp --reflink=auto -v "${SRC[@]}" "$ROOTDIR"/"$DST"      || { log 2 "Copy to image failed"; return 2; }
    else sudo cp --reflink=auto -v "${SRC[@]}" "$ROOTDIR"/"$DST" || { log 2 "Copy to image failed"; return 2; }
    fi; sync; umount_raspbian
}

# Return codes
# 1: Invalid number of arguments
# 2: Failed to mount IMG root
function deactivate_unattended_upgrades {
    [[ "$#" -lt 1 ]] && return 1
    local -r IMG="$1" ROOTDIR="${ROOTDIR:-raspbian_root}"
    mount_raspbian "$IMG" || { log 2 "Failed to mount IMG root"; return 2; }
    if ! is_file "${ROOTDIR}/etc/apt/apt.conf.d/20ncp-upgrades"
    then log 1 "Directory not found: ${ROOTDIR}/etc/apt/apt.conf.d/20ncp-upgrades"
    else
         if is_root
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
    [[ "$#" -lt 2 ]] && { return 1; }
    local -r URL="$1" IMGFILE="$2" \
             IMG_CACHE='cache/raspios_lite.img' \
             ZIP_CACHE='cache/raspios_lite.xz'
    log -1 "Downloading Raspberry Pi OS"
    mkdir --parents cache
    if is_file "$IMG_CACHE"
    then log -1 "File exists: $IMG_CACHE"; log -1 "Skipping download"
         cp -v --reflink=auto "$IMG_CACHE" "$IMGFILE" || { log 2 "Copy failed, from $IMG_CACHE to $IMGFILE"; return 2; }
         return 0
    elif is_file "$ZIP_CACHE"
    then log -1 "File exists: $ZIP_CACHE"; log -1 "Skipping download"
    else wget "$URL" -nv -O "$ZIP_CACHE" || { log 2 "Download failed from: $URL"; return 3; }
    fi
    
    ! has_cmd 'unxz' && { log 2 "Missing command: unxz"; return 4; }
    unxz -k -c "$ZIP_CACHE" > "$IMG_CACHE"
    cp -v --reflink=auto "$IMG_CACHE" "$IMGFILE" || { log 2 "Copy failed, from $IMG_CACHE to $IMGFILE"; return 2; }
}

# Return codes
# 0: Success
# 1: Invalid number of arguments
# 2: Failed packing image
function pack_image {
    [[ "$#" -lt 2 ]] && { return 1; }
    local -r IMG="$1" TAR="$2"
    local DIR IMGNAME
    DIR="$( dirname  "$IMG" )"
    IMGNAME="$( basename "$IMG" )"
    log -1 "Packing image: $IMG → $TAR"
    if is_root
    then if tar -C "$DIR" -cavf "$TAR" "$IMGNAME"
         then log 0 "$TAR packed successfully"; return 0
         else log 2 "Failed packing IMG: $TAR"; return 2
         fi
    else
         if sudo tar -C "$DIR" -cavf "$TAR" "$IMGNAME"
         then log 0 "$TAR packed successfully"; return 0
         else log 2 "Failed packing IMG: $TAR"; return 2
         fi
    fi
}

# Return codes
# 0: Success
# 1: Invalid number of arguments
function create_torrent {
    [[ "$#" -lt 1 ]] && { return 1; }
    local -r TAR="$1"
    local IMGNAME DIR
    log -1 "Creating torrent"
    ! is_file "$TAR" && { log 2 "File not found: $TAR"; return 1; }
    IMGNAME="$( basename "$TAR" .tar.bz2 )"
    DIR="torrent/$IMGNAME"
    is_directory "$DIR" && { log 2 "Directory already exists: $DIR"; return 1; }
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
    [[ "$#" -lt 1 ]] && { return 1; }
    local -r IMGNAME="$1"
    local RET
    log -1 "Upload FTP: $IMGNAME"
    ! is_file torrent/"$IMGNAME"/"$IMGNAME".tar.bz2 && { log 2 "File not found: $IMGNAME"; return 2; }
    is_zero "$FTPPASS" && { log 2 "No FTP password was found, variable not set, skipping upload"; return 0; }
    
    if is_directory 'torrent'
    then cd torrent || { log 2 "Failed to change directory"; return 3; }
    else log 2 "Directory not found:  torrent/$IMGNAME"; return 4
    fi
    
    ftp -np ftp.ownyourbits.com <<EOF
user root@ownyourbits.com "$FTPPASS"
mkdir testing
mkdir testing/"$IMGNAME"
cd testing/"$IMGNAME"
binary
rm  "$IMGNAME".torrent
put "$IMGNAME".torrent
bye
EOF
    cd - || { log 2 "Failed to change directory to: -"; return 3; }
    if is_directory torrent/"$IMGNAME"
    then cd torrent/"$IMGNAME" || { log 2 "Failed to change directory to: torrent/$IMGNAME"; return 3; }
    else log 2 "Directory not found:  torrent/$IMGNAME"; return 4
    fi

    ftp -np ftp.ownyourbits.com <<EOF
user root@ownyourbits.com "$FTPPASS"
cd testing/"$IMGNAME"
binary
rm  "$IMGNAME".tar.bz2
put "$IMGNAME".tar.bz2
rm  md5sum
put md5sum
bye
EOF
    RET="$?"
    cd - || { log 2 "Failed to change directory to: -"; return 3; }
    return "$RET"
}

function upload_images {
    if ! is_directory 'output'
    then log 2 "Directory not found: output"
         log 1 "No uploads available"; return
    fi
    is_zero "$FTPPASS" && { log 2 "No FTP password was found, variable not set, skipping upload"; return 0; }
    mkdir --parents archive
    for IMG in output/*.tar.bz2
    do upload_ftp "$(basename "$IMG" .tar.bz2)" && mv "$IMG" archive
    done
}

function upload_docker {
    export DOCKER_CLI_EXPERIMENTAL='enabled'
    local -r OWNER='ownyourbits'
    declare -r -a REPOS=('nextcloudpi' 'nextcloud' 'lamp' 'debian-ncp')
    declare -r -a ARCHS=('x86' 'armhf' 'arm64')
    declare -r -a DARCHS=('amd64' 'arm' 'arm64')

    for (( i = 0; i < "${#ARCHS[@]}"; i++ ))
    do for (( x = 0; x < "${#REPOS[@]}"; x++ ))
       do docker push "$OWNER"/"${REPOS[$x]}"-"${ARCHS[$i]}":"$VERSION"
          docker push "$OWNER"/"${REPOS[$x]}"-"${ARCHS[$i]}":latest
       done
    done

    # Docker multi-arch
    docker manifest create --amend "$OWNER"/nextcloudpi:"$VERSION"
    for (( i = 0; i < "${#ARCHS[@]}"; i++ ))
    do docker manifest create --amend "$OWNER"/"${REPOS[0]}"-"${ARCHS[$i]}":"$VERSION"
       docker manifest create --amend "$OWNER"/"${REPOS[0]}"-"${ARCHS[$i]}":latest
    done
    for (( i = 0; i < "${#ARCHS[@]}"; i++ ))
    do docker manifest annotate "$OWNER"/"${REPOS[0]}":"$VERSION" \
                                "$OWNER"/"${REPOS[0]}"-"${ARCHS[$i]}":"$VERSION" \
                                --os linux --arch "${DARCHS[$i]}"
       docker manifest annotate "$OWNER"/"${REPOS[0]}":latest \
                                "$OWNER"/"${REPOS[0]}"-"${ARCHS[$i]}":latest \
                                --os linux --arch "${DARCHS[$i]}"
    done
    docker manifest push -p "$OWNER"/"${REPOS[0]}":"$VERSION"
    docker manifest push -p "$OWNER"/"${REPOS[0]}":latest
}

function is_docker {
    (
        if is_directory 'build/docker'
        then cd build/docker || { log 2 "Failed to change directory to: build/docker" ; return 3; }
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
