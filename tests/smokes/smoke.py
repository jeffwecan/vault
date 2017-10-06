"""
Smoke tests to be run after each deploy.
"""

import os
import requests

from retrying import retry
from unittest import TestCase


class VaultService:

    @property
    def base_url(self):
        return 'https://{}'.format(os.environ.get('SMOKE_DOMAIN', default='vault.wpengine.io'))

    @property
    def status_url(self):
        return '{}/v1/health/'.format(self.base_url)

    @property
    def version(self):
        return os.environ.get('VERSION')


class StatusTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.service = VaultService()

    def test_status_ok(self):
        @retry("Wait for the deploy to finish.")
        def block():
            response = requests.get(self.app.status_url)
            self.assertEqual(200, response.status_code, 'Expected 200 status code:  {}'.format(response.text))
            json_response = response.json()
            self.assertTrue(json_response['success'], 'Status check failed:  {}'.format(response.text))
            self.assertIn('version', json_response, 'Version not found in status: {}'.format(response.text))
            self.assertEqual(self.app.version, json_response['version'], 'Expected version {}:  {}'.format(
                self.app.version, json_response['version']))
