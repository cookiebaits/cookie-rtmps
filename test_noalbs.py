import unittest
from unittest.mock import patch, MagicMock
import os
import sys
import time
import xml.etree.ElementTree as ET

# Ensure /app or current directory is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), 'noalbs')))
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from noalbs.noalbs import Noalbs, DEFAULT_BRB_URL

class TestNoalbs(unittest.TestCase):
    def setUp(self):
        os.environ["NOALBS_ENABLED"] = "true"
        os.environ["LOW_BITRATE"] = "1000"
        os.environ["RESTORE_BITRATE"] = "1500"
        os.environ["CLOUD_BRB"] = "true"
        os.environ["CLOUD_BRB_TIMEOUT"] = "300"
        os.environ["BRB_VIDEO_URL"] = ""
        os.environ["BRB_VIDEO_PATH"] = "/tmp/test_brb_video.mp4"

    def tearDown(self):
        if os.path.exists("/tmp/test_brb_video.mp4"):
            try:
                os.remove("/tmp/test_brb_video.mp4")
            except OSError:
                pass

    def test_default_video_url_fallback(self):
        noalbs_inst = Noalbs()
        self.assertEqual(noalbs_inst.brb_video_url, DEFAULT_BRB_URL)
        self.assertEqual(noalbs_inst.cloud_brb_timeout, 300)

    def test_ensure_brb_video_existing_file(self):
        with open("/tmp/test_brb_video.mp4", "w") as f:
            f.write("dummy video data")
        noalbs_inst = Noalbs()
        self.assertTrue(noalbs_inst.ensure_brb_video())

    @patch("requests.get")
    def test_ensure_brb_video_download_success(self, mock_get):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.iter_content.return_value = [b"chunk1", b"chunk2"]
        mock_get.return_value = mock_response

        noalbs_inst = Noalbs()
        res = noalbs_inst.ensure_brb_video()
        self.assertTrue(res)
        self.assertTrue(os.path.exists("/tmp/test_brb_video.mp4"))
        with open("/tmp/test_brb_video.mp4", "rb") as f:
            self.assertEqual(f.read(), b"chunk1chunk2")

    @patch("noalbs.noalbs.requests.get")
    def test_get_bitrate_ignores_cloud_brb(self, mock_get):
        xml_data = """<?xml version="1.0" encoding="utf-8" ?>
        <rtmp>
            <server>
                <application>
                    <name>live</name>
                    <live>
                        <stream>
                            <name>obs_key_123</name>
                            <publishing></publishing>
                            <bw_in>256000</bw_in>
                        </stream>
                        <stream>
                            <name>cloud_brb_loop</name>
                            <publishing></publishing>
                            <bw_in>384000</bw_in>
                        </stream>
                    </live>
                </application>
            </server>
        </rtmp>
        """
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.text = xml_data
        mock_get.return_value = mock_response

        noalbs_inst = Noalbs()
        # 256000 bytes/s * 8 / 1024 = 2000 kbps (cloud_brb_loop should be ignored)
        bitrate = noalbs_inst.get_bitrate()
        self.assertEqual(bitrate, 2000)

    @patch.object(Noalbs, "switch_scene")
    @patch.object(Noalbs, "start_cloud_brb")
    @patch.object(Noalbs, "get_bitrate")
    def test_immediate_low_bitrate_trigger(self, mock_get_bitrate, mock_start_brb, mock_switch_scene):
        mock_get_bitrate.side_effect = [500] # Immediately low
        noalbs_inst = Noalbs()
        noalbs_inst.is_streaming = True

        # Simulate 1 loop check
        bitrate = noalbs_inst.get_bitrate()
        if bitrate < noalbs_inst.low_threshold and not noalbs_inst.is_low:
            noalbs_inst.switch_scene(noalbs_inst.scene_brb)
            if noalbs_inst.cloud_brb_enabled:
                noalbs_inst.start_cloud_brb()
            noalbs_inst.is_low = True

        mock_switch_scene.assert_called_once_with(noalbs_inst.scene_brb)
        mock_start_brb.assert_called_once()
        self.assertTrue(noalbs_inst.is_low)

    @patch.object(Noalbs, "stop_cloud_brb")
    def test_cloud_brb_timeout(self, mock_stop_brb):
        noalbs_inst = Noalbs()
        noalbs_inst.cloud_process = MagicMock()
        noalbs_inst.cloud_brb_start_time = time.time() - 350 # Elapsed 350s > 300s timeout
        noalbs_inst.cloud_brb_timeout = 300

        elapsed = time.time() - noalbs_inst.cloud_brb_start_time
        if elapsed >= noalbs_inst.cloud_brb_timeout:
            noalbs_inst.stop_cloud_brb()

        mock_stop_brb.assert_called_once()

if __name__ == "__main__":
    unittest.main()
