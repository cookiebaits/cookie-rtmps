"""Disconnection protection built on MediaMTX "always available" paths.

ingest (nginx live/vertical) --feed--> MediaMTX feed/<orientation> --relay--> nginx broadcast_h/_v --> platforms

The relay never disconnects while a session is active: when the feed stops
(disconnect or low bitrate) MediaMTX fills the path with the looping MP4.
If the source does not recover within the timeout, the relay is stopped and
the platforms see the broadcast end.
"""
import json
import logging
import os
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
from collections import deque

try:
    import defusedxml.ElementTree as ET
except ImportError:
    import xml.etree.ElementTree as ET

logging.basicConfig(level=logging.INFO, format='%(asctime)s - [Protection] %(levelname)s - %(message)s')
log = logging.getLogger("Protection")

DATA_DIR = os.getenv("PROTECTION_DATA_DIR", "/app/data")
STATUS_FILE = os.getenv("PROTECTION_STATUS_FILE", "/tmp/stream_protection.json")
PREP_STATUS_FILE = os.getenv("PROTECTION_PREP_STATUS_FILE", "/tmp/stream_prep_status.json")
NGINX_STAT = os.getenv("PROTECTION_NGINX_STAT", "http://127.0.0.1:8081/stat")
NGINX_CONTROL = os.getenv("PROTECTION_NGINX_CONTROL", "http://127.0.0.1:8081/control")
NGINX_RTMP = os.getenv("PROTECTION_NGINX_RTMP", "rtmp://127.0.0.1:19359")
MTX_BIN = os.getenv("MEDIAMTX_BIN", "/usr/local/bin/mediamtx")
MTX_CONFIG = os.getenv("MEDIAMTX_CONFIG", "/etc/mediamtx.yml")
MTX_RTMP_PORT = int(os.getenv("MEDIAMTX_RTMP_PORT", "1937"))
MTX_API_PORT = int(os.getenv("MEDIAMTX_API_PORT", "9997"))
DEFAULT_VIDEO_URL = "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"

def update_prep_status(percent, stage, detail=""):
    try:
        data = {
            "percent": int(percent),
            "stage": stage,
            "detail": detail,
            "updatedAt": int(time.time()),
            "ready": percent >= 100
        }
        tmp = PREP_STATUS_FILE + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f)
        os.replace(tmp, PREP_STATUS_FILE)
    except Exception as e:
        log.debug(f"Failed to write prep status: {e}")

LOW_GRACE_SECONDS = 5
RESTORE_GRACE_SECONDS = 3
BITRATE_WINDOW_SECONDS = 2

OUTPUTS = {
    "horizontal": {"app": "broadcast_h", "size": (1920, 1080)},
    "vertical": {"app": "broadcast_v", "size": (1080, 1920)},
}


def env_int(name, default, minimum=0):
    try:
        return max(minimum, int(str(os.getenv(name, default)).strip()))
    except ValueError:
        return default


def is_valid_file(path):
    return os.path.isfile(path) and os.path.getsize(path) > 0


def http_get(url, timeout=3):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "CookieRTMPS"}), timeout=timeout) as r:
        return r.read()


class Settings:
    def __init__(self):
        self.reload()

    def reload(self):
        env_file = os.path.join(DATA_DIR, "rtmp_config.env")
        file_env = {}
        if os.path.isfile(env_file):
            try:
                with open(env_file) as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#') and '=' in line:
                            k, v = line.split('=', 1)
                            file_env[k.strip()] = v.strip().strip('"').strip("'")
            except Exception:
                pass

        def get_int(name, default, minimum=0):
            val = file_env.get(name, os.getenv(name, str(default)))
            try:
                return max(minimum, int(str(val).strip()))
            except (ValueError, TypeError):
                return default

        self.enabled = str(file_env.get("NOALBS_ENABLED", os.getenv("NOALBS_ENABLED", "true"))).strip().lower() == "true"
        self.low_kbps = get_int("LOW_BITRATE", 1000, 1)
        self.restore_kbps = max(self.low_kbps, get_int("RESTORE_BITRATE", 1500, 1))
        self.timeout = get_int("CLOUD_BRB_TIMEOUT", 300, 5)
        self.video_url = (file_env.get("BRB_VIDEO_URL") or os.getenv("BRB_VIDEO_URL", "")).strip() or DEFAULT_VIDEO_URL
        self.ingest_apps = {"horizontal": os.getenv("APP_NAME", "live") or "live", "vertical": "vertical"}


# ---------------------------------------------------------------- video prep

def probe_has_stream(path, kind):
    res = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", kind, "-show_entries", "stream=codec_type", "-of", "csv=p=0", path],
        capture_output=True, text=True, timeout=30)
    return res.returncode == 0 and bool(res.stdout.strip())


def ensure_source_video(url):
    update_prep_status(10, "Verifying backup video source", url)
    source = os.path.join(DATA_DIR, "brb_source.mp4")
    url_file = os.path.join(DATA_DIR, "brb_source.url")
    legacy = os.path.join(DATA_DIR, "brb_video.mp4")
    os.makedirs(DATA_DIR, exist_ok=True)

    if not is_valid_file(source) and is_valid_file(legacy):
        os.replace(legacy, source)
        with open(url_file, "w") as f:
            f.write(url)

    saved_url = open(url_file).read().strip() if os.path.isfile(url_file) else ""
    if is_valid_file(source) and saved_url == url:
        update_prep_status(30, "Backup video cached and ready", source)
        return source

    update_prep_status(20, "Downloading backup video...", url)
    log.info(f"Downloading backup video from {url}")
    tmp = source + ".download"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r, open(tmp, "wb") as out:
            while True:
                chunk = r.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
        if not probe_has_stream(tmp, "v"):
            raise ValueError("downloaded file has no video track")
        os.replace(tmp, source)
        with open(url_file, "w") as f:
            f.write(url)
        update_prep_status(35, "Backup video downloaded", source)
        log.info("Backup video downloaded.")
    except Exception as e:
        log.error(f"Backup video download failed: {e}")
        if os.path.exists(tmp):
            os.remove(tmp)
    return source if is_valid_file(source) else None


def build_output_video(source, orientation):
    """Transcodes the backup video to a fixed broadcast format. The audio format must match
    what the feed sends (AAC 48 kHz stereo) or MediaMTX rejects the live stream."""
    w, h = OUTPUTS[orientation]["size"]
    target = os.path.join(DATA_DIR, f"brb_{orientation}.mp4" if source else f"standby_{orientation}.mp4")
    if not source and is_valid_file(target):
        return target
    if source and is_valid_file(target) and os.path.getmtime(target) >= os.path.getmtime(source):
        return target

    tmp = target + ".tmp.mp4"
    vf = f"scale={w}:{h}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2,fps=60,format=yuv420p"
    if source:
        inputs = ["-t", "8", "-i", source]
        if probe_has_stream(source, "a"):
            maps = ["-map", "0:v:0", "-map", "0:a:0?"]
        else:
            inputs += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000"]
            maps = ["-map", "0:v:0", "-map", "1:a:0"]
    else:
        log.warning(f"No backup video available, generating a plain standby screen for {orientation}.")
        inputs = ["-f", "lavfi", "-i", f"color=c=0x0f172a:s={w}x{h}:r=60:d=4",
                  "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000"]
        maps = ["-map", "0:v:0", "-map", "1:a:0"]

    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *inputs, *maps,
           "-t", "8",
           "-vf", vf, "-threads", "2", "-c:v", "libx264", "-preset", "ultrafast", "-profile:v", "high", "-level:v", "4.2",
           "-g", "120", "-keyint_min", "120", "-sc_threshold", "0",
           "-b:v", "4500k", "-maxrate", "4500k", "-bufsize", "9000k",
           "-c:a", "aac", "-ar", "48000", "-ac", "2", "-b:a", "160k",
           "-shortest",
           "-movflags", "+faststart", tmp]
    log.info(f"Preparing {orientation} backup video ({w}x{h})...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0 or not is_valid_file(tmp):
        log.error(f"Backup video preparation failed for {orientation} (exit {res.returncode}): {res.stderr.strip()[-400:]}")
        if os.path.exists(tmp):
            os.remove(tmp)
        return target if is_valid_file(target) else None
    os.replace(tmp, target)
    return target


def prepare_videos(settings):
    source = ensure_source_video(settings.video_url)
    videos = {}
    outputs_list = list(OUTPUTS.keys())
    for idx, o in enumerate(outputs_list):
        pct = 40 + int((idx / max(1, len(outputs_list))) * 45)
        update_prep_status(pct, f"Formatting {o} backup video...", f"{OUTPUTS[o]['size'][0]}x{OUTPUTS[o]['size'][1]} 60fps")
        videos[o] = (source and build_output_video(source, o)) or build_output_video(None, o)
        update_prep_status(pct + 20, f"{o.capitalize()} backup video ready", f"Formatted {o}")
    update_prep_status(88, "Backup video files prepared", "Configuring MediaMTX")
    return videos


def write_mediamtx_config(videos):
    lines = [
        "logLevel: warn",
        "rtsp: false",
        "hls: false",
        "webrtc: false",
        "srt: false",
        "moq: false",
        "rtmp: true",
        f"rtmpAddress: 127.0.0.1:{MTX_RTMP_PORT}",
        "api: true",
        f"apiAddress: 127.0.0.1:{MTX_API_PORT}",
        "authInternalUsers:",
        "  - user: any",
        "    ips: ['127.0.0.1', '::1']",
        "    permissions:",
        "      - action: publish",
        "      - action: read",
        "      - action: api",
        "paths:",
    ]
    for orientation, video in videos.items():
        if video and is_valid_file(video):
            lines += [f"  feed/{orientation}:", "    alwaysAvailable: true", f"    alwaysAvailableFile: {json.dumps(video)}"]
        else:
            lines += [f"  feed/{orientation}:", "    alwaysAvailable: true"]
    with open(MTX_CONFIG, "w") as f:
        f.write("\n".join(lines) + "\n")


# ------------------------------------------------------------------ helpers

def read_ingest_streams(apps):
    """Returns {app: (stream_name, bytes_in)} for apps with an active publisher."""
    root = ET.fromstring(http_get(NGINX_STAT))
    found = {}
    for app in root.iter("application"):
        name = (app.findtext("name") or "").strip()
        if name not in apps:
            continue
        for stream in app.iter("stream"):
            if any(c.find("publishing") is not None for c in stream.iter("client")):
                found[name] = ((stream.findtext("name") or "").strip(), int(stream.findtext("bytes_in") or 0))
                break
    return found


class Proc:
    def __init__(self, label, cmd):
        self.label = label
        log_path = f"/tmp/protection_{label}.log"
        self.log_file = open(log_path, "a")
        self.p = subprocess.Popen(cmd, stdout=self.log_file, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)

    def alive(self):
        return self.p.poll() is None

    def stop(self):
        if self.alive():
            self.p.terminate()
            try:
                self.p.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.p.kill()
                self.p.wait()
        try:
            if hasattr(self, 'log_file') and not self.log_file.closed:
                self.log_file.close()
        except Exception:
            pass


class Channel:
    def __init__(self, orientation, ingest_app, settings, protected):
        self.orientation = orientation
        self.ingest_app = ingest_app
        self.output_app = OUTPUTS[orientation]["app"]
        self.s = settings
        self.protected = protected
        self.state = "idle"
        self.feed = None
        self.relay = None
        self.stream_name = None
        self.samples = deque()
        self.kbps = None
        self.low_count = 0
        self.good_count = 0
        self.backup_since = None
        self.last_event = "Waiting for stream"

    # --- measurements
    def update_bitrate(self, publisher, now):
        if publisher is None:
            self.stream_name, self.kbps = None, None
            self.samples.clear()
            return
        name, total = publisher
        if name != self.stream_name:
            self.stream_name = name
            self.samples.clear()
        self.samples.append((now, total))
        while len(self.samples) > 2 and now - self.samples[0][0] > BITRATE_WINDOW_SECONDS:
            self.samples.popleft()
        if len(self.samples) >= 2:
            (t0, b0), (t1, b1) = self.samples[0], self.samples[-1]
            self.kbps = int(max(0, b1 - b0) * 8 / 1000 / max(t1 - t0, 0.001))
        else:
            self.kbps = None

    # --- processes
    def feed_cmd(self):
        src = f"{NGINX_RTMP}/{self.ingest_app}/{self.stream_name}"
        if not self.protected:
            return ["ffmpeg", "-hide_banner", "-loglevel", "warning",
                    "-analyzeduration", "3000000", "-probesize", "3000000",
                    "-fflags", "+genpts",
                    "-rw_timeout", "15000000", "-i", src,
                    "-map", "0:v:0?", "-map", "0:a:0?",
                    "-c:v", "copy",
                    "-c:a", "copy",
                    "-flvflags", "no_duration_filesize", "-max_muxing_queue_size", "8192",
                    "-f", "flv", f"{NGINX_RTMP}/{self.output_app}/{self.orientation}"]
        return ["ffmpeg", "-hide_banner", "-loglevel", "warning",
                "-analyzeduration", "3000000", "-probesize", "3000000",
                "-fflags", "+genpts",
                "-rw_timeout", "15000000", "-i", src,
                "-map", "0:v:0?", "-map", "0:a:0?",
                "-c:v", "copy",
                "-c:a", "aac", "-ar", "48000", "-ac", "2", "-b:a", "160k",
                "-af", "aresample=async=1000",
                "-flvflags", "no_duration_filesize", "-max_muxing_queue_size", "8192",
                "-f", "flv", f"rtmp://127.0.0.1:{MTX_RTMP_PORT}/feed/{self.orientation}"]

    def relay_cmd(self):
        return ["ffmpeg", "-hide_banner", "-loglevel", "warning",
                "-analyzeduration", "3000000", "-probesize", "3000000",
                "-fflags", "+genpts",
                "-rw_timeout", "15000000",
                "-i", f"rtmp://127.0.0.1:{MTX_RTMP_PORT}/feed/{self.orientation}",
                "-map", "0:v:0?", "-map", "0:a:0?",
                "-c:v", "copy",
                "-c:a", "copy",
                "-flvflags", "no_duration_filesize", "-max_muxing_queue_size", "8192",
                "-f", "flv", f"{NGINX_RTMP}/{self.output_app}/{self.orientation}"]

    def start_feed(self):
        self.stop_feed()
        self.feed = Proc(f"{self.orientation}_feed", self.feed_cmd())

    def stop_feed(self):
        if self.feed:
            self.feed.stop()
            self.feed = None

    def start_relay(self):
        self.stop_relay()
        self.relay = Proc(f"{self.orientation}_relay", self.relay_cmd())

    def stop_relay(self):
        if self.relay:
            self.relay.stop()
            self.relay = None

    def event(self, msg, level=logging.INFO):
        self.last_event = msg
        log.log(level, f"[{self.orientation}] {msg}")

    # --- state machine
    def tick(self, now):
        present = self.stream_name is not None
        kbps = self.kbps
        if self.state == "idle":
            if present:
                self.start_feed()
                if self.protected:
                    self.start_relay()
                self.state = "live"
                self.low_count = 0
                self.event(f"Stream received ({kbps if kbps is not None else 'starting'} kbps). Broadcasting to platforms.")
            return

        if self.protected and self.relay and not self.relay.alive():
            self.event("Broadcast relay stopped unexpectedly, restarting.", logging.WARNING)
            self.start_relay()

        if self.state == "live":
            if not self.protected:
                if not present:
                    self.end_session("Stream disconnected (protection is turned off).")
                elif self.feed and not self.feed.alive():
                    self.start_feed()
                return
            if not present:
                self.enter_backup("Stream disconnected.")
            elif kbps is not None and kbps < self.s.low_kbps:
                self.low_count += 1
                if self.low_count >= LOW_GRACE_SECONDS:
                    self.enter_backup(f"Low bitrate ({kbps} kbps < {self.s.low_kbps} kbps).")
            else:
                self.low_count = 0
                if self.feed and not self.feed.alive():
                    self.event("Stream hand-off stopped, restarting it. Your encoder must send H.264 video with audio.",
                               logging.WARNING)
                    self.start_feed()
            return

        if self.state == "backup":
            if present and (kbps is None or kbps >= self.s.low_kbps):
                self.good_count += 1
                if self.good_count >= RESTORE_GRACE_SECONDS:
                    self.start_feed()
                    self.state = "live"
                    self.backup_since = None
                    self.low_count = 0
                    self.event(f"Stream recovered ({kbps if kbps is not None else 'restoring'} kbps). Switched back to live.")
                    return
            else:
                self.good_count = 0
            if now - self.backup_since >= self.s.timeout:
                if present:
                    drop_publisher(self.ingest_app, self.stream_name)
                self.end_session(f"No recovery within {self.s.timeout} seconds. Broadcast ended.")

    def enter_backup(self, reason):
        self.stop_feed()
        self.state = "backup"
        self.backup_since = time.time()
        self.good_count = 0
        self.event(f"{reason} Playing backup video for up to {self.s.timeout} seconds.", logging.WARNING)

    def end_session(self, reason):
        self.stop_feed()
        self.stop_relay()
        self.state = "idle"
        self.backup_since = None
        self.event(reason, logging.WARNING)

    def status(self, now):
        return {
            "state": self.state,
            "kbps": self.kbps,
            "backupElapsed": int(now - self.backup_since) if self.backup_since else 0,
            "lastEvent": self.last_event,
        }

    def shutdown(self):
        self.stop_feed()
        self.stop_relay()


def drop_publisher(app, name):
    try:
        http_get(f"{NGINX_CONTROL}/drop/publisher?app={urllib.parse.quote(app)}&name={urllib.parse.quote(name)}")
    except Exception as e:
        log.warning(f"Could not drop publisher on {app}: {e}")


class MediaMTX:
    def __init__(self):
        self.proc = None

    def ensure_running(self):
        if self.proc and self.proc.alive():
            return False
        if self.proc:
            log.warning("MediaMTX exited, restarting.")
        self.proc = Proc("mediamtx", [MTX_BIN, MTX_CONFIG])
        time.sleep(1)
        return True

    def stop(self):
        if self.proc:
            self.proc.stop()


def write_status(settings, channels, now):
    data = {
        "enabled": settings.enabled,
        "lowBitrateKbps": settings.low_kbps,
        "restoreBitrateKbps": settings.restore_kbps,
        "timeoutSeconds": settings.timeout,
        "updatedAt": int(now),
        "channels": {c.orientation: c.status(now) for c in channels},
    }
    tmp = STATUS_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.replace(tmp, STATUS_FILE)


def main():
    settings = Settings()
    log.info(f"Starting. Protection {'ON' if settings.enabled else 'OFF'}; low={settings.low_kbps} kbps, "
             f"restore={settings.restore_kbps} kbps, backup duration={settings.timeout}s")

    mtx = None
    if settings.enabled:
        videos = prepare_videos(settings)
        update_prep_status(92, "Writing MediaMTX configuration", MTX_CONFIG)
        write_mediamtx_config(videos)
        update_prep_status(96, "Starting MediaMTX video streamer", f"Port {MTX_RTMP_PORT}")
        mtx = MediaMTX()
        mtx.ensure_running()
        update_prep_status(100, "MediaMTX Active & Ready", "Disconnection failover ready")

    channels = [Channel(o, settings.ingest_apps[o], settings, settings.enabled) for o in OUTPUTS]
    stop = threading.Event()

    def handle_signal(*_):
        stop.set()
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    while not stop.is_set():
        now = time.time()
        settings.reload()
        if mtx and mtx.ensure_running():
            for c in channels:
                if c.relay:
                    c.start_relay()
                if c.state == "live":
                    c.start_feed()
        try:
            publishers = read_ingest_streams(set(settings.ingest_apps.values()))
        except Exception as e:
            log.debug(f"Stats unavailable: {e}")
            stop.wait(1)
            continue
        for c in channels:
            c.update_bitrate(publishers.get(c.ingest_app), now)
            c.tick(now)
        try:
            write_status(settings, channels, now)
        except OSError as e:
            log.debug(f"Status write failed: {e}")
        stop.wait(1)

    for c in channels:
        c.shutdown()
    if mtx:
        mtx.stop()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "prepare":
        prepare_videos(Settings())
    else:
        main()
