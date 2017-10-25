import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_supervisor_conf(host):
    assert host.supervisor("consul-agent").status not in ['BACKOFF', 'STOPPING', 'EXITED', 'FATAL', 'UNKNOWN']
    assert host.supervisor("consul-server").status not in ['BACKOFF', 'STOPPING', 'EXITED', 'FATAL', 'UNKNOWN']
