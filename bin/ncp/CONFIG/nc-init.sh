#!/bin/bash

# Init NextCloud database and perform initial configuration
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

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

function configure {
  local DBADMIN='ncadmin' REDISPASS REDIS_CONF='/etc/redis/redis.conf' \
        MYSQLD_PID='/run/mysqld/mysqld.pid' \
        MYSQLD_SOCKET='/var/run/mysqld/mysqld.sock' \
        DB_PID DBPASSWD DBNAME='nextcloud' DBTYPE='mysql' \
        UPLOADTMPDIR='/var/www/nextcloud/data/tmp' \
        HTTP_USER='www-data' NCVER NCPREV ID \
        NEXTCLOUD_DIRECTORY='/var/www/nextcloud' \
        REDIS_USER='redis' REDIS_DIR='/var/run/redis' \
        REDIS_CONF='/etc/redis/redis.conf' \
        REDIS_SOCKET='/run/redis/redis.sock'
  echo "Setting up a clean Nextcloud instance... wait until message 'NC init done'"

  # Checks
  REDISPASS="$(grep "^requirepass" "$REDIS_CONF" | cut -d' ' -f2)"
  [[ "$REDISPASS" == "" ]] && {
    log 2 "Redis server without a password"
    return 1
  }

  ## RE-CREATE DATABASE TABLE
  log -1 "Setting up database"

  # Launch MariaDB if not already running
  if [[ ! -f "$MYSQLD_PID" ]]
  then
    log -1 "Starting MariaDB"
    mysqld &
    DB_PID="$!"
  fi

  # Wait for MariaDB
  while :
  do
    if [[ -S "$MYSQLD_SOCKET" ]]
    then
      log -1 "MariaDB started"
      break
    else
      log -1 "Waiting on MariaDB"
      sleep 1
    fi
  done

  # Workaround to emulate DROP USER IF EXISTS
  DBPASSWD="$(grep 'password' /root/.my.cnf | sed 's|password=||')"
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

  ## INITIALIZE NEXTCLOUD

  # make sure redis is running first
  if ! pgrep -c redis-server &>/dev/null; then
    mkdir --parents "$REDIS_DIR"
    chown redis "$REDIS_DIR"
    sudo -u "$REDIS_USER" redis-server "$REDIS_CONF" &
  fi

  while :
  do
    [[ -S "$REDIS_SOCKET" ]] && break
    sleep 1
  done


  log -1 "Setting up Nextcloud"

  cd "$NEXTCLOUD_DIRECTORY" || return 1
  rm --force config/config.php
  ncc maintenance:install --database      "$DBTYPE" \
                          --database-name "$DBNAME" \
                          --database-user "$DBADMIN" \
                          --database-pass "$DBPASSWD" \
                          --admin-user    "$ADMINUSER" \
                          --admin-pass    "$ADMINPASS"

  # cron jobs
  ncc background:cron

  # redis cache
  sed -i '$d' config/config.php
  cat >> config/config.php <<EOF
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' =>
  array (
    'host' => '$REDIS_SOCKET',
    'port' => 0,
    'timeout' => 0.0,
    'password' => '$REDISPASS',
  ),
);
EOF

  # tmp upload dir
  mkdir --parents "$UPLOADTMPDIR"
  chown "${HTTP_USER}:${HTTP_USER}" "$UPLOADTMPDIR"
  ncc config:system:set tempdirectory --value "$UPLOADTMPDIR"
  sed -i "s|^;\?upload_tmp_dir =.*$|upload_tmp_dir = $UPLOADTMPDIR|" "/etc/php/${PHP_VERSION}/cli/php.ini"
  sed -i "s|^;\?upload_tmp_dir =.*$|upload_tmp_dir = $UPLOADTMPDIR|" "/etc/php/${PHP_VERSION}/fpm/php.ini"
  sed -i "s|^;\?sys_temp_dir =.*$|sys_temp_dir = $UPLOADTMPDIR|"     "/etc/php/${PHP_VERSION}/fpm/php.ini"

  # 4 Byte UTF8 support
  ncc config:system:set mysql.utf8mb4 --type boolean --value="true"

  ncc config:system:set trusted_domains 7 --value="nextcloudpi"
  ncc config:system:set trusted_domains 5 --value="nextcloudpi.local"
  ncc config:system:set trusted_domains 8 --value="nextcloudpi.lan"
  ncc config:system:set trusted_domains 3 --value="nextcloudpi.lan"

  # email
  ncc config:system:set mail_smtpmode     --value="sendmail"
  ncc config:system:set mail_smtpauthtype --value="LOGIN"
  ncc config:system:set mail_from_address --value="admin"
  ncc config:system:set mail_domain       --value="nextcloudpi.com"

  # NCP theme
  [[ -e /usr/local/etc/logo ]] && {
    ID="$(grep 'instanceid' config/config.php | awk -F "=> " '{print $2}' | sed "s|[,']||g" )"
    [[ "$ID" == "" ]] && {
      log 2 "Failed to get ID"
      return 1
    }
    mkdir --parents                      "data/appdata_${ID}/theming/images"
    cp '/usr/local/etc/background'       "data/appdata_${ID}/theming/images"
    cp '/usr/local/etc/logo'             "data/appdata_${ID}/theming/images/logo"
    cp '/usr/local/etc/logo'             "data/appdata_${ID}/theming/images/logoheader"
    chown -R "${HTTP_USER}:${HTTP_USER}" "data/appdata_${ID}"
  }

  mysql nextcloud <<EOF
replace into  oc_appconfig values ( 'theming', 'name'          , "NextcloudPi"             );
replace into  oc_appconfig values ( 'theming', 'slogan'        , "keep your data close"    );
replace into  oc_appconfig values ( 'theming', 'url'           , "https://nextcloudpi.com" );
replace into  oc_appconfig values ( 'theming', 'logoMime'      , "image/svg+xml"           );
replace into  oc_appconfig values ( 'theming', 'backgroundMime', "image/png"               );
EOF

  # NCP app
  cp -r /var/www/ncp-app "${NEXTCLOUD_DIRECTORY}/apps/nextcloudpi"
  chown -R "$HTTP_USER": "${NEXTCLOUD_DIRECTORY}/apps/nextcloudpi"
  ncc app:enable nextcloudpi
  # Enable some apps by default
  ncc app:install calendar
  ncc app:install contacts
  ncc app:install notes
  ncc app:install tasks
  # We handle this ourselves
  ncc app:disable updatenotification

  # News dropped support for 32-bit -> https://github.com/nextcloud/news/issues/1423
  if ! [[ "$ARCH" == "armv7" ]]; then
    ncc app:install news
  fi

  # ncp-previewgenerator
  NCVER="$(ncc status 2>/dev/null | grep "version:" | awk '{print $3}')"
  if is_more_recent_than "21.0.0" "$NCVER"; then
    NCPREV='/var/www/ncp-previewgenerator/ncp-previewgenerator-nc20'
  else
    ncc app:install notify_push
    [[ -f /.ncp-image ]] || startNotifyPush # don't start during build
    NCPREV='/var/www/ncp-previewgenerator/ncp-previewgenerator-nc21'
  fi
  ln -snf "$NCPREV" /var/www/nextcloud/apps/previewgenerator
  chown -R "$HTTP_USER": /var/www/nextcloud/apps/previewgenerator
  ncc app:enable previewgenerator

  # previews
  ncc config:app:set previewgenerator squareSizes --value="32 256"
  ncc config:app:set previewgenerator widthSizes  --value="256 384"
  ncc config:app:set previewgenerator heightSizes --value="256"
  ncc config:system:set preview_max_x --value 2048
  ncc config:system:set preview_max_y --value 2048
  ncc config:system:set jpeg_quality --value 60
  ncc config:app:set preview jpeg_quality --value="60"

  # other
  ncc config:system:set overwriteprotocol --value='https'
  ncc config:system:set overwrite.cli.url --value="https://nextcloudpi/"

  # bash completion for ncc
  installPKG bash-completion
  ncc _completion -g --shell-type bash -p ncc | sed 's|/var/www/nextcloud/occ|ncc|g' > /usr/share/bash-completion/completions/ncp
  echo ". /etc/bash_completion" >> /etc/bash.bashrc
  echo ". /usr/share/bash-completion/completions/ncp" >> /etc/bash.bashrc

  # TODO temporary workaround for https://github.com/nextcloud/server/pull/13358
  ncc -n db:convert-filecache-bigint
  ncc db:add-missing-indices

  # Default trusted domain (only from ncp-config)
  [[ -f /usr/local/bin/nextcloud-domain.sh ]] && {
    [[ -f /.ncp-image ]] || bash /usr/local/bin/nextcloud-domain.sh
  }

  # dettach mysql during the build
  if [[ "$DB_PID" != "" ]]; then
    log -1 "Shutting down MariaDB ( $DB_PID )"
    mysqladmin -u root shutdown
    wait "$DB_PID"
  fi

  log 0 "Nextcloud init is done"
}

function install { :; }

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
