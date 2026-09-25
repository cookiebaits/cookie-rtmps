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

DEFAULT_BRB_URL = "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"

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
        self.brb_video_path = os.getenv("BRB_VIDEO_PATH", "/app/data/brb_video.mp4")
        self.brb_video_url = os.getenv("BRB_VIDEO_URL", "").strip() or DEFAULT_BRB_URL
        self.cloud_brb_timeout = int(os.getenv("CLOUD_BRB_TIMEOUT", 300))
        self.cloud_process = None
        self.cloud_brb_start_time = None

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

    def ensure_brb_video(self):
        """Ensures that the BRB video file exists and is valid. Downloads default if missing."""
        if os.path.exists(self.brb_video_path) and os.path.getsize(self.brb_video_path) > 0:
            return True

        url = self.brb_video_url or DEFAULT_BRB_URL
        os.makedirs(os.path.dirname(self.brb_video_path), exist_ok=True)
        logger.info(f"BRB video missing. Downloading from {url}...")
        try:
            response = requests.get(url, stream=True, timeout=30)
            if response.status_code == 200:
                with open(self.brb_video_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                logger.info(f"Downloaded BRB video to {self.brb_video_path}")
                return True
            else:
                logger.error(f"Failed to download BRB video: HTTP {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Error downloading BRB video: {e}")
            return False

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
                                    stream_name = stream.find('name')
                                    # Ignore Cloud BRB streams to avoid false source recovery
                                    if stream_name is not None and stream_name.text and stream_name.text.startswith('cloud_brb'):
                                        continue
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

        if not self.ensure_brb_video():
            logger.error(f"Cloud BRB video not available at {self.brb_video_path}")
            return

        logger.info("Starting Cloud BRB server-side video fallback stream...")
        # FFmpeg command to loop the video and push to local ingest points
        # Encodes with AAC stereo audio and H.264 video to guarantee compatibility with destination platforms
        cmd = [
            "ffmpeg", "-re", "-stream_loop", "-1", "-i", self.brb_video_path,
            "-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency",
            "-b:v", "3000k", "-maxrate", "3000k", "-bufsize", "3000k", "-sc_threshold", "0",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", "-b:a", "160k",
            "-f", "tee",
            f"[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/{self.app_name}/cloud_brb_loop|[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/vertical/cloud_brb_loop"
        ]
        try:
            self.cloud_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.cloud_brb_start_time = time.time()
            logger.info("Cloud BRB stream started successfully.")
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
            self.cloud_brb_start_time = None

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

        while True:
            bitrate = self.get_bitrate()

            if bitrate > 0:
                self.stop_cloud_brb()
                if not self.is_streaming:
                    logger.info(f"Stream detected at {bitrate}kbps.")
                    self.is_streaming = True

                if bitrate < self.low_threshold:
                    # Trigger immediately when bitrate drops below threshold
                    if not self.is_low:
                        logger.warning(f"Low bitrate ({bitrate}kbps) detected below threshold ({self.low_threshold}kbps). Immediately switching to {self.scene_brb}")
                        self.switch_scene(self.scene_brb)
                        if self.cloud_brb_enabled:
                            self.start_cloud_brb()
                        self.is_low = True
                else:
                    if bitrate >= self.restore_threshold and self.is_low:
                        logger.info(f"Bitrate restored ({bitrate}kbps). Switching to {self.scene_main}")
                        self.switch_scene(self.scene_main)
                        self.is_low = False
            else:
                if self.is_streaming or (not self.is_low and self.cloud_brb_enabled):
                    logger.warning("Source stream disconnected / 0 kbps. Immediately triggering BRB fallback protection.")
                    self.switch_scene(self.scene_brb)
                    if self.cloud_brb_enabled:
                        self.start_cloud_brb()
                    self.is_low = True
                    self.is_streaming = False

                # Monitor Cloud BRB timeout duration
                if self.cloud_process and self.cloud_brb_start_time:
                    elapsed = time.time() - self.cloud_brb_start_time
                    if elapsed >= self.cloud_brb_timeout:
                        logger.error(f"Cloud BRB protection timeout ({self.cloud_brb_timeout}s) reached without recovery. Terminating server fallback.")
                        self.stop_cloud_brb()
                        client = self.get_obs_client()
                        if client:
                            try:
                                client.stop_stream()
                            except Exception as e:
                                logger.error(f"Failed to stop OBS stream on timeout: {e}")
                        self.is_low = False
                        self.is_streaming = False

            time.sleep(2)

if __name__ == "__main__":
    Noalbs().run()
