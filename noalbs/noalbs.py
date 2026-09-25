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
        self.enabled = os.getenv("NOALBS_ENABLED", "true").lower() == "true"
        self.low_threshold = int(os.getenv("LOW_BITRATE", 1000))
        self.restore_threshold = int(os.getenv("RESTORE_BITRATE", 1500))
        self.obs_host = os.getenv("OBS_WS_HOST", "127.0.0.1")
        self.obs_port = int(os.getenv("OBS_WS_PORT", 4455))
        self.obs_password = os.getenv("OBS_WS_PASSWORD", "")
        self.scene_main = os.getenv("OBS_SCENE_LIVE", "Main")
        self.scene_brb = os.getenv("OBS_SCENE_BRB", "BRB")
        self.app_name = os.getenv("APP_NAME", "live")
        # Internal port 8081 for stats
        self.stats_url = "http://127.0.0.1:8081/stat"

        self.cloud_brb_enabled = os.getenv("CLOUD_BRB", "true").lower() == "true"
        self.brb_video_url = os.getenv("BRB_VIDEO_URL", "").strip() or DEFAULT_BRB_URL
        self.brb_video_path = os.getenv("BRB_VIDEO_PATH", "/app/data/brb_video.mp4")
        self.cloud_brb_timeout = int(os.getenv("CLOUD_BRB_TIMEOUT", 300))

        self.cloud_process = None
        self.cloud_brb_start_time = None

        self.is_low = False
        self.is_streaming = False
        self.obs_client = None

    def ensure_brb_video(self):
        """Ensures the BRB video exists, is downloaded, and is compatible with FFmpeg/AAC."""
        os.makedirs(os.path.dirname(self.brb_video_path), exist_ok=True)

        if not os.path.exists(self.brb_video_path) or os.path.getsize(self.brb_video_path) == 0:
            logger.info(f"Downloading BRB fallback video from: {self.brb_video_url}")
            temp_path = self.brb_video_path + ".tmp"
            try:
                r = requests.get(self.brb_video_url, stream=True, timeout=30)
                r.raise_for_status()
                with open(temp_path, 'wb') as f:
                    for chunk in r.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                os.rename(temp_path, self.brb_video_path)
                logger.info(f"Downloaded BRB video to {self.brb_video_path}")
            except Exception as e:
                logger.error(f"Failed to download BRB video: {e}")
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                return False

        # Verify FFmpeg & AAC compatibility
        return self.verify_and_transcode_video()

    def verify_and_transcode_video(self):
        """Verifies if video is valid H.264/AAC. If not, transcodes it to an RTMP compliant video."""
        if not os.path.exists(self.brb_video_path) or os.path.getsize(self.brb_video_path) == 0:
            return False

        # Check with ffprobe
        probe_cmd = [
            "ffprobe", "-v", "error", "-show_entries",
            "stream=codec_name", "-of", "default=noprintwrappers=1:nokey=1", self.brb_video_path
        ]
        try:
            res = subprocess.run(probe_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
            codecs = res.stdout.strip().splitlines()
            if "h264" in codecs and "aac" in codecs:
                return True
        except Exception as e:
            logger.warning(f"ffprobe check failed: {e}")

        # If not H.264 + AAC or probe failed, transcode
        logger.info(f"Transcoding {self.brb_video_path} into RTMP compliant H.264/AAC format...")
        transcoded_path = self.brb_video_path + ".transcoded.mp4"
        transcode_cmd = [
            "ffmpeg", "-y", "-i", self.brb_video_path,
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "60",
            "-c:a", "aac", "-ac", "2", "-ar", "48000",
            transcoded_path
        ]
        try:
            res = subprocess.run(transcode_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
            if res.returncode == 0 and os.path.exists(transcoded_path) and os.path.getsize(transcoded_path) > 0:
                os.replace(transcoded_path, self.brb_video_path)
                logger.info("BRB video successfully transcoded and verified.")
                return True
            else:
                logger.error("FFmpeg transcode failed.")
                if os.path.exists(transcoded_path):
                    os.remove(transcoded_path)
                return False
        except Exception as e:
            logger.error(f"Transcode error: {e}")
            if os.path.exists(transcoded_path):
                os.remove(transcoded_path)
            return False

    def get_obs_client(self):
        if self.obs_client:
            return self.obs_client
        try:
            self.obs_client = obs.ReqClient(host=self.obs_host, port=self.obs_port, password=self.obs_password, timeout=3)
            return self.obs_client
        except Exception as e:
            logger.error(f"Failed to connect to OBS: {e}")
            self.obs_client = None
            return None

    def get_bitrate(self):
        """Fetches total active source bitrate, excluding internal cloud_brb streams."""
        try:
            r = requests.get(self.stats_url, timeout=5)
            if r.status_code != 200:
                return 0

            root = ET.fromstring(r.text)
            total_bitrate = 0
            for app in root.findall('.//application'):
                app_name_node = app.find('name')
                if app_name_node is not None:
                    app_name_text = app_name_node.text
                    if app_name_text == self.app_name or app_name_text == "vertical":
                        live = app.find('live')
                        if live is not None:
                            for stream in live.findall('stream'):
                                name_node = stream.find('name')
                                # Ignore internal cloud_brb streams when calculating source bitrate
                                if name_node is not None and name_node.text and name_node.text.startswith('cloud_brb'):
                                    continue

                                if stream.find('publishing') is not None:
                                    bw_in = stream.find('bw_in')
                                    if bw_in is not None:
                                        total_bitrate += int(int(bw_in.text) * 8 / 1024)
            return total_bitrate
        except Exception as e:
            logger.debug(f"Bitrate fetch error: {e}")
            return 0

    def start_cloud_brb(self):
        if not self.cloud_brb_enabled or self.cloud_process:
            return

        if not self.ensure_brb_video():
            logger.error("Cloud BRB video is not ready or failed verification.")
            return

        logger.info("Process of noalbs taking over: Starting server-side Cloud BRB stream...")

        # Dual stream push via tee muxer to both main and vertical apps
        cmd = [
            "ffmpeg", "-re", "-stream_loop", "-1",
            "-fflags", "+nobuffer", "-flags", "+low_delay",
            "-i", self.brb_video_path,
            "-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency",
            "-b:v", "3000k", "-maxrate", "3000k", "-bufsize", "3000k", "-g", "60", "-sc_threshold", "0",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", "-b:a", "160k",
            "-thread_queue_size", "1024", "-max_muxing_queue_size", "1024",
            "-f", "tee", "-map", "0:v", "-map", "0:a",
            f"[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/{self.app_name}/cloud_brb_loop|[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/vertical/cloud_brb_loop"
        ]
        try:
            self.cloud_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.cloud_brb_start_time = time.time()
            logger.info("Cloud BRB process started successfully.")
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
            logger.info(f"Process of noalbs taking over: Successfully switched OBS scene to: {scene}")
        except Exception as e:
            logger.error(f"OBS WebSocket Switch Error: {e}")
            self.obs_client = None

    def run(self):
        if not self.enabled:
            logger.info("NOALBS is disabled.")
            return

        logger.info(f"NOALBS Started. Monitoring {self.app_name} & vertical on {self.stats_url}")

        while True:
            bitrate = self.get_bitrate()

            # Source stream active and above threshold
            if bitrate >= self.restore_threshold:
                if self.is_low or self.cloud_process:
                    logger.info(f"Bitrate restored ({bitrate}kbps >= {self.restore_threshold}kbps). Restoring stream state.")
                    self.stop_cloud_brb()
                    self.switch_scene(self.scene_main)
                    self.is_low = False

                if not self.is_streaming:
                    logger.info(f"Stream detected at {bitrate}kbps.")
                    self.is_streaming = True

            # Bitrate below threshold or completely 0 (stream disruption)
            elif bitrate < self.low_threshold:
                if self.is_streaming or self.cloud_process or bitrate > 0:
                    if not self.is_low:
                        logger.error(f"Stream disruption / Low bitrate detected ({bitrate}kbps < {self.low_threshold}kbps). Immediate takeover!")
                        self.switch_scene(self.scene_brb)
                        if self.cloud_brb_enabled:
                            self.start_cloud_brb()
                        self.is_low = True

                    # Monitor Disconnection Protection Timeout while Cloud BRB is running
                    if self.cloud_process and self.cloud_brb_start_time:
                        elapsed = time.time() - self.cloud_brb_start_time
                        if elapsed > self.cloud_brb_timeout:
                            logger.error(f"Cloud BRB protection timeout reached ({int(elapsed)}s > {self.cloud_brb_timeout}s). Stopping broadcast.")
                            self.stop_cloud_brb()
                            self.is_streaming = False
                            self.is_low = False

            time.sleep(2)

if __name__ == "__main__":
    Noalbs().run()
