import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_file_additions(host):
    assert host.file('/root/.profile').exists
    assert host.file('/root/.selected_editor').exists
