#!/usr/bin/env pytest
"""
Tests for the ufw-firewall role
"""
import pytest


@pytest.mark.parametrize("package_name", ["ufw"])
def test_packages_installed(host, package_name):
    pkg = host.package(package_name)
    assert pkg.is_installed
