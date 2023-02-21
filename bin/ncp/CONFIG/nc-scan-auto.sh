#!/usr/bin/env bash

# Periodically synchronize NextCloud for externally modified files
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at: https://ownyourbits.com
#

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

function configure {
    [[ "$ACTIVE" != "yes" ]] && {
        rm --force '/etc/cron.d/ncp-scan-auto'
        service cron restart
        println "Automatic scans disabled"
        return 0
    }

    # set crontab
    local DAYS HOUR MINS RECURSIVE NON_EXTERNAL
    DAYS="$(( "$SCANINTERVAL" / 1440 ))"
    if [[ "$DAYS" != "0" ]]
    then DAYS="*/$DAYS" HOUR="1" MINS="15"
    else DAYS="*"
         HOUR="$(( "$SCANINTERVAL" / 60 ))"
         MINS="$(( "$SCANINTERVAL" % 60 ))"
         MINS="*/$MINS"
         if [[ "$HOUR" == "0" ]]
         then HOUR="*"
         else HOUR="*/$HOUR"
              MINS="15"
         fi
    
    [[ "$RECURSIVE"   == "no"  ]] && RECURSIVE='--shallow'
    # shellcheck disable=SC2153
    [[ "$NONEXTERNAL" == "yes" ]] && NON_EXTERNAL='--home-only'
    
    cat > '/usr/local/bin/ncp-scan-auto' <<EOF
#!/usr/bin/env bash
(

  echo -e "\n[ nc-scan-auto ]"

  [[ "$PATH1" != "" ]] && /usr/local/bin/ncc files:scan $RECURSIVE $NON_EXTERNAL -n -p "$PATH1"
  [[ "$PATH2" != "" ]] && /usr/local/bin/ncc files:scan $RECURSIVE $NON_EXTERNAL -n -p "$PATH2"
  [[ "$PATH3" != "" ]] && /usr/local/bin/ncc files:scan $RECURSIVE $NON_EXTERNAL -n -p "$PATH3"

  [[ "${PATH1}${PATH2}${PATH3}" == "" ]] && /usr/local/bin/ncc files:scan $RECURSIVE $NON_EXTERNAL -n --all

) 2>&1 >>/var/log/ncp.log
EOF
chmod +x '/usr/local/bin/ncp-scan-auto'

    echo "$MINS  $HOUR  $DAYS  *  *  root /usr/local/bin/ncp-scan-auto" > '/etc/cron.d/ncp-scan-auto'
    chmod 644 '/etc/cron.d/ncp-scan-auto'
    service cron restart
    
    println "Automatic scans enabled"
fi
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

