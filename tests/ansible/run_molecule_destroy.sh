#!/usr/bin/env bash

role_to_destroy="${1}"
role_path="ansible/roles/${role_to_destroy}"

pushd "${role_path}" >/dev/null

echo "[molecule] [${role_to_destroy}]: Cleaning up / destroying test instance"
molecule destroy &>/dev/null

popd >/dev/null
