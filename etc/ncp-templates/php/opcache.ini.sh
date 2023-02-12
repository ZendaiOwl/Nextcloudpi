#!/usr/bin/env bash

# A log that uses log levels for logging different outputs
# Log levels
# -2: Debug
# -1: Info
#  0: Success
#  1: Warning
#  2: Error
function log {
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
           printf "${RED}ERROR${Z} %s\n" "$TEXT" >&2
           ;;
      esac
    else
      log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"
    fi
  fi
}

# Checks if a given path is a regular file
# 0: Is a file
# 1: Not a file
# 2: Invalid number of arguments
function isFile
{
  [[ "$#" -ne 1 ]] && return 2
  [[ -f "$1" ]]
}

# Checks if a given variable has been set and assigned a value.
# Return codes
# 0: Not set
# 1: Is set 
# 2: Invalid number of arguments
function notSet
{
  [[ "$#" -ne 1 ]] && return 2
  [[ ! -v "$1" ]]
}

set -e

if isFile '/usr/local/etc/library.sh'; then
  # shellcheck disable=SC1090
  source '/usr/local/etc/library.sh'
elif isFile 'etc/library.sh'; then
  # shellcheck disable=SC1090
  source 'etc/library.sh'
else
  log 2 "File not found: library.sh"
  exit 1
fi

if notSet PHPVER; then
  log 2 "PHPVER variable is not set!"
  exit 1
fi

if [[ "$1" == "--defaults" ]] || [[ ! -f "${BINDIR}/CONFIG/nc-datadir.sh" ]] && ! is_docker
then
  log -1 "Restoring template to default settings" >&2
  TMP_DIR='/tmp/.opcache'
elif is_docker
then
  DATADIR='/data-ro/ncdata/data'
  [[ "$DOCKERBUILD" == 1 ]] || DATADIR="$(get_nc_config_value datadirectory || echo '/data/ncdata/data')"
  TMP_DIR="$DATADIR/.opcache"
else
  TMP_DIR="$(source "${BINDIR}/CONFIG/nc-datadir.sh"; tmpl_opcache_dir)"
fi

mkdir --parents "$TMP_DIR"

cat <<EOF
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=0
opcache.fast_shutdown=1
opcache.interned_strings_buffer=12
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=1
opcache.file_cache=${TMP_DIR}
opcache.jit=function
EOF
