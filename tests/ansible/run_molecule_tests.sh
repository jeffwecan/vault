#!/usr/bin/env bash
set -euo pipefail

role_to_test="${1}"
role_path="ansible/roles/${role_to_test}"

echo "Running 'molecule test' against role without bootstrap tags: ${role_to_test}"
pushd "${role_path}" >/dev/null

echo "[${role_to_test}]: Setting up test instance"
molecule destroy 2>&1 >/dev/null

echo "[${role_to_test}]: Running initial provisioning playbook sans bootstrap tags"
molecule converge -- --skip-tags=bootstrap

echo "[${role_to_test}]: Running initial provisioning playbook with only bootstrap tags"
molecule converge -- --tags=bootstrap

molecule idempotence

echo "[${role_to_test}]: Verifying / testing test instance"
molecule verify

echo "[${role_to_test}]: Destroying test instance"
molecule destroy 2>&1 >/dev/null

popd >/dev/null
