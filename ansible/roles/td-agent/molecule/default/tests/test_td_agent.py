#!/usr/bin/env pytest
"""
Tests for the td-agent role
"""
import pytest


@pytest.mark.parametrize("service_name", ["td-agent"])
def test_services_running(host, service_name):
    service = host.service(service_name)
    assert service.is_enabled
    # assert service.is_running
