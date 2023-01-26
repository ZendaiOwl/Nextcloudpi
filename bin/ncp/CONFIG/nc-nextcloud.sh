#!/usr/bin/env bash
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

function TmplMaxTransferTime() {
  findAppParameter nc-nextcloud MAXTRANSFERTIME
}

# Install function for Nextcloud
# External storage: smbclient exfat-fuse exfat-utils
# Gallery:          php"$PHP_VERSION"-exif
# LDAP:             php"$PHP_VERSION"-bcmath
# Bookmarks:        php"$PHP_VERSION"-gmp
function install {
  local OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends) \
        APTUPDATE=(apt-get "${OPTIONS[@]}" update) \
        APTINSTALL=(apt-get "${OPTIONS[@]}" install) \
        PACKAGES=(smbclient exfat-fuse exfat-utils redis-server php"$PHP_VERSION"-{exif,bcmath,gmp,redis}) \
        PROVISIONING_SERVICE='/usr/lib/systemd/system/nc-provisioning.service' \
        DBADMIN='ncadmin' \
        REDIS_MEM='3gb' \
        REDIS_CONF='/etc/redis/redis.conf' \
        REDIS_INIT='/etc/init.d/redis-server' \
        REDIS_SERVICE_D='/etc/systemd/system/redis-server.service.d' \
        REDIS_PASSWORD='default' \
        REDIS_GROUP='redis' \
        HTTP_USER='www-data' \
        LXC_FIX_CONF='/etc/systemd/system/redis-server.service.d/lxc_fix.conf' \
        SYSCTL_CONF='/etc/sysctl.conf' \
        SYSTEM_DIR='/usr/lib/systemd/system'

  # During build, this service runs before Ncp.sh
  # Avoid executing twice
  [[ -f "$PROVISIONING_SERVICE" ]] && return 0

  # Optional packages for Nextcloud & Nextcloud Apps
  DEBIAN_FRONTEND=noninteractive "${APTUPDATE[@]}"
  DEBIAN_FRONTEND=noninteractive "${APTINSTALL[@]}" --target-release "$RELEASE" "${PACKAGES[@]}"

  sed -i "s|# unixsocket .*|unixsocket /var/run/redis/redis.sock|"   "$REDIS_CONF"
  # Default redis unixsocketperm is 700 
  sed -i "s|# unixsocketperm .*|unixsocketperm 770|"                 "$REDIS_CONF"
  sed -i "s|# requirepass .*|requirepass $REDISPASS|"                "$REDIS_CONF"
  sed -i 's|# maxmemory-policy .*|maxmemory-policy allkeys-lru|'     "$REDIS_CONF"
  sed -i 's|# rename-command CONFIG ""|rename-command CONFIG ""|'    "$REDIS_CONF"
  sed -i "s|^port.*|port 0|"                                         "$REDIS_CONF"
  echo "maxmemory $REDIS_MEM"     >>                                 "$REDIS_CONF"
  echo 'vm.overcommit_memory = 1' >>                                 "$SYSCTL_CONF"
  # TODO
  # Inside Docker container
  # Modify: /etc/init.d/redis-server
  # Add line: chmod 644 $PIDFILE
  if [[ "$DOCKERBUILD" -eq 1 ]]
  then
    sed -i '/chmod 755 $RUNDIR/i chmod 644 $PIDFILE'                 "$REDIS_INIT"
  fi

  if isLXC
  then
    mkdir --parents "$REDIS_SERVICE_D"
    cat > "$LXC_FIX_CONF" <<'EOF'
[Service]
ReadOnlyDirectories=
EOF
    systemctl daemon-reload
  fi

  chown redis: "$REDIS_CONF"
  usermod --append --groups "$REDIS_GROUP" "$HTTP_USER"

  service redis-server restart
  update-rc.d redis-server enable
  clearOPCache

  mkdir --parents "$SYSTEM_DIR"
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
  [[ "$DOCKERBUILD" -ne 1 ]] && systemctl enable nc-provisioning
  return 0
}

function configure {
  local DBCONF='/root/.my.cnf'
  local OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends) \
        APTUPDATE=(apt-get "${OPTIONS[@]}" update) \
        APTINSTALL=(apt-get "${OPTIONS[@]}" install) \
        URL="https://download.nextcloud.com/server/${PREFIX}releases/nextcloud-${VER}.tar.bz2" \
        BACKUP_DIR="${HTTP_DIR}/backup" \
        HTTP_DIR='/var/www' \
        HTTP_USER='www-data' \
        HTTP_GROUP='www-data' \
        OCPATH="${HTTP_DIR}/nextcloud" \
        APPS_PATH="${OCPATH}/apps" \
        CONFIG_PATH="${OCPATH}/config" \
        DATA_PATH="${OCPATH}/data" \
        THEMES_PATH="${OCPATH}/themes" \
        UPDATER_PATH="${OCPATH}/updater" \
        OCC_PATH="${OCPATH}/occ" \
        ROOT_USER='root' \
        OPCACHEDIR="$(
          # shellcheck disable=SC2015
          [ -f "${BINDIR}/CONFIG/nc-datadir.sh" ] && { source "${BINDIR}/CONFIG/nc-datadir.sh"; tmpl_opcache_dir; } || true
        )" \
        MYSQLD_PID='/run/mysqld/mysqld.pid' \
        MYSQLD_SOCKET='/var/run/mysqld/mysqld.sock' \
        DBADMIN='ncadmin' REDIS_MEM='3gb' DB_PID \
        DBPASSWD="$(grep 'password' "$DB_CONF" | sed 's|password=||')"
  
  # Download & overwrite Nextcloud
  ################################
  cd "$HTTP_DIR"
  log -1 "Downloading Nextcloud $NEXTCLOUD_VERSION_LATEST"
  if ! wget -q "$URL" -O nextcloud.tar.bz2
  then
    log 2 "Couldn't download $NEXTCLOUD_VERSION_LATEST"
    return 1
  fi
  mkdir --parents "$BACKUP_DIR"
  mv nextcloud    "${BACKUP_DIR}/"
  #rm --recursive --force nextcloud
  log -1 "Installing $NEXTCLOUD_VERSION_LATEST"

  tar -xf nextcloud.tar.bz2
  rm nextcloud.tar.bz2
  
  # File Permissions Configuration
  ################################
  log -1 "Creating possible missing directories"
  mkdir --parents "$DATA_PATH"
  mkdir --parents "$UPDATER_PATH"

  log -1 "Permissions: Files 'chmod 0640' | Directories 'chmod 0750'"
  find "${OCPATH}/" -type f -print0 | xargs -0 chmod 0640
  find "${OCPATH}/" -type d -print0 | xargs -0 chmod 0750

  log -1 "Change owner to: ${HTTP_USER}:${HTTP_GROUP}"
  chown -R "${HTTP_USER}:${HTTP_GROUP}" "$OCPATH"
  #chown -R "${HTTP_USER}:${HTTP_GROUP}" "$APPS_PATH"
  #chown -R "${HTTP_USER}:${HTTP_GROUP}" "$CONFIG_PATH"
  #chown -R "${HTTP_USER}:${HTTP_GROUP}" "$DATA_PATH"
  #chown -R "${HTTP_USER}:${HTTP_GROUP}" "$THEMES_PATH"
  #chown -R "${HTTP_USER}:${HTTP_GROUP}" "$UPDATER_PATH"

  chmod +x "$OCC_PATH"

  if [[ -f "${OCPATH}/.htaccess" ]]
  then
    chmod 0644 "${OCPATH}/.htaccess"
    chown "${HTTP_USER}:${HTTP_GROUP}" "${OCPATH}/.htaccess"
  fi
  if [[ -f "${DATA_PATH}/.htaccess" ]]
  then
    chmod 0644 "${DATA_PATH}/.htaccess"
    chown "${HTTP_USER}:${HTTP_GROUP}" "${DATA_PATH}/.htaccess"
  fi

  if [[ -< "$OPCACHEDIR" ]]
  then
    installTemplate "php/opcache.ini.sh" "/etc/php/${PHP_VERSION}/mods-available/opcache.ini" --defaults
  else
    mkdir -p "$OPCACHEDIR"
    chown -R "${HTTP_USER}:${HTTP_GROUP}" "$OPCACHEDIR"
    installTemplate "php/opcache.ini.sh" "/etc/php/${PHP_VERSION}/mods-available/opcache.ini"
  fi
  
  # Recreate database table
  #########################
  if [[ ! -f "$MYSQLD_PID" ]]
  then
    log -1 "Starting MariaDB"
    mysqld &
    DB_PID="$!"
  fi

  while :
  do
    if [[ -S "$MYSQLD_SOCKET" ]]
    then
      break
    else
      sleep 1
    fi
  done

  log -1 "Setting up the database"

  # Workaround to emulate DROP USER IF EXISTS
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

  # Set Apache2 VirtualHost
  #########################

  log -1 "Setting up Apache2"
  if ! installTemplate nextcloud.conf.sh /etc/apache2/sites-available/nextcloud.conf --allow-fallback
  then
    log 2 "Parsing template failed"
    exit 1
  fi

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

  ARCH="$(dpkg --print-architecture)"
  [[ "$ARCH" =~ ^(armhf|arm)$ ]]       && ARCH='armv7'
  [[ "$ARCH" == "arm64" ]]             && ARCH='aarch64'
  [[ "$ARCH" == "amd64" ]]             && ARCH='x86_64'

  installTemplate systemd/notify_push.service.sh /etc/systemd/system/notify_push.service
  [[ -f /.docker-image ]] || systemctl enable notify_push

  # Some added security
  sed -i 's|^ServerSignature .*|ServerSignature Off|' /etc/apache2/conf-enabled/security.conf
  sed -i 's|^ServerTokens .*|ServerTokens Prod|'      /etc/apache2/conf-enabled/security.conf

  log -1 "Setting up system"

  # Set limits
  ############
  
  cat > /etc/php/"$PHP_VERSION"/fpm/conf.d/90-ncp.ini <<EOF
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

  # Set cron
  ##########
  
  echo "*/5  *  *  *  * php -f /var/www/nextcloud/cron.php" > /tmp/crontab_http
  crontab -u www-data /tmp/crontab_http
  rm /tmp/crontab_http
  
  # Detach MySQL during build
  if [[ "$DB_PID" != "" ]]
  then
    log -1 "Shutting down MariaDB ( $DB_PID )"
    mysqladmin -u root shutdown
    wait "$DB_PID"
  fi

  log -1 "Don't forget to run nc-init"
  
}

