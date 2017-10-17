#!/bin/bash
CONFIG_FILE="/etc/wpengine/wpe.cnf"
SECTION=${1?:"You must specify a section to read"}
VARNAME=${2}

function read_cfg() {
	eval `sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
	-e 's/;.*$//' \
	-e 's/[[:space:]]*$//' \
	-e 's/^[[:space:]]*//' \
	-e "s/^\(.*\)=\([^\"']*\)$/\1=\"\2\"/" \
	< $CONFIG_FILE \
	| sed -n -e "/^\[$SECTION\]/,/^\s*\[/{/^[^;].*\=.*/p;}"`
	if [[ "$VARNAME" = "user" ]] ; then
		echo $user
	elif [[ "$VARNAME" = "pass" ]] ; then
		echo $pass;
	fi	
}

read_cfg
