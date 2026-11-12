import logging
import os
import signal
import subprocess
import time
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("StreamProtection")

DEFAULT_BRB_URL = "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
STATS_URL = os.getenv("STATS_URL", "http://127.0.0.1:8081/stat")
TICK_SECONDS = 1
LOW_TICKS_TO_FALLBACK = 3
GOOD_TICKS_TO_RESTORE = 5

LIVE_PLATFORMS = ["YOUTUBE", "FACEBOOK", "INSTAGRAM", "TIKTOK", "TWITCH", "KICK", "X", "TROVO", "RTMP1"]
VERTICAL_PLATFORMS = ["V_YOUTUBE", "V_FACEBOOK", "V_INSTAGRAM", "V_TIKTOK", "V_TWITCH", "V_KICK", "V_X", "V_RTMP1"]


def read_destinations(platforms):
    destinations = []
    for name in platforms:
        url = os.getenv(f"{name}_URL", "").strip()
        key = os.getenv(f"{name}_KEY", "").strip()
        if not key or not url or url == "auto":
            continue
        destinations.append(url + key)
    return destinations


def is_valid_file(path):
    return os.path.isfile(path) and os.path.getsize(path) > 0


def ensure_brb_video(path, url):
    if is_valid_file(path):
        return True
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp_path = path + ".tmp"
    try:
        logger.info(f"Downloading backup video from {url}")
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=120) as response, open(tmp_path, 'wb') as out_file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                out_file.write(chunk)
        if not is_valid_file(tmp_path):
            raise RuntimeError("downloaded file is empty")
        os.replace(tmp_path, path)
        logger.info("Backup video downloaded.")
        return True
    except Exception as e:
        logger.error(f"Backup video download failed: {e}")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return False


def fetch_feed_stats(feed_app):
    """Returns (stream_name, bitrate_kbps) for the publishing stream on the internal feed app, or (None, 0)."""
    try:
        with urllib.request.urlopen(STATS_URL, timeout=2) as r:
            root = ET.fromstring(r.read())
    except Exception as e:
        logger.debug(f"Stats fetch error: {e}")
        return None, 0
    for app in root.iter('application'):
        if app.findtext('name') != feed_app:
            continue
        for stream in app.iter('stream'):
            if stream.find('publishing') is None:
                continue
            name = stream.findtext('name')
            bw_in = stream.findtext('bw_in')
            if name and bw_in and bw_in.isdigit():
                return name, int(int(bw_in) * 8 / 1024)
    return None, 0


@dataclass
class Lane:
    label: str
    feed_app: str
    destinations: list
    brb_path: str
    brb_url: str
    low_kbps: int
    restore_kbps: int
    timeout_seconds: int
    protection_enabled: bool = True
    state: str = "IDLE"
    process: subprocess.Popen = None
    process_mode: str = None
    low_ticks: int = 0
    good_ticks: int = 0
    fallback_started: float = 0.0
    brb_video_ready: bool = False

    def tee_target(self):
        return "|".join(f"[f=flv:onfail=ignore]{d}" for d in self.destinations)

    def stop_process(self):
        if self.process is None:
            return
        proc = self.process
        self.process = None
        self.process_mode = None
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass

    def start_source(self, source_name):
        self.stop_process()
        url = f"rtmp://127.0.0.1:19359/{self.feed_app}/{source_name}"
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "warning",
            "-fflags", "+nobuffer+discardcorrupt", "-flags", "+low_delay",
            "-rw_timeout", "10000000",
            "-i", url,
            "-map", "0:v", "-map", "0:a?",
            "-c", "copy",
            "-f", "tee", "-flush_packets", "1", self.tee_target(),
        ]
        self._spawn(cmd, "source")
        logger.info(f"[{self.label}] Live feed relayed to {len(self.destinations)} destination(s).")

    def start_brb(self):
        self.stop_process()
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "warning",
            "-re", "-stream_loop", "-1", "-i", self.brb_path,
            "-map", "0:v", "-map", "0:a?",
            "-c:v", "libx264", "-preset", "veryfast", "-tune", "zerolatency",
            "-pix_fmt", "yuv420p", "-b:v", "3000k", "-maxrate", "3000k", "-bufsize", "6000k",
            "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
            "-c:a", "aac", "-ar", "48000", "-ac", "2", "-b:a", "160k",
            "-f", "tee", "-flush_packets", "1", self.tee_target(),
        ]
        self._spawn(cmd, "brb")
        logger.warning(f"[{self.label}] Backup video is now live on all destinations.")

    def _spawn(self, cmd, mode):
        if not self.destinations:
            return
        self.process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=None)
        self.process_mode = mode

    def process_died(self):
        return self.process is not None and self.process.poll() is not None

    def stop_all(self):
        self.stop_process()
        self.state = "ENDED"

    def tick(self, source_name, bitrate):
        source_present = source_name is not None and bitrate > 0
        now = time.time()

        if source_present:
            self.low_ticks = self.low_ticks + 1 if bitrate < self.low_kbps else 0
            self.good_ticks = self.good_ticks + 1 if bitrate >= self.restore_kbps else 0
        else:
            self.low_ticks += 1
            self.good_ticks = 0

        if self.state == "IDLE":
            if source_present and bitrate >= self.low_kbps:
                self.state = "LIVE"
                self.start_source(source_name)
            return

        if self.state == "LIVE":
            if self.process_died() and self.process_mode == "source" and source_present:
                self.start_source(source_name)
                return
            if self.low_ticks >= LOW_TICKS_TO_FALLBACK and self.protection_enabled:
                logger.error(f"[{self.label}] Source dropped or below {self.low_kbps} kbps. Switching to backup video.")
                self.fallback_started = now
                self.state = "BRB"
                self._enter_brb()
            return

        if self.state == "BRB":
            if now - self.fallback_started >= self.timeout_seconds:
                logger.error(f"[{self.label}] No recovery after {self.timeout_seconds // 60} minute(s). Ending stream outputs.")
                self.stop_all()
                return
            if self.good_ticks >= GOOD_TICKS_TO_RESTORE:
                logger.info(f"[{self.label}] Source recovered at {bitrate} kbps. Switching back to live.")
                self.state = "LIVE"
                self.start_source(source_name)
                return
            if self.process_died():
                self.start_brb()
            return

        if self.state == "ENDED":
            if self.good_ticks >= GOOD_TICKS_TO_RESTORE:
                logger.info(f"[{self.label}] Source is back. Resuming live relay.")
                self.state = "LIVE"
                self.start_source(source_name)

    def _enter_brb(self):
        if not self.brb_video_ready:
            self.brb_video_ready = ensure_brb_video(self.brb_path, self.brb_url)
        if self.brb_video_ready:
            self.start_brb()
        else:
            logger.error(f"[{self.label}] Backup video unavailable; outputs stopped.")
            self.stop_all()


def build_lanes():
    brb_path = os.getenv("BRB_VIDEO_PATH", "/app/data/brb_video.mp4")
    brb_url = os.getenv("BRB_VIDEO_URL", "").strip() or DEFAULT_BRB_URL
    common = dict(
        brb_path=brb_path,
        brb_url=brb_url,
        low_kbps=int(os.getenv("LOW_BITRATE", "1000")),
        restore_kbps=int(os.getenv("RESTORE_BITRATE", "1500")),
        timeout_seconds=int(os.getenv("DISCONNECT_MINUTES", "5")) * 60,
        protection_enabled=os.getenv("PROTECTION_ENABLED", "true").lower() == "true",
    )
    return [
        Lane(label="horizontal", feed_app="feed", destinations=read_destinations(LIVE_PLATFORMS), **common),
        Lane(label="vertical", feed_app="vfeed", destinations=read_destinations(VERTICAL_PLATFORMS), **common),
    ]


def main():
    lanes = build_lanes()
    for lane in lanes:
        logger.info(f"[{lane.label}] {len(lane.destinations)} destination(s) configured.")
    def shutdown(*_):
        for lane in lanes:
            lane.stop_process()
        os._exit(0)

    signal.signal(signal.SIGTERM, shutdown)

    while True:
        for lane in lanes:
            source_name, bitrate = fetch_feed_stats(lane.feed_app)
            lane.tick(source_name, bitrate)
        time.sleep(TICK_SECONDS)


if __name__ == "__main__":
    main()
