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
        self.stats_url = "http://127.0.0.1:8081/stat"

        self.cloud_brb_enabled = os.getenv("CLOUD_BRB", "false").lower() == "true"
        self.cloud_brb_timeout = int(os.getenv("CLOUD_BRB_TIMEOUT", 300))
        self.brb_video_path = os.getenv("BRB_VIDEO_PATH", "/app/data/brb_video.mp4")
        self.brb_video_url = os.getenv("BRB_VIDEO_URL", "")
        self.cloud_process = None
        self.cloud_brb_start_time = None

        self.is_low = False
        self.is_streaming = False
        self.obs_client = None

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

    def download_default_video(self):
        target_url = self.brb_video_url if self.brb_video_url else "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
        logger.info(f"Downloading BRB video from {target_url} to {self.brb_video_path}...")
        try:
            os.makedirs(os.path.dirname(self.brb_video_path), exist_ok=True)
            r = requests.get(target_url, stream=True, timeout=30)
            if r.status_code == 200:
                with open(self.brb_video_path, 'wb') as f:
                    for chunk in r.iter_content(chunk_size=8192):
                        f.write(chunk)
                logger.info("BRB video downloaded successfully.")
                return True
            else:
                logger.error(f"Failed to download BRB video, HTTP status {r.status_code}")
                return False
        except Exception as e:
            logger.error(f"Error downloading BRB video: {e}")
            return False

    def check_and_ensure_video(self):
        if not os.path.exists(self.brb_video_path) or os.path.getsize(self.brb_video_path) == 0:
            return self.download_default_video()
        return True

    def get_bitrate(self):
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
                                if name_node is not None and name_node.text and name_node.text.startswith("cloud_brb"):
                                    # Ignore internal cloud BRB loop streams
                                    continue
                                if stream.find('publishing') is not None:
                                    bw_in = stream.find('bw_in')
                                    if bw_in is not None:
                                        total_bitrate += int(int(bw_in.text) * 8 / 1024)
            return total_bitrate
        except Exception as e:
            logger.debug(f"Bitrate fetch error: {e}")
            return 0

    def check_nvenc_support(self):
        try:
            res = subprocess.run(["ffmpeg", "-encoders"], capture_output=True, text=True, timeout=5)
            return "h264_nvenc" in res.stdout
        except Exception:
            return False

    def start_cloud_brb(self):
        if not self.cloud_brb_enabled:
            return

        if self.cloud_process and self.cloud_process.poll() is None:
            return

        if not self.check_and_ensure_video():
            logger.error(f"Cloud BRB video not available at {self.brb_video_path}")
            return

        logger.info("Process of noalbs taking over: Starting Cloud BRB stream...")

        has_nvenc = self.check_nvenc_support()
        vcodec = ["-c:v", "h264_nvenc", "-preset", "p1", "-tune", "ll"] if has_nvenc else ["-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency"]

        tee_target = f"[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/{self.app_name}/cloud_brb_loop|[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/vertical/cloud_brb_loop"

        cmd = [
            "ffmpeg", "-re", "-stream_loop", "-1", "-i", self.brb_video_path,
            *vcodec,
            "-b:v", "3000k", "-maxrate", "3000k", "-bufsize", "3000k", "-sc_threshold", "0",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", "-b:a", "160k",
            "-map", "0:v:0", "-map", "0:a?",
            "-thread_queue_size", "1024", "-max_muxing_queue_size", "1024",
            "-fflags", "+nobuffer", "-flags", "+low_delay",
            "-f", "tee", tee_target
        ]

        try:
            self.cloud_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.cloud_brb_start_time = time.time()
            logger.info(f"Cloud BRB process started (PID: {self.cloud_process.pid}). Protection duration: {self.cloud_brb_timeout}s.")
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

        try:
            client.call_vendor_request("aitum-vertical-canvas", "switch_scene", {"scene": scene})
        except Exception:
            pass

    def run(self):
        if not self.enabled:
            logger.info("NOALBS is disabled.")
            return

        logger.info(f"NOALBS Started. Monitoring {self.app_name} & vertical on {self.stats_url}")

        while True:
            bitrate = self.get_bitrate()

            # Timeout check for Cloud BRB duration
            if self.cloud_process and self.cloud_brb_start_time:
                # Restart if crashed
                if self.cloud_process.poll() is not None:
                    logger.warning("Cloud BRB process terminated unexpectedly. Restarting...")
                    self.cloud_process = None
                    self.start_cloud_brb()

                elapsed = time.time() - self.cloud_brb_start_time
                if elapsed >= self.cloud_brb_timeout:
                    logger.error(f"Cloud BRB protection timeout ({self.cloud_brb_timeout}s) reached. Stopping fallback stream and disconnecting broadcast.")
                    self.stop_cloud_brb()
                    client = self.get_obs_client()
                    if client:
                        try:
                            client.stop_stream()
                        except Exception as e:
                            logger.error(f"Failed to stop OBS stream: {e}")

            if bitrate > 0:
                if not self.is_streaming:
                    logger.info(f"Stream detected at {bitrate}kbps.")
                    self.is_streaming = True

                if bitrate < self.low_threshold:
                    if not self.is_low:
                        logger.error(f"Stream disruption: Low bitrate ({bitrate}kbps < {self.low_threshold}kbps). Immediate takeover.")
                        self.switch_scene(self.scene_brb)
                        self.is_low = True
                        if self.cloud_brb_enabled:
                            self.start_cloud_brb()
                else:
                    if bitrate >= self.restore_threshold:
                        if self.cloud_process:
                            logger.info("Source stream recovered above restore threshold. Stopping Cloud BRB.")
                            self.stop_cloud_brb()
                        if self.is_low:
                            logger.info(f"Bitrate restored ({bitrate}kbps >= {self.restore_threshold}kbps). Switching back to {self.scene_main}")
                            self.switch_scene(self.scene_main)
                            self.is_low = False
            else:
                if self.is_streaming:
                    logger.error("Stream disruption: Source stream disconnected (0 kbps). Immediate takeover.")
                    client = self.get_obs_client()
                    is_obs_streaming = True
                    if client:
                        try:
                            status = client.get_stream_status()
                            is_obs_streaming = getattr(status, 'output_active', getattr(status, 'outputActive', True))
                        except Exception as e:
                            logger.error(f"Failed to get OBS stream status: {e}")
                            is_obs_streaming = True
                    else:
                        logger.warning("Could not connect to OBS. Assuming network drop.")
                        is_obs_streaming = True

                    if is_obs_streaming or self.cloud_brb_enabled:
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
