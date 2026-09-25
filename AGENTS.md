## Developer Memory

### System Base
- **Base Image**: Debian Bookworm (Debian 12, `buildpack-deps:bookworm`). All components are verified compatible with Bookworm and updated to ensure no components use Debian Trixie 13.7.

### Nginx & RTMP Module
- **Version**: Nginx 1.30.3 (stable) with local `cookie-nginx-rtmp` module.
- **Hardening**: AMF recursion limit (128), no VLAs, `ngx_random()` handshakes, and fixed memory leaks in `ngx_rtmp_eval.c`.
- **Codecs**: Support for HEVC (H.265), AV1, and VP9 via Enhanced RTMP FourCC identification.

### Streaming Infrastructure
- **RTMPS**: Handled via local Stunnel proxying (ports 19350-19358). Stunnel config includes SNI and `checkHost` for CDN compatibility.
- **Dual-Streaming**: Supported via separate `live` (horizontal) and `vertical` Nginx applications. `install.sh` handles auto-mirroring and server diversification.

### Management & UI
- **Installer**: `install.sh` provides interactive menu reordered for Domain (#5) and Whitelist (#8).
- **Control Dashboard**: `chat.html` integrated with `stream_validator.py` (Flask) for side-by-side chat and sync title updates.
- **OAuth**: Supported for Twitch and YouTube with background token refresh logic to maintain sessions.
- **Persistence**: Stream keys and episode counts persisted in host volume `./data`.
