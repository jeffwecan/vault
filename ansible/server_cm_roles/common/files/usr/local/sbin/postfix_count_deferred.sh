#!/bin/bash

QUEUE_PATH="/var/spool/postfix/deferred/"
STATE_FILE="/var/tmp/postfix_deferred"

find "${QUEUE_PATH}" -mindepth 2 -type f | wc -l > "${STATE_FILE}"
chmod a+r -- "${STATE_FILE}"
