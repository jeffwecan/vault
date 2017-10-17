#!/bin/bash
set -eu
set -o pipefail

add_users_to_group() {
    group=${1}
    getent group ${group} &>/dev/null || exit
    getent passwd | awk -F '[:]' '{if ($1 ~ /_$/) print $1}' | while read user ; do /usr/bin/groups ${user} 2>/dev/null | grep -q ${group} || /usr/sbin/usermod -G ${group} -a ${user} ; done
}

prune_users_from_group() {
    group=${1}
    getent group ${group} &>/dev/null || exit
    getent group ${group} | awk -F '[:,]' '{ for (i=4; i <= NF; i++) if ($i ~ /_$/) print $i}' | while read user ; do getent passwd ${user} &>/dev/null || gpasswd -d ${user} ${group} &>/dev/null ; done
}


add_users_to_group www-data
prune_users_from_group www-data

add_users_to_group www-wpe
prune_users_from_group www-wpe
