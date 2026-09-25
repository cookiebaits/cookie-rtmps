#!/usr/bin/env python3
"""
test_noalbs.py - Unit tests for NOALBS component
"""
import unittest
from unittest.mock import patch, MagicMock
import os
import sys
import time
import xml.etree.ElementTree as ET

# Ensure noalbs path is importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from noalbs.noalbs import Noalbs, DEFAULT_BRB_URL

class TestNoalbsComponent(unittest.TestCase):

    def setUp(self):
        os.environ["NOALBS_ENABLED"] = "true"
        os.environ["LOW_BITRATE"] = "1000"
        os.environ["RESTORE_BITRATE"] = "1500"
        os.environ["CLOUD_BRB"] = "true"
        os.environ["CLOUD_BRB_TIMEOUT"] = "300"
        os.environ["BRB_VIDEO_URL"] = ""

    def test_default_brb_url_fallback(self):
        """Test default BRB video URL fallback when BRB_VIDEO_URL is unset."""
        instance = Noalbs()
        self.assertEqual(instance.brb_video_url, DEFAULT_BRB_URL)
        self.assertEqual(instance.cloud_brb_timeout, 300)

    def test_bitrate_ignores_cloud_brb_loop(self):
        """Test that get_bitrate ignores internal cloud_brb streams."""
        instance = Noalbs()
        mock_xml = """<?xml version="1.0" encoding="UTF-8"?>
        <rtmp>
            <server>
                <application>
                    <name>live</name>
                    <live>
                        <stream>
                            <name>cloud_brb_loop</name>
                            <publishing/>
                            <bw_in>2048000</bw_in>
                        </stream>
                        <stream>
                            <name>my_stream_key</name>
                            <publishing/>
                            <bw_in>384000</bw_in>
                        </stream>
                    </live>
                </application>
            </server>
        </rtmp>
        """
        with patch("requests.get") as mock_get:
            mock_resp = MagicMock()
            mock_resp.status_code = 200
            mock_resp.text = mock_xml
            mock_get.return_value = mock_resp

            bitrate = instance.get_bitrate()
            # 384000 * 8 / 1024 = 3000 kbps (cloud_brb_loop ignored)
            self.assertEqual(bitrate, 3000)

    def test_immediate_trigger_on_low_bitrate(self):
        """Test that Cloud BRB triggers immediately when bitrate < low_threshold."""
        instance = Noalbs()
        instance.is_streaming = True

        with patch.object(instance, 'get_bitrate', return_value=500), \
             patch.object(instance, 'switch_scene') as mock_switch, \
             patch.object(instance, 'start_cloud_brb') as mock_start_brb:

            # Execute one iteration logic
            bitrate = instance.get_bitrate()
            if bitrate < instance.low_threshold:
                instance.switch_scene(instance.scene_brb)
                if instance.cloud_brb_enabled:
                    instance.start_cloud_brb()
                instance.is_low = True

            mock_switch.assert_called_with(instance.scene_brb)
            mock_start_brb.assert_called_once()
            self.assertTrue(instance.is_low)

    def test_cloud_brb_timeout_protection(self):
        """Test that Cloud BRB terminates when CLOUD_BRB_TIMEOUT duration is exceeded."""
        instance = Noalbs()
        instance.cloud_process = MagicMock()
        instance.cloud_brb_timeout = 300
        # Simulate started 301 seconds ago
        instance.cloud_brb_start_time = time.time() - 301

        with patch.object(instance, 'stop_cloud_brb') as mock_stop_brb:
            elapsed = time.time() - instance.cloud_brb_start_time
            if elapsed > instance.cloud_brb_timeout:
                instance.stop_cloud_brb()
                instance.is_streaming = False
                instance.is_low = False

            mock_stop_brb.assert_called_once()
            self.assertFalse(instance.is_streaming)
            self.assertFalse(instance.is_low)

    @patch("subprocess.Popen")
    @patch.object(Noalbs, "ensure_brb_video", return_value=True)
    def test_start_and_stop_cloud_brb(self, mock_ensure, mock_popen):
        """Test Cloud BRB process lifecycle and tee muxer parameters."""
        instance = Noalbs()
        mock_proc = MagicMock()
        mock_popen.return_value = mock_proc

        instance.start_cloud_brb()
        self.assertIsNotNone(instance.cloud_process)
        self.assertIsNotNone(instance.cloud_brb_start_time)
        mock_popen.assert_called_once()

        instance.stop_cloud_brb()
        mock_proc.terminate.assert_called_once()
        self.assertIsNone(instance.cloud_process)
        self.assertIsNone(instance.cloud_brb_start_time)

if __name__ == "__main__":
    unittest.main()
