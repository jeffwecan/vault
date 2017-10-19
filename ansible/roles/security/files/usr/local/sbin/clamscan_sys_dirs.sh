#!/usr/bin/env bash

# Exit if any command fails
set -euo pipefail

FLOCK_LOCK_FILE='/var/run/clamscan_usr.lock'
EMAIL_RECIPIENTS='security+clamscan@wpengine.com'

scan_local_filesystem () {
    clamscan -ir --no-summary --stdout 2>&1 \
         /etc \
         /{,s}bin \
         /usr/{local/,}{lib,bin,sbin} \
    | ifne mail -s "Clamscan Hit - $(hostname)" "${EMAIL_RECIPIENTS}"
}

# Use flock to ensure we don't run more than one instance of this script at a time
(
    flock --nonblock 200 || echo "Could not unlock ${FLOCK_LOCK_FILE}"
    scan_local_filesystem
) 200>${FLOCK_LOCK_FILE}

