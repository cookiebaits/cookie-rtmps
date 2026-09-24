import unittest
from unittest.mock import patch, MagicMock, call
import os
import sys
import time

# Add repo root to path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from noalbs.noalbs import Noalbs

class TestNoalbsComprehensive(unittest.TestCase):

    def setUp(self):
        os.environ["NOALBS_ENABLED"] = "true"
        os.environ["CLOUD_BRB"] = "true"
        os.environ["LOW_BITRATE"] = "1000"
        os.environ["RESTORE_BITRATE"] = "1500"
        os.environ["APP_NAME"] = "live"
        os.environ["OBS_SCENE_LIVE"] = "Main"
        os.environ["OBS_SCENE_BRB"] = "BRB"

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

    @patch("noalbs.noalbs.os.path.exists", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_custom_brb_video_path(self, mock_run, mock_popen, mock_exists):
        custom_path = "/tmp/my_custom_brb.mp4"
        os.environ["BRB_VIDEO_PATH"] = custom_path
        noalbs = Noalbs()
        self.assertEqual(noalbs.brb_video_path, custom_path)

        noalbs.start_cloud_brb()
        mock_popen.assert_called_once()
        cmd = mock_popen.call_args[0][0]
        self.assertIn("-stream_loop", cmd)
        self.assertIn("-1", cmd)
        self.assertIn(custom_path, cmd)

    @patch("noalbs.noalbs.os.path.exists", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_libx264_command(self, mock_run, mock_popen, mock_exists):
        mock_run.return_value = MagicMock(stdout="libx264")
        noalbs = Noalbs()
        noalbs.start_cloud_brb()

        mock_popen.assert_called_once()
        cmd = mock_popen.call_args[0][0]
        self.assertEqual(cmd[0], "ffmpeg")
        self.assertIn("-c:v", cmd)
        self.assertIn("libx264", cmd)
        
        # Verify optional audio map (-map 0:a?) and port 1935 target
        self.assertIn("-map", cmd)
        self.assertIn("0:a?", cmd)
        tee_target = cmd[-1]
        self.assertIn("rtmp://127.0.0.1:1935/live/cloud_brb_loop", tee_target)
        self.assertIn("rtmp://127.0.0.1:1935/vertical/cloud_brb_loop", tee_target)

    @patch("noalbs.noalbs.os.path.exists", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_restarts_crashed_process(self, mock_run, mock_popen, mock_exists):
        noalbs = Noalbs()
        crashed_proc = MagicMock()
        crashed_proc.poll.return_value = 1 # Process exited with error
        noalbs.cloud_process = crashed_proc

        noalbs.start_cloud_brb()
        mock_popen.assert_called_once()

    @patch("noalbs.noalbs.os.path.exists", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_start_cloud_brb_nvenc_command(self, mock_run, mock_popen, mock_exists):
        mock_run.return_value = MagicMock(stdout="h264_nvenc acceleration available")
        noalbs = Noalbs()
        noalbs.start_cloud_brb()

        cmd = mock_popen.call_args[0][0]
        self.assertIn("h264_nvenc", cmd)

    @patch("noalbs.noalbs.os.path.exists", return_value=False)
    @patch("subprocess.Popen")
    def test_start_cloud_brb_missing_video_file(self, mock_popen, mock_exists):
        noalbs = Noalbs()
        noalbs.start_cloud_brb()
        mock_popen.assert_not_called()

    @patch("noalbs.noalbs.os.path.exists", return_value=True)
    @patch("subprocess.Popen")
    def test_stop_cloud_brb(self, mock_popen, mock_exists):
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

    @patch("noalbs.noalbs.os.path.exists", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    @patch("requests.get")
    def test_disconnection_protection_simulation(self, mock_get, mock_run, mock_popen, mock_exists):
        mock_run.return_value = MagicMock(stdout="libx264")
        noalbs = Noalbs()
        mock_obs = MagicMock()

        # Simulate OBS returning outputActive = False when stream drops
        status_mock = MagicMock()
        status_mock.outputActive = False
        status_mock.output_active = False
        mock_obs.get_stream_status.return_value = status_mock
        noalbs.obs_client = mock_obs

        # Step 1: Active streaming
        noalbs.is_streaming = True

        # Step 2: Ingest stream disconnects (bitrate = 0)
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = self.make_stat_xml(live_bw=0)
        mock_get.return_value = mock_resp

        # Run logic when bitrate is 0
        bitrate = noalbs.get_bitrate()
        self.assertEqual(bitrate, 0)

        # Disconnection handling block simulation
        if bitrate == 0 and noalbs.is_streaming:
            client = noalbs.get_obs_client()
            is_obs_streaming = True
            if client:
                status = client.get_stream_status()
                is_obs_streaming = getattr(status, 'output_active', getattr(status, 'outputActive', True))

            if is_obs_streaming or noalbs.cloud_brb_enabled:
                noalbs.switch_scene(noalbs.scene_brb)
                noalbs.is_low = True
                if noalbs.cloud_brb_enabled:
                    noalbs.start_cloud_brb()
            else:
                noalbs.is_low = False
            noalbs.is_streaming = False

        # Assertions
        mock_obs.set_current_program_scene.assert_called_with("BRB")
        mock_popen.assert_called_once()
        self.assertFalse(noalbs.is_streaming)
        self.assertTrue(noalbs.is_low)
        self.assertIsNotNone(noalbs.cloud_process)

    @patch("noalbs.noalbs.os.path.exists", return_value=True)
    @patch("subprocess.Popen")
    @patch("subprocess.run")
    def test_timeout_300s_stops_cloud_brb(self, mock_run, mock_popen, mock_exists):
        noalbs = Noalbs()
        mock_proc = MagicMock()
        mock_proc.poll.return_value = None
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
