import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_supervisord_conf(host):
    vault_supervisord = host.supervisor("vault_supervisord")
    from pprint import pprint
    pprint(vault_supervisord)
    pprint(dir(vault_supervisord))
