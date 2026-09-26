import requests
import time
import os
import logging
import xml.etree.ElementTree as ET
import obsws_python as obs
import subprocess
import signal
import threading
import urllib.request

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("NOALBS")

def is_valid_file(path):
    try:
        return os.path.exists(path) and os.path.getsize(path) > 0
    except Exception:
        return False

class Noalbs:
    def __init__(self):
        self.enabled = os.getenv("NOALBS_ENABLED", "false").lower() == "true"
        self.fallback_mode = os.getenv("FALLBACK_MODE", "video").lower()
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
        self.cloud_brb_timeout = int(os.getenv("CLOUD_BRB_TIMEOUT", 300))
        self.cloud_process = None
        self.cloud_brb_start_time = None

        self.is_low = False
        self.is_streaming = False
        self.obs_client = None

    def ensure_brb_video_ready(self):
        default_url = "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
        video_url = os.getenv("BRB_VIDEO_URL", "").strip() or default_url

        target_path = self.brb_video_path
        os.makedirs(os.path.dirname(target_path), exist_ok=True)

        if not is_valid_file(target_path):
            logger.info(f"BRB video missing. Downloading default video from {video_url}...")
            try:
                tmp_path = target_path + ".tmp"
                urllib.request.urlretrieve(video_url, tmp_path)
                logger.info(f"Downloaded video to {tmp_path}")

                # Transcode and verify compatibility using FFmpeg (H.264 + AAC 48kHz stereo)
                logger.info("Transcoding downloaded BRB video with FFmpeg to ensure AAC/H.264 compatibility...")

                # Extract duration using ffprobe if available
                total_duration = 0
                try:
                    probe_cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprintwrappers=1:nokey=1", tmp_path]
                    probe_res = subprocess.run(probe_cmd, capture_output=True, text=True, timeout=10)
                    if probe_res.returncode == 0 and probe_res.stdout.strip():
                        total_duration = float(probe_res.stdout.strip())
                except Exception:
                    pass

                transcode_cmd = [
                    "ffmpeg", "-y", "-hide_banner", "-loglevel", "warning", "-progress", "pipe:1",
                    "-i", tmp_path,
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "60",
                    "-c:a", "aac", "-ar", "48000", "-ac", "2",
                    target_path
                ]
                proc = subprocess.Popen(transcode_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                last_logged_pct = -1
                if proc.stdout:
                    for line in proc.stdout:
                        line = line.strip()
                        if line.startswith("out_time_ms="):
                            try:
                                ms = int(line.split("=")[1])
                                sec = ms / 1000000.0
                                if total_duration > 0:
                                    pct = int((sec / total_duration) * 100)
                                    pct = min(pct, 100)
                                    if pct >= last_logged_pct + 10 or pct == 100:
                                        logger.info(f"Transcoding BRB Video Progress: {pct}%")
                                        last_logged_pct = pct
                                else:
                                    if int(sec) % 5 == 0 and int(sec) != last_logged_pct:
                                        logger.info(f"Transcoding BRB Video Processed: {int(sec)}s")
                                        last_logged_pct = int(sec)
                            except Exception:
                                pass
                proc.wait(timeout=180)

                if proc.returncode == 0 and is_valid_file(target_path):
                    logger.info("BRB video successfully downloaded and transcoded.")
                else:
                    logger.warning("FFmpeg transcoding failed or not available. Using downloaded raw file.")
                    if os.path.exists(tmp_path):
                        os.replace(tmp_path, target_path)
                if os.path.exists(tmp_path):
                    try:
                        os.remove(tmp_path)
                    except Exception:
                        pass
            except Exception as e:
                logger.error(f"Failed to download/transcode BRB video: {e}")

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
                                name_node = stream.find('name')
                                # Ignore fallback cloud_brb streams when calculating source bitrate
                                if name_node is not None and name_node.text and name_node.text.startswith('cloud_brb'):
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
            if self.cloud_process.poll() is None:
                return
            logger.warning("Existing Cloud BRB process exited. Restarting...")
            self.cloud_process = None

        if not is_valid_file(self.brb_video_path):
            self.ensure_brb_video_ready()

        if not is_valid_file(self.brb_video_path):
            logger.error(f"Cloud BRB video not found at {self.brb_video_path}")
            return

        logger.info("Process of noalbs taking over: Starting Cloud BRB fallback video stream...")
        if not self.cloud_brb_start_time:
            self.cloud_brb_start_time = time.time()

        # Check for NVENC encoder support
        has_nvenc = False
        try:
            res = subprocess.run(["ffmpeg", "-encoders"], capture_output=True, text=True, timeout=5)
            if "h264_nvenc" in res.stdout:
                has_nvenc = True
        except Exception:
            pass

        if has_nvenc:
            vcodec = ["-c:v", "h264_nvenc", "-preset", "p3", "-tune", "ll"]
        else:
            vcodec = ["-c:v", "libx264", "-preset", "veryfast", "-tune", "zerolatency"]

        tee_target = f"[f=flv:onfail=ignore]rtmp://127.0.0.1:19352/{self.app_name}/cloud_brb_loop|[f=flv:onfail=ignore]rtmp://127.0.0.1:19352/vertical/cloud_brb_loop"

        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "warning",
            "-re", "-thread_queue_size", "1024",
            "-stream_loop", "-1", "-i", self.brb_video_path,
            *vcodec,
            "-b:v", "3000k", "-maxrate", "3000k", "-bufsize", "6000k",
            "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
            "-c:a", "aac", "-ac", "2", "-ar", "48000", "-b:a", "160k",
            "-max_muxing_queue_size", "1024",
            "-f", "tee", "-map", "0:v", "-map", "0:a?",
            tee_target
        ]
        try:
            with open("/tmp/cloud_brb.log", "a") as log_file:
                self.cloud_process = subprocess.Popen(cmd, stdout=log_file, stderr=subprocess.STDOUT)
            logger.info("Cloud BRB fallback video process successfully spawned.")
        except Exception as e:
            logger.error(f"Failed to start Cloud BRB process: {e}")

    def stop_cloud_brb(self):
        if self.cloud_process:
            logger.info("Stopping Cloud BRB stream process...")
            proc = self.cloud_process
            self.cloud_process = None
            self.cloud_brb_start_time = None
            def kill_proc():
                try:
                    proc.terminate()
                    proc.wait(timeout=3)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass
            threading.Thread(target=kill_proc, daemon=True).start()

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

        # Attempt Aitum Vertical Canvas scene switch if plugin vendor request is supported
        try:
            if client:
                client.call_vendor_request("aitum-vertical-canvas", "switch_scene", {"scene": scene})
                logger.info(f"Successfully switched Aitum Vertical Canvas scene to: {scene}")
        except Exception:
            pass

    def run(self):
        if not self.enabled:
            logger.info("NOALBS is disabled.")
            return

        logger.info(f"NOALBS Started. Monitoring {self.app_name} & vertical on {self.stats_url}")

        consecutive_low = 0
        while True:
            bitrate = self.get_bitrate()

            # Check timeout or process crash if Cloud BRB is active
            if self.cloud_process and self.cloud_brb_start_time:
                if self.cloud_process.poll() is not None:
                    logger.warning("Cloud BRB FFmpeg process exited unexpectedly. Restarting...")
                    self.cloud_process = None
                    self.start_cloud_brb()

                elapsed = time.time() - self.cloud_brb_start_time
                if elapsed >= self.cloud_brb_timeout:
                    logger.error(f"Cloud BRB fallback active for {self.cloud_brb_timeout} seconds without stream recovery. Terminating stream completely.")
                    self.stop_cloud_brb()
                    client = self.get_obs_client()
                    if client:
                        try:
                            client.stop_stream()
                            logger.info("Successfully requested OBS WebSocket to stop stream.")
                        except Exception as e:
                            logger.error(f"Failed to stop OBS stream via WebSocket: {e}")
                    self.is_streaming = False
                    self.is_low = False
                    time.sleep(2)
                    continue

            if bitrate > 0:
                if not self.is_streaming:
                    logger.info(f"Stream detected at {bitrate}kbps.")
                    self.is_streaming = True

                if bitrate < self.low_threshold:
                    if not self.is_low:
                        logger.error(f"Stream disruption: Low bitrate ({bitrate}kbps < {self.low_threshold}kbps).")
                        self.is_low = True
                        if self.fallback_mode == "video" or self.cloud_brb_enabled:
                            logger.warning("Process of noalbs taking over: Immediately playing video MP4 fallback stream.")
                            self.start_cloud_brb()
                        if self.fallback_mode == "obs" or self.obs_client:
                            logger.warning(f"Process of noalbs taking over: Switching OBS scene to {self.scene_brb}")
                            self.switch_scene(self.scene_brb)
                else:
                    self.stop_cloud_brb()
                    if bitrate >= self.restore_threshold and self.is_low:
                        logger.info(f"Bitrate restored ({bitrate}kbps). Switching OBS scene to {self.scene_main}")
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
                            is_obs_streaming = getattr(status, 'output_active', getattr(status, 'outputActive', True))
                        except Exception as e:
                            logger.error(f"Failed to get OBS stream status: {e}")
                            # If connection fails, assume it's a disconnect (network drop)
                            is_obs_streaming = True
                    else:
                        logger.warning("Could not connect to OBS. Assuming network drop.")
                        is_obs_streaming = True

                    if is_obs_streaming or self.cloud_brb_enabled or self.fallback_mode == "video":
                        logger.error("Process of noalbs taking over: Source stream disconnected / dropped! Bitrate 0 kbps.")
                        self.is_low = True
                        if self.fallback_mode == "video" or self.cloud_brb_enabled:
                            logger.warning("Process of noalbs taking over: Immediately playing video MP4 fallback stream.")
                            self.start_cloud_brb()
                        if self.fallback_mode == "obs" or self.obs_client:
                            logger.warning(f"Switching OBS scene to {self.scene_brb}.")
                            self.switch_scene(self.scene_brb)
                    else:
                        logger.info("Source stream ended cleanly.")
                        self.is_low = False
                    self.is_streaming = False

            time.sleep(2)

if __name__ == "__main__":
    Noalbs().run()
