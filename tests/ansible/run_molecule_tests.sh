#!/usr/bin/env bash
set -euo pipefail

role_to_test="${1}"
role_path="ansible/roles/${role_to_test}"

pushd "${role_path}" >/dev/null

echo "[molecule ${role_to_test}]: Setting up test instance"
molecule destroy 2>&1 >/dev/null

echo "[molecule ${role_to_test}]: Running initial provisioning playbook sans bootstrap tags"
molecule converge -- --skip-tags=bootstrap | awk -v "role=${role_to_test}" '{print "[molecule " role "] [skip-tags=bootstrap]: " $0}'

echo "[molecule ${role_to_test}]: Running initial provisioning playbook with only bootstrap tags"
molecule converge -- --tags=bootstrap | awk -v "role=${role_to_test}" '{print "[molecule " role "] [tags=bootstrap]: " $0}'

molecule idempotence >/dev/null

echo "[molecule ${role_to_test}]: Verifying / testing test instance"
molecule verify | awk -v "role=${role_to_test}" '{print "[molecule " role "] [verify]: " $0}'

echo "[molecule ${role_to_test}]: Destroying test instance"
molecule destroy 2>&1 >/dev/null

popd >/dev/null
