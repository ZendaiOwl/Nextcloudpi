#!/usr/bin/env bash

# FreeDNS updater client installation on Raspbian 
#
# Copyleft 2017 by Panteleimon Sarantos <pantelis.fedora _a_t_ gmail _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#

# printlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

function install {
    local -r ARGS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    apt-get update  "${ARGS[@]}"
    apt-get install "${ARGS[@]}" dnsutils
}

function configure {
    local UPDATEURL='https://freedns.afraid.org/dynamic/update.php'
    local URL="${UPDATEURL}?${UPDATEHASH}"
    
    [[ "$ACTIVE" != "yes" ]] && {
        rm --force '/etc/cron.d/freeDNS'
        service cron restart
        println "Disabled: FreeDNS client"
        return 0
    }
    
    cat > '/usr/local/bin/freedns.sh' <<EOF
#!/usr/bin/env bash
# printlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function println () {
    printf '%s\n' "$@"
}
println "Started: FreeDNS client"
println "$URL"
REGISTERED_IP=\$(dig +short "$DOMAIN"|tail -n1)
CURRENT_IP=\$(wget -q -O - http://checkip.dyndns.org|sed s/[^0-9.]//g)
    [[ "\$CURRENT_IP" != "\$REGISTERED_IP" ]] && {
        wget -q -O /dev/null $URL
    }
println "Registered IP: \$REGISTERED_IP | Current IP: \$CURRENT_IP"
EOF
    chmod +744 '/usr/local/bin/freedns.sh'
    
    echo "*/$UPDATEINTERVAL  *  *  *  *  root  /bin/bash /usr/local/bin/freedns.sh" > '/etc/cron.d/freeDNS'
    chmod 644 '/etc/cron.d/freeDNS'
    service cron restart
    
    set_nc_domain "$DOMAIN"
    
    println "Enabled: FreeDNS client"
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
