#!/usr/bin/env bash

# Data dir configuration script for NextcloudPi
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/03/13/nextcloudpi-gets-nextcloudpi-config/
#

# Prints a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function Print {
    printf '%s\n' "$@"
}

function is_active {
  local SRCDIR
  SRCDIR="$( grep datadirectory /var/www/nextcloud/config/config.php | awk '{ print $3 }' | grep -oP "[^']*[^']" | head -1 )" || return 1
  [[ "$SRCDIR" != "/var/www/nextcloud/data" ]]
}

function install {
  apt_install btrfs-progs
}

function tmpl_opcache_dir {
    local DATADIR
    DATADIR="$(get_nc_config_value datadirectory || find_app_param nc-datadir DATADIR)"
    echo -n "${DATADIR}/.opcache"
    #[[ $( stat -fc%d / ) == $( stat -fc%d "$DATADIR" ) ]] && echo "/tmp" || echo "${DATADIR}/.opcache"
}

function tmpl_tmp_upload_dir {
    local DATADIR
    DATADIR="$(get_nc_config_value datadirectory || find_app_param nc-datadir DATADIR)"
    echo -n "${DATADIR}/tmp"
}

function create_opcache_dir {
    local OPCACHE_DIR
    OPCACHE_DIR="$(tmpl_opcache_dir)"
    mkdir --parents "$OPCACHE_DIR"
    chown --recursive 'www-data':'www-data' "$OPCACHE_DIR"
    if [[ "$(stat -fc%T "$BASEDIR")" == "btrfs" ]]
    then chattr -R +C "$OPCACHE_DIR"
    fi
}

function create_tmp_upload_dir {
    local UPLOAD_DIR
    UPLOAD_DIR="$(tmpl_tmp_upload_dir)"
    mkdir --parents "$UPLOAD_DIR"
    chown 'www-data':'www-data' "$UPLOAD_DIR"
    if [[ "$(stat -fc%T "$BASEDIR")" == "btrfs" ]]
    then chattr +C "$UPLOAD_DIR"
    fi
}

function configure {
    set -e -o pipefail
    shopt -s dotglob # includes dot files
    
    ## CHECKS
    local SRCDIR BASEDIR ENCDIR BKP
    if ! SRCDIR="$( get_nc_config_value datadirectory )"
    then Print "Error reading data directory. Is Nextcloud running and configured?"
         return 1
    fi
    
    if [[ ! -d "${SRCDIR?}" ]]
    then Print "Directory not found: $SRCDIR"
         return 1
    fi
    
    if [[ "$SRCDIR" == "${DATADIR?}" ]]
    then Print "Data exists: $SRCDIR"
         return 0
    elif [[ "$SRCDIR" == "$DATADIR"/data ]]
    then Print "Data exists: $SRCDIR"
         return 0
    fi
    
    BASEDIR="$DATADIR"
    # If the user chooses the root of the mountpoint, force a folder
    if mountpoint -q "${BASEDIR?}"
    then BASEDIR="${BASEDIR}/ncdata"
    fi
    
    mkdir --parents "$BASEDIR"
    BASEDIR="$(cd "$BASEDIR" && pwd -P)" # resolve symlinks and use the real path
    DATADIR="${BASEDIR}/data"
    ENCDIR="${BASEDIR}/ncdata_enc"
    
    # Checks
    if [[ "$DISABLE_FS_CHECK" != 1 ]]
    then if ! grep -q -e ext -e btrfs <( stat -fc%T "$BASEDIR" )
         then Print "Only ext/btrfs filesystems can hold the data directory (found '$(stat -fc%T "$BASEDIR")')"
              return 1
         fi
    fi
    if ! sudo -u www-data test -x "$BASEDIR"
    then Print "ERROR: www-data user does not have execute permissions in: $BASEDIR"
         return 1
    fi
    
    # backup possibly existing datadir
    if [[ -d "$BASEDIR" ]]
    then if ! rmdir "$BASEDIR" &>/dev/null
         then BKP="${BASEDIR}-$(date "+%m-%d-%y.%s")"
              Print "INFO: $BASEDIR is not empty. Creating backup: ${BKP?}"
              if ! mv "$BASEDIR" "$BKP"
              then log 2 "Failed to create a backup"; return 1
              fi
         fi
         mkdir --parents "$BASEDIR"
    fi
    
    ## COPY
    if ! cd '/var/www/nextcloud'
    then Print "Failed to change directory to: /var/www/nextcloud"; return 1
    fi
    [[ "$BUILD_MODE" == 1 ]] || save_maintenance_mode
    
    Print "Moving data directory from $SRCDIR to $BASEDIR"
    
    # use subvolumes, if BTRFS
    if [[ "$(stat -fc%T "$BASEDIR")" == "btrfs" ]] && ! is_docker
    then Print "BTRFS filesystem detected"
         if ! rmdir "$BASEDIR"
         then log 2 "Failed to remove directory: $BASEDIR"; return 1
         fi
         if ! btrfs subvolume create "$BASEDIR"
         then log 2 "Failed to create BTRFS subvolume in: $BASEDIR"; return 1
         fi 
    fi
    
    # use encryption, if selected
    if is_active_app nc-encrypt # if we have encryption AND BTRFS, then store ncdata_enc in the subvolume
    then mv "$(dirname "$SRCDIR")"/ncdata_enc "${ENCDIR?}"
         mkdir "$DATADIR"                        && mount --bind "$SRCDIR" "$DATADIR"
         mkdir "$(dirname "$SRCDIR")"/ncdata_enc && mount --bind "$ENCDIR" "$(dirname "$SRCDIR")"/ncdata_enc
    else mv "$SRCDIR" "$DATADIR"
    fi
    chown -R www-data:www-data "$DATADIR"
    
    # datadir
    ncc config:system:set datadirectory  --value="$DATADIR" \
    || sed -i "s|'datadirectory' =>.*|'datadirectory' => '$DATADIR',|" "${NCDIR?}"/config/config.php
    
    ncc config:system:set logfile --value="${DATADIR}/nextcloud.log" \
    || sed -i "s|'logfile' =>.*|'logfile' => '${DATADIR}/nextcloud.log',|" "${NCDIR?}"/config/config.php
    set_ncpcfg datadir "$DATADIR"
    
    # tmp upload dir
    create_tmp_upload_dir
    ncc config:system:set tempdirectory --value "$DATADIR/tmp" \
    || sed -i "s|'tempdirectory' =>.*|'tempdirectory' => '${DATADIR}/tmp',|" "${NCDIR?}"/config/config.php
    sed -i "s|^;\?upload_tmp_dir =.*$|uploadtmp_dir = ${DATADIR}/tmp|"  /etc/php/"$PHPVER"/cli/php.ini
    sed -i "s|^;\?upload_tmp_dir =.*$|upload_tmp_dir = ${DATADIR}/tmp|" /etc/php/"$PHPVER"/fpm/php.ini
    sed -i "s|^;\?sys_temp_dir =.*$|sys_temp_dir = ${DATADIR}/tmp|"     /etc/php/"$PHPVER"/fpm/php.ini
    
    # opcache dir
    create_opcache_dir
    install_template "php/opcache.ini.sh" "/etc/php/${PHPVER}/mods-available/opcache.ini"
    
    # update fail2ban logpath
    if [[ -f '/etc/fail2ban/jail.local' ]]
    then sed -i "s|logpath  =.*nextcloud.log|logpath  = ${DATADIR}/nextcloud.log|" '/etc/fail2ban/jail.local'
    fi
    
    if [[ "$BUILD_MODE" != 1 ]]
    then restore_maintenance_mode
    fi
    
    (
        # shellcheck disable=SC1090
        . "${BINDIR?}/SYSTEM/metrics.sh"
        if ! reload_metrics_config
        then Print "WARNING: There was an issue reloading ncp metrics. This might not affect your installation, but keep it in mind if there is an issue with metrics."
             true
        fi
    )
    
    Print "The NC data directory has been moved successfully."
}

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

