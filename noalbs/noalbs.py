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
        self.enabled = os.getenv("NOALBS_ENABLED", "true").lower() == "true"
        self.low_threshold = int(os.getenv("LOW_BITRATE", 1000))
        self.restore_threshold = int(os.getenv("RESTORE_BITRATE", 1500))
        self.obs_host = os.getenv("OBS_WS_HOST", "127.0.0.1")
        self.obs_port = int(os.getenv("OBS_WS_PORT", 4455))
        self.obs_password = os.getenv("OBS_WS_PASSWORD", "")
        self.scene_main = os.getenv("OBS_SCENE_LIVE", "Main")
        self.scene_brb = os.getenv("OBS_SCENE_BRB", "BRB")
        self.app_name = os.getenv("APP_NAME", "live")
        self.stats_url = "http://127.0.0.1:8081/stat"

        DEFAULT_BRB_URL = "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
        self.cloud_brb_enabled = os.getenv("CLOUD_BRB", "true").lower() == "true"
        self.brb_video_path = os.getenv("BRB_VIDEO_PATH", "/app/data/brb_video.mp4")
        self.brb_video_url = os.getenv("BRB_VIDEO_URL") or DEFAULT_BRB_URL
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
            for app in root.findall('.//application'):
                app_name_node = app.find('name')
                if app_name_node is not None:
                    app_name_text = app_name_node.text
                    if app_name_text == self.app_name or app_name_text == "vertical":
                        live = app.find('live')
                        if live is not None:
                            for stream in live.findall('stream'):
                                stream_name = stream.find('name')
                                if stream_name is not None and stream_name.text and stream_name.text.startswith("cloud_brb"):
                                    continue
                                if stream.find('publishing') is not None:
                                    bw_in = stream.find('bw_in')
                                    if bw_in is not None:
                                        total_bitrate += int(int(bw_in.text) * 8 / 1024)
            return total_bitrate
        except Exception as e:
            logger.debug(f"Bitrate fetch error: {e}")
            return 0

    def ensure_rtmp_compatible_mp4(self):
        if not os.path.exists(self.brb_video_path):
            return False

        tmp_converted = self.brb_video_path + ".converted.mp4"
        logger.info(f"Verifying and optimizing MP4 video for RTMP streaming at {self.brb_video_path}...")
        cmd = [
            "ffmpeg", "-y", "-i", self.brb_video_path,
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "fast",
            "-g", "60", "-sc_threshold", "0",
            "-c:a", "aac", "-ac", "2", "-ar", "48000",
            tmp_converted
        ]
        try:
            res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
            if res.returncode == 0 and os.path.exists(tmp_converted) and os.path.getsize(tmp_converted) > 0:
                os.replace(tmp_converted, self.brb_video_path)
                logger.info("MP4 video successfully converted to RTMP-compatible format.")
                return True
            else:
                if os.path.exists(tmp_converted):
                    os.remove(tmp_converted)
                return True
        except Exception as e:
            logger.debug(f"Conversion skipped or error encountered: {e}")
            if os.path.exists(tmp_converted):
                try:
                    os.remove(tmp_converted)
                except Exception:
                    pass
            return True

    def download_brb_video_if_missing(self):
        if os.path.exists(self.brb_video_path):
            try:
                if os.path.getsize(self.brb_video_path) > 0:
                    return True
            except Exception:
                return True

        download_url = self.brb_video_url or "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
        logger.info(f"BRB video missing or empty at {self.brb_video_path}. Attempting download from {download_url}...")
        try:
            os.makedirs(os.path.dirname(self.brb_video_path), exist_ok=True)
            res = requests.get(download_url, timeout=15, stream=True)
            if res.status_code == 200:
                with open(self.brb_video_path, 'wb') as f:
                    for chunk in res.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                logger.info(f"Successfully downloaded BRB video to {self.brb_video_path}")
                self.ensure_rtmp_compatible_mp4()
                return True
            else:
                logger.error(f"Failed to download BRB video. HTTP status: {res.status_code}")
                return False
        except Exception as e:
            logger.error(f"Error downloading BRB video: {e}")
            return False

    def start_cloud_brb(self):
        if not self.cloud_brb_enabled:
            return

        if self.cloud_process:
            if self.cloud_process.poll() is None:
                return
            else:
                logger.warning("Existing Cloud BRB process terminated unexpectedly. Restarting...")
                self.cloud_process = None

        if not self.download_brb_video_if_missing():
            logger.error(f"Cloud BRB video unavailable at {self.brb_video_path}")
            return

        logger.info("Starting Cloud BRB fallback stream...")

        # Detect NVENC hardware encoder availability
        use_nvenc = False
        try:
            enc_proc = subprocess.run(["ffmpeg", "-encoders"], capture_output=True, text=True, timeout=5)
            if "h264_nvenc" in enc_proc.stdout:
                use_nvenc = True
        except Exception as e:
            logger.debug(f"Encoder check error: {e}")

        if use_nvenc:
            video_codec = ["-c:v", "h264_nvenc", "-preset", "p1", "-tune", "ll"]
        else:
            video_codec = ["-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency"]

        target_live = f"rtmp://127.0.0.1:1935/{self.app_name}/cloud_brb_loop"
        target_vert = "rtmp://127.0.0.1:1935/vertical/cloud_brb_loop"
        tee_target = f"[f=flv:onfail=ignore]{target_live}|[f=flv:onfail=ignore]{target_vert}"

        cmd = [
            "ffmpeg", "-re", "-stream_loop", "-1",
            "-fflags", "+nobuffer", "-flags", "+low_delay",
            "-i", self.brb_video_path,
            "-map", "0:v:0", "-map", "0:a?"
        ] + video_codec + [
            "-b:v", "1500k", "-maxrate", "1500k", "-bufsize", "3000k",
            "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", "-b:a", "160k",
            "-f", "tee", tee_target
        ]

        try:
            log_file = open('/tmp/cloud_brb.log', 'a')
            self.cloud_process = subprocess.Popen(cmd, stdout=log_file, stderr=log_file)
            self.cloud_brb_start_time = time.time()
            logger.info("Cloud BRB stream started successfully.")
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
            logger.info(f"Successfully switched OBS program scene to: {scene}")
        except Exception as e:
            logger.error(f"OBS WebSocket Switch Error: {e}")
            self.obs_client = None

        try:
            client.call_vendor_request('aitum-vertical-canvas', 'switch_scene', {'scene': scene})
            logger.info(f"Successfully switched Aitum Vertical scene to: {scene}")
        except Exception as e:
            logger.debug(f"Aitum vertical switch optional notice: {e}")

    def run(self):
        if not self.enabled:
            logger.info("NOALBS is disabled.")
            return

        logger.info(f"NOALBS Started. Monitoring {self.app_name} & vertical on {self.stats_url}")

        consecutive_low = 0
        while True:
            # Check Cloud BRB timeout (300s default)
            if self.cloud_process and self.cloud_brb_start_time:
                if self.cloud_process.poll() is not None:
                    logger.warning("Cloud BRB process exited unexpectedly. Restarting...")
                    self.cloud_process = None
                    self.start_cloud_brb()
                elif (time.time() - self.cloud_brb_start_time) >= self.cloud_brb_timeout:
                    logger.error(f"Cloud BRB reached {self.cloud_brb_timeout}s timeout without source recovery. Stopping stream.")
                    self.stop_cloud_brb()
                    client = self.get_obs_client()
                    if client:
                        try:
                            client.stop_stream()
                        except Exception as e:
                            logger.error(f"Failed to stop OBS stream: {e}")

            bitrate = self.get_bitrate()

            if bitrate > 0:
                if self.cloud_process:
                    logger.info(f"Source stream recovered ({bitrate}kbps). Stopping Cloud BRB.")
                    self.stop_cloud_brb()

                if not self.is_streaming:
                    logger.info(f"Stream detected at {bitrate}kbps.")
                    self.is_streaming = True

                if bitrate < self.low_threshold:
                    consecutive_low += 1
                    if consecutive_low >= 3 and not self.is_low:
                        logger.error(f"Low bitrate ({bitrate}kbps) for 6s. Process of noalbs taking over...")
                        self.switch_scene(self.scene_brb)
                        self.is_low = True
                        if self.cloud_brb_enabled:
                            self.start_cloud_brb()
                else:
                    consecutive_low = 0
                    if bitrate >= self.restore_threshold and self.is_low:
                        logger.info(f"Bitrate restored ({bitrate}kbps). Switching to {self.scene_main}")
                        self.switch_scene(self.scene_main)
                        self.is_low = False
            else:
                consecutive_low = 0
                if self.is_streaming:
                    logger.error("Source stream disconnected! Process of noalbs taking over instantly...")
                    self.switch_scene(self.scene_brb)
                    self.is_low = True
                    if self.cloud_brb_enabled:
                        self.start_cloud_brb()
                    self.is_streaming = False

            time.sleep(2)

if __name__ == "__main__":
    Noalbs().run()
