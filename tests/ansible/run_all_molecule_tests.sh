#!/usr/bin/env bash
set -euo pipefail

max_xargs_processes=5

roles_to_test=$(find ansible/roles/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
echo -e "Found the following roles to test:\n${roles_to_test}"

test_runner="$(dirname $0)/run_molecule_tests.sh"
echo "${roles_to_test}" | xargs -I {} -P${max_xargs_processes} ${test_runner} {}
