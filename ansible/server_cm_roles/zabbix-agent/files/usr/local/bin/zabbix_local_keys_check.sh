#!/usr/bin/env bash

# This script checks that a given node can connect to other nodes in the same cluster

# Exit if any command fails
set -euo pipefail

output_file=/var/lib/zabbix/zabbix_local_keys_check.txt

error() {
    echo 1 > $output_file
}
trap 'error' ERR

# grab list of instances local to the cluster from server_meta
cluster_id=$(cat /etc/cluster-id)
local_hosts=$(python /opt/server-cm/inventory/server_meta.py -q "${cluster_id}" | jq -r '.[] | .[] | .ip_priv | select(.!=null)')

for local_host in $local_hosts; do
  ping -c 2 -t 2 "${local_host}" &>/dev/null || continue
  ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout 10' -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' "${local_host}" exit
done

echo 0 > $output_file
