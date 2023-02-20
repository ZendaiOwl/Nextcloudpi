#!/usr/bin/env bash

# DuckDNS installation on Raspbian for NextcloudPi
#
#
# Copyleft 2017 by Courtney Hicks
# GPL licensed (see end of file) * Use at your own risk!
#

# prtlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function prtln () {
    printf '%s\n' "$@"
}

INSTALLDIR='duckdns'
INSTALLPATH="/usr/local/etc/$INSTALLDIR"
CRONFILE='/etc/cron.d/duckdns'

function configure () {
    local DOMAIN SUCCESS
    DOMAIN="${DOMAIN//.duckdns.org/}"
    #DOMAIN="$( sed 's|.duckdns.org||' <<<"$DOMAIN" )"
    if [[ "$ACTIVE" == "yes" ]]
    then mkdir --parents "$INSTALLPATH"
    
         # Creates duck.sh script that checks for updates to DNS records
         if ! touch "$INSTALLPATH"/duck.sh
         then prtln "Failed to create file: $INSTALLPATH/duck.sh"; return 1
         fi
         if ! touch "$INSTALLPATH"/duck.log
         then prtln "Failed to create file: $INSTALLPATH/duck.log"; return 1
         fi
         
         echo -e "echo url=\"https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=\" | curl -k -o ${INSTALLPATH}/duck.log -K -" > "$INSTALLPATH"/duck.sh
         
         # Adds file to cron to run script for DNS record updates and change permissions
         if ! touch "$CRONFILE"
         then prtln "Failed to create file: $CRONFILE"; return 1
         fi
         
         echo "*/5 * * * * root $INSTALLPATH/duck.sh >/dev/null 2>&1" > "$CRONFILE"
         chmod 700 "$INSTALLPATH"/duck.sh
         chmod 644 "$CRONFILE"
         
         # First-time execution of duck script
         "$INSTALLPATH"/duck.sh > /dev/null 2>&1
         SUCCESS="$( cat "$INSTALLPATH"/duck.log )"
         
         # Checks for successful run of duck.sh
         if [[ "$SUCCESS" == "OK" ]]
         then prtln "DuckDNS is enabled"
         elif [[ "$SUCCESS" == "KO" ]]
         then prtln "Failed to install DuckDNS, is your information correct?"
         fi
         
    elif [[ "$ACTIVE" == "no" ]]
    then rm --force "$CRONFILE"
         rm --force "$INSTALLPATH"/duck.sh
         rm --force "$INSTALLPATH"/duck.log
         rmdir "$INSTALLPATH"
         prtln "Disabled: DuckDNS"
    fi
}

function install () { :; }

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
