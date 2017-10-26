#!/usr/bin/env bash
set -euo pipefail
export WPE_DEPLOY_PACKAGE_NAME=vault
export WPE_DEPLOY_PHASE='test_harnessing'

role_to_test="${1}"
role_path="ansible/roles/${role_to_test}"

echo "Running 'molecule test' against role without bootstrap tags: ${role_to_test}"
pushd "${role_path}" >/dev/null
export ROLE_NAME="${role_to_test}"
#echo "[${role_to_test}]: Performing basic liniting"
#molecule syntax
#molecule lint

echo "[${role_to_test}]: Setting up test instance"
molecule destroy 2>&1 >/dev/null

echo "[${role_to_test}]: Running initial provisioning playbook sans bootstrap tags"
WPE_DEPLOY_PACKAGE_NAME=tests WPE_DEPLOY_PHASE='skip_tags_bootstrap' molecule converge -- --skip-tags=bootstrap

echo "[${role_to_test}]: Running initial provisioning playbook sans bootstrap tags"
WPE_DEPLOY_PACKAGE_NAME=tests WPE_DEPLOY_PHASE='tags_bootstrap' molecule converge -- --tags=bootstrap

export WPE_DEPLOY_PHASE='test_harnessing'
molecule idempotence 2>&1 >/dev/null

echo "[${role_to_test}]: Verifying / testing test instance"
molecule verify 2>&1 >/dev/null

echo "[${role_to_test}]: Destroying test instance"
molecule destroy 2>&1 >/dev/null

popd >/dev/null
