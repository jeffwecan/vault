#!/usr/bin/env pytest
"""
Tests for the common server-cm role
"""
import apt
import pytest


def check_service(host, service_name):
    service = host.service(service_name)
    assert service.is_enabled
    # assert service.is_running


def test_td_agent_service_running(host):
    cache = apt.Cache()
    td_agent_pkg = cache['td-agent']
    if not td_agent_pkg.installed:
        pytest.skip()

    check_service(host, 'td-agent')
