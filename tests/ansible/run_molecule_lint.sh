#!/usr/bin/env bash
set -euo pipefail

role_to_lint="${1}"
role_path="ansible/roles/${role_to_lint}"

pushd "${role_path}"

molecule syntax
molecule lint

popd >/dev/null
