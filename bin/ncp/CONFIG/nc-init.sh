#!/usr/bin/env bash

# Init NextCloud database and perform initial configuration
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://ownyourbits.com/2017/02/13/nextcloud-ready-raspberry-pi-image/
#

# print_lines a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function print_line {
    printf '%s\n' "$@"
}

DBADMIN='ncadmin'

function configure {
    local DBPASSWD REDISPASS UPLOADTMPDIR='/var/www/nextcloud/data/tmp' \
          ID NCVER NCPREV
    print_line "Setting up: Nextcloud"
    print_line "Wait until you see the message: NC init done"
    
    # checks
    REDISPASS="$( grep "^requirepass" /etc/redis/redis.conf  | cut -d' ' -f2 )"
    if [[ -z "$REDISPASS" ]]
    then print_line "Redis server is without a password"; return 1
    fi
    
    ## RE-CREATE DATABASE TABLE
    
    print_line "Setting up: Database"
    
    # launch mariadb if not already running
    if [[ ! -f '/run/mysqld/mysqld.pid' ]]
    then print_line "Starting MariaDB"
         mysqld &
         local db_pid="$!"
    fi
    
    # wait for mariadb
    while :
    do [[ -S '/run/mysqld/mysqld.sock' ]] && break
       sleep 1
    done
    sleep 1
    
    # workaround to emulate DROP USER IF EXISTS ..;)
    DBPASSWD="$( grep 'password' '/root/.my.cnf' | sed 's|password=||' )"
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
    if ! pgrep -c redis-server &>/dev/null
    then mkdir --parents '/var/run/redis'
         chown 'redis'   '/var/run/redis'
         # TODO: Add hostname to stop sudo error: unable to resolve host
         sudo -u redis redis-server '/etc/redis/redis.conf' &
    fi
    
    while :
    do [[ -S '/run/redis/redis.sock' ]] && break
       sleep 1
    done
    
    
    print_line "Setting up: Nextcloud"
    if [[ -d '/var/www/nextcloud/' ]]
    then cd '/var/www/nextcloud/' || print_line "Failed to change directory to: /var/www/nextcloud/"
    fi

    if [[ -f 'config/config.php' ]]
    then if ! rm --force 'config/config.php'
         then print_line "Failed to remove file: config/config.php"; exit 1
         fi
    fi
    ncc maintenance:install --database 'mysql' \
                            --database-name 'nextcloud'  \
                            --database-user "$DBADMIN" \
                            --database-pass "$DBPASSWD" \
                            --admin-user "$ADMINUSER" \
                            --admin-pass "$ADMINPASS"
    
    # cron jobs
    ncc background:cron
    
    # redis cache
    sed -i '$d' 'config/config.php'
    cat >> 'config/config.php' <<EOF
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' =>
  array (
    'host' => '/var/run/redis/redis.sock',
    'port' => 0,
    'timeout' => 0.0,
    'password' => '$REDISPASS',
  ),
);
EOF

    mkdir --parents "$UPLOADTMPDIR"
    chown 'www-data':'www-data' "$UPLOADTMPDIR"
    ncc config:system:set tempdirectory --value "$UPLOADTMPDIR"
    sed -i "s|^;\?upload_tmp_dir =.*$|upload_tmp_dir = $UPLOADTMPDIR|" /etc/php/"$PHPVER"/cli/php.ini
    sed -i "s|^;\?upload_tmp_dir =.*$|upload_tmp_dir = $UPLOADTMPDIR|" /etc/php/"$PHPVER"/fpm/php.ini
    sed -i "s|^;\?sys_temp_dir =.*$|sys_temp_dir = $UPLOADTMPDIR|"     /etc/php/"$PHPVER"/fpm/php.ini
    
    # 4 Byte UTF8 support
    ncc config:system:set mysql.utf8mb4 --type boolean --value='true'
    
    ncc config:system:set trusted_domains 7 --value='nextcloudpi'
    ncc config:system:set trusted_domains 5 --value='nextcloudpi.local'
    ncc config:system:set trusted_domains 8 --value='nextcloudpi.lan'
    ncc config:system:set trusted_domains 3 --value='nextcloudpi.lan'
    
    # email
    ncc config:system:set mail_smtpmode     --value='sendmail'
    ncc config:system:set mail_smtpauthtype --value='LOGIN'
    ncc config:system:set mail_from_address --value='admin'
    ncc config:system:set mail_domain       --value='nextcloudpi.com'
    
    # NCP theme
    [[ -e '/usr/local/etc/logo' ]] && {
        ID="$( grep 'instanceid' 'config/config.php' | awk -F "=> " '{ print $2 }' | sed "s|[,']||g" )"

        [[ -z "$ID" ]] || print_line "Failed to get ID"; return 1
        
        mkdir --parents                data/appdata_"$ID"/theming/images
        cp '/usr/local/etc/background' data/appdata_"$ID"/theming/images
        cp '/usr/local/etc/logo'       data/appdata_"$ID"/theming/images/logo
        cp '/usr/local/etc/logo'       data/appdata_"$ID"/theming/images/logoheader
        chown -R 'www-data':'www-data' data/appdata_"$ID"
    }
    
    mysql nextcloud <<EOF
replace into  oc_appconfig values ( 'theming', 'name'          , "NextcloudPi"             );
replace into  oc_appconfig values ( 'theming', 'slogan'        , "Keep your data close"    );
replace into  oc_appconfig values ( 'theming', 'url'           , "https://nextcloudpi.com" );
replace into  oc_appconfig values ( 'theming', 'logoMime'      , "image/svg+xml"           );
replace into  oc_appconfig values ( 'theming', 'backgroundMime', "image/png"               );
EOF

    # NCP app
    cp --recursive '/var/www/ncp-app' '/var/www/nextcloud/apps/nextcloudpi'
    chown -R 'www-data':              '/var/www/nextcloud/apps/nextcloudpi'
    ncc app:enable nextcloudpi
    
    # Install some default apps, will be enabled by installation
    ncc app:install calendar
    ncc app:install contacts
    ncc app:install notes
    ncc app:install tasks
    
    # we handle this ourselves
    ncc app:disable updatenotification
    
    # News dropped support for 32-bit -> https://github.com/nextcloud/news/issues/1423
    if ! [[ "$ARCH" =~ armv7 ]]
    then ncc app:install news
         # ncc app:enable  news
    fi
    
    # ncp-previewgenerator
    NCVER="$(ncc status 2>/dev/null | grep 'version:' | awk '{ print $3 }')"
    if is_more_recent_than '21.0.0' "$NCVER"
    then NCPREV='/var/www/ncp-previewgenerator/ncp-previewgenerator-nc20'
    else ncc app:install notify_push
         ncc app:enable  notify_push
         [[ -f '/.ncp-image' ]] || start_notify_push # don't start during build
         NCPREV='/var/www/ncp-previewgenerator/ncp-previewgenerator-nc21'
    fi
    ln -snf "$NCPREV"    '/var/www/nextcloud/apps/previewgenerator'
    chown -R 'www-data': '/var/www/nextcloud/apps/previewgenerator'
    ncc app:enable previewgenerator
    
    # Preview generator
    ncc config:app:set previewgenerator squareSizes --value='32 256'
    ncc config:app:set previewgenerator widthSizes  --value='256 384'
    ncc config:app:set previewgenerator heightSizes --value='256'
    ncc config:system:set preview_max_x             --value 2048
    ncc config:system:set preview_max_y             --value 2048
    ncc config:system:set jpeg_quality              --value 60
    ncc config:app:set preview jpeg_quality         --value='60'
    # Other
    ncc config:system:set overwriteprotocol         --value='https'
    ncc config:system:set overwrite.cli.url         --value='https://nextcloudpi/'
    
    # Bash completion for ncc
    apt_install bash-completion
    ncc _completion -g --shell-type bash -p ncc | sed 's|/var/www/nextcloud/occ|ncc|g' > '/usr/share/bash-completion/completions/ncp'
    print_line ". /etc/bash_completion" >> '/etc/bash.bashrc'
    print_line ". /usr/share/bash-completion/completions/ncp" >> '/etc/bash.bashrc'
    
    # TODO temporary workaround for https://github.com/nextcloud/server/pull/13358
    ncc -n db:convert-filecache-bigint
    ncc db:add-missing-indices
    
    # Default trusted domain (only from ncp-config)
    if [[ -f '/usr/local/bin/nextcloud-domain.sh' ]]
    then [[ -f '/.ncp-image' ]] || bash '/usr/local/bin/nextcloud-domain.sh'
    fi
    
    # dettach mysql during the build
    if [[ "$db_pid" != "" ]]
    then print_line "Shutting down MariaDB ($db_pid)"
         mysqladmin -u root shutdown
         wait "$db_pid"
    fi
    print_line "NC init done"
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
