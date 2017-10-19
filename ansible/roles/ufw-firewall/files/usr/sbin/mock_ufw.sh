#!/bin/bash

if [[ "${1}" == "status" ]]; then
	echo "Status: active"
else
	echo "UFW called with: ${@}"
fi
