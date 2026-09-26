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

# Add repo root to path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from noalbs.noalbs import Noalbs

class TestNoalbsComprehensive(unittest.TestCase):

    def setUp(self):
        os.environ["NOALBS_ENABLED"] = "true"
        os.environ["FALLBACK_MODE"] = "video"
        os.environ["CLOUD_BRB"] = "true"
        os.environ["LOW_BITRATE"] = "1000"
        os.environ["RESTORE_BITRATE"] = "1500"
        os.environ["APP_NAME"] = "live"
        os.environ["OBS_SCENE_LIVE"] = "Main"
        os.environ["OBS_SCENE_BRB"] = "BRB"
        os.environ["CLOUD_BRB_TIMEOUT"] = "300"

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
        noalbs = Noalbs()

        # 5000 kbps live = 640000 B/s, 2000 kbps vert = 256000 B/s
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = self.make_stat_xml(live_bw=640000, vert_bw=256000, include_cloud_brb=True)
        mock_get.return_value = mock_resp

        bitrate = noalbs.get_bitrate()
        # Should sum live + vertical (7000 kbps) and ignore cloud_brb_loop
        self.assertEqual(bitrate, 7000)

    @patch("requests.get", side_effect=Exception("Connection refused"))
    def test_get_bitrate_handles_network_error(self, mock_get):
        noalbs = Noalbs()
        bitrate = noalbs.get_bitrate()
        self.assertEqual(bitrate, 0)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_libx264_command(self, mock_run, mock_popen, mock_is_valid):
        mock_run.return_value = MagicMock(stdout="libx264")
        noalbs = Noalbs()
        noalbs.start_cloud_brb()

        mock_popen.assert_called_once()
        cmd = mock_popen.call_args[0][0]
        self.assertEqual(cmd[0], "ffmpeg")
        self.assertIn("-c:v", cmd)
        self.assertIn("libx264", cmd)
        
        # Verify optional audio map (-map 0:a?) and port 19352 target
        self.assertIn("-map", cmd)
        self.assertIn("0:a?", cmd)
        tee_target = cmd[-1]
        self.assertIn("rtmp://127.0.0.1:19352/live/cloud_brb_loop", tee_target)
        self.assertIn("rtmp://127.0.0.1:19352/vertical/cloud_brb_loop", tee_target)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_restarts_crashed_process(self, mock_run, mock_popen, mock_is_valid):
        noalbs = Noalbs()
        crashed_proc = MagicMock()
        crashed_proc.poll.return_value = 1 # Process exited with error
        noalbs.cloud_process = crashed_proc

        noalbs.start_cloud_brb()
        mock_popen.assert_called_once()

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_nvenc_command(self, mock_run, mock_popen, mock_is_valid):
        mock_run.return_value = MagicMock(stdout="h264_nvenc acceleration available")
        noalbs = Noalbs()
        noalbs.start_cloud_brb()

        cmd = mock_popen.call_args[0][0]
        self.assertIn("h264_nvenc", cmd)

    @patch("noalbs.noalbs.is_valid_file", return_value=False)
    @patch("subprocess.Popen")
    @patch.object(Noalbs, "ensure_brb_video_ready")
    def test_start_cloud_brb_missing_video_file(self, mock_ensure, mock_popen, mock_is_valid):
        noalbs = Noalbs()
        noalbs.start_cloud_brb()
        mock_ensure.assert_called_once()

    @patch("noalbs.noalbs.urllib.request.urlretrieve")
    @patch("subprocess.run")
    @patch("noalbs.noalbs.is_valid_file")
    def test_ensure_brb_video_ready_downloads_default_and_transcodes(self, mock_is_valid, mock_run, mock_urlretrieve):
        # File missing initially (False), then present after download/transcode (True)
        mock_is_valid.side_effect = [False, True, True, True]
        mock_run.return_value = MagicMock(returncode=0)

        noalbs = Noalbs()
        noalbs.ensure_brb_video_ready()

        mock_urlretrieve.assert_called_once()
        downloaded_url = mock_urlretrieve.call_args[0][0]
        self.assertEqual(downloaded_url, "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4")

        # Verify FFmpeg transcode call included AAC audio and H.264
        mock_run.assert_called_once()
        ffmpeg_cmd = mock_run.call_args[0][0]
        self.assertEqual(ffmpeg_cmd[0], "ffmpeg")
        self.assertIn("libx264", ffmpeg_cmd)
        self.assertIn("aac", ffmpeg_cmd)

    def test_cloud_brb_timeout_env_config(self):
        os.environ["CLOUD_BRB_TIMEOUT"] = "600"
        noalbs = Noalbs()
        self.assertEqual(noalbs.cloud_brb_timeout, 600)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    def test_stop_cloud_brb(self, mock_popen, mock_is_valid):
        noalbs = Noalbs()
        mock_proc = MagicMock()
        noalbs.cloud_process = mock_proc
        noalbs.cloud_brb_start_time = time.time()

        noalbs.stop_cloud_brb()
        self.assertIsNone(noalbs.cloud_process)
        self.assertIsNone(noalbs.cloud_brb_start_time)

    def test_switch_scene_includes_aitum_vertical(self):
        noalbs = Noalbs()
        mock_client = MagicMock()
        noalbs.obs_client = mock_client

        noalbs.switch_scene("BRB")
        mock_client.set_current_program_scene.assert_called_with("BRB")
        mock_client.call_vendor_request.assert_called_with("aitum-vertical-canvas", "switch_scene", {"scene": "BRB"})

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    @patch("requests.get")
    def test_disconnection_protection_simulation_video_mode(self, mock_get, mock_run, mock_popen, mock_is_valid):
        mock_run.return_value = MagicMock(stdout="libx264")
        os.environ["FALLBACK_MODE"] = "video"
        noalbs = Noalbs()
        mock_obs = MagicMock()

        status_mock = MagicMock()
        status_mock.outputActive = False
        status_mock.output_active = False
        mock_obs.get_stream_status.return_value = status_mock
        noalbs.obs_client = mock_obs

        noalbs.is_streaming = True

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = self.make_stat_xml(live_bw=0)
        mock_get.return_value = mock_resp

        bitrate = noalbs.get_bitrate()
        self.assertEqual(bitrate, 0)

        if bitrate == 0 and noalbs.is_streaming:
            client = noalbs.get_obs_client()
            is_obs_streaming = True
            if client:
                status = client.get_stream_status()
                is_obs_streaming = getattr(status, 'output_active', getattr(status, 'outputActive', True))

            if is_obs_streaming or noalbs.cloud_brb_enabled:
                noalbs.is_low = True
                if noalbs.fallback_mode == "obs":
                    noalbs.switch_scene(noalbs.scene_brb)
                else:
                    if noalbs.cloud_brb_enabled:
                        noalbs.start_cloud_brb()
            else:
                noalbs.is_low = False
            noalbs.is_streaming = False

        # Assertions: Video fallback triggered, OBS scene NOT switched
        mock_obs.set_current_program_scene.assert_not_called()
        mock_popen.assert_called_once()
        self.assertFalse(noalbs.is_streaming)
        self.assertTrue(noalbs.is_low)
        self.assertIsNotNone(noalbs.cloud_process)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    @patch("requests.get")
    def test_disconnection_protection_simulation_obs_mode(self, mock_get, mock_run, mock_popen, mock_is_valid):
        mock_run.return_value = MagicMock(stdout="libx264")
        os.environ["FALLBACK_MODE"] = "obs"
        noalbs = Noalbs()
        mock_obs = MagicMock()

        status_mock = MagicMock()
        status_mock.outputActive = False
        status_mock.output_active = False
        mock_obs.get_stream_status.return_value = status_mock
        noalbs.obs_client = mock_obs

        noalbs.is_streaming = True

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = self.make_stat_xml(live_bw=0)
        mock_get.return_value = mock_resp

        bitrate = noalbs.get_bitrate()
        self.assertEqual(bitrate, 0)

        if bitrate == 0 and noalbs.is_streaming:
            client = noalbs.get_obs_client()
            is_obs_streaming = True
            if client:
                status = client.get_stream_status()
                is_obs_streaming = getattr(status, 'output_active', getattr(status, 'outputActive', True))

            if is_obs_streaming or noalbs.cloud_brb_enabled:
                noalbs.is_low = True
                if noalbs.fallback_mode == "obs":
                    noalbs.switch_scene(noalbs.scene_brb)
                else:
                    if noalbs.cloud_brb_enabled:
                        noalbs.start_cloud_brb()
            else:
                noalbs.is_low = False
            noalbs.is_streaming = False

        # Assertions: OBS scene switched, Video fallback NOT started
        mock_obs.set_current_program_scene.assert_called_with("BRB")
        mock_popen.assert_not_called()
        self.assertFalse(noalbs.is_streaming)
        self.assertTrue(noalbs.is_low)
        self.assertIsNone(noalbs.cloud_process)

    @patch("noalbs.noalbs.is_valid_file", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_timeout_300s_stops_cloud_brb(self, mock_run, mock_popen, mock_is_valid):
        noalbs = Noalbs()
        mock_proc = MagicMock()
        mock_proc.poll = MagicMock(return_value=None)
        noalbs.cloud_process = mock_proc
        noalbs.cloud_brb_start_time = time.time() - 301 # Elapsed > 300s
        
        mock_obs = MagicMock()
        noalbs.obs_client = mock_obs

        # Run timeout check
        if noalbs.cloud_process and noalbs.cloud_brb_start_time:
            if noalbs.cloud_process.poll() is not None:
                noalbs.cloud_process = None
                noalbs.start_cloud_brb()

            elapsed = time.time() - noalbs.cloud_brb_start_time
            if elapsed >= noalbs.cloud_brb_timeout:
                noalbs.stop_cloud_brb()
                client = noalbs.get_obs_client()
                if client:
                    client.stop_stream()

        self.assertIsNone(noalbs.cloud_process)
        mock_obs.stop_stream.assert_called_once()

if __name__ == "__main__":
    unittest.main()
