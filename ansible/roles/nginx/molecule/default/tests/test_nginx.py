#!/usr/bin/env pytest
"""
Tests for the nginx server-cm role
"""
import pytest


@pytest.mark.parametrize("service_name", ["nginx"])
def test_services_running(host, service_name):
    service = host.service(service_name)
    assert service.is_enabled
    # assert service.is_running


@pytest.mark.parametrize("command", ["nginx -t"])
def test_nginx_config(host, command):
    result = host.run(command)
    status = result.rc
    assert status == 0, '"nginx -t" expected return code 0, got: {}, stderr: {}'.format(status, result.stderr)
