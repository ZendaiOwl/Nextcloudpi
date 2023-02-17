#!/usr/bin/env bash

# Print NCP sytem info
#
# Copyleft 2017 by Ignacio Nunez Hernanz <nacho _a_t_ ownyourbits _d_o_t_ com>
# GPL licensed (see end of file) * Use at your own risk!
#
# More at: https://ownyourbits.com
#

# Prints a line using printf instead of using echo
# For compatibility and reducing unwanted behaviour
function Print {
    printf '%s\n' "$@"
}

function install () {
  apt-get update  --assume-yes
  apt-get install --assume-yes --no-install-recommends bsdmainutils
}

function configure () {
  Print "Gathering information"
  local OUT
  OUT="$(bash '/usr/local/bin/ncp-diag')"

  # info
  Print "$OUT" | column -t -s'|'

  # suggestions
  Print ""
  bash '/usr/local/bin/ncp-suggestions' "$OUT"
 
  return 0
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
