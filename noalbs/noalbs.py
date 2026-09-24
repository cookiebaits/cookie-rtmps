import requests
import time
import os
import logging
import xml.etree.ElementTree as ET
import obsws_python as obs
import subprocess
import signal

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("NOALBS")

class Noalbs:
    def __init__(self):
        self.enabled = os.getenv("NOALBS_ENABLED", "false").lower() == "true"
        self.low_threshold = int(os.getenv("LOW_BITRATE", 1000))
        self.restore_threshold = int(os.getenv("RESTORE_BITRATE", 1500))
        self.obs_host = os.getenv("OBS_WS_HOST", "127.0.0.1")
        self.obs_port = int(os.getenv("OBS_WS_PORT", 4455))
        self.obs_password = os.getenv("OBS_WS_PASSWORD", "")
        self.scene_main = os.getenv("OBS_SCENE_LIVE", "Main")
        self.scene_brb = os.getenv("OBS_SCENE_BRB", "BRB")
        self.app_name = os.getenv("APP_NAME", "live")
        # NOALBS uses internal port 8081 for stats
        self.stats_url = "http://127.0.0.1:8081/stat"

        self.cloud_brb_enabled = os.getenv("CLOUD_BRB", "false").lower() == "true"
        self.brb_video_path = "/app/data/brb_video.mp4"
        self.cloud_process = None

        self.is_low = False
        self.is_streaming = False
        self.obs_client = None

    def get_obs_client(self):
        if self.obs_client:
            return self.obs_client
        try:
            # Using ReqClient for scene switching
            self.obs_client = obs.ReqClient(host=self.obs_host, port=self.obs_port, password=self.obs_password, timeout=3)
            return self.obs_client
        except Exception as e:
            logger.error(f"Failed to connect to OBS: {e}")
            self.obs_client = None
            return None

    def get_bitrate(self):
        try:
            r = requests.get(self.stats_url, timeout=5)
            if r.status_code != 200:
                return 0

            root = ET.fromstring(r.text)
            total_bitrate = 0
            # Monitor both horizontal (app_name) and vertical applications
            for app in root.findall('.//application'):
                app_name_node = app.find('name')
                if app_name_node is not None:
                    app_name_text = app_name_node.text
                    if app_name_text == self.app_name or app_name_text == "vertical":
                        live = app.find('live')
                        if live is not None:
                            for stream in live.findall('stream'):
                                if stream.find('publishing') is not None:
                                    bw_in = stream.find('bw_in')
                                    if bw_in is not None:
                                        # Convert bytes/s to kbps
                                        total_bitrate += int(int(bw_in.text) * 8 / 1024)
            return total_bitrate
        except Exception as e:
            logger.debug(f"Bitrate fetch error: {e}")
            return 0

    def start_cloud_brb(self):
        if not self.cloud_brb_enabled or self.cloud_process:
            return

        if not os.path.exists(self.brb_video_path):
            logger.error(f"Cloud BRB video not found at {self.brb_video_path}")
            return

        logger.info("Starting Cloud BRB stream...")
        # FFmpeg command to loop the video and push to the local ingest
        # This keeps the stream alive at the ingest points if the source drops
        cmd = [
            "ffmpeg", "-re", "-stream_loop", "-1", "-i", self.brb_video_path,
            "-c:v", "libx264", "-preset", "veryfast", "-tune", "zerolatency",
            "-b:v", "1500k", "-maxrate", "1500k", "-bufsize", "3000k",
            "-f", "flv", f"rtmp://127.0.0.1:1935/{self.app_name}/cloud_brb_loop"
        ]
        try:
            self.cloud_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            logger.error(f"Failed to start Cloud BRB process: {e}")

    def stop_cloud_brb(self):
        if self.cloud_process:
            logger.info("Stopping Cloud BRB stream.")
            self.cloud_process.terminate()
            try:
                self.cloud_process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.cloud_process.kill()
            self.cloud_process = None

    def switch_scene(self, scene):
        client = self.get_obs_client()
        if not client:
            return
        try:
            client.set_current_program_scene(scene)
            logger.info(f"Successfully switched OBS scene to: {scene}")
        except Exception as e:
            logger.error(f"OBS WebSocket Switch Error: {e}")
            self.obs_client = None # Force reconnect next time

    def run(self):
        if not self.enabled:
            logger.info("NOALBS is disabled.")
            return

        logger.info(f"NOALBS Started. Monitoring {self.app_name} & vertical on {self.stats_url}")

        consecutive_low = 0
        while True:
            bitrate = self.get_bitrate()

            if bitrate > 0:
                self.stop_cloud_brb()
                if not self.is_streaming:
                    logger.info(f"Stream detected at {bitrate}kbps.")
                    self.is_streaming = True

                if bitrate < self.low_threshold:
                    consecutive_low += 1
                    if consecutive_low >= 3 and not self.is_low:
                        logger.warning(f"Low bitrate ({bitrate}kbps) for 6s. Switching to {self.scene_brb}")
                        self.switch_scene(self.scene_brb)
                        self.is_low = True
                else:
                    consecutive_low = 0
                    if bitrate >= self.restore_threshold and self.is_low:
                        logger.info(f"Bitrate restored ({bitrate}kbps). Switching to {self.scene_main}")
                        self.switch_scene(self.scene_main)
                        self.is_low = False
            else:
                consecutive_low = 0
                if self.is_streaming:
                    client = self.get_obs_client()
                    # Default to True if we can't connect, assuming a severe network drop
                    is_obs_streaming = True
                    if client:
                        try:
                            status = client.get_stream_status()
                            is_obs_streaming = getattr(status, 'output_active', True)
                        except Exception as e:
                            logger.error(f"Failed to get OBS stream status: {e}")
                            # If connection fails, assume it's a disconnect (network drop)
                            is_obs_streaming = True
                    else:
                        logger.warning("Could not connect to OBS. Assuming network drop.")
                        is_obs_streaming = True

                    if is_obs_streaming:
                        logger.warning("Source stream disconnected but OBS is still streaming (or unreachable). Switching to BRB scene.")
                        self.switch_scene(self.scene_brb)
                        self.is_low = True
                        if self.cloud_brb_enabled:
                            self.start_cloud_brb()
                    else:
                        logger.info("Source stream ended cleanly.")
                        self.is_low = False

                    self.is_streaming = False

            time.sleep(2)

if __name__ == "__main__":
    Noalbs().run()
