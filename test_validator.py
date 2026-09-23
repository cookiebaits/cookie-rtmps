import unittest
from unittest.mock import patch
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

import stream_validator

class TestStreamValidator(unittest.TestCase):

    def test_is_ip_allowed_loopback(self):
        self.assertTrue(stream_validator.is_ip_allowed("127.0.0.1", "10.0.0.1"))
        self.assertTrue(stream_validator.is_ip_allowed("::1", "10.0.0.1"))

    def test_is_ip_allowed_empty_setting(self):
        self.assertTrue(stream_validator.is_ip_allowed("203.0.113.45", ""))
        self.assertTrue(stream_validator.is_ip_allowed("192.168.1.100", None))

    def test_is_ip_allowed_matching_ip(self):
        whitelist = "10.0.0.1, 192.168.1.50"
        self.assertTrue(stream_validator.is_ip_allowed("10.0.0.1", whitelist))
        self.assertTrue(stream_validator.is_ip_allowed("192.168.1.50", whitelist))

    def test_is_ip_allowed_non_matching_ip(self):
        whitelist = "10.0.0.1"
        # Turning off Wireguard produces an external public IP
        self.assertFalse(stream_validator.is_ip_allowed("203.0.113.45", whitelist))
        self.assertFalse(stream_validator.is_ip_allowed("10.0.0.2", whitelist))

    def test_is_ip_allowed_with_port(self):
        whitelist = "10.0.0.1"
        self.assertTrue(stream_validator.is_ip_allowed("10.0.0.1:54321", whitelist))
        self.assertFalse(stream_validator.is_ip_allowed("203.0.113.45:54321", whitelist))

    def test_is_ip_allowed_cidr(self):
        whitelist = "10.8.0.0/24"
        self.assertTrue(stream_validator.is_ip_allowed("10.8.0.5", whitelist))
        self.assertFalse(stream_validator.is_ip_allowed("10.9.0.5", whitelist))

    @patch.object(stream_validator, 'VALID_KEYS', ['test_key_123'])
    @patch.object(stream_validator, 'ACCEPTED_IP', '10.0.0.1')
    def test_validate_route_whitelisting(self):
        client = stream_validator.app.test_client()

        # Whitelisted IP -> 200 OK
        resp = client.post('/validate', data={'name': 'test_key_123', 'addr': '10.0.0.1', 'app': 'live'})
        self.assertEqual(resp.status_code, 200)

        # Wireguard OFF / External non-whitelisted IP -> 403 Forbidden
        resp = client.post('/validate', data={'name': 'test_key_123', 'addr': '203.0.113.45', 'app': 'live'})
        self.assertEqual(resp.status_code, 403)
        self.assertIn(b'IP not whitelisted', resp.data)

        # Cloud BRB stream on loopback -> 200 OK
        resp = client.post('/validate', data={'name': 'cloud_brb_loop', 'addr': '127.0.0.1', 'app': 'live'})
        self.assertEqual(resp.status_code, 200)

if __name__ == '__main__':
    unittest.main()
