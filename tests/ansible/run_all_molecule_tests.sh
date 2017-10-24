#!/usr/bin/env bash
set -euo pipefail

# roles_to_test=$(tr ',' ' ' <<<${1})
ls -la .
roles_to_test=$(find ansible/roles/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
echo "Found the following roles to test:\n${roles_to_test}"

for role_to_test in ${roles_to_test}; do
    role_path="ansible/roles/${role_to_test}"
    echo "Running 'molecule test' against role without bootstrap tags: ${role_to_test}"
    pushd "${role_path}"

    ls -la .
    echo 'hmmm'
    ls -la ../../molecule

    echo "[${role_to_test}]: Performing basic liniting"
    molecule syntax
    molecule lint

    echo "[${role_to_test}]: Setting up test instance"
    molecule destroy

    echo "[${role_to_test}]: Running initial provisioning playbook sans bootstrap tags"
    molecule converge -- --skip-tags=bootstrap

    echo "[${role_to_test}]: Running initial provisioning playbook sans bootstrap tags"
    molecule converge -- --tags=bootstrap

    molecule idempotence

    echo "[${role_to_test}]: Verifying / testing test instance"
    molecule verify

    echo "[${role_to_test}]: Destroying test instance"
    molecule destroy

    popd
done
