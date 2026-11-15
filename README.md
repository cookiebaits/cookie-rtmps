# CookieRTMPS (RTMP/RTMPS Multi-Stream Relay)

CookieRTMPS is a Dockerized Nginx-RTMP + Stunnel multi-streaming relay server built for simultaneous horizontal and vertical broadcasting across YouTube, Twitch, Kick, TikTok, Facebook, Instagram, X (Twitter), Trovo, and custom RTMP endpoints.

## Key Features

- **Horizontal & Vertical Multi-Streaming:** Route horizontal (`rtmp://<host>:1935/live`) and vertical (`rtmp://<host>:1935/vertical`) OBS feeds simultaneously with automatic ingest server diversification for YouTube, Twitch, and Kick.
- **Native RTMP & Stunnel RTMPS Support:** Direct RTMP support for YouTube (`a.rtmp.youtube.com`) and Twitch (`ingest.global-contribute.live-video.net`), alongside encrypted RTMPS relays via Stunnel for Facebook (`19350`), Instagram (`19351`), Twitch (`19353`), X (`19354`), YouTube Primary/Backup (`19355`/`19357`), Kick (`19356`), and TikTok (`19358`).
- **Pure RTMP Footprint (No Web/HTML Pages):** All HTML pages (`chat.html`, `/stat`, `stat.xsl`), Combined Chat, and Stream Title/Twitch API web hooks are stripped out, exposing only the RTMP ingest port (`1935`) without binding or interfering with host web ports (`80`, `443`, etc.).
- **NOALBS Disabled by Default:** Disconnection protection and BRB MP4 download/FFmpeg transcoding are disabled out of the box (`NOALBS_ENABLED="false"`, `CLOUD_BRB="false"`) and can be enabled on demand from the installer menu.
- **Automatic Persistent Configuration & Fast Redeploy:** Settings saved in `rtmp_config.env` are automatically mirrored to `~/.cookie-rtmps/rtmp_config.env` so replacing `install.sh` or re-cloning the repository preserves every stream key and menu setting.
- **Pre-Start Cleanup & Deep Uninstall:** Automatically clears old RTMP containers, volumes, stale temp/cache files, and non-sensitive RTMP port conflicts before starting, and provides a deep uninstall option that wipes all RTMP/RTMPS artifacts without touching sensitive system ports (`22`, `53`, `80`, `443`, etc.).

---

## Fresh Installation

```bash
git clone https://github.com/cookiebaits/cookie-rtmps.git && cd cookie-rtmps && chmod +x install.sh && ./install.sh
```

1. Select **1) Install Docker** if Docker is not yet installed on your host.
2. Configure your stream keys under **2) Configure Stream Keys (Horizontal)** and/or **3) Configure Stream Keys (Vertical)**.
3. Optionally configure your OBS security key, custom app path, IP whitelist, domain, or chunk size.
4. Select **9) Build & Start Server**.

---

## Updating & Quick Redeployment (Preserving All Settings)

Whenever you configure any option in `install.sh`, your configuration is saved to `./rtmp_config.env` **and** automatically backed up outside the repository folder at:

```text
~/.cookie-rtmps/rtmp_config.env
```

Because the backup lives outside the `cookie-rtmps` directory, you can cleanly replace the entire repository or drop in an updated `install.sh` and `Dockerfile` without losing any stream keys, OBS keys, IP whitelists, or menu settings.

### Option A: Clean Replace & Launch Interactive Menu

Run this one-liner from the parent directory where `cookie-rtmps` is located:

```bash
rm -rf cookie-rtmps && git clone https://github.com/cookiebaits/cookie-rtmps.git && cd cookie-rtmps && chmod +x install.sh && ./install.sh
```

When `./install.sh` launches, it automatically detects `~/.cookie-rtmps/rtmp_config.env`, restores `./rtmp_config.env`, and loads all your previous settings.

### Option B: Clean Replace with Custom `install.sh` / `Dockerfile` & Instant Redeploy

If you maintain customized versions of `install.sh` and `Dockerfile` (for example, saved in `~/.cookie-rtmps/custom/`), you can replace the repository, apply your custom files, and rebuild immediately in a single command without stepping through any menus:

```bash
mkdir -p ~/.cookie-rtmps/custom && \
cp -f cookie-rtmps/install.sh cookie-rtmps/Dockerfile ~/.cookie-rtmps/custom/ 2>/dev/null || true && \
rm -rf cookie-rtmps && \
git clone https://github.com/cookiebaits/cookie-rtmps.git && \
cp -f ~/.cookie-rtmps/custom/install.sh ~/.cookie-rtmps/custom/Dockerfile cookie-rtmps/ && \
cd cookie-rtmps && \
chmod +x install.sh && \
./install.sh --redeploy
```

### Option C: Updating Inside an Existing Repository Directory

If you only replaced `install.sh` (or pulled updates inside `cookie-rtmps`), simply run:

```bash
chmod +x install.sh && ./install.sh --redeploy
```

---

## Installer Menu Reference

| Option | Description |
| :--- | :--- |
| **1) Install Docker** | Installs Docker Engine and enables the systemd service if missing. |
| **2) Configure Stream Keys (Horizontal)** | Configure horizontal ingest URLs and stream keys for YouTube, Twitch, Kick, TikTok, Facebook, Instagram, X, Trovo, or Custom RTMP. |
| **3) Configure Stream Keys (Vertical)** | Configure vertical stream keys or mirror horizontal keys with automatic ingest server diversification. |
| **4) Configure OBS Setup & Security Key** | View RTMP ingest URLs, set a custom OBS stream key, or change the RTMP application path. |
| **5) Configure IP Whitelist (Optional)** | Restrict incoming OBS connections to your server/VPN IP or a specific client IP. |
| **6) Configure Domain / Reverse Proxy (Optional)** | Set a custom hostname for displaying RTMP ingest URLs. |
| **7) Configure Optimizations (Chunk Size)** | Adjust RTMP chunk size (default `8192`) and apply Google BBR + TCP socket buffer tuning. |
| **8) Configure NOALBS Scene Switcher** | Enable/configure optional low-bitrate OBS scene switching or BRB video fallback (disabled by default). |
| **9) Build & Start Server** | Cleans old RTMP containers/temp files, verifies port `1935`, builds the Docker image, and starts `cookie-rtmps`. |
| **10) Run Integration Tests** | Runs `./integration_test.sh` against the active container. |
| **11) Stop Server & Uninstall** | Deep-searches and removes all RTMP/RTMPS containers, images, volumes, networks, cache/temp files, persistent backups, and non-sensitive RTMP ports (never touching ports `80`, `443`, `22`, `53`, etc.). |
| **12) View Logs** | Streams color-coded container logs with an option to truncate log files. |
| **13) Quit** | Exits the installer. |

---

## Ports Used

- **External Host Port:** `1935/tcp` (RTMP Horizontal & Vertical Ingest)
- **Internal Container Loopback Stunnel Ports (`127.0.0.1` only):**
  - `19350`: Facebook RTMPS
  - `19351`: Instagram RTMPS
  - `19353`: Twitch RTMPS
  - `19354`: X (Twitter) RTMPS
  - `19355`: YouTube Primary RTMPS
  - `19356`: Kick RTMPS
  - `19357`: YouTube Backup RTMPS
  - `19358`: TikTok RTMPS
- **Protected Ports (Never Modified or Bound):** `20`, `21`, `22`, `25`, `53`, `67`, `68`, `80`, `110`, `123`, `143`, `443`, `465`, `587`, `993`, `995`, `3306`, `5432`, `6379`, `27017`.