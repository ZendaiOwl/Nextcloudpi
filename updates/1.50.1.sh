#!/usr/bin/env bash

set -e
export NCPCFG=/usr/local/etc/ncp.cfg
source /usr/local/etc/library.sh

installTemplate systemd/notify_push.service.sh /etc/systemd/system/notify_push.service

bash -c "sleep 6; source /usr/local/etc/library.sh; clearOpCache; service php${PHPVER}-fpm reload" &>/dev/null &
