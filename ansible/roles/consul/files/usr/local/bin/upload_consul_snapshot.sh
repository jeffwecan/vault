#!/usr/bin/env bash

# Exit if any command fails
set -euo pipefail

FLOCK_LOCK_FILE='/tmp/flock.upload_consul_snapshot'
CONSUL_LOCK_KEY='upload_consul_snapshot'
LAST_RUN_FILENAME='/var/lib/consul/upload_consul_snapshot_last_run'
TMP_FILE=$(/bin/mktemp)

trap release_lock EXIT

get_session_id() {
    session_id=''

    # first check to see if we have an existing session
    session_query=$(curl -s "http://localhost:8500/v1/kv/${CONSUL_LOCK_KEY}")
    if [[ ! -z "${session_query}" ]]; then
        session_id=$(echo "${session_query}" | jq -r '.[] | .Session')
    fi

    # if no existing session is found, create a new one
    if [[ -z "${session_id}" ]] || [[ "${session_id}" == 'null' ]]; then
        # no existing session ID found, so create a new one
        session_id=$(curl -s -X PUT -d '{"Name": "'"${CONSUL_LOCK_KEY}"'"}' http://localhost:8500/v1/session/create | jq -r '.ID')
    fi

    echo "${session_id}"
}

release_lock() {
    curl -s -X PUT "http://localhost:8500/v1/kv/${CONSUL_LOCK_KEY}?release=$(get_session_id)"
}

obtain_lock() {
    # We only need one consul node to generate a backup, so use consul itself to obtain said lock
    acquire_key_result=$(curl -s -X PUT -d $(hostname) "http://localhost:8500/v1/kv/${CONSUL_LOCK_KEY}?acquire=$(get_session_id)")
    echo ${acquire_key_result}
}

generate_snapshot () {
    /usr/local/bin/consul snapshot save ${TMP_FILE}
}

upload_to_s3() {
    /usr/local/bin/aws s3 mv ${TMP_FILE} "s3://{{ consul_s3_bucket }}/consul-backups/$(hostname)-snapshot-$(date +%s)"
}

update_last_run_timestamp() {
    echo $(date +%s) > "${LAST_RUN_FILENAME}"
}

# Use flock to ensure we don't run more than one instance of this script at a time
(
 flock --nonblock 9 || echo "Could not unlock ${FLOCK_LOCK_FILE}"
 obtain_lock_result=$(obtain_lock)
 if [[ "${obtain_lock_result}" != "true" ]]; then
    echo "Unable to obtain lock on ${CONSUL_LOCK_KEY}. Exiting."
    exit 0;
 fi
 generate_snapshot
 upload_to_s3
 update_last_run_timestamp
) 9>${FLOCK_LOCK_FILE}
