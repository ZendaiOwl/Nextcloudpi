#!/usr/bin/env bash

# Periodically generate previews for the gallery
#
# Copyleft 2019 by Timo Stiefel and Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#

# printlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function println {
    printf '%s\n' "$@"
}

function is_active {
    [[ -f "/etc/cron.d/nc-previews-auto" ]]
}

function configure {
    [[ "$ACTIVE" != "yes" ]] && {
        rm --force '/etc/cron.d/nc-previews-auto'
        service cron restart
        echo "Automatic preview generation disabled"
        return 0
    }
    
    grep -qP "^\d+$" <<<"$RUNTIME" || { println "Invalid RUNTIME value: $RUNTIME"; return 1; }
    RUNTIME="$(( "$RUNTIME" * 60 ))"
    
    echo "0  2  *  *  *  root  /usr/local/bin/nc-previews" >  '/etc/cron.d/ncp-previews-auto'
    chmod 644 '/etc/cron.d/ncp-previews-auto'
    
    cat > '/usr/local/bin/nc-previews' <<EOF
#!/usr/bin/env bash
echo -e "\n[ nc-previews-auto ]" >> /var/log/ncp.log
(
    for i in \$(seq 1 \$(nproc)); do
      ionice -c3 nice -n20 /usr/local/bin/ncc preview:pre-generate -n -vvv &
    done
    wait
) 2>&1 >>/var/log/ncp.log &

PID=\$!
[[ "$RUNTIME" != 0 ]] && {
  for i in \$(seq 1 1 $RUNTIME); do
    sleep 1
    kill -0 "\$PID" &>/dev/null || break
  done
  pkill -f preview:pre-generate
  pkill -f preview:generate-all
}
wait "\$PID"
EOF
    chmod +x '/usr/local/bin/nc-previews'

    service cron restart
    println "Automatic preview generation enabled"
    return 0
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
