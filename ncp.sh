#!/usr/bin/env bash

# NextcloudPi additions to Raspbian
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at https://nextcloudpi.com
#

# Checks if a given path is a regular file
# 0: Is a file
# 1: Not a file
# 2: Invalid number of arguments
function isFile {
    [[ "$#" -ne 1 ]] && return 2
    [[ -f "$1" ]]
}

# Checks if a user exists
# Return codes
# 0: Is a user
# 1: Not a user
# 2: Invalid number of arguments
function isUser {
    [[ "$#" -ne 1 ]] && return 2
    if id -u "$1" &>/dev/null
    then return 0
    else return 1
    fi
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

function is_docker {
    isFile /.dockerenv || isFile /.docker-image || isEqual "$DOCKERBUILD" 1
}

function is_lxc {
    grep -q container=lxc /proc/1/environ &>/dev/null
}

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

#########################

if isFile 'etc/library.sh'
then LIBRARY='etc/library.sh'
elif isFile '/usr/local/etc/library.sh'
then LIBRARY='/usr/local/etc/library.sh'
else log 2 "File not found: library.sh"; return 1
fi

# shellcheck disable=SC1090
source "$LIBRARY"

WEBADMIN='ncp'
WEBPASSWD='ownyourbits'
BINDIR='/usr/local/bin/ncp'
CONFDIR='/usr/local/etc/ncp-config.d'
BRANCH="${BRANCH:-master}"

function install {
    local -r NCC_SCRIPTFILE='/usr/local/bin/ncc' \
             ACTIVATION_CONFIG='/etc/apache2/sites-available/ncp-activation.conf' \
             NCP_CONFIG='/etc/apache2/sites-available/ncp.conf' \
             RASPI_CONFIG='/usr/bin/raspi-config' \
             NOLOGIN_SHELL='/usr/sbin/nologin' \
             HTTP_USER='www-data' \
             HOME_HTTP_USER='/home/www'
    
    local NCP_LAUNCHER="${HOME_HTTP_USER}/ncp-launcher.sh" \
          BACKUP_LAUNCHER="${HOME_HTTP_USER}/ncp-backup-launcher.sh"
    # NCP-CONFIG
    installPKG git dialog whiptail jq file lsb-release
    mkdir --parents "$CONFDIR" "$BINDIR"
    
    # This has changed, pi user no longer exists by default, the user needs to create it with Raspberry Pi imager
    # The raspi-config layout and options have also changed
    # https://github.com/RPi-Distro/raspi-config/blob/master/raspi-config
    if isFile "$RASPI_CONFIG"
    then # shellcheck disable=SC1003
        sed -i '/S3 Password/i "S0 NextcloudPi Configuration" "Configuration of NextcloudPi" \\' "$RASPI_CONFIG"
        sed -i '/S3\\ \*) do_change_pass ;;/i S0\\ *) ncp-config ;;'                             "$RASPI_CONFIG"
    fi
    
    # Add 'ncc' script shortcut
    cat > "$NCC_SCRIPTFILE" <<'EOF'
#!/usr/bin/env bash
SUDO=(sudo -E -u www-data)
"${SUDO[@]}" php /var/www/nextcloud/occ "$@"
EOF

    chmod +x "$NCC_SCRIPTFILE"
    
    # NCP-WEB
    ## Apache2 VirtualHost
    cat > "$ACTIVATION_CONFIG" <<EOF
<VirtualHost _default_:443>
  DocumentRoot /var/www/ncp-web/
  SSLEngine on
  SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem
  SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

</VirtualHost>
<Directory /var/www/ncp-web/>
  <RequireAll>

   <RequireAny>
      Require host localhost
      Require local
      Require ip 192.168
      Require ip 172
      Require ip 10
      Require ip fe80::/10
      Require ip fd00::/8
   </RequireAny>

  </RequireAll>
</Directory>
EOF

    cat > "$NCP_CONFIG" <<EOF
Listen 4443
<VirtualHost _default_:4443>
  DocumentRoot /var/www/ncp-web
  SSLEngine on
  SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem
  SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
  <IfModule mod_headers.c>
    Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains"
  </IfModule>

  # 2 days to avoid very big backups requests to timeout
  TimeOut 172800

  <IfModule mod_authnz_external.c>
    DefineExternalAuth pwauth pipe /usr/sbin/pwauth
  </IfModule>

</VirtualHost>
<Directory /var/www/ncp-web/>

  AuthType Basic
  AuthName "ncp-web login"
  AuthBasicProvider external
  AuthExternal pwauth

  SetEnvIf Request_URI "^" noauth
  SetEnvIf Request_URI "^index\.php$" !noauth
  SetEnvIf Request_URI "^/$" !noauth
  SetEnvIf Request_URI "^/wizard/index.php$" !noauth
  SetEnvIf Request_URI "^/wizard/$" !noauth

  <RequireAll>

   <RequireAny>
      Require host localhost
      Require local
      Require ip 192.168
      Require ip 172
      Require ip 10
      Require ip fe80::/10
      Require ip fd00::/8
   </RequireAny>

   <RequireAny>
      Require env noauth
      Require user $WEBADMIN
   </RequireAny>

  </RequireAll>

</Directory>
EOF

    installPKG libapache2-mod-authnz-external pwauth
    a2enmod authnz_external \
            authn_core \
            auth_basic
    a2dissite nextcloud
    a2ensite ncp-activation
    
    ## NCP USER FOR AUTHENTICATION
    if ! isUser "$WEBADMIN"
    then useradd --home-dir /nonexistent "$WEBADMIN"
    fi
    Print "$WEBPASSWD" "$WEBPASSWD" | passwd "$WEBADMIN"
    chsh -s "$NOLOGIN_SHELL" "$WEBADMIN"
    chsh -s "$NOLOGIN_SHELL" root
    
    ## NCP LAUNCHER
    mkdir --parents "$HOME_HTTP_USER"
    chown "$HTTP_USER":"$HTTP_USER" "$HOME_HTTP_USER"
    chmod 700 "$HOME_HTTP_USER"
    
    cat > /home/www/ncp-launcher.sh <<'EOF'
#!/usr/bin/env bash
grep -q '[\\&#;`|*?~<>^()[{}$&[:space:]]' <<< "$*" && exit 1
source /usr/local/etc/library.sh
run_app "$1"
EOF
  chmod 700 "$NCP_LAUNCHER"

  cat > "$BACKUP_LAUNCHER" <<'EOF'
#!/usr/bin/env bash
ACTION="${1}"
FILE="${2}"
COMPRESSED="${3}"
grep -q '[\\&#;`|*?~<>^()[{}$&]' <<< "$*" && exit 1
[[ "$FILE" =~ ".." ]] && exit 1
[[ "$ACTION" == "chksnp" ]] && {
  btrfs subvolume show "$FILE" &>/dev/null || exit 1
  exit
}
[[ "$ACTION" == "delsnp" ]] && {
  btrfs subvolume delete "$FILE" || exit 1
  exit
}
[[ -f "$FILE" ]] || exit 1
[[ "$FILE" =~ ".tar" ]] || exit 1
[[ "$ACTION" == "del" ]] && {
  [[ "$(file "$FILE")" =~ "tar archive" ]] || [[ "$(file "$FILE")" =~ "gzip compressed data" ]] || exit 1
  rm "$FILE" || exit 1
  exit
}
[[ "$COMPRESSED" != "" ]] && PIGZ="-I pigz"
tar $PIGZ -tf "$FILE" data &>/dev/null
EOF
  chmod 700 "$BACKUP_LAUNCHER"
  Print "www-data ALL = NOPASSWD: /home/www/ncp-launcher.sh , /home/www/ncp-backup-launcher.sh, /sbin/halt, /sbin/reboot" > /etc/sudoers.d/www-data

  # NCP AUTO TRUSTED DOMAIN
  mkdir --parents /usr/lib/systemd/system
  cat > /usr/lib/systemd/system/nextcloud-domain.service <<'EOF'
[Unit]
Description=Register Current IP as Nextcloud trusted domain
Requires=network.target
After=mysql.service redis.service

[Service]
ExecStart=/bin/bash /usr/local/bin/nextcloud-domain.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  [[ "$DOCKERBUILD" != 1 ]] && systemctl enable nextcloud-domain

  # NEXTCLOUDPI UPDATES
  cat > /etc/cron.daily/ncp-check-version <<EOF
#!/bin/sh
/usr/local/bin/ncp-check-version
EOF
  chmod a+x /etc/cron.daily/ncp-check-version
  touch               /var/run/.ncp-latest-version
  chown root:www-data /var/run/.ncp-latest-version
  chmod g+w           /var/run/.ncp-latest-version

  # Install all ncp-apps
  ALLOW_UPDATE_SCRIPT=1 bin/ncp-update "$BRANCH" || exit "$?"

  # LIMIT LOG SIZE
  grep -q maxsize /etc/logrotate.d/apache2 || sed -i /weekly/amaxsize2M /etc/logrotate.d/apache2
  cat > /etc/logrotate.d/ncp <<'EOF'
/var/log/ncp.log
{
        rotate 4
        size 500K
        missingok
        notifempty
        compress
}
EOF
  chmod 0444 /etc/logrotate.d/ncp

  # ONLY FOR IMAGE BUILDS
  # If-statement closes at the end of the install function()
  if isFile '/.ncp-image'
  then rm --recursive --force /var/log/ncp.log
       ## NEXTCLOUDPI MOTD
       rm --recursive --force /etc/update-motd.d
       mkdir /etc/update-motd.d
       rm /etc/motd
       ln -s /var/run/motd /etc/motd
       cat > /etc/update-motd.d/10logo <<EOF
#!/bin/sh
echo
cat /usr/local/etc/ncp-ascii.txt
EOF
       cat > /etc/update-motd.d/20updates <<'EOF'
#!/usr/bin/env bash
/usr/local/bin/ncp-check-updates
EOF
       chmod a+x /etc/update-motd.d/*

       ## HOSTNAME AND mDNS
       if ! isFile '/.docker-image'
       then installPKG avahi-daemon
            sed -i '/^127.0.1.1/d'                        /etc/hosts
            sed -i "\$a127.0.1.1 nextcloudpi $(hostname)" /etc/hosts
       fi
       Print 'nextcloudpi' > /etc/hostname
       
       ## tag image
       is_docker && local DOCKER_TAG="_docker"
       is_lxc && local DOCKER_TAG="_lxc"
       Print "NextcloudPi${DOCKER_TAG}_$( date  "+%m-%d-%y" )" > /usr/local/etc/ncp-baseimage
       
       ## SSH hardening
       if [[ -f /etc/ssh/sshd_config ]]
       then sed -i 's|^#AllowTcpForwarding .*|AllowTcpForwarding no|'     /etc/ssh/sshd_config
            sed -i 's|^#ClientAliveCountMax .*|ClientAliveCountMax 2|'    /etc/ssh/sshd_config
            sed -i 's|^MaxAuthTries .*|MaxAuthTries 1|'                   /etc/ssh/sshd_config
            sed -i 's|^#MaxSessions .*|MaxSessions 2|'                    /etc/ssh/sshd_config
            sed -i 's|^#TCPKeepAlive .*|TCPKeepAlive no|'                 /etc/ssh/sshd_config
            sed -i 's|^X11Forwarding .*|X11Forwarding no|'                /etc/ssh/sshd_config
            sed -i 's|^#LogLevel .*|LogLevel VERBOSE|'                    /etc/ssh/sshd_config
            sed -i 's|^#Compression .*|Compression no|'                   /etc/ssh/sshd_config
            sed -i 's|^#AllowAgentForwarding .*|AllowAgentForwarding no|' /etc/ssh/sshd_config
       fi
       
       ## kernel hardening
       cat >> /etc/sysctl.conf <<EOF
fs.protected_hardlinks=1
fs.protected_symlinks=1
kernel.core_uses_pid=1
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.sysrq=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.log_martians=1
net.ipv4.tcp_timestamps=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
EOF

       ## other tweaks
       sed -i "s|^UMASK.*|UMASK           027|" /etc/login.defs
  fi
}

function configure { :; }


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
