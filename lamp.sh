#!/usr/bin/env bash
# A log function that uses log levels for logging different outputs
# Log levels
# -2: Debug
# -1: Info
#  0: Success
#  1: Warning
#  2: Error
function log() {
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
function isRoot() {
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
function hasCMD() {
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

function install() {
  local OPTIONS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends) \
        APTUPDATE=(apt-get "${OPTIONS[@]}" update) \
        APTINSTALL=(apt-get "${OPTIONS[@]}" install) \
        PACKAGES=(apt-utils cron curl ssl-cert apache2 mariadb-server) \
        GROUP_OPTIONS=(--quiet --system) \
        USER_OPTIONS=(--quiet --uid 180 --system --group --no-create-home --home /run/systemd --gecos "systemd Network Management") \
        DBPASSWD="default" \
        MARIADB_CNF='/root/.my.cnf' \
        RUN_LOCK='/run/lock' \
        RUN_PHP='/run/php' \
        RUN_MYSQLD='/run/mysqld' \
        APACHE2_CONF='/etc/apache2/apache2.conf' \
        MYSQLD_PID='/run/mysqld/mysqld.pid' \
        MYSQLD_SOCK='/run/mysqld/mysqld.sock'

  set -x
  if hasCMD wget
  then
    # Sury's PHP Repository
    #######################
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ ${RELEASE%-security} main" > /etc/apt/sources.list.d/php.list
    DEBIAN_FRONTEND=noninteractive "${APTUPDATE[@]}"
  else
    log 2 "Missing command: wget"
    exit 1
  fi

  # Packages Installation
  #######################
  DEBIAN_FRONTEND=noninteractive "${APTINSTALL[@]}" "${PACKAGES[@]}"

  mkdir --parents "$RUN_LOCK"

  apache2ctl -V || true

  if ! id --user systemd-resolve
  then
    addgroup "${GROUP_OPTIONS[@]}" systemd-journal
    adduser  "${USER_OPTIONS[@]}"  systemd-resolve
  fi
  
  installWithShadowWorkaround systemd

  # PHP Installation
  ##################
  DEBIAN_FRONTEND=noninteractive "${APTINSTALL[@]}" --target-release "$RELEASE" \
  php"$PHP_VERSION" php"$PHP_VERSION"-{curl,gd,fpm,cli,opcache,mbstring,xml,zip,fileinfo,ldap,intl,bz2,mysql}

  mkdir --parents "$RUN_PHP"

  # MariaDB Password
  ##################
  echo -e "[client]\npassword=$DBPASSWD" > "$MARIADB_CNF"
  chmod 600                                "$MARIADB_CNF"

  debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password password $DBPASSWD"
  debconf-set-selections <<< "mariadb-server-10.5 mysql-server/root_password_again password $DBPASSWD"
  
  mkdir --parents "$RUN_MYSQLD"
  chown mysql     "$RUN_MYSQLD"

  # Apache Configuration
  ######################
  installTemplate apache2/http2.conf.sh /etc/apache2/conf-available/http2.conf --defaults

  # PHP Configuration
  ###################
  installTemplate "php/opcache.ini.sh" "/etc/php/${PHP_VERSION}/mods-available/opcache.ini" --defaults
  
  a2enmod http2
  a2enconf http2
  
  a2enmod proxy_fcgi setenvif
  a2enconf php"$PHP_VERSION"-fpm
  
  a2enmod rewrite headers dir mime ssl

  echo "ServerName localhost" >> "$APACHE2_CONF"
  
  # Lamp Configuration
  ####################
  installTemplate "mysql/90-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/90-ncp.cnf" --defaults
  installTemplate "mysql/91-ncp.cnf.sh" "/etc/mysql/mariadb.conf.d/91-ncp.cnf" --defaults

  if [[ ! -f "$MYSQLD_PID" ]]
  then
    log -1 "Starting MariaDB"
    mysqld &
  fi

  log -1 "Waiting for MariaDB to start"
  while :
  do
    # True if file exists and is socket
    [[ -S "$MYSQLD_SOCK" ]] && break
    sleep 0.5
  done
  log 0 "MariaDB started"

  cd /tmp
  mysql_secure_installation <<EOF
$DBPASSWD
y
$DBPASSWD
$DBPASSWD
y
y
y
y
EOF
log 0 "Lamp installation complete"
}

function configure() { :; }
