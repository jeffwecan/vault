#!/bin/bash
set -eu
set -o pipefail

myname=$(basename "${0:-0}")
editor=$(basename "${EDITOR:-1}")

if [ "${myname}" == "${editor}" ] ; then
cat > "$1" <<EOF
libpam-runtime/profiles="Pwquality password strength checking, activate mkhomedir, Unix authentication, SSS authentication, Inheritable Capabilities Management"
EOF
else
before=$(sha256sum /etc/pam.d/*)
EDITOR="$(dirname ${0})/$(basename ${0})" DEBIAN_FRONTEND="editor" pam-auth-update --force 2>/dev/null
after=$(sha256sum /etc/pam.d/*)
[[ "${before}" == "${after}" ]] || echo CHANGED
fi
