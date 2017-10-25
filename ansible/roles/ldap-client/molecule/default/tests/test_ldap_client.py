import os

import pytest
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("service_name", ["sssd"])
def test_services_running(host, service_name):
    service = host.service(service_name)
    assert service.is_enabled
    # assert service.is_running
