#!/usr/bin/env bash
set -euo pipefail

role_to_lint="${1}"
role_path="ansible/roles/${role_to_lint}"

pushd "${role_path}" >/dev/null

molecule syntax >/dev/null
molecule lint >/dev/null

popd >/dev/null
