#!/usr/bin/env bash

# dnsmasq DNS server with cache installation on Raspbian
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at: https://ownyourbits.com/2017/03/09/dnsmasq-as-dns-cache-server-for-nextcloudpi-and-raspbian/
#

# prtlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function prtln () {
    printf '%s\n' "$@"
}

function install () {
    local -r ARGS=(--quiet --assume-yes --no-show-upgraded --auto-remove=true --no-install-recommends)
    local RC
    set -x
    apt-get update  "${ARGS[@]}"
    apt-get install "${ARGS[@]}" dnsmasq
    RC=0
    service dnsmasq status > /dev/null 2>&1 || RC="$?"
    if ! is_docker \
    && [[ "$RC" -eq 3 ]] \
    && [[ ! "$INIT_SYSTEM" =~ ^("chroot"|"unknown")$ ]]
    then {
            prtln "Applying workaround for dnsmasq bug (compare issue #1446)"
            service systemd-resolved stop || true
            service dnsmasq start
            service dnsmasq status
         }
    fi
    service dnsmasq stop
    if [[ "$INIT_SYSTEM" == "systemd" ]]
    then service systemd-resolved start
    else true
    fi
    update-rc.d dnsmasq disable || rm '/etc/systemd/system/multi-user.target.wants/dnsmasq.service'
    
    [[ "$DOCKERBUILD" == 1 ]] && {
        cat > /etc/services-available.d/100dnsmasq <<EOF
#!/usr/bin/env bash

source /usr/local/etc/library.sh

# prtlns a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function prtln () {
    printf '%s\n' "$@"
}

[[ "\$1" == "stop" ]] && {
    prtln "Stopping: dnsmasq"
    service dnsmasq stop
    exit 0
}

persistent_cfg '/etc/dnsmasq.conf'

prtln "Starting: dnsmasq"
service dnsmasq start

exit 0
EOF
        chmod +x '/etc/services-available.d/100dnsmasq'
    }
    return 0
}

function configure () {
    if [[ "$ACTIVE" != "yes" ]]
    then service dnsmasq stop
         update-rc.d dnsmasq disable
         prtln "Disabled: dnmasq"
         return
    fi
    
    local IFACE IP
    IFACE="$( ip r | grep "default via"   | awk '{ print $5 }' | head -1 )"
    IP="$( ncc config:system:get trusted_domains 6 | grep -oP '\d{1,3}(.\d{1,3}){3}' )"
    if [[ "$IP" == "" ]]
    then IP="$(get_ip)"
    fi
    
    if [[ "$IP" == "" ]]
    then prtln "Failed to detect IP-address"
         return 1
    fi
    
    cat > '/etc/dnsmasq.conf' <<EOF
interface=$IFACE
domain-needed         # Never forward plain names (without a dot or domain part)
bogus-priv            # Never forward addresses in the non-routed address spaces.
no-poll               # Don't poll for changes in /etc/resolv.conf
no-resolv             # Don't use /etc/resolv.conf or any other file
cache-size=$CACHESIZE
server=$DNSSERVER
address=/$DOMAIN/$IP  # This is optional if we add it to /etc/hosts
EOF

    # required to run in container
    if [[ -d '/data' ]]
    then prtln "user=root" >> '/etc/dnsmasq.conf'
    fi

    sed -i 's|#\?IGNORE_RESOLVCONF=.*|IGNORE_RESOLVCONF=yes|' '/etc/default/dnsmasq'
    
    update-rc.d dnsmasq defaults
    update-rc.d dnsmasq enable
    service dnsmasq restart
    ncc config:system:set trusted_domains 2 --value="$DOMAIN"
    set_nc_domain "$DOMAIN" --no-trusted-domain
    prtln "Enabled: dnsmasq"
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

