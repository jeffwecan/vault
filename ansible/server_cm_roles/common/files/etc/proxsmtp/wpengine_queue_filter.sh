#!/bin/bash
# WP Engine proxsmtp queue filter script
# http://thewalter.net/stef/software/proxsmtp/proxsmtpd.html

# proxsmtp uses return codes from this script to determine delivery: yes for 0, no for all others
# stderr is returned back to postfix, which acts based on SMTP codes in these strings

# Obtain our script dir for later reference.
SCRIPT_DIR="$(dirname ${0})"

# Soft threshold, pass this and we re-queue your mail
THRESHOLD_SOFT=251
# Hard threshold, pass this and we discard your mail
THRESHOLD_HARD=501
# Discard is accomplished by a 'disable' flag, which is removed after this number of seconds
DISABLE_MAX="3600"
# Rolling period used for sent mail tallying
COUNT_PERIOD="1 hour"
# State directory contains counters and session lock files
STATE="/var/spool/proxsmtp"
# The "default" value of X-WPE-Internal-ID. SHA-1 of a null-terminated "WP_USER", as it turns out.
DEFAULT_HASH="d9543b1178b77ff83fc79e803a4ef08eab669c58"

# NOTE: when discarding, use 250 to avoid postfix bouncing the message. 250 + nonzero exit effects a discard
DISABLE_MSG="250 NOPE: User disabled, discarding mail."
# Immutable disable.* files indicate a human has forcibly disabled mail for this hash
IMMUTABLE_MSG="250 NOPE: User administratively disabled, discarding mail."

# NOTE: these conditions are intended to cause postfix to requeue messages
THROTTLE_MSG="450 Delayed: too many concurrent messages"
QUOTA_MSG="450 Delayed: sender over quota"

# Honor feature flags
[ -e /etc/wpengine/disabled/proxsmtp ] && exit 0

# Return early if for some reason the mail variable is undefined
[ -z "${EMAIL}" ] && exit 0

# Return early if the mail file doesn't exist
[ -e "${EMAIL}" ] || exit 0

# Sanitize the first X-WPE-Internal-ID header found
HASH=$(grep --no-messages --max-count=1 --before-context=999 '^From:' "${EMAIL}" | grep --no-messages --max-count=1 -- '^X-WPE-Internal-ID' | tr -d '\r\n?' | awk '{print $NF}')

# define headers file even if we exit before we can use it, so the trap can delete it if we do
HEADERS="${STATE}/headers.${HASH}"

# Return early if we could not find an ID header
[ -z "${HASH}" ] && exit 0

# Now that we have a site hash, we can define our lock, counter, and disable paths
LOCK="${STATE}/lock.${HASH}"
COUNTER="${STATE}/count.${HASH}"
DISABLE_FLAG="${STATE}/disable.${HASH}"

# Use a trap to clean up locks in case we don't make it to the end
cleanup() {
    rm -f -- "${HEADERS}"
    rmdir -- "${LOCK}" &>/dev/null || true
}
trap cleanup SIGHUP SIGINT SIGTERM EXIT

# use mkdir for locking because it causes an immediate vfs sync
# if we do collide, cause postfix to queue
mkdir "${LOCK}" &>/dev/null || { echo "${THROTTLE_MSG}" >&2; exit 1; }

# Extract headers for later perusal
# anything after the From: header is body
grep --no-messages --max-count=1 --before-context=999 '^From: ' "${EMAIL}" > "${HEADERS}"

# What time is it?  NOTE: this is used for DISABLE_AGE in addition to COUNTER
NOW="$(date +%s)"

# we're processing a message for real, increment the counter
echo "${NOW}" >> "${COUNTER}"

# Fail on immutable flag files - this hash has been administratively disabled
if [[ -e "${DISABLE_FLAG}" ]] ; then
    if (\lsattr "${DISABLE_FLAG}" 2>/dev/null | \cut -b5 | \grep -sq '^i$') ; then
        echo "${IMMUTABLE_MSG}" >&2
        exit 1
    else
        DISABLE_TIME=$(stat -c %Y -- "${DISABLE_FLAG}")
        DISABLE_AGE=$((NOW-DISABLE_TIME))
        if [[ ${DISABLE_AGE} -gt ${DISABLE_MAX} ]] ; then
            /bin/rm -f -- "${DISABLE_FLAG}"
        else
            echo "${DISABLE_MSG}" >&2
            exit 1
        fi
    fi
fi

# Remove any entries older than our accounting period from the counter file
THEN=$(date +%s -d "${COUNT_PERIOD} ago")
awk -vDate="${THEN}" '{if ($1 > Date) print $1}' "${COUNTER}" | sponge "${COUNTER}"

# Tally what's left
COUNT=$(grep -hc . "${COUNTER}")

# override thresholds for default X-WPE-Internal-ID
if [[ "${DEFAULT_HASH}" == "${HASH}" ]] ; then
    THRESHOLD_SOFT="51"
    THRESHOLD_HARD="101"
fi

# override thresholds even more if a known bad header appears
if grep --no-messages --silent --file="${SCRIPT_DIR}/evil_headers.txt" -- "${HEADERS}" ; then
    THRESHOLD_SOFT="5"
    THRESHOLD_HARD="11"
fi

# if we've passed the hard threshold, disable the site hash entirely, effective on next run
if [[ "${COUNT}" -gt "${THRESHOLD_HARD}" ]] ; then
    touch "${DISABLE_FLAG}"
    echo "${DISABLE_MSG}" >&2
    exit 1
# if we've passed the soft threshold, requeue
elif [[ "${COUNT}" -gt "${THRESHOLD_SOFT}" ]] ; then
    echo "${QUOTA_MSG}" >&2
    exit 1
fi

exit 0
