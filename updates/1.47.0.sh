#!/usr/bin/env bash

set -e

source /usr/local/etc/library.sh

# Stop metrics services if running
for svc in prometheus-node-exporter ncp-metrics-exporter
do
  service "$svc" status || [[ $? -ne 4 ]] || continue
  service "$svc" stop || [[ $? -ne 4 ]]
done

# Reinstall metrics services
installApp metrics
isAppActive metrics && (
  export METRICS_SKIP_PASSWORD_CONFIG=true
  runApp metrics
)

exit 0
