import unittest
from unittest.mock import patch, MagicMock, call
import os
import sys
import time

# Mock missing third-party packages if not installed in current environment
try:
    import requests
except ImportError:
    mock_requests = MagicMock()
    sys.modules["requests"] = mock_requests

try:
    import obsws_python
except ImportError:
    mock_obsws = MagicMock()
    sys.modules["obsws_python"] = mock_obsws

flask_installed = True
try:
    import flask
except ImportError:
    flask_installed = False
    mock_flask = MagicMock()
    sys.modules["flask"] = mock_flask

# Add repo root to path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from noalbs.noalbs import MediaMTXProtection, Noalbs
from stream_validator import is_ip_allowed

if flask_installed:
    try:
        from stream_validator import app as validator_app
    except Exception:
        validator_app = None
else:
    validator_app = None

class TestIPWhitelistVPNWireGuard(unittest.TestCase):
    """
    Tests for IP Whitelisting supporting VPN, WireGuard, IPv4/IPv6 CIDR subnets,
    and exact addresses, including the user's reference whitelist string:
    10.0.0.0/8,10.18.0.1,127.0.0.1,172.16.0.0/12,172.17.0.1,172.18.0.1,172.20.0.1,192.168.0.0/16,217.196.51.37,2a02:4780:10:cbe0::1
    """

    def setUp(self):
        self.whitelist = "10.0.0.0/8,10.18.0.1,127.0.0.1,172.16.0.0/12,172.17.0.1,172.18.0.1,172.20.0.1,192.168.0.0/16,217.196.51.37,2a02:4780:10:cbe0::1"

    def test_empty_whitelist_allows_all(self):
        self.assertTrue(is_ip_allowed("8.8.8.8", ""))
        self.assertTrue(is_ip_allowed("192.168.1.1", None))

    def test_user_vpn_and_wireguard_whitelist_matches(self):
        # 10.0.0.0/8 CIDR (VPN / WireGuard)
        self.assertTrue(is_ip_allowed("10.5.2.1", self.whitelist))
        self.assertTrue(is_ip_allowed("10.0.0.1", self.whitelist))
        self.assertTrue(is_ip_allowed("10.255.255.254", self.whitelist))

        # Exact IPs
        self.assertTrue(is_ip_allowed("10.18.0.1", self.whitelist))
        self.assertTrue(is_ip_allowed("127.0.0.1", self.whitelist))
        self.assertTrue(is_ip_allowed("172.17.0.1", self.whitelist))
        self.assertTrue(is_ip_allowed("172.18.0.1", self.whitelist))
        self.assertTrue(is_ip_allowed("172.20.0.1", self.whitelist))
        self.assertTrue(is_ip_allowed("217.196.51.37", self.whitelist))

        # 172.16.0.0/12 CIDR
        self.assertTrue(is_ip_allowed("172.16.1.5", self.whitelist))
        self.assertTrue(is_ip_allowed("172.31.255.254", self.whitelist))

        # 192.168.0.0/16 CIDR (LAN / VPN)
        self.assertTrue(is_ip_allowed("192.168.1.50", self.whitelist))
        self.assertTrue(is_ip_allowed("192.168.254.10", self.whitelist))

        # IPv6 exact address
        self.assertTrue(is_ip_allowed("2a02:4780:10:cbe0::1", self.whitelist))
        self.assertTrue(is_ip_allowed("[2a02:4780:10:cbe0::1]", self.whitelist))

    def test_ports_and_brackets_handling(self):
        # Client IP with port
        self.assertTrue(is_ip_allowed("10.18.0.1:54321", self.whitelist))
        self.assertTrue(is_ip_allowed("[2a02:4780:10:cbe0::1]:8080", self.whitelist))

    def test_unauthorized_ips_rejected(self):
        self.assertFalse(is_ip_allowed("8.8.8.8", self.whitelist))
        self.assertFalse(is_ip_allowed("1.1.1.1", self.whitelist))
        self.assertFalse(is_ip_allowed("172.32.0.1", self.whitelist)) # Outside 172.16.0.0/12
        self.assertFalse(is_ip_allowed("2a02:4780:10:cbe0::2", self.whitelist))

    def test_ipv6_cidr_subnet(self):
        v6_list = "2001:db8::/32, 10.8.0.0/24"
        self.assertTrue(is_ip_allowed("2001:db8:1234::1", v6_list))
        self.assertTrue(is_ip_allowed("10.8.0.5", v6_list))
        self.assertFalse(is_ip_allowed("2001:db9::1", v6_list))

    def test_simplified_wireguard_and_server_ip_whitelist(self):
        # Test simplified format: Server IP + WireGuard client subnet
        server_ip = "203.0.113.195"
        wg_subnet = "10.8.0.0/24"
        whitelist = f"{server_ip},{wg_subnet}"

        # WireGuard client IPs allowed
        self.assertTrue(is_ip_allowed("10.8.0.1", whitelist))
        self.assertTrue(is_ip_allowed("10.8.0.2", whitelist))
        self.assertTrue(is_ip_allowed("10.8.0.254", whitelist))
        # Server IP allowed
        self.assertTrue(is_ip_allowed("203.0.113.195", whitelist))
        # Non-whitelisted IPs blocked
        self.assertFalse(is_ip_allowed("10.8.1.1", whitelist))
        self.assertFalse(is_ip_allowed("198.51.100.1", whitelist))

class TestValidatorEndpoints(unittest.TestCase):
    def setUp(self):
        if validator_app and hasattr(validator_app, 'test_client'):
            self.client = validator_app.test_client()
        else:
            self.client = None

    @patch("urllib.request.urlopen")
    def test_yt_video_id_channel_handle_resolution(self, mock_urlopen):
        if not self.client:
            self.skipTest("Flask test client not available")
        mock_response = MagicMock()
        mock_response.read.return_value = b'{"videoId":"cdPyuLr_rI0"}'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        res = self.client.get('/yt_video_id?channel=@YouTube')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data.decode('utf-8'), 'cdPyuLr_rI0')

    @patch("urllib.request.urlopen")
    def test_yt_video_id_fallback_to_video_id(self, mock_urlopen):
        if not self.client:
            self.skipTest("Flask test client not available")
        mock_urlopen.side_effect = Exception("Not found")

        res = self.client.get('/yt_video_id?channel=cdPyuLr_rI0')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data.decode('utf-8'), 'cdPyuLr_rI0')

    def test_yt_video_id_missing_channel(self):
        if not self.client:
            self.skipTest("Flask test client not available")
        res = self.client.get('/yt_video_id')
        self.assertEqual(res.status_code, 400)

class TestMediaMTXProtectionComprehensive(unittest.TestCase):

    def setUp(self):
        os.environ["MEDIAMTX_PROTECTION_ENABLED"] = "true"
        os.environ["NOALBS_ENABLED"] = "true"
        os.environ["CLOUD_BRB"] = "true"
        os.environ["FALLBACK_MODE"] = "video"
        os.environ["LOW_BITRATE"] = "1000"
        os.environ["RESTORE_BITRATE"] = "1500"
        os.environ["APP_NAME"] = "live"
        os.environ["OBS_SCENE_LIVE"] = "Main"
        os.environ["OBS_SCENE_BRB"] = "BRB"
        os.environ["CLOUD_BRB_TIMEOUT"] = "300"

    def test_default_protection_disabled(self):
        # When environment variables are not set or default to false
        orig_protection = os.environ.pop("MEDIAMTX_PROTECTION_ENABLED", None)
        orig_noalbs = os.environ.pop("NOALBS_ENABLED", None)
        orig_cloud_brb = os.environ.pop("CLOUD_BRB", None)
        try:
            prot_default = MediaMTXProtection()
            self.assertFalse(prot_default.enabled)
            self.assertFalse(prot_default.cloud_brb_enabled)
        finally:
            if orig_protection is not None: os.environ["MEDIAMTX_PROTECTION_ENABLED"] = orig_protection
            if orig_noalbs is not None: os.environ["NOALBS_ENABLED"] = orig_noalbs
            if orig_cloud_brb is not None: os.environ["CLOUD_BRB"] = orig_cloud_brb

    def test_fallback_mode_configuration(self):
        os.environ["FALLBACK_MODE"] = "obs"
        prot_obs = MediaMTXProtection()
        self.assertEqual(prot_obs.fallback_mode, "obs")

        os.environ["FALLBACK_MODE"] = "video"
        prot_video = MediaMTXProtection()
        self.assertEqual(prot_video.fallback_mode, "video")

    def make_stat_xml(self, live_bw=0, vert_bw=0, include_cloud_brb=False):
        xml = f"""<?xml version="1.0" encoding="UTF-8" ?>
<rtmp>
  <server>
    <application>
      <name>live</name>
      <live>
"""
        if live_bw > 0:
            xml += f"""
        <stream>
          <name>stream_key_123</name>
          <publishing/>
          <bw_in>{live_bw}</bw_in>
        </stream>
"""
        if include_cloud_brb:
            xml += f"""
        <stream>
          <name>cloud_brb_loop</name>
          <publishing/>
          <bw_in>384000</bw_in>
        </stream>
"""
        xml += """
      </live>
    </application>
    <application>
      <name>vertical</name>
      <live>
"""
        if vert_bw > 0:
            xml += f"""
        <stream>
          <name>v_stream_key_123</name>
          <publishing/>
          <bw_in>{vert_bw}</bw_in>
        </stream>
"""
        xml += """
      </live>
    </application>
  </server>
</rtmp>
"""
        return xml

    @patch("requests.get")
    def test_get_bitrate_calculation_and_filtering(self, mock_get):
        prot = MediaMTXProtection()

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = self.make_stat_xml(live_bw=640000, vert_bw=256000, include_cloud_brb=True)
        mock_get.return_value = mock_resp

        bitrate = prot.get_bitrate()
        self.assertEqual(bitrate, 7000)

    @patch("requests.get", side_effect=Exception("Connection refused"))
    def test_get_bitrate_handles_network_error(self, mock_get):
        prot = MediaMTXProtection()
        bitrate = prot.get_bitrate()
        self.assertEqual(bitrate, 0)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_libx264_command(self, mock_run, mock_popen, mock_is_valid):
        mock_run.return_value = MagicMock(stdout="libx264")
        prot = MediaMTXProtection()
        prot.start_cloud_brb()

        mock_popen.assert_called_once()
        cmd = mock_popen.call_args[0][0]
        self.assertEqual(cmd[0], "ffmpeg")
        self.assertIn("-c:v", cmd)
        self.assertIn("libx264", cmd)
        
        self.assertIn("-map", cmd)
        self.assertIn("0:a?", cmd)
        tee_target = cmd[-1]
        self.assertIn("rtmp://127.0.0.1:19359/live/cloud_brb_loop", tee_target)
        self.assertIn("rtmp://127.0.0.1:19359/vertical/cloud_brb_loop", tee_target)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_restarts_crashed_process(self, mock_run, mock_popen, mock_is_valid):
        prot = MediaMTXProtection()
        crashed_proc = MagicMock()
        crashed_proc.poll.return_value = 1
        prot.cloud_process = crashed_proc

        prot.start_cloud_brb()
        mock_popen.assert_called_once()

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_nvenc_command(self, mock_run, mock_popen, mock_is_valid):
        mock_run.return_value = MagicMock(stdout="h264_nvenc acceleration available")
        prot = MediaMTXProtection()
        prot.start_cloud_brb()

        cmd = mock_popen.call_args[0][0]
        self.assertIn("h264_nvenc", cmd)

    @patch("noalbs.noalbs.is_valid_file", return_value=False)
    @patch("subprocess.Popen")
    @patch.object(MediaMTXProtection, "ensure_brb_video_ready")
    def test_start_cloud_brb_missing_video_file(self, mock_ensure, mock_popen, mock_is_valid):
        prot = MediaMTXProtection()
        prot.start_cloud_brb()
        mock_ensure.assert_called_once()

    @patch("noalbs.noalbs.urllib.request.urlopen")
    @patch("builtins.open")
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    @patch("noalbs.noalbs.is_valid_file")
    def test_ensure_brb_video_ready_downloads_default_and_transcodes(self, mock_is_valid, mock_run, mock_popen, mock_open, mock_urlopen):
        mock_is_valid.side_effect = [False, True, True, True]
        mock_run.return_value = MagicMock(returncode=0, stdout="10.0")
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = ["out_time_us=5000000"]
        mock_popen.return_value = mock_proc

        mock_response = MagicMock()
        mock_response.read.return_value = b"fake video content"
        mock_urlopen.return_value.__enter__.return_value = mock_response

        prot = MediaMTXProtection()
        prot.ensure_brb_video_ready()

        mock_urlopen.assert_called_once()
        req_arg = mock_urlopen.call_args[0][0]
        self.assertEqual(req_arg.full_url, "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4")

        mock_popen.assert_called_once()
        ffmpeg_cmd = mock_popen.call_args[0][0]
        self.assertEqual(ffmpeg_cmd[0], "ffmpeg")
        self.assertIn("libx264", ffmpeg_cmd)
        self.assertIn("aac", ffmpeg_cmd)

    def test_cloud_brb_timeout_env_config(self):
        os.environ["CLOUD_BRB_TIMEOUT"] = "600"
        prot = MediaMTXProtection()
        self.assertEqual(prot.cloud_brb_timeout, 600)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    def test_stop_cloud_brb(self, mock_popen, mock_is_valid):
        prot = MediaMTXProtection()
        mock_proc = MagicMock()
        prot.cloud_process = mock_proc
        prot.cloud_brb_start_time = time.time()

        prot.stop_cloud_brb()
        self.assertIsNone(prot.cloud_process)
        self.assertIsNone(prot.cloud_brb_start_time)

    def test_switch_scene_includes_aitum_vertical(self):
        prot = MediaMTXProtection()
        mock_client = MagicMock()
        prot.obs_client = mock_client

        prot.switch_scene("BRB")
        mock_client.set_current_program_scene.assert_called_with("BRB")
        mock_client.call_vendor_request.assert_called_with("aitum-vertical-canvas", "switch_scene", {"scene": "BRB"})

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    @patch("requests.get")
    def test_disconnection_protection_simulation(self, mock_get, mock_run, mock_popen, mock_is_valid):
        mock_run.return_value = MagicMock(stdout="libx264")
        prot = MediaMTXProtection()
        mock_obs = MagicMock()

        status_mock = MagicMock()
        status_mock.outputActive = False
        status_mock.output_active = False
        mock_obs.get_stream_status.return_value = status_mock
        prot.obs_client = mock_obs

        prot.is_streaming = True

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = self.make_stat_xml(live_bw=0)
        mock_get.return_value = mock_resp

        bitrate = prot.get_bitrate()
        self.assertEqual(bitrate, 0)

        if bitrate == 0 and prot.is_streaming:
            client = prot.get_obs_client()
            is_obs_streaming = True
            if client:
                status = client.get_stream_status()
                is_obs_streaming = getattr(status, 'output_active', getattr(status, 'outputActive', True))

            if is_obs_streaming or prot.cloud_brb_enabled:
                prot.switch_scene(prot.scene_brb)
                prot.is_low = True
                if prot.cloud_brb_enabled:
                    prot.start_cloud_brb()
            else:
                prot.is_low = False
            prot.is_streaming = False

        mock_obs.set_current_program_scene.assert_called_with("BRB")
        mock_popen.assert_called_once()
        self.assertFalse(prot.is_streaming)
        self.assertTrue(prot.is_low)
        self.assertIsNotNone(prot.cloud_process)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_timeout_300s_stops_cloud_brb(self, mock_run, mock_popen, mock_is_valid):
        prot = MediaMTXProtection()
        mock_proc = MagicMock()
        mock_proc.poll = MagicMock(return_value=None)
        prot.cloud_process = mock_proc
        prot.cloud_brb_start_time = time.time() - 301
        
        mock_obs = MagicMock()
        prot.obs_client = mock_obs

        if prot.cloud_process and prot.cloud_brb_start_time:
            if prot.cloud_process.poll() is not None:
                prot.cloud_process = None
                prot.start_cloud_brb()

            elapsed = time.time() - prot.cloud_brb_start_time
            if elapsed >= prot.cloud_brb_timeout:
                prot.stop_cloud_brb()
                client = prot.get_obs_client()
                if client:
                    client.stop_stream()

        self.assertIsNone(prot.cloud_process)
        mock_obs.stop_stream.assert_called_once()

    @patch("requests.get")
    def test_mediamtx_source_online_check(self, mock_get):
        protection = MediaMTXProtection()

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "items": [
                {"name": "live", "ready": True, "online": True},
                {"name": "vertical", "ready": True, "online": False}
            ]
        }
        mock_get.return_value = mock_resp
        self.assertTrue(protection.check_mediamtx_source_online())

        mock_resp.json.return_value = {
            "items": [
                {"name": "live", "ready": True, "online": False},
                {"name": "vertical", "ready": True, "online": False}
            ]
        }
        self.assertFalse(protection.check_mediamtx_source_online())

        mock_get.side_effect = Exception("API unreachable")
        self.assertIsNone(protection.check_mediamtx_source_online())

if __name__ == "__main__":
    unittest.main()
