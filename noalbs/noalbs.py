import requests
import time
import os
import logging
import xml.etree.ElementTree as ET
import obsws_python as obs
import subprocess

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("NOALBS")

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
        # NOALBS uses internal port 8081 for stats
        self.stats_url = "http://127.0.0.1:8081/stat"

        self.cloud_brb_enabled = os.getenv("CLOUD_BRB", "true").lower() == "true"
        self.brb_video_path = os.getenv("BRB_VIDEO_PATH", "/app/data/brb_video.mp4")
        self.brb_video_url = os.getenv("BRB_VIDEO_URL", "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4")
        self.cloud_brb_timeout = int(os.getenv("CLOUD_BRB_TIMEOUT", 300))
        self.cloud_brb_start_time = None
        self.cloud_process = None

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
                                stream_name_node = stream.find('name')
                                if stream_name_node is not None and stream_name_node.text:
                                    if "cloud_brb" in stream_name_node.text:
                                        continue
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
        if not self.cloud_brb_enabled:
            return

        if self.cloud_process:
            if self.cloud_process.poll() is not None:
                self.cloud_process = None
            else:
                return

        file_missing_or_empty = False
        if not os.path.exists(self.brb_video_path):
            file_missing_or_empty = True
        else:
            try:
                if os.path.getsize(self.brb_video_path) == 0:
                    file_missing_or_empty = True
            except Exception:
                pass

        if file_missing_or_empty:
            if self.brb_video_url:
                try:
                    logger.info(f"Downloading BRB video from {self.brb_video_url}...")
                    os.makedirs(os.path.dirname(self.brb_video_path), exist_ok=True)
                    resp = requests.get(self.brb_video_url, timeout=10)
                    if resp.status_code == 200:
                        with open(self.brb_video_path, "wb") as f:
                            f.write(resp.content)
                except Exception as e:
                    logger.error(f"Failed to download BRB video: {e}")

        if not os.path.exists(self.brb_video_path):
            logger.error(f"Cloud BRB video not found at {self.brb_video_path}")
            return

        logger.info("Starting Cloud BRB stream... Process of noalbs taking over")

        encoder_flags = ["-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency"]
        try:
            res = subprocess.run(["ffmpeg", "-encoders"], capture_output=True, text=True, timeout=5)
            if "h264_nvenc" in res.stdout:
                encoder_flags = ["-c:v", "h264_nvenc", "-preset", "p1", "-tune", "ll"]
        except Exception:
            pass

        tee_target = f"[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/{self.app_name}/cloud_brb_loop|[f=flv:onfail=ignore]rtmp://127.0.0.1:1935/vertical/cloud_brb_loop"
        cmd = [
            "ffmpeg", "-re", "-stream_loop", "-1",
            "-fflags", "+nobuffer", "-flags", "+low_delay",
            "-i", self.brb_video_path,
            *encoder_flags,
            "-b:v", "3000k", "-maxrate", "3000k", "-bufsize", "3000k",
            "-sc_threshold", "0",
            "-map", "0:v", "-map", "0:a?",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", "-b:a", "160k",
            "-thread_queue_size", "1024", "-max_muxing_queue_size", "1024",
            "-f", "tee",
            tee_target
        ]
        try:
            self.cloud_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.cloud_brb_start_time = time.time()
        except Exception as e:
            logger.error(f"Failed to start Cloud BRB process: {e}")

    def stop_cloud_brb(self):
        if self.cloud_process:
            logger.info("Stopping Cloud BRB stream.")
            try:
                self.cloud_process.terminate()
                self.cloud_process.wait(timeout=2)
            except Exception:
                try:
                    self.cloud_process.kill()
                except Exception:
                    pass
            self.cloud_process = None
            self.cloud_brb_start_time = None

    def switch_scene(self, scene):
        client = self.get_obs_client()
        if not client:
            return
        try:
            client.set_current_program_scene(scene)
            logger.info(f"Successfully switched OBS scene to: {scene}. Process of noalbs taking over")
        except Exception as e:
            logger.error(f"OBS WebSocket Switch Error: {e}")
            self.obs_client = None

        try:
            client.call_vendor_request('aitum-vertical-canvas', 'switch_scene', {'scene': scene})
        except Exception:
            pass

    def check_cloud_brb_timeout(self):
        if self.cloud_process and self.cloud_brb_start_time:
            if self.cloud_process.poll() is not None:
                self.cloud_process = None
                self.start_cloud_brb()
            elif time.time() - self.cloud_brb_start_time >= self.cloud_brb_timeout:
                logger.error(f"Cloud BRB timeout ({self.cloud_brb_timeout}s) reached without source recovery.")
                self.stop_cloud_brb()
                client = self.get_obs_client()
                if client:
                    try:
                        client.stop_stream()
                    except Exception as e:
                        logger.error(f"Failed to stop OBS stream: {e}")

    def run(self):
        if not self.enabled:
            logger.info("NOALBS is disabled.")
            return

        logger.info(f"NOALBS Started. Monitoring {self.app_name} & vertical on {self.stats_url}")

        consecutive_low = 0
        while True:
            self.check_cloud_brb_timeout()
            bitrate = self.get_bitrate()

            if bitrate > 0:
                self.stop_cloud_brb()
                if not self.is_streaming:
                    logger.info(f"Stream detected at {bitrate}kbps.")
                    self.is_streaming = True

                if bitrate < self.low_threshold:
                    consecutive_low += 1
                    if consecutive_low >= 3 and not self.is_low:
                        logger.error(f"Stream disruption: Low bitrate ({bitrate}kbps) for 6s. Switching to {self.scene_brb}")
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
                    is_obs_streaming = True
                    if client:
                        try:
                            status = client.get_stream_status()
                            is_obs_streaming = getattr(status, 'output_active', getattr(status, 'outputActive', True))
                        except Exception as e:
                            logger.error(f"Failed to get OBS stream status: {e}")
                            is_obs_streaming = True
                    else:
                        logger.error("Could not connect to OBS. Assuming network drop.")
                        is_obs_streaming = True

                    if is_obs_streaming or self.cloud_brb_enabled:
                        logger.error("Stream disruption: Source stream disconnected. Switching to BRB scene and starting Cloud BRB.")
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
