#!/usr/bin/env bash

# Nextcloud installation on Raspbian over LAMP base
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
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
    then if [[ "$1" =~ [(-2)-2] ]]
         then case "$1" in
                  -2) printf '\e[1;36mDEBUG\e[0m %s\n'   "${*:2}" >&2 ;;
                  -1) printf '\e[1;34mINFO\e[0m %s\n'    "${*:2}"     ;;
                   0) printf '\e[1;32mSUCCESS\e[0m %s\n' "${*:2}"     ;;
                   1) printf '\e[1;33mWARNING\e[0m %s\n' "${*:2}"     ;;
                   2) printf '\e[1;31mERROR\e[0m %s\n'   "${*:2}" >&2 ;;
              esac
         else log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"
         fi
  fi
}

# Update apt list and packages
# Return codes
# 0: install_pkg completed
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
# 0: install_pkg completed
# 1: Error during installation
# 2: Missing package argument
function install_package {
    if [[ "$#" -eq 0 ]]
    then log 2 "Requires: [PKG(s)]"; return 2
    else declare -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
         declare -r SUDOINSTALL=(sudo apt-get "${OPTIONS[@]}" install) \
                    ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
         if [[ "$EUID" -eq 0 ]]
         then log -1 "install_pkging $*"
              if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "$@"
              then log 0 "install_pkgation complete"; return 0
              else log 2 "Something went wrong during installation"; return 1
              fi
         else log -1 "install_pkging $*"
              if DEBIAN_FRONTEND=noninteractive "${SUDOINSTALL[@]}" "$@"
              then log 0 "install_pkgation complete"; return 0
              else log 2 "Something went wrong during installation"; return 1
              fi
         fi
    fi
}

DBADMIN='ncadmin'
REDIS_MEM='3gb'

function tmpl_max_transfer_time {
    find_app_param 'nc-nextcloud' 'MAXTRANSFERTIME'
}

function install {
    local -r REDIS_CONF='/etc/redis/redis.conf' \
             REDIS_USER='redis' \
             REDISPASS='default' \
             REDIS_SOCKET='/var/run/redis/redis.sock' \
             SOCKET_PERMISSION='770' \
             PORT_NR='0' \
             HTTP_USER='www-data' \
             PROVISIONING_SERVICE='/usr/lib/systemd/system/nc-provisioning.service'
    # During build, this step is run before ncp.sh. Avoid executing twice
    [[ -f "$PROVISIONING_SERVICE" ]] && return 0

    # Update
    update_apt

    # Optional packets for Nextcloud and Apps
    # NOTE: php-smbclient in sury but not in Debian sources, we'll use the binary version
    # https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/external_storage/smb.html
    # smbclient, exfat-fuse, exfat-utils: for external storage
    # exif:                 for gallery
    # bcmath:               for LDAP
    # gmp:                  for bookmarks
    # imagick, ghostscript: for gallery
    install_package jq \
                    wget \
                    lbzip2 \
                    procps \
                    psmisc \
                    binutils \
                    smbclient \
                    exfat-fuse \
                    exfat-utils \
                    iputils-ping \
                    redis-server \
                    php"$PHPVER"-{exif,bcmath,gmp,redis} 
    #install_package imagemagick php"$PHPVER"-imagick ghostscript

    # POSTFIX
    if ! install_package 'postfix'
    then # [armbian] workaround for bug - https://bugs.launchpad.net/ubuntu/+source/postfix/+bug/1531299
         log -1 "[NCP]: Please ignore the previous postfix installation error"
         mv '/usr/bin/newaliases' '/'
         ln -s '/bin/true' '/usr/bin/newaliases'
         install_package 'postfix'
         rm '/usr/bin/newaliases'
         mv '/newaliases' '/usr/bin/newaliases'
    fi
  
    sed -i "s|# unixsocket .*|unixsocket $REDIS_SOCKET|"              "$REDIS_CONF"
    sed -i "s|# unixsocketperm .*|unixsocketperm $SOCKET_PERMISSION|" "$REDIS_CONF"
    sed -i "s|# requirepass .*|requirepass $REDISPASS|"               "$REDIS_CONF"
    sed -i 's|# maxmemory-policy .*|maxmemory-policy allkeys-lru|'    "$REDIS_CONF"
    sed -i 's|# rename-command CONFIG ""|rename-command CONFIG ""|'   "$REDIS_CONF"
    sed -i "s|^port.*|port $PORT_NR|"                                 "$REDIS_CONF"
    println "maxmemory $REDIS_MEM"     >> "$REDIS_CONF"
    println 'vm.overcommit_memory = 1' >> '/etc/sysctl.conf'

    if is_lxc
    then mkdir --parents '/etc/systemd/system/redis-server.service.d'
         cat > '/etc/systemd/system/redis-server.service.d/lxc_fix.conf' <<'EOF'
[Service]
ReadOnlyDirectories=
EOF
       systemctl daemon-reload
    fi

    chown "$REDIS_USER": "$REDIS_CONF"
    usermod --append --groups "$REDIS_USER" "$HTTP_USER"
    
    service redis-server restart
    update-rc.d redis-server enable
    clear_opcache
    
    # service to randomize passwords on first boot
    mkdir --parents '/usr/lib/systemd/system'
    cat > "$PROVISIONING_SERVICE" <<'EOF'
[Unit]
Description=Randomize passwords on first boot
Requires=network.target
After=mysql.service redis.service

[Service]
ExecStart=/bin/bash /usr/local/bin/ncp-provisioning.sh

[Install]
WantedBy=multi-user.target
EOF
    if [[ "$DOCKERBUILD" != 1 ]]
    then systemctl enable nc-provisioning
    fi; return 0
}

function configure
{
    local -r OCPATH='/var/www/nextcloud' \
             HTPATH='/var/www' \
             HTUSER='www-data' \
             HTGROUP='www-data' \
             MYSQL_PID='/run/mysqld/mysqld.pid' \
             MYSQL_SOCKET='/var/run/mysqld/mysqld.sock' \
             NEXTCLOUD_TEMPLATE='nextcloud.conf.sh' \
             NEXTCLOUD_CONF='/etc/apache2/sites-available/nextcloud.conf' \
             OPCACHE_TEMPLATE='php/opcache.ini.sh' \
             OPCACHE_CONF="/etc/php/${PHPVER}/mods-available/opcache.ini" \
             NOTIFYPUSH_TEMPLATE='systemd/notify_push.service.sh' \
             NOTIFYPUSH_SERVICE='/etc/systemd/system/notify_push.service' \
             URL="https://download.nextcloud.com/server/${PREFIX}releases/nextcloud-${NCLATESTVER}.tar.bz2"
    local OPCACHEDIR DBPASSWD DB_PID

    ## DOWNLOAD AND (OVER)WRITE NEXTCLOUD
    cd "$HTPATH" || log 2 "Unable to change directory to: $HTPATH"; exit 1

    log -1 "Downloading Nextcloud: $NCLATESTVER"
    if ! wget -q "$URL" -O 'nextcloud.tar.bz2'
    then log 2 "Download failed: $URL"; return 1
    fi

    log -1 "Checking for existing nextcloud directory"
    if [[ -d 'nextcloud' ]]
    then rm --recursive --force 'nextcloud'
         log -1 "Removed directory: nextcloud"
    else log -1 "Directory not found: nextcloud"
    fi
    
    log -1 "Installing Nextcloud: $NCLATESTVER"
    tar -xf 'nextcloud.tar.bz2'
    rm 'nextcloud.tar.bz2'
    
    ## CONFIGURE FILE PERMISSIONS
    
    log -1 "Creating possible missing directories"
    mkdir --parents "$OCPATH"/data
    mkdir --parents "$OCPATH"/updater
    
    log -1 "chmod: files (0640) & directories (0750)"
    find "$OCPATH"/ -type f -print0 | xargs -0 chmod 0640
    find "$OCPATH"/ -type d -print0 | xargs -0 chmod 0750
    
    log -1 "chown: directories ($HTUSER)"
    
    chown -R "$HTUSER":"$HTGROUP" "$OCPATH"/
    chown -R "$HTUSER":"$HTGROUP" "$OCPATH"/apps/
    chown -R "$HTUSER":"$HTGROUP" "$OCPATH"/config/
    chown -R "$HTUSER":"$HTGROUP" "$OCPATH"/data/
    chown -R "$HTUSER":"$HTGROUP" "$OCPATH"/themes/
    chown -R "$HTUSER":"$HTGROUP" "$OCPATH"/updater/
    
    chmod +x "$OCPATH"/occ
    
    log -1 "chmod ($HTUSER) & chown (0644): .htaccess"
    if [[ -f "$OCPATH"/.htaccess ]]
    then chmod 0644 "$OCPATH"/.htaccess
         chown "$HTUSER":"$HTGROUP" "$OCPATH"/.htaccess
    fi
    if [[ -f "$OCPATH"/data/.htaccess ]]
    then chmod 0644 "$OCPATH"/data/.htaccess
         chown "$HTUSER":"$HTGROUP" "$OCPATH"/data/.htaccess
    fi

    # create and configure opcache dir
    OPCACHEDIR="$(
    # shellcheck disable=SC2015
    if [[ -f "${BINDIR}/CONFIG/nc-datadir.sh" ]]
    then # shellcheck disable=SC1090
         source "${BINDIR}/CONFIG/nc-datadir.sh"
         tmpl_opcache_dir
    else true
    fi
    )"
    if [[ -z "$OPCACHEDIR" ]]
    then install_template  "php/opcache.ini.sh" "/etc/php/${PHPVER}/mods-available/opcache.ini" '--defaults'
    else mkdir --parents   "$OPCACHEDIR"
         chown --recursive "$HTUSER":"$HTUSER" "$OPCACHEDIR"
         install_template  "$OPCACHE_TEMPLATE" "$OPCACHE_CONF"
    fi
    
    ## RE-CREATE DATABASE TABLE
    # Launch MariaDB if not already running (for docker build)
    if [[ ! -f "$MYSQL_PID" ]]
    then log -1 "Starting: MariaDB"
         mysqld &
         DB_PID="$!"
    fi
    
    while :
    do [[ -S "$MYSQL_SOCKET" ]] && break
       sleep 1
    done
    
    log -1 "Setting up: Database"
    
    # workaround to emulate DROP USER IF EXISTS ..;)
    DBPASSWD="$(grep 'password' '/root/.my.cnf' | sed 's|password=||')"
    mysql <<EOF
DROP DATABASE IF EXISTS nextcloud;
CREATE DATABASE nextcloud
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_general_ci;
GRANT USAGE ON *.* TO '$DBADMIN'@'localhost' IDENTIFIED BY '$DBPASSWD';
DROP USER '$DBADMIN'@'localhost';
CREATE USER '$DBADMIN'@'localhost' IDENTIFIED BY '$DBPASSWD';
GRANT ALL PRIVILEGES ON nextcloud.* TO $DBADMIN@localhost;
EXIT
EOF

    ## SET APACHE VHOST
    log -1 "Setting up: Apache2 VirtualHost"
  
    if ! install_template "$NEXTCLOUD_TEMPLATE" "$NEXTCLOUD_CONF" '--allow-fallback'
    then log 2 "Failed parsing template: $NEXTCLOUD_TEMPLATE"; exit 1
    fi
    
    a2ensite nextcloud
    
    cat > '/etc/apache2/sites-available/000-default.conf' <<'EOF'
<VirtualHost _default_:80>
  DocumentRoot /var/www/nextcloud
  <IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteRule ^.well-known/acme-challenge/ - [L]
    RewriteCond %{HTTPS} !=on
    RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
  </IfModule>
  <Directory /var/www/nextcloud/>
    Options +FollowSymlinks
    AllowOverride All
    <IfModule mod_dav.c>
      Dav off
    </IfModule>
    LimitRequestBody 0
  </Directory>
</VirtualHost>
EOF

    # for notify_push app in NC21
    a2enmod proxy \
            proxy_http \
            proxy_wstunnel
    
    arch="$(uname -m)"
    [[ "$arch" =~ "armv7" ]] && arch='armv7'
    install_template "$NOTIFYPUSH_TEMPLATE" "$NOTIFYPUSH_SERVICE"

    if [[ ! -f '/.docker-image' ]]
    then systemctl enable notify_push
    fi
    
    # some added security
    sed -i 's|^ServerSignature .*|ServerSignature Off|' '/etc/apache2/conf-enabled/security.conf'
    sed -i 's|^ServerTokens .*|ServerTokens Prod|'      '/etc/apache2/conf-enabled/security.conf'
    
    log -1 "Setting up: System"
    
    ## SET LIMITS
    cat > /etc/php/"$PHPVER"/fpm/conf.d/90-ncp.ini <<EOF
; disable .user.ini files for performance and workaround NC update bugs
user_ini.filename =

; from Nextcloud .user.ini
upload_max_filesize=$MAXFILESIZE
post_max_size=$MAXFILESIZE
memory_limit=$MEMORYLIMIT
mbstring.func_overload=0
always_populate_raw_post_data=-1
default_charset='UTF-8'
output_buffering=0

; slow transfers will be killed after this time
max_execution_time=$MAXTRANSFERTIME
max_input_time=$MAXTRANSFERTIME
EOF

    ## SET CRON
    echo "*/5  *  *  *  * php -f /var/www/nextcloud/cron.php" > '/tmp/crontab_http'
    crontab -u "$HTUSER" '/tmp/crontab_http'
    if ! rm '/tmp/crontab_http'
    then log 2 "Failed to remove: /tmp/crontab_http"; exit 1
    fi
    
    # dettach mysql during the build
    if [[ "$DB_PID" != "" ]]
    then log -1 "Shutting down MariaDB [$DB_PID]"
         mysqladmin -u root shutdown
         wait "$DB_PID"
    fi
    log 0 "Completed: ${BASH_SOURCE[0]##*/}"; log -1 "Don't forget to run nc-init"
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

