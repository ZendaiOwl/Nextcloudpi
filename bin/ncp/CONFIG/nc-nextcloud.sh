#!/usr/bin/env bash

# Nextcloud installation on Raspbian over LAMP base
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

# A log that uses log levels for logging different outputs
# Log levels
# -2: Debug
# -1: Info
#  0: Success
#  1: Warning
#  2: Error
function log
{
  if [[ "$#" -gt 0 ]]; then local -r LOGLEVEL="$1" TEXT="${*:2}" Z='\e[0m'
    if [[ "$LOGLEVEL" =~ [(-2)-2] ]]; then
      case "$LOGLEVEL" in
        -2) local -r CYAN='\e[1;36m'; printf "${CYAN}DEBUG${Z} %s\n" "$TEXT" >&2
           ;;
        -1) local -r BLUE='\e[1;34m'; printf "${BLUE}INFO${Z} %s\n" "$TEXT"
           ;;
         0) local -r GREEN='\e[1;32m'; printf "${GREEN}SUCCESS${Z} %s\n" "$TEXT"
           ;;
         1) local -r YELLOW='\e[1;33m'; printf "${YELLOW}WARNING${Z} %s\n" "$TEXT"
           ;;
         2) local -r RED='\e[1;31m'; printf "${RED}ERROR${Z} %s\n" "$TEXT" >&2
           ;;
      esac
    else log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"; fi
  fi
}

# Prints a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function Print
{
  printf '%s\n' "$@"
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

# Checks if a command exists on the system
# Return status codes
# 0: Command exists on the system
# 1: Command is unavailable on the system
# 2: Missing command argument to check
function hasCMD
{
  if [[ "$#" -eq 1 ]]; then local -r CHECK="$1"
    if command -v "$CHECK" &>/dev/null; then return 0; else return 1; fi; else return 2; fi
}

# Installs package(s) using the package manager and pre-configured options
# Return codes
# 0: Install completed
# 1: Coudn't update apt list
# 2: Error during installation
# 3: Missing package argument
# 4: Not running as root/sudo
function installPKG
{
  if [[ "$#" -eq 0 ]]; then log 2 "Requires: [PKG(s) to install]"; return 3
  elif [[ "$EUID" -ne 0 ]]; then log 2 "Requires root privileges"; return 4 
  else local -r OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
       local -r ROOTUPDATE=(apt-get "${OPTIONS[@]}" update) \
                ROOTINSTALL=(apt-get "${OPTIONS[@]}" install)
       local PKG=()
       IFS=' ' read -ra PKG <<<"$@"
       log -1 "Updating apt lists"
       if "${ROOTUPDATE[@]}" &>/dev/null; then log 0 "Apt list updated"
       else log 2 "Couldn't update apt lists"; return 1
       fi; log -1 "Installing ${PKG[*]}"
       if DEBIAN_FRONTEND=noninteractive "${ROOTINSTALL[@]}" "${PKG[@]}"; then
         log 0 "Installation completed"; return 0
       else log 2 "Something went wrong during installation"; return 1; fi
  fi
}

DBADMIN='ncadmin'
REDIS_MEM=3gb

function tmpl_max_transfer_time
{
  find_app_param nc-nextcloud MAXTRANSFERTIME
}

function install
{
  local -r REDIS_CONF='/etc/redis/redis.conf' \
           REDIS_USER='redis' \
           REDISPASS='default' \
           REDIS_SOCKET='/var/run/redis/redis.sock' \
           SOCKET_PERMISSION='770' \
           PORT_NR='0' \
           HTTP_USER='www-data' \
           PROVISIONING_SERVICE='/usr/lib/systemd/system/nc-provisioning.service'
  # During build, this step is run before ncp.sh. Avoid executing twice
  if isFile "$PROVISIONING_SERVICE"; then return 0; fi

  # Optional packets for Nextcloud and Apps
  # NOTE: php-smbclient in sury but not in Debian sources, we'll use the binary version
  # https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/external_storage/smb.html
  # smbclient, exfat-fuse, exfat-utils: for external storage
  # exif: for gallery
  # bcmath: for LDAP
  # gmp: for bookmarks
  # imagick, ghostscript: for gallery
  installPKG jq \
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
  #installPKG imagemagick php"$PHPVER"-imagick ghostscript

  # POSTFIX
  installPKG postfix || {
    # [armbian] workaround for bug - https://bugs.launchpad.net/ubuntu/+source/postfix/+bug/1531299
    log -1 "[NCP]: Please ignore the previous postfix installation error"
    mv /usr/bin/newaliases /
    ln -s /bin/true /usr/bin/newaliases
    installPKG postfix
    rm /usr/bin/newaliases
    mv /newaliases /usr/bin/newaliases
  }
  
  sed -i "s|# unixsocket .*|unixsocket $REDIS_SOCKET|"              "$REDIS_CONF"
  sed -i "s|# unixsocketperm .*|unixsocketperm $SOCKET_PERMISSION|" "$REDIS_CONF"
  sed -i "s|# requirepass .*|requirepass $REDISPASS|"               "$REDIS_CONF"
  sed -i 's|# maxmemory-policy .*|maxmemory-policy allkeys-lru|'    "$REDIS_CONF"
  sed -i 's|# rename-command CONFIG ""|rename-command CONFIG ""|'   "$REDIS_CONF"
  sed -i "s|^port.*|port $PORT_NR|"                                 "$REDIS_CONF"
  Print "maxmemory $REDIS_MEM" >> "$REDIS_CONF"
  Print 'vm.overcommit_memory = 1' >> /etc/sysctl.conf

  if is_lxc; then
    # Otherwise it fails to start in Buster LXC container
    mkdir --parents /etc/systemd/system/redis-server.service.d
    cat > /etc/systemd/system/redis-server.service.d/lxc_fix.conf <<'EOF'
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
  mkdir --parents /usr/lib/systemd/system
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
  [[ "$DOCKERBUILD" != 1 ]] && systemctl enable nc-provisioning; return 0
}

function configure
{
  local -r OCPATH='/var/www/nextcloud' \
           HTPATH='/var/www' \
           HTUSER='www-data' \
           HTGROUP='www-data' \
           ROOTUSER='root' \
           MYSQL_PID='/run/mysqld/mysqld.pid' \
           MYSQL_SOCKET='/var/run/mysqld/mysqld.sock' \
           NEXTCLOUD_TEMPLATE='nextcloud.conf.sh' \
           NEXTCLOUD_CONF='/etc/apache2/sites-available/nextcloud.conf' \
           OPCACHE_TEMPLATE='php/opcache.ini.sh' \
           OPCACHE_CONF="/etc/php/${PHPVER}/mods-available/opcache.ini" \
           NOTIFYPUSH_TEMPLATE='systemd/notify_push.service.sh' \
           NOTIFYPUSH_SERVICE='/etc/systemd/system/notify_push.service' \
           URL="https://download.nextcloud.com/server/${PREFIX}releases/nextcloud-${NCLATESTVER}.tar.bz2"
  ## DOWNLOAD AND (OVER)WRITE NEXTCLOUD
  if ! cd "$HTPATH"; then log 2 "Unable to change directory to: $HTPATH"; exit 1; fi

  log -1 "Downloading Nextcloud: $NCLATESTVER"
  wget -q "$URL" -O nextcloud.tar.bz2 || { log 2 "Couldn't download: $URL"; return 1 }
  rm --recursive --force nextcloud

  log -1 "Installing  Nextcloud: $NCLATESTVER"
  tar -xf nextcloud.tar.bz2; rm nextcloud.tar.bz2

  ## CONFIGURE FILE PERMISSIONS

  log -1 "Creating possible missing directories"
  mkdir -p "$OCPATH"/data
  mkdir -p "$OCPATH"/updater

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
  if [ -f "$OCPATH"/.htaccess ]; then
    chmod 0644 "$OCPATH"/.htaccess
    chown "$HTUSER":"$HTGROUP" "$OCPATH"/.htaccess
  fi
  if [ -f "$OCPATH"/data/.htaccess ]; then
    chmod 0644 "$OCPATH"/data/.htaccess
    chown "$HTUSER":"$HTGROUP" "$OCPATH"/data/.htaccess
  fi

  # create and configure opcache dir
  local OPCACHEDIR="$(
    # shellcheck disable=SC2015
    [[ -f "${BINDIR}/CONFIG/nc-datadir.sh" ]] && { source "${BINDIR}/CONFIG/nc-datadir.sh"; tmpl_opcache_dir; } || true
  )"
  if [[ -z "${OPCACHEDIR}" ]]; then
    install_template "php/opcache.ini.sh" "/etc/php/${PHPVER}/mods-available/opcache.ini" "--defaults"
  else mkdir --parents "$OPCACHEDIR"
       chown -R "$HTUSER":"$HTUSER" "$OPCACHEDIR"
       install_template "$OPCACHE_TEMPLATE" "$OPCACHE_CONF"
  fi
  
  ## RE-CREATE DATABASE TABLE
  # Launch MariaDB if not already running (for docker build)
  if [[ ! -f "$MYSQL_PID" ]]; then log -1 "Starting: MariaDB"
    mysqld &
    local DB_PID="$!"
  fi

  while :; do [[ -S "$MYSQL_SOCKET" ]] && break
    sleep 1
  done

  log -1 "Setting up: Database"

  # workaround to emulate DROP USER IF EXISTS ..;)
  local DBPASSWD="$( grep password /root/.my.cnf | sed 's|password=||' )"
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
  
  install_template "$NEXTCLOUD_TEMPLATE" "$NEXTCLOUD_CONF" --allow-fallback || {
      log 2 "Failed parsing template: $NEXTCLOUD_TEMPLATE"; exit 1
  }
  a2ensite nextcloud

  cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
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
  a2enmod proxy proxy_http proxy_wstunnel

  arch="$(uname -m)"
  [[ "${arch}" =~ "armv7" ]] && arch="armv7"
  install_template "$NOTIFYPUSH_TEMPLATE" "$NOTIFYPUSH_SERVICE"
  [[ -f /.docker-image ]] || systemctl enable notify_push

  # some added security
  sed -i 's|^ServerSignature .*|ServerSignature Off|' /etc/apache2/conf-enabled/security.conf
  sed -i 's|^ServerTokens .*|ServerTokens Prod|'      /etc/apache2/conf-enabled/security.conf

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
  echo "*/5  *  *  *  * php -f /var/www/nextcloud/cron.php" > /tmp/crontab_http
  crontab -u "$HTUSER" /tmp/crontab_http
  rm /tmp/crontab_http

  # Detach MySQL during the build
  if [[ "$DB_PID" != "" ]]; then log -1 "Shutting down MariaDB [$DB_PID]"
    mysqladmin -u root shutdown; wait "$DB_PID"
  fi; log 0 "Completed: ${BASH_SOURCE[0]##*/}"; log -1 "Don't forget to run nc-init"
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

