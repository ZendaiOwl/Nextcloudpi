#!/usr/bin/env bash

# Export NextcloudPi configuration
#
#
# Copyleft 2017 by Courtney Hicks
# GPL licensed (see end of file) * Use at your own risk!
#

# prtlns a line using printf instead of using echo, for compatibility and reducing unwanted behaviour
function prtln {
    printf '%s\n' "$@"
}

function configure () {
  [[ -d "$DIR" ]] || { prtln "Directory not found: $DIR"; return 1; }
  local DESTFILE
  DESTFILE="$DIR"/ncp-config_"$(date +"%Y%m%d")".tar

  tar -cf "$DESTFILE" -C /usr/local/etc/ncp-config.d .
  chmod 600 "$DESTFILE"

  prtln "Configuration exported to: $DESTFILE"
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
