set -e

if [[ -f /usr/local/etc/library.sh ]]; then
  # shellcheck disable=SC1090
  source /usr/local/etc/library.sh
elif [[ -f etc/library.sh ]]; then
  # shellcheck disable=SC1090
  source etc/library.sh
else
  echo "File not found: library.sh" >&2
  exit 1
fi

if notSet PHPVER; then
  echo "PHPVER variable is not set!"
  exit 1
fi

if [[ "$1" == "--defaults" ]] || [[ ! -f "${BINDIR}/CONFIG/nc-datadir.sh" ]] && ! is_docker; then
  echo "Restoring template to default settings" >&2
  TMP_DIR=/tmp/.opcache
elif is_docker; then
  DATADIR=/data-ro/ncdata/data
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
