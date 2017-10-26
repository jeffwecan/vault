import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_supervisord_conf(host):
    assert host.supervisor("vault_supervisord").status not in ['BACKOFF', 'STOPPING', 'EXITED', 'FATAL', 'UNKNOWN']
