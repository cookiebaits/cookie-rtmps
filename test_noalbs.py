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

class TestStreamProtectionV2(unittest.TestCase):
    def test_stream_protection_settings_and_channels(self):
        import stream_protection
        settings = stream_protection.Settings()
        self.assertIsNotNone(settings.low_kbps)
        self.assertIsNotNone(settings.timeout)

        # Test Channel object instantiation and commands
        ch = stream_protection.Channel("horizontal", "live", settings, protected=True)
        ch.stream_name = "test_key"
        feed_cmd = ch.feed_cmd()
        relay_cmd = ch.relay_cmd()

        self.assertEqual(feed_cmd[0], "ffmpeg")
        self.assertIn("rtmp://127.0.0.1:1937/feed/horizontal", feed_cmd[-1])
        self.assertEqual(relay_cmd[0], "ffmpeg")
        self.assertIn("broadcast_h/horizontal", relay_cmd[-1])

    def test_stream_protection_state_machine_transitions(self):
        import stream_protection
        from unittest.mock import MagicMock
        settings = stream_protection.Settings()
        settings.low_kbps = 1000
        ch = stream_protection.Channel("horizontal", "live", settings, protected=True)

        now = 1000.0
        # Initially idle
        self.assertEqual(ch.state, "idle")

        # Stream appears
        ch.update_bitrate(("test_key", 500000), now)
        ch.update_bitrate(("test_key", 1000000), now + 1.0)
        ch.start_feed = MagicMock()
        ch.start_relay = MagicMock()
        ch.tick(now + 1.0)
        self.assertEqual(ch.state, "live")

        # Drop publisher -> enter backup
        ch.update_bitrate(None, now + 2.0)
        ch.stop_feed = MagicMock()
        ch.tick(now + 2.0)
        self.assertEqual(ch.state, "backup")
        self.assertIsNotNone(ch.backup_since)

    def test_write_mediamtx_config(self):
        import stream_protection
        import tempfile
        with tempfile.NamedTemporaryFile("w+", delete=False) as tf:
            conf_path = tf.name

        try:
            old_conf = stream_protection.MTX_CONFIG
            stream_protection.MTX_CONFIG = conf_path
            videos = {"horizontal": "/app/data/brb_horizontal.mp4", "vertical": "/app/data/brb_vertical.mp4"}
            stream_protection.write_mediamtx_config(videos)
            with open(conf_path) as f:
                content = f.read()
            self.assertIn("feed/horizontal:", content)
            self.assertIn("feed/vertical:", content)
            self.assertIn("alwaysAvailable: true", content)
        finally:
            stream_protection.MTX_CONFIG = old_conf
            if os.path.exists(conf_path):
                os.remove(conf_path)

class TestInstallationAndUpgradeOverwrite(unittest.TestCase):
    """
    Tests ensuring the clone and installation command cleanly updates existing clones
    and overwrites outdated install.sh and .install.sh files without throwing:
    'fatal: destination path already exists and is not an empty directory.'
    """

    def test_existing_instance_upgrade_cleanup_dot_install_sh(self):
        import tempfile
        import subprocess

        install_sh_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "install.sh"))
        with open(install_sh_path, "r") as f:
            content = f.read()
        func_body = content.split("handle_existing_instance_upgrade() {")[1].split("\n}\n")[0]
        func_script = f"handle_existing_instance_upgrade() {{\n{func_body}\n}}\nhandle_existing_instance_upgrade\n"

        with tempfile.TemporaryDirectory() as tmpdir:
            test_dir = os.path.join(tmpdir, "cookie-rtmps")
            os.makedirs(test_dir)
            dot_install = os.path.join(test_dir, ".install.sh")
            with open(dot_install, "w") as f:
                f.write("#!/bin/bash\necho old\n")

            # Execute handle_existing_instance_upgrade inside test_dir
            res = subprocess.run(["bash", "-c", func_script], cwd=test_dir, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)

            # Assert .install.sh has been cleaned up
            self.assertFalse(os.path.exists(dot_install))

    def test_install_command_seamless_overwrite(self):
        import tempfile
        import subprocess

        with tempfile.TemporaryDirectory() as tmpdir:
            # Set up a mock remote repository
            repo_dir = os.path.join(tmpdir, "remote_repo")
            os.makedirs(repo_dir)
            subprocess.run(["git", "init", "-b", "main"], cwd=repo_dir, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["git", "config", "user.name", "Tester"], cwd=repo_dir, check=True)
            subprocess.run(["git", "config", "user.email", "tester@example.com"], cwd=repo_dir, check=True)
            with open(os.path.join(repo_dir, "install.sh"), "w") as f:
                f.write("#!/bin/bash\necho v1\n")
            subprocess.run(["git", "add", "."], cwd=repo_dir, check=True)
            subprocess.run(["git", "commit", "-m", "v1"], cwd=repo_dir, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            # First run: fresh clone
            cmd = (
                f"(if [ -d cookie-rtmps/.git ]; then "
                f"(cd cookie-rtmps && git fetch origin && (git reset --hard origin/HEAD 2>/dev/null || git reset --hard origin/main 2>/dev/null || git pull)); "
                f"elif [ -d cookie-rtmps ]; then "
                f"(cd cookie-rtmps && git init && git remote add origin {repo_dir} 2>/dev/null || git remote set-url origin {repo_dir}; git fetch origin && (git reset --hard origin/main 2>/dev/null || git reset --hard origin/master 2>/dev/null)); "
                f"else git clone {repo_dir} cookie-rtmps; fi) && "
                f"cd cookie-rtmps && rm -f .install.sh && chmod +x install.sh"
            )
            res1 = subprocess.run(cmd, shell=True, cwd=tmpdir, capture_output=True, text=True)
            self.assertEqual(res1.returncode, 0)
            self.assertNotIn("already exists and is not an empty directory", res1.stderr)

            # User edits install.sh, adds a legacy .install.sh, adds config and data
            clone_dir = os.path.join(tmpdir, "cookie-rtmps")
            with open(os.path.join(clone_dir, "install.sh"), "w") as f:
                f.write("#!/bin/bash\necho modified-locally\n")
            with open(os.path.join(clone_dir, ".install.sh"), "w") as f:
                f.write("#!/bin/bash\necho legacy-hidden\n")
            with open(os.path.join(clone_dir, "rtmp_config.env"), "w") as f:
                f.write("STREAM_KEY=my_secret\n")
            os.makedirs(os.path.join(clone_dir, "data"), exist_ok=True)
            with open(os.path.join(clone_dir, "data", "brb_video.mp4"), "w") as f:
                f.write("mock_video_bytes")

            # Remote repo publishes v2
            with open(os.path.join(repo_dir, "install.sh"), "w") as f:
                f.write("#!/bin/bash\necho v2-updated\n")
            subprocess.run(["git", "commit", "-am", "v2"], cwd=repo_dir, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            # Second run: re-running install command on existing directory
            res2 = subprocess.run(cmd, shell=True, cwd=tmpdir, capture_output=True, text=True)
            self.assertEqual(res2.returncode, 0)
            self.assertNotIn("already exists and is not an empty directory", res2.stderr)

            # Verify that install.sh is cleanly updated to v2, .install.sh is removed, and user data/config is kept intact
            with open(os.path.join(clone_dir, "install.sh")) as f:
                self.assertIn("v2-updated", f.read())
            self.assertFalse(os.path.exists(os.path.join(clone_dir, ".install.sh")))
            with open(os.path.join(clone_dir, "rtmp_config.env")) as f:
                self.assertEqual(f.read().strip(), "STREAM_KEY=my_secret")
            with open(os.path.join(clone_dir, "data", "brb_video.mp4")) as f:
                self.assertEqual(f.read(), "mock_video_bytes")

if __name__ == "__main__":
    unittest.main()
