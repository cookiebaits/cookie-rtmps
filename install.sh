#!/bin/bash
# install.sh - Menu style configuration and installation for CookieRTMPS
# Ensure script is run with bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2/"
YOUTUBE_KEY=""
FACEBOOK_URL="rtmp://127.0.0.1:19350/rtmp/"
FACEBOOK_KEY=""
INSTAGRAM_URL="rtmp://127.0.0.1:19351/rtmp/"
INSTAGRAM_KEY=""
TIKTOK_URL="rtmp://127.0.0.1:19358/s_v/"
TIKTOK_KEY=""
TIKTOK_SL_TOKEN=""
TIKTOK_TITLE=""
TIKTOK_GAME_ID=""
TWITCH_URL="rtmp://127.0.0.1:19353/app/"
TWITCH_KEY=""
KICK_URL="rtmp://127.0.0.1:19356/kick/"
KICK_KEY=""
X_URL="rtmp://127.0.0.1:19354/x/"
X_KEY=""
TROVO_URL="rtmp://livepush.trovo.live/live/"
TROVO_KEY=""
RTMP1_URL=""
RTMP1_KEY=""

# Vertical Defaults
V_YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2/"
V_YOUTUBE_KEY=""
V_TWITCH_URL="rtmp://127.0.0.1:19353/app/"
V_TWITCH_KEY=""
V_KICK_URL="rtmp://127.0.0.1:19356/kick/"
V_KICK_KEY=""
V_TIKTOK_URL="rtmp://127.0.0.1:19358/s_v/"
V_TIKTOK_KEY=""
V_FACEBOOK_URL="rtmp://127.0.0.1:19350/rtmp/"
V_FACEBOOK_KEY=""
V_INSTAGRAM_URL="rtmp://127.0.0.1:19351/rtmp/"
V_INSTAGRAM_KEY=""
V_X_URL="rtmp://127.0.0.1:19354/x/"
V_X_KEY=""
V_TROVO_URL="rtmp://livepush.trovo.live/live/"
V_TROVO_KEY=""
V_RTMP1_URL=""
V_RTMP1_KEY=""

OBS_KEY=""
APP_NAME="live"
ACCEPTED_IP=""
WHITELIST_MODE="auto"
SERVER_DOMAIN=""
CHUNK_SIZE="4096"

# Host Port Settings
PORT_RTMP="1935"
PORT_RELAY_INTERNAL="19359"

# Docker Bridge Network for Server OBS <-> CookieRTMPS Relay
DOCKER_NET_NAME="cookie-rtmps-net"
DOCKER_NET_SUBNET="172.28.0.0/16"

# NOALBS & Disconnection Protection Settings (Disabled by default -> Pure RTMP passthrough)
NOALBS_ENABLED="false"
FALLBACK_MODE="obs"
OBS_WS_HOST="cookie-rtmps-obs"
OBS_WS_PORT="4455"
OBS_WS_PASSWORD=""
OBS_SCENE_LIVE="Main"
OBS_SCENE_BRB="BRB"
LOW_BITRATE="1000"
RESTORE_BITRATE="1500"
LOW_FPS="15"
RESTORE_FPS="20"
CLOUD_BRB="true"
BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
CLOUD_BRB_TIMEOUT="300"

# Server OBS Output Profile (720p30 recommended on 1-2 vCPU; 1080p30/60 for 4+ vCPU)
OBS_WIDTH="1280"
OBS_HEIGHT="720"
OBS_FPS="30"
OBS_BITRATE="3500"

# Latest detected plugin versions (populated without host apt-get update/upgrade)
LATEST_NOALBS_VERSION=""
LATEST_NGINX_RTMP_VERSION=""

CONFIG_FILE="$SCRIPT_DIR/rtmp_config.env"
PERSIST_USER_DIR="$HOME/.cookie-rtmps"
PERSIST_USER_CONFIG="$PERSIST_USER_DIR/rtmp_config.env"
PERSIST_SYS_DIR="/etc/cookie-rtmps"
PERSIST_SYS_CONFIG="$PERSIST_SYS_DIR/rtmp_config.env"

CONFIG_VARS=(
    YOUTUBE_URL YOUTUBE_KEY FACEBOOK_URL FACEBOOK_KEY INSTAGRAM_URL INSTAGRAM_KEY
    TIKTOK_URL TIKTOK_KEY TIKTOK_SL_TOKEN TIKTOK_TITLE TIKTOK_GAME_ID
    TWITCH_URL TWITCH_KEY KICK_URL KICK_KEY X_URL X_KEY TROVO_URL TROVO_KEY
    RTMP1_URL RTMP1_KEY V_YOUTUBE_URL V_YOUTUBE_KEY V_TWITCH_URL V_TWITCH_KEY
    V_KICK_URL V_KICK_KEY V_TIKTOK_URL V_TIKTOK_KEY V_FACEBOOK_URL V_FACEBOOK_KEY
    V_INSTAGRAM_URL V_INSTAGRAM_KEY V_X_URL V_X_KEY V_TROVO_URL V_TROVO_KEY
    V_RTMP1_URL V_RTMP1_KEY OBS_KEY APP_NAME ACCEPTED_IP WHITELIST_MODE
    SERVER_DOMAIN CHUNK_SIZE NOALBS_ENABLED FALLBACK_MODE OBS_WS_HOST
    OBS_WS_PORT OBS_WS_PASSWORD OBS_SCENE_LIVE OBS_SCENE_BRB LOW_BITRATE
    RESTORE_BITRATE LOW_FPS RESTORE_FPS CLOUD_BRB BRB_VIDEO_URL
    CLOUD_BRB_TIMEOUT PORT_RTMP OBS_WIDTH OBS_HEIGHT OBS_FPS OBS_BITRATE
)

get_sudo() {
    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
        echo "sudo"
    fi
}

get_server_ip() {
    if [ -z "$CACHED_SERVER_IP" ]; then
        CACHED_SERVER_IP=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
        [ -z "$CACHED_SERVER_IP" ] && CACHED_SERVER_IP="<your_server_ip>"
    fi
    echo "$CACHED_SERVER_IP"
}

is_server_managed_obs() {
    [ "$NOALBS_ENABLED" == "true" ] && [ "$FALLBACK_MODE" == "obs" ] && \
    { [ -z "$OBS_WS_HOST" ] || [ "$OBS_WS_HOST" == "127.0.0.1" ] || [ "$OBS_WS_HOST" == "localhost" ] || [ "$OBS_WS_HOST" == "cookie-rtmps-obs" ]; }
}

mask_to_cidr() {
    local mask="$1"
    local bits=0
    local IFS='.'
    read -r o1 o2 o3 o4 <<< "$mask"
    for octet in "$o1" "$o2" "$o3" "$o4"; do
        case "$octet" in
            255) bits=$((bits + 8)) ;;
            254) bits=$((bits + 7)) ;;
            252) bits=$((bits + 6)) ;;
            248) bits=$((bits + 5)) ;;
            240) bits=$((bits + 4)) ;;
            224) bits=$((bits + 3)) ;;
            192) bits=$((bits + 2)) ;;
            128) bits=$((bits + 1)) ;;
            0)   ;;
            *)   return 1 ;;
        esac
    done
    echo "$bits"
}

normalize_ipv4_cidr() {
    local input="$1"
    local ip="${input%%/*}"
    local prefix="${input#*/}"

    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    if [ "$ip" == "$prefix" ] || ! [[ "$prefix" =~ ^[0-9]+$ ]] || [ "$prefix" -lt 0 ] || [ "$prefix" -gt 32 ]; then
        echo "$ip"
        return 0
    fi
    if [ "$prefix" -eq 32 ]; then
        echo "${ip}/32"
        return 0
    fi
    if [ "$prefix" -eq 0 ]; then
        return 1
    fi

    local IFS='.'
    read -r o1 o2 o3 o4 <<< "$ip"
    local ip_int=$(( (o1 << 24) + (o2 << 16) + (o3 << 8) + o4 ))
    local mask_int=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
    local net_int=$(( ip_int & mask_int ))
    printf "%d.%d.%d.%d/%d\n" \
        $(( (net_int >> 24) & 255 )) \
        $(( (net_int >> 16) & 255 )) \
        $(( (net_int >> 8) & 255 )) \
        $(( net_int & 255 )) \
        "$prefix"
}

detect_vpn_ip_ranges() {
    local SUDO
    SUDO=$(get_sudo)
    local raw_ranges=()

    # 1. Detect active WireGuard (wg*) and OpenVPN (tun*/tap*) interfaces
    if command -v ip &> /dev/null; then
        local iface addr route_net norm
        while read -r iface; do
            [ -z "$iface" ] && continue
            while read -r route_net; do
                if [[ "$route_net" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
                    norm=$(normalize_ipv4_cidr "$route_net" 2>/dev/null || true)
                    [ -n "$norm" ] && raw_ranges+=("$norm")
                fi
            done < <(ip -4 route show dev "$iface" scope link 2>/dev/null | awk '{print $1}')

            while read -r addr; do
                norm=$(normalize_ipv4_cidr "$addr" 2>/dev/null || true)
                [ -n "$norm" ] && raw_ranges+=("$norm")
            done < <(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4}')
        done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 | grep -E '^(wg|tun|tap|ovpn|utun)[0-9a-zA-Z_-]*$' || true)
    fi

    # 2. Detect WireGuard subnets from /etc/wireguard/*.conf
    local wg_conf wg_line wg_item norm
    if [ -d "/etc/wireguard" ]; then
        while IFS= read -r wg_conf; do
            [ -z "$wg_conf" ] && continue
            while IFS= read -r wg_line; do
                wg_line=$(echo "$wg_line" | sed -E 's/^[[:space:]]*Address[[:space:]]*=[[:space:]]*//I' | tr -d ' ')
                IFS=',' read -ra wg_parts <<< "$wg_line"
                for wg_item in "${wg_parts[@]}"; do
                    if [[ "$wg_item" == *.* ]]; then
                        norm=$(normalize_ipv4_cidr "$wg_item" 2>/dev/null || true)
                        [ -n "$norm" ] && raw_ranges+=("$norm")
                    fi
                done
            done < <($SUDO grep -iE '^[[:space:]]*Address[[:space:]]*=' "$wg_conf" 2>/dev/null || true)
        done < <($SUDO find /etc/wireguard -maxdepth 2 -type f -name "*.conf" 2>/dev/null || true)
    fi

    # 3. Detect OpenVPN subnets from /etc/openvpn/*.conf and /etc/openvpn/server/*.conf
    local ovpn_conf ovpn_net ovpn_mask ovpn_cidr norm
    if [ -d "/etc/openvpn" ]; then
        while IFS= read -r ovpn_conf; do
            [ -z "$ovpn_conf" ] && continue
            while read -r _ ovpn_net ovpn_mask _; do
                ovpn_cidr=$(mask_to_cidr "$ovpn_mask" 2>/dev/null || true)
                if [ -n "$ovpn_cidr" ]; then
                    norm=$(normalize_ipv4_cidr "${ovpn_net}/${ovpn_cidr}" 2>/dev/null || true)
                    [ -n "$norm" ] && raw_ranges+=("$norm")
                fi
            done < <($SUDO grep -iE '^[[:space:]]*server[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$ovpn_conf" 2>/dev/null || true)
        done < <($SUDO find /etc/openvpn -maxdepth 3 -type f -name "*.conf" 2>/dev/null || true)
    fi

    # 4. Always include standard private WireGuard & OpenVPN default subnets
    raw_ranges+=(
        "10.8.0.0/24"
        "10.66.66.0/24"
        "10.7.0.0/24"
        "10.13.13.0/24"
    )

    # Deduplicate while preserving order
    local seen="" item
    for item in "${raw_ranges[@]}"; do
        [ -z "$item" ] && continue
        [ "$item" == "0.0.0.0/0" ] && continue
        if [[ ",$seen," != *",$item,"* ]]; then
            seen="${seen:+${seen},}${item}"
        fi
    done
    echo "$seen"
}

build_default_whitelist() {
    local srv_ip vpn_ranges combined="" item
    srv_ip=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || true)
    if [[ "$srv_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        CACHED_SERVER_IP="$srv_ip"
        combined="$srv_ip"
    fi

    # Always allow localhost for internal relays, host Stunnel RTMPS, and Server-Side BRB
    if [[ ",$combined," != *",127.0.0.1,"* ]]; then
        combined="${combined:+${combined},}127.0.0.1"
    fi

    vpn_ranges=$(detect_vpn_ip_ranges)
    IFS=',' read -ra vpn_list <<< "$vpn_ranges"
    for item in "${vpn_list[@]}"; do
        [ -z "$item" ] && continue
        if [[ ",$combined," != *",$item,"* ]]; then
            combined="${combined:+${combined},}${item}"
        fi
    done

    echo "$combined"
}

ensure_localhost_in_whitelist() {
    local list="$1"
    [ -z "$list" ] && { echo ""; return 0; }
    if [[ ",$list," != *",127.0.0.1,"* ]]; then
        echo "127.0.0.1,${list}"
    else
        echo "$list"
    fi
}

sync_container_nginx_whitelist() {
    local container_name="$1"
    local include_docker_net="${2:-false}"
    local effective_ip
    effective_ip=$(ensure_localhost_in_whitelist "$ACCEPTED_IP")

    if [ "$include_docker_net" == "true" ] && [ -n "$effective_ip" ] && [[ ",$effective_ip," != *",${DOCKER_NET_SUBNET},"* ]]; then
        effective_ip="${effective_ip},${DOCKER_NET_SUBNET}"
    fi

    command -v docker &> /dev/null || return 0
    docker ps --format '{{.Names}}' | grep -qx "$container_name" || return 0

    echo -e "${CYAN}Syncing IP whitelist rules into '${container_name}'...${NC}"

    local rules_block=""
    if [ -n "$effective_ip" ]; then
        local entry
        for entry in $(echo "$effective_ip" | tr ',' ' '); do
            entry=$(echo "$entry" | tr -d '[:space:]')
            [ -n "$entry" ] && rules_block="${rules_block}            allow publish ${entry};"$'\n'
        done
        rules_block="${rules_block}            deny publish all;"
    else
        rules_block="            allow publish all;"
    fi

    docker exec -i -e "WL_RULES=$rules_block" "$container_name" sh -c '
        CONF=""
        for candidate in /etc/nginx/nginx.conf /usr/local/nginx/conf/nginx.conf /etc/nginx/rtmp.conf; do
            if [ -f "$candidate" ] && grep -q "rtmp[[:space:]]*{" "$candidate"; then
                CONF="$candidate"
                break
            fi
        done

        if [ -z "$CONF" ]; then
            echo "No RTMP nginx.conf found inside container." >&2
            exit 1
        fi

        cp -f "$CONF" "${CONF}.bak"

        awk -v rules="$WL_RULES" '\''
            BEGIN { in_rtmp = 0; in_app = 0 }
            /^[[:space:]]*rtmp[[:space:]]*\{/ { in_rtmp = 1 }
            in_rtmp && /^[[:space:]]*application[[:space:]]+[^{]+\{/ {
                in_app = 1
                print
                print rules
                next
            }
            in_app && /^[[:space:]]*(allow|deny)[[:space:]]+publish[[:space:]]+/ {
                next
            }
            in_app && /^[[:space:]]*\}/ {
                in_app = 0
            }
            { print }
        '\'' "${CONF}.bak" > "$CONF"

        if nginx -t >/dev/null 2>&1; then
            nginx -s reload >/dev/null 2>&1 || true
            rm -f "${CONF}.bak"
            exit 0
        else
            mv -f "${CONF}.bak" "$CONF"
            echo "Nginx syntax validation failed; rolled back config." >&2
            exit 1
        fi
    '

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Whitelist rules synced and reloaded inside '${container_name}'.${NC}"
    else
        echo -e "${YELLOW}Warning: Could not automatically reload whitelist in '${container_name}'.${NC}"
    fi
}

sync_obs_container_whitelist() {
    [ "$NOALBS_ENABLED" == "true" ] || return 0
    sync_container_nginx_whitelist "cookie-rtmps-obs" "true"
}

generate_obs_server_files() {
    local obs_dir="$SCRIPT_DIR/obs-server"
    mkdir -p "$obs_dir"

    cat << 'DOCKERFILE_OBS_EOF' > "$obs_dir/Dockerfile"
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV GALLIUM_DRIVER=llvmpipe
ENV LP_NUM_THREADS=1
ENV MESA_GL_VERSION_OVERRIDE=3.3
ENV QT_QPA_PLATFORM=xcb
ENV QT_X11_NO_MITSHM=1
ENV XDG_RUNTIME_DIR=/tmp/runtime-root

# Install Full Official OBS Studio (via obsproject PPA with Ubuntu fallback) + full FFmpeg/VLC/OpenGL stack (no apt-get upgrade)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    software-properties-common \
    && (add-apt-repository -y ppa:obsproject/obs-studio || true) \
    && apt-get update -qq \
    && apt-get install -y \
    ffmpeg \
    libgl1 \
    libgl1-mesa-dri \
    libnginx-mod-rtmp \
    mesa-utils \
    nginx \
    obs-studio \
    pulseaudio \
    pulseaudio-utils \
    python3 \
    vlc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY auth_server.py /app/auth_server.py
COPY obs_controller.py /app/obs_controller.py
COPY obs_entrypoint.sh /app/obs_entrypoint.sh
RUN chmod +x /app/auth_server.py /app/obs_controller.py /app/obs_entrypoint.sh

EXPOSE 1935 4455
ENTRYPOINT ["/app/obs_entrypoint.sh"]
DOCKERFILE_OBS_EOF

    cat << 'AUTH_PY_EOF' > "$obs_dir/auth_server.py"
#!/usr/bin/env python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

EXPECTED_KEY = os.environ.get("OBS_KEY", "").strip()


class AuthHandler(BaseHTTPRequestHandler):
    def _check(self):
        if not EXPECTED_KEY:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
            return
        qs = parse_qs(urlparse(self.path).query)
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length).decode("utf-8", errors="ignore") if length > 0 else ""
        form = parse_qs(body)
        name = (form.get("name") or qs.get("name") or [""])[0]
        key = (form.get("key") or qs.get("key") or [""])[0]
        if name == EXPECTED_KEY or key == EXPECTED_KEY:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden")

    def do_GET(self):
        self._check()

    def do_POST(self):
        self._check()

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8089), AuthHandler).serve_forever()
AUTH_PY_EOF

    cat << 'CONTROLLER_PY_EOF' > "$obs_dir/obs_controller.py"
#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import socket
import struct
import time
import urllib.request
import xml.etree.ElementTree as ET

APP_NAME = os.environ.get("APP_NAME", "live")
OBS_WS_HOST = "127.0.0.1"
OBS_WS_PORT = int(os.environ.get("OBS_WS_PORT", "4455") or "4455")
OBS_WS_PASSWORD = os.environ.get("OBS_WS_PASSWORD", "")
OBS_SCENE_LIVE = os.environ.get("OBS_SCENE_LIVE", "Main")
OBS_SCENE_BRB = os.environ.get("OBS_SCENE_BRB", "BRB")
LOW_BITRATE = int(os.environ.get("LOW_BITRATE", "1000") or "1000")
RESTORE_BITRATE = int(os.environ.get("RESTORE_BITRATE", "1500") or "1500")
LOW_FPS = float(os.environ.get("LOW_FPS", "15") or "15")
RESTORE_FPS = float(os.environ.get("RESTORE_FPS", "20") or "20")
BRB_TIMEOUT = int(os.environ.get("CLOUD_BRB_TIMEOUT", "300") or "300")
STAT_URL = os.environ.get("NGINX_STAT_URL", "http://127.0.0.1:8088/stat")


def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] [OBS-Controller] {msg}", flush=True)


class SimpleWSClient:
    """Minimal stdlib RFC 6455 WebSocket client for OBS WebSocket v5."""
    def __init__(self, host, port, password="", timeout=5.0):
        self.host = host
        self.port = port
        self.password = password
        self.timeout = timeout
        self.sock = None
        self.req_id = 0

    def _recv_exact(self, n):
        buf = bytearray()
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("WebSocket closed")
            buf.extend(chunk)
        return bytes(buf)

    def connect(self):
        self.close()
        self.sock = socket.create_connection((self.host, self.port), timeout=self.timeout)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        req = (
            f"GET / HTTP/1.1\r\n"
            f"Host: {self.host}:{self.port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        )
        self.sock.sendall(req.encode("ascii"))
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = self.sock.recv(1024)
            if not chunk:
                raise ConnectionError("WebSocket handshake failed")
            resp += chunk
        if b"101 " not in resp.split(b"\r\n", 1)[0]:
            raise ConnectionError(f"Bad WS status: {resp[:64]!r}")

        # OBS WebSocket v5 handshake: Op 0 Hello -> Op 1 Identify -> Op 2 Identified
        hello = self.recv_json()
        if hello.get("op") != 0:
            raise RuntimeError(f"Expected Hello (op 0), got {hello}")
        ident_d = {"rpcVersion": 1, "eventSubscriptions": 0}
        auth = hello.get("d", {}).get("authentication")
        if auth and self.password:
            secret = base64.b64encode(
                hashlib.sha256((self.password + auth["salt"]).encode("utf-8")).digest()
            ).decode("ascii")
            auth_str = base64.b64encode(
                hashlib.sha256((secret + auth["challenge"]).encode("utf-8")).digest()
            ).decode("ascii")
            ident_d["authentication"] = auth_str
        self.send_json({"op": 1, "d": ident_d})
        identified = self.recv_json()
        if identified.get("op") != 2:
            raise RuntimeError(f"OBS Identify failed: {identified}")

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None

    def send_frame(self, payload_bytes, opcode=0x1):
        mask_key = os.urandom(4)
        length = len(payload_bytes)
        header = bytearray([0x80 | opcode])
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", length))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", length))
        masked = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload_bytes))
        self.sock.sendall(bytes(header) + mask_key + masked)

    def send_json(self, obj):
        self.send_frame(json.dumps(obj).encode("utf-8"), opcode=0x1)

    def recv_json(self):
        while True:
            b1, b2 = self._recv_exact(2)
            opcode = b1 & 0x0F
            masked = bool(b2 & 0x80)
            length = b2 & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._recv_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._recv_exact(8))[0]
            mask_key = self._recv_exact(4) if masked else None
            payload = self._recv_exact(length)
            if mask_key:
                payload = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))
            if opcode == 0x8:
                raise ConnectionError("WebSocket closed by OBS")
            if opcode == 0x9:
                self.send_frame(payload, opcode=0xA)
                continue
            if opcode == 0xA:
                continue
            if opcode == 0x1:
                return json.loads(payload.decode("utf-8"))

    def call(self, request_type, request_data=None):
        self.req_id += 1
        rid = str(self.req_id)
        d = {"requestType": request_type, "requestId": rid}
        if request_data:
            d["requestData"] = request_data
        self.send_json({"op": 6, "d": d})
        while True:
            msg = self.recv_json()
            if msg.get("op") == 7 and msg.get("d", {}).get("requestId") == rid:
                return msg["d"]


def poll_nginx_stat():
    """Return dict with publishing, name, bw_in_kbps, bw_video_kbps, bytes_in, meta_fps."""
    info = {
        "publishing": False,
        "name": None,
        "bw_in_kbps": 0,
        "bw_video_kbps": 0,
        "bytes_in": 0,
        "meta_fps": 0.0,
    }
    try:
        with urllib.request.urlopen(STAT_URL, timeout=2.0) as resp:
            xml_data = resp.read()
        root = ET.fromstring(xml_data)
        for app in root.findall(".//application"):
            name_el = app.find("name")
            if name_el is None or name_el.text != APP_NAME:
                continue
            live = app.find("live")
            if live is None:
                continue
            for stream in live.findall("stream"):
                if stream.find("publishing") is not None:
                    sname_el = stream.find("name")
                    bw_el = stream.find("bw_in")
                    bwv_el = stream.find("bw_video")
                    bytes_el = stream.find("bytes_in")
                    fps_el = stream.find("./meta/video/frame_rate")

                    info["publishing"] = True
                    info["name"] = sname_el.text.strip() if (sname_el is not None and sname_el.text) else "stream"
                    if bw_el is not None and bw_el.text and bw_el.text.strip().isdigit():
                        info["bw_in_kbps"] = int(bw_el.text.strip()) // 1000
                    if bwv_el is not None and bwv_el.text and bwv_el.text.strip().isdigit():
                        info["bw_video_kbps"] = int(bwv_el.text.strip()) // 1000
                    if bytes_el is not None and bytes_el.text and bytes_el.text.strip().isdigit():
                        info["bytes_in"] = int(bytes_el.text.strip())
                    if fps_el is not None and fps_el.text:
                        try:
                            info["meta_fps"] = float(fps_el.text.strip())
                        except ValueError:
                            pass
                    return info
    except Exception:
        pass
    return info


def get_ingest_media_state(ws):
    """Query OBS RTMP_Ingest_Source mediaState and mediaCursor."""
    try:
        res = ws.call("GetMediaInputStatus", {"inputName": "RTMP_Ingest_Source"})
        data = res.get("responseData") or {}
        return data.get("mediaState", ""), data.get("mediaCursor")
    except Exception:
        return "", None


def switch_to_main(ws, sname, current_stream_name, already_on_main=False):
    """Ensure RTMP_Ingest_Source points to the active stream and cleanly activates Main without double-restarting."""
    ingest_url = f"rtmp://127.0.0.1:1935/{APP_NAME}/{sname}"
    if sname != current_stream_name:
        ws.call("SetInputSettings", {
            "inputName": "RTMP_Ingest_Source",
            "inputSettings": {"input": ingest_url},
            "overlay": True,
        })
    if already_on_main:
        # Main was already active in STANDBY, so trigger a single restart to pull the fresh RTMP feed
        ws.call("TriggerMediaInputAction", {
            "inputName": "RTMP_Ingest_Source",
            "mediaAction": "OBS_WEBSOCKET_MEDIA_INPUT_ACTION_RESTART",
        })
    else:
        # Switching from BRB -> Main: restart_on_activate=true automatically opens RTMP_Ingest_Source cleanly once
        ws.call("SetCurrentProgramScene", {"sceneName": OBS_SCENE_LIVE})
    return sname


def ensure_connected(ws):
    if ws.sock is not None:
        return True
    try:
        ws.connect()
        log(f"Connected to OBS WebSocket v5 at {OBS_WS_HOST}:{OBS_WS_PORT}")
        return True
    except Exception as exc:
        log(f"Waiting for OBS WebSocket ({exc})...")
        ws.close()
        return False


def main():
    log(
        f"Starting Full Server OBS Workflow Controller | app=/{APP_NAME} "
        f"main='{OBS_SCENE_LIVE}' brb='{OBS_SCENE_BRB}' "
        f"low_bw={LOW_BITRATE}kbps restore_bw={RESTORE_BITRATE}kbps "
        f"low_fps={LOW_FPS} restore_fps={RESTORE_FPS} timeout={BRB_TIMEOUT}s"
    )
    ws = SimpleWSClient(OBS_WS_HOST, OBS_WS_PORT, OBS_WS_PASSWORD)
    state = "STANDBY"  # STANDBY -> LIVE <-> BRB -> STANDBY
    current_stream_name = None
    low_streak = 0
    high_streak = 0
    stall_streak = 0
    last_bytes_in = -1
    last_stat_ts = time.monotonic()
    last_perf_log = 0.0
    last_cursor = None
    brb_started_at = None
    live_grace_until = 0.0
    initialized_standby = False

    while True:
        try:
            if not ensure_connected(ws):
                time.sleep(2)
                continue

            # Enforce clean STANDBY on startup: Main scene selected, output stream OFF
            if not initialized_standby:
                ws.call("SetCurrentProgramScene", {"sceneName": OBS_SCENE_LIVE})
                status = ws.call("GetStreamStatus")
                if status.get("responseData", {}).get("outputActive", False):
                    ws.call("StopStream")
                initialized_standby = True
                log(f"Server OBS ready in STANDBY on '{OBS_SCENE_LIVE}' (waiting for RTMP/RTMPS feed)")

            now = time.monotonic()
            dt = max(now - last_stat_ts, 0.2)
            last_stat_ts = now

            stat = poll_nginx_stat()
            publishing = stat["publishing"]
            sname = stat["name"]
            bw_kbps = stat["bw_in_kbps"]
            bytes_in = stat["bytes_in"]
            meta_fps = stat["meta_fps"]

            # Compute instantaneous 1-second bitrate from bytes_in delta (faster than nginx 10s average)
            instant_kbps = 0
            bytes_advancing = False
            if publishing:
                if last_bytes_in >= 0 and bytes_in > last_bytes_in:
                    bytes_advancing = True
                    instant_kbps = int(((bytes_in - last_bytes_in) * 8) / (dt * 1000.0))
                last_bytes_in = bytes_in
            else:
                last_bytes_in = -1

            effective_kbps = max(bw_kbps, instant_kbps) if (state == "STANDBY") else (bw_kbps if bw_kbps > 0 else instant_kbps)

            if state == "STANDBY":
                if publishing and (effective_kbps >= 50 or bytes_advancing):
                    high_streak += 1
                    if high_streak >= 2:
                        high_streak = 0
                        low_streak = 0
                        stall_streak = 0
                        last_cursor = None
                        current_stream_name = switch_to_main(ws, sname, current_stream_name, already_on_main=True)
                        status = ws.call("GetStreamStatus")
                        if not status.get("responseData", {}).get("outputActive", False):
                            ws.call("StartStream")
                        live_grace_until = time.monotonic() + 8.0
                        state = "LIVE"
                        log(
                            f"RTMP/RTMPS feed detected ('{sname}', {effective_kbps} kbps, "
                            f"{meta_fps:.1f} fps) -> Projecting '{OBS_SCENE_LIVE}' & GOING ONLINE"
                        )
                else:
                    high_streak = 0

            elif state == "LIVE":
                in_grace = now < live_grace_until
                degraded_reason = None

                # Log OBS runtime performance every 30s while LIVE to verify zero jitter/frame drops
                if now - last_perf_log >= 30.0:
                    last_perf_log = now
                    try:
                        obs_stats = (ws.call("GetStats").get("responseData") or {})
                        log(
                            f"LIVE Metrics | ingest={bw_kbps}kbps (inst={instant_kbps}kbps) | "
                            f"obs_fps={obs_stats.get('activeFps', 0):.1f} | "
                            f"cpu={obs_stats.get('cpuUsage', 0):.1f}% | "
                            f"render_skipped={obs_stats.get('renderSkippedFrames', 0)} | "
                            f"output_skipped={obs_stats.get('outputSkippedFrames', 0)}"
                        )
                    except Exception:
                        pass

                if not publishing:
                    degraded_reason = "RTMP feed disconnected"
                elif not in_grace:
                    if LOW_BITRATE > 0 and bw_kbps < LOW_BITRATE and instant_kbps < LOW_BITRATE:
                        degraded_reason = f"low bitrate (avg={bw_kbps}, inst={instant_kbps} < {LOW_BITRATE} kbps)"
                    elif not bytes_advancing:
                        degraded_reason = "incoming RTMP stream stalled (0 bytes/sec)"
                    elif LOW_FPS > 0 and meta_fps > 0 and meta_fps < LOW_FPS:
                        degraded_reason = f"low frame rate ({meta_fps:.1f} < {LOW_FPS:.1f} fps)"
                    else:
                        # Catch severe ingest frame drops / freezes on RTMP_Ingest_Source
                        m_state, m_cursor = get_ingest_media_state(ws)
                        if m_state in ("OBS_MEDIA_STATE_ENDED", "OBS_MEDIA_STATE_STOPPED", "OBS_MEDIA_STATE_ERROR", "OBS_MEDIA_STATE_BUFFERING"):
                            stall_streak += 1
                            if stall_streak >= 3:
                                degraded_reason = f"ingest frame stall ({m_state})"
                        elif m_state == "OBS_MEDIA_STATE_PLAYING" and m_cursor is not None and last_cursor is not None and m_cursor == last_cursor:
                            stall_streak += 1
                            if stall_streak >= 3:
                                degraded_reason = "video frames frozen (decoder cursor stalled)"
                        else:
                            stall_streak = 0
                        last_cursor = m_cursor

                if degraded_reason:
                    low_streak += 1
                    needed = 2 if not publishing else 3
                    if low_streak >= needed:
                        low_streak = 0
                        high_streak = 0
                        stall_streak = 0
                        last_cursor = None
                        ws.call("SetCurrentProgramScene", {"sceneName": OBS_SCENE_BRB})
                        brb_started_at = time.monotonic()
                        state = "BRB"
                        log(f"Protection triggered ({degraded_reason}) -> Switched to '{OBS_SCENE_BRB}' looping MP4 (timeout: {BRB_TIMEOUT}s)")
                else:
                    low_streak = 0

            elif state == "BRB":
                elapsed = time.monotonic() - (brb_started_at or time.monotonic())
                fps_ok = (LOW_FPS <= 0) or (meta_fps <= 0) or (meta_fps >= RESTORE_FPS)
                bw_ok = (RESTORE_BITRATE <= 0) or (bw_kbps >= RESTORE_BITRATE) or (instant_kbps >= RESTORE_BITRATE)

                if publishing and bytes_advancing and bw_ok and fps_ok:
                    high_streak += 1
                    if high_streak >= 2:
                        high_streak = 0
                        low_streak = 0
                        stall_streak = 0
                        last_cursor = None
                        current_stream_name = switch_to_main(ws, sname, current_stream_name, already_on_main=False)
                        brb_started_at = None
                        live_grace_until = time.monotonic() + 8.0
                        state = "LIVE"
                        log(
                            f"Signal restored ('{sname}', avg={bw_kbps}kbps, inst={instant_kbps}kbps, "
                            f"{meta_fps:.1f} fps) -> Returned automatically to '{OBS_SCENE_LIVE}'"
                        )
                else:
                    high_streak = 0
                    if elapsed >= BRB_TIMEOUT:
                        log(
                            f"BRB timeout expired ({BRB_TIMEOUT}s) -> Disconnecting stream, "
                            f"returning to '{OBS_SCENE_LIVE}' in STANDBY until signal returns"
                        )
                        status = ws.call("GetStreamStatus")
                        if status.get("responseData", {}).get("outputActive", False):
                            ws.call("StopStream")
                        ws.call("SetCurrentProgramScene", {"sceneName": OBS_SCENE_LIVE})
                        brb_started_at = None
                        current_stream_name = None
                        last_cursor = None
                        state = "STANDBY"

            time.sleep(1)

        except Exception as exc:
            log(f"Controller loop error ({exc}); reconnecting to OBS WebSocket...")
            ws.close()
            time.sleep(2)


if __name__ == "__main__":
    main()
CONTROLLER_PY_EOF

    cat << 'ENTRYPOINT_OBS_EOF' > "$obs_dir/obs_entrypoint.sh"
#!/bin/bash
set -e

APP_NAME="${APP_NAME:-live}"
OBS_KEY="${OBS_KEY:-}"
CHUNK_SIZE="${CHUNK_SIZE:-4096}"
ACCEPTED_IP="${ACCEPTED_IP:-}"
OBS_WS_PORT="${OBS_WS_PORT:-4455}"
OBS_WS_PASSWORD="${OBS_WS_PASSWORD:-}"
OBS_SCENE_LIVE="${OBS_SCENE_LIVE:-Main}"
OBS_SCENE_BRB="${OBS_SCENE_BRB:-BRB}"
OBS_WIDTH="${OBS_WIDTH:-1280}"
OBS_HEIGHT="${OBS_HEIGHT:-720}"
OBS_FPS="${OBS_FPS:-30}"
OBS_BITRATE="${OBS_BITRATE:-3500}"
RELAY_HOST="${RELAY_HOST:-cookie-rtmps}"
RELAY_PORT="${RELAY_PORT:-1935}"
BRB_VIDEO_PATH="${BRB_VIDEO_PATH:-/app/data/brb_video.mp4}"

STREAM_KEY="${OBS_KEY:-stream}"
CPU_CORES=$(nproc 2>/dev/null || echo 1)

# Tune Mesa software OpenGL + x264 threads dynamically so threads never thrash on 1-2 core VPS
if [ "$CPU_CORES" -le 1 ]; then
    export LP_NUM_THREADS=1
    X264_THREADS=1
elif [ "$CPU_CORES" -le 3 ]; then
    export LP_NUM_THREADS=1
    X264_THREADS=2
else
    export LP_NUM_THREADS=2
    X264_THREADS=0
fi

mkdir -p /tmp/runtime-root /var/log/nginx /run/nginx
chmod 700 /tmp/runtime-root

# 1. Build jitter-hardened Nginx-RTMP ingest config with comma-split IP whitelist + /auth + /stat
ALLOW_LINES=""
if [ -n "$ACCEPTED_IP" ]; then
    for entry in $(echo "$ACCEPTED_IP" | tr ',' ' '); do
        entry=$(echo "$entry" | tr -d '[:space:]')
        [ -n "$entry" ] && ALLOW_LINES="${ALLOW_LINES}            allow publish ${entry};"$'\n'
    done
    ALLOW_LINES="${ALLOW_LINES}            deny publish all;"
else
    ALLOW_LINES="            allow publish all;"
fi

cat << NGINX_EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes 1;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size ${CHUNK_SIZE};
        buflen 500ms;
        max_message 16M;
        ping 10s;
        ping_timeout 5s;

        application ${APP_NAME} {
            live on;
            record off;
            interleave on;
            wait_key on;
            wait_video on;
            sync 300ms;
            drop_idle_publisher 8s;
            on_publish http://127.0.0.1:8089/auth;
${ALLOW_LINES}
            allow play 127.0.0.1;
            deny play all;
        }

        application vertical {
            live on;
            record off;
            interleave on;
            wait_key on;
            wait_video on;
            on_publish http://127.0.0.1:8089/auth;
${ALLOW_LINES}
            push rtmp://${RELAY_HOST}:${RELAY_PORT}/vertical;
        }
    }
}

http {
    access_log off;
    tcp_nodelay on;
    server {
        listen 127.0.0.1:8088;
        location /stat {
            rtmp_stat all;
        }
    }
}
NGINX_EOF

# 2. Generate Full OBS Studio configuration (Advanced CBR x264, Preview Disabled, WebSocket v5, Main & BRB Scenes)
OBS_CFG="/root/.config/obs-studio"
mkdir -p "$OBS_CFG/basic/profiles/CookieOBS" "$OBS_CFG/basic/scenes" "$OBS_CFG/plugin_config/obs-websocket"

AUTH_REQ="false"
[ -n "$OBS_WS_PASSWORD" ] && AUTH_REQ="true"

cat << GLOBAL_INI_EOF > "$OBS_CFG/global.ini"
[General]
FirstRun=true
Pre19MigrationDone=true
EnableAutoUpdates=false
ConfirmOnExit=false
OpenStatsOnStartup=false
LastVersion=30.2.3

[Basic]
Profile=CookieOBS
ProfileDir=CookieOBS
SceneCollection=CookieOBS
SceneCollectionFile=CookieOBS

[BasicWindow]
PreviewEnabled=false
PreviewProgramMode=false
ShowListboxToolbars=false
ShowStatusBar=false

[OBSWebSocket]
ServerEnabled=true
ServerPort=${OBS_WS_PORT}
AuthRequired=${AUTH_REQ}
ServerPassword=${OBS_WS_PASSWORD}
GLOBAL_INI_EOF

cat << WS_CFG_EOF > "$OBS_CFG/plugin_config/obs-websocket/config.json"
{
    "alerts_enabled": false,
    "auth_required": ${AUTH_REQ},
    "first_load": false,
    "server_enabled": true,
    "server_password": "${OBS_WS_PASSWORD}",
    "server_port": ${OBS_WS_PORT}
}
WS_CFG_EOF

cat << BASIC_INI_EOF > "$OBS_CFG/basic/profiles/CookieOBS/basic.ini"
[General]
Name=CookieOBS

[Output]
Mode=Advanced
Reconnect=true
RetryDelay=2
MaxRetries=20
DelayEnable=false

[AdvOut]
TrackIndex=1
Encoder=obs_x264
ApplyServiceSettings=false
Rescale=false
AudioTrack1Bitrate=128

[Video]
BaseCX=${OBS_WIDTH}
BaseCY=${OBS_HEIGHT}
OutputCX=${OBS_WIDTH}
OutputCY=${OBS_HEIGHT}
FPSType=0
FPSCommon=${OBS_FPS}
ScaleType=bilinear
ColorFormat=NV12
ColorSpace=709
ColorRange=Partial

[Audio]
SampleRate=48000
ChannelSetup=Stereo
LowLatencyAudioBuffering=false
BASIC_INI_EOF

cat << ENCODER_JSON_EOF > "$OBS_CFG/basic/profiles/CookieOBS/streamEncoder.json"
{
    "bitrate": ${OBS_BITRATE},
    "buffer_size": ${OBS_BITRATE},
    "keyint_sec": 2,
    "preset": "ultrafast",
    "profile": "main",
    "rate_control": "CBR",
    "tune": "zerolatency",
    "use_bufsize": true,
    "x264opts": "rc-lookahead=0 sync-lookahead=0 bframes=0 scenecut=0 threads=${X264_THREADS} sliced-threads=0"
}
ENCODER_JSON_EOF

cat << SERVICE_JSON_EOF > "$OBS_CFG/basic/profiles/CookieOBS/service.json"
{
    "type": "rtmp_custom",
    "settings": {
        "server": "rtmp://${RELAY_HOST}:${RELAY_PORT}/${APP_NAME}",
        "key": "${STREAM_KEY}",
        "use_auth": false
    }
}
SERVICE_JSON_EOF

cat << SCENES_JSON_EOF > "$OBS_CFG/basic/scenes/CookieOBS.json"
{
    "current_scene": "${OBS_SCENE_LIVE}",
    "current_program_scene": "${OBS_SCENE_LIVE}",
    "scene_order": [
        { "name": "${OBS_SCENE_LIVE}" },
        { "name": "${OBS_SCENE_BRB}" }
    ],
    "name": "CookieOBS",
    "sources": [
        {
            "prev_ver": 503316480,
            "name": "RTMP_Ingest_Source",
            "id": "ffmpeg_source",
            "versioned_id": "ffmpeg_source",
            "settings": {
                "is_local_file": false,
                "input": "rtmp://127.0.0.1:1935/${APP_NAME}/${STREAM_KEY}",
                "ffmpeg_options": "rtmp_live=live",
                "buffering_mb": 2,
                "speed_percent": 100,
                "reconnect_delay_sec": 1,
                "close_when_inactive": true,
                "restart_on_activate": true,
                "clear_on_media_end": false,
                "linear_alpha": false,
                "hw_decode": false
            },
            "mixers": 255,
            "sync": 0,
            "flags": 0,
            "volume": 1.0,
            "balance": 0.5,
            "enabled": true,
            "muted": false,
            "monitoring_type": 0
        },
        {
            "prev_ver": 503316480,
            "name": "BRB_Video_Source",
            "id": "ffmpeg_source",
            "versioned_id": "ffmpeg_source",
            "settings": {
                "is_local_file": true,
                "local_file": "${BRB_VIDEO_PATH}",
                "looping": true,
                "speed_percent": 100,
                "close_when_inactive": true,
                "restart_on_activate": true,
                "linear_alpha": false,
                "hw_decode": false
            },
            "mixers": 255,
            "sync": 0,
            "flags": 0,
            "volume": 1.0,
            "balance": 0.5,
            "enabled": true,
            "muted": false,
            "monitoring_type": 0
        },
        {
            "prev_ver": 503316480,
            "name": "${OBS_SCENE_LIVE}",
            "id": "scene",
            "versioned_id": "scene",
            "settings": {
                "id_counter": 1,
                "custom_size": false,
                "items": [
                    {
                        "name": "RTMP_Ingest_Source",
                        "id": 1,
                        "visible": true,
                        "locked": false,
                        "rot": 0.0,
                        "pos": { "x": 0.0, "y": 0.0 },
                        "scale": { "x": 1.0, "y": 1.0 },
                        "bounds_type": 2,
                        "bounds_align": 0,
                        "bounds": { "x": ${OBS_WIDTH}.0, "y": ${OBS_HEIGHT}.0 }
                    }
                ]
            },
            "mixers": 0,
            "enabled": true
        },
        {
            "prev_ver": 503316480,
            "name": "${OBS_SCENE_BRB}",
            "id": "scene",
            "versioned_id": "scene",
            "settings": {
                "id_counter": 1,
                "custom_size": false,
                "items": [
                    {
                        "name": "BRB_Video_Source",
                        "id": 1,
                        "visible": true,
                        "locked": false,
                        "rot": 0.0,
                        "pos": { "x": 0.0, "y": 0.0 },
                        "scale": { "x": 1.0, "y": 1.0 },
                        "bounds_type": 2,
                        "bounds_align": 0,
                        "bounds": { "x": ${OBS_WIDTH}.0, "y": ${OBS_HEIGHT}.0 }
                    }
                ]
            },
            "mixers": 0,
            "enabled": true
        }
    ]
}
SCENES_JSON_EOF

# 3. Start fixed 48kHz PulseAudio null sink (prevents audio clock jitter/frame drops)
pulseaudio -D --exit-idle-time=-1 --disable-shm=yes --realtime=no 2>/dev/null || true
pactl load-module module-null-sink sink_name=obs_null rate=48000 channels=2 >/dev/null 2>&1 || true
pactl set-default-sink obs_null >/dev/null 2>&1 || true

# 4. Start local /auth server and Nginx-RTMP ingest
python3 /app/auth_server.py &
nginx -t
nginx

# 5. Start compact Xvfb virtual display (GUI preview disabled in OBS to save 50% Mesa CPU) and supervised Full OBS
Xvfb :99 -screen 0 640x360x24 -ac +extension GLX +render -noreset &
sleep 2

(
    while true; do
        obs --disable-updater --disable-shutdown-check --disable-missing-files-check --profile CookieOBS --collection CookieOBS >>/var/log/obs.log 2>&1 || true
        sleep 2
    done
) &

# 6. Wait for OBS WebSocket v5 port to listen, then start the auto-live & BRB workflow controller
for i in $(seq 1 30); do
    if python3 -c "import socket; s=socket.create_connection(('127.0.0.1', ${OBS_WS_PORT}), 1); s.close()" 2>/dev/null; then
        break
    fi
    sleep 1
done

exec python3 /app/obs_controller.py
ENTRYPOINT_OBS_EOF

    chmod +x "$obs_dir/auth_server.py" "$obs_dir/obs_controller.py" "$obs_dir/obs_entrypoint.sh"
}

verify_disconnection_protection() {
    echo -e "\n${CYAN}=== Full Server OBS & Disconnection Protection Health Check ===${NC}"
    if ! command -v docker &> /dev/null || ! docker ps --format '{{.Names}}' | grep -qx 'cookie-rtmps'; then
        echo -e "  ${RED}[FAIL]${NC} Container 'cookie-rtmps' is not running."
        return 1
    fi

    if [ "$NOALBS_ENABLED" != "true" ]; then
        echo -e "  ${YELLOW}[INFO]${NC} Disconnection protection is DISABLED (Pure RTMP Passthrough)."
        return 0
    fi

    if is_server_managed_obs; then
        local host_cores
        host_cores=$(nproc 2>/dev/null || echo 1)
        echo -e "  ${GREEN}[PASS]${NC} Workflow Config: mode=full-server-obs | vCPUs=${host_cores} | output=${OBS_WIDTH}x${OBS_HEIGHT}@${OBS_FPS}fps (${OBS_BITRATE}kbps) | low=${LOW_BITRATE}kbps/${LOW_FPS}fps | brb_timeout=${CLOUD_BRB_TIMEOUT}s"

        if [ "$host_cores" -le 1 ] && { [ "$OBS_HEIGHT" -ge 1080 ] || [ "$OBS_FPS" -ge 60 ]; }; then
            echo -e "  ${YELLOW}[WARN]${NC} Detected ${host_cores} vCPU with ${OBS_WIDTH}x${OBS_HEIGHT}@${OBS_FPS}fps. Software OBS encoding at 1080p or 60fps on 1 vCPU can drop frames; 1280x720@30fps is recommended via Option 8 -> 14."
        fi

        if docker ps --format '{{.Names}}' | grep -qx 'cookie-rtmps-obs'; then
            echo -e "  ${GREEN}[PASS]${NC} Container 'cookie-rtmps-obs' is running."
        else
            echo -e "  ${RED}[FAIL]${NC} Container 'cookie-rtmps-obs' is NOT running!"
            return 1
        fi

        local obs_ver
        obs_ver=$(docker exec cookie-rtmps-obs obs --version 2>/dev/null | head -n 1 || echo "installed")
        echo -e "  ${GREEN}[PASS]${NC} Full OBS Studio binary verified: ${obs_ver}"

        if docker exec cookie-rtmps-obs nginx -t >/dev/null 2>&1; then
            echo -e "  ${GREEN}[PASS]${NC} Nginx-RTMP ingest config inside 'cookie-rtmps-obs' is valid."
        else
            echo -e "  ${RED}[FAIL]${NC} Nginx-RTMP ingest config inside 'cookie-rtmps-obs' failed syntax test."
        fi

        if docker exec cookie-rtmps-obs sh -c 'ps aux 2>/dev/null || ps -ef 2>/dev/null' | grep -q '[X]vfb'; then
            echo -e "  ${GREEN}[PASS]${NC} Headless virtual display (Xvfb :99, preview disabled) is running."
        else
            echo -e "  ${RED}[FAIL]${NC} Xvfb is not running inside 'cookie-rtmps-obs'."
        fi

        if docker exec cookie-rtmps-obs sh -c 'ps aux 2>/dev/null || ps -ef 2>/dev/null' | grep -qE '[ /]obs( |$)'; then
            echo -e "  ${GREEN}[PASS]${NC} Server OBS Studio process is running in standby."
        else
            echo -e "  ${RED}[FAIL]${NC} Server OBS Studio process is not running inside 'cookie-rtmps-obs'."
        fi

        if docker exec cookie-rtmps-obs sh -c 'ps aux 2>/dev/null || ps -ef 2>/dev/null' | grep -q 'obs_controller.py'; then
            echo -e "  ${GREEN}[PASS]${NC} Standby / Auto-Live / BRB workflow controller (obs_controller.py) is running."
        else
            echo -e "  ${RED}[FAIL]${NC} obs_controller.py is not running inside 'cookie-rtmps-obs'."
        fi

        if docker exec cookie-rtmps-obs sh -c 'curl -fsS --max-time 2 http://127.0.0.1:8088/stat 2>/dev/null | grep -q "<rtmp>"' 2>/dev/null; then
            echo -e "  ${GREEN}[PASS]${NC} Local Nginx-RTMP /stat XML telemetry responding on 127.0.0.1:8088."
        else
            echo -e "  ${RED}[FAIL]${NC} Local Nginx-RTMP /stat XML is not responding inside 'cookie-rtmps-obs'."
        fi

        if docker exec cookie-rtmps-obs python3 -c "import socket; s=socket.create_connection(('cookie-rtmps', 1935), 3); s.close()" 2>/dev/null; then
            echo -e "  ${GREEN}[PASS]${NC} Server OBS can reach downstream CookieRTMPS relay (cookie-rtmps:1935)."
        else
            echo -e "  ${RED}[FAIL]${NC} Server OBS cannot reach downstream relay at cookie-rtmps:1935."
        fi

        local brb_size
        brb_size=$(docker exec cookie-rtmps-obs sh -c '[ -s /app/data/brb_video.mp4 ] && wc -c < /app/data/brb_video.mp4 || echo 0' 2>/dev/null | tr -d '[:space:]')
        if [[ "$brb_size" =~ ^[0-9]+$ ]] && [ "$brb_size" -gt 10240 ]; then
            echo -e "  ${GREEN}[PASS]${NC} BRB MP4 verified inside 'cookie-rtmps-obs' (/app/data/brb_video.mp4, ${brb_size} bytes)."
        else
            echo -e "  ${RED}[FAIL]${NC} /app/data/brb_video.mp4 is missing or empty (${brb_size} bytes)."
        fi

        # End-to-end OBS WebSocket v5 handshake + Scene/Source verification + Main -> BRB -> Main dry-run + runtime metrics
        local ws_check_out
        ws_check_out=$(docker exec \
            -e "WS_HOST=127.0.0.1" \
            -e "WS_PORT=${OBS_WS_PORT}" \
            -e "WS_PASS=${OBS_WS_PASSWORD}" \
            -e "SCENE_LIVE=${OBS_SCENE_LIVE}" \
            -e "SCENE_BRB=${OBS_SCENE_BRB}" \
            cookie-rtmps-obs python3 -c '
import base64, hashlib, json, os, socket, struct, sys, time
host = os.environ["WS_HOST"]
port = int(os.environ["WS_PORT"])
pw = os.environ.get("WS_PASS", "")
s_live = os.environ["SCENE_LIVE"]
s_brb = os.environ["SCENE_BRB"]

s = socket.create_connection((host, port), timeout=5)
key = base64.b64encode(os.urandom(16)).decode()
s.sendall(f"GET / HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n".encode())
resp = b""
while b"\r\n\r\n" not in resp:
    c = s.recv(1024)
    if not c: raise RuntimeError("handshake closed")
    resp += c
def rx_exact(n):
    b = bytearray()
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c: raise RuntimeError("eof")
        b.extend(c)
    return bytes(b)
def rx_json():
    while True:
        b1, b2 = rx_exact(2)
        op = b1 & 0x0f
        ln = b2 & 0x7f
        if ln == 126: ln = struct.unpack("!H", rx_exact(2))[0]
        elif ln == 127: ln = struct.unpack("!Q", rx_exact(8))[0]
        mk = rx_exact(4) if (b2 & 0x80) else None
        pl = rx_exact(ln)
        if mk: pl = bytes(x ^ mk[i % 4] for i, x in enumerate(pl))
        if op == 1: return json.loads(pl.decode())
def tx_json(obj):
    pl = json.dumps(obj).encode()
    mk = os.urandom(4)
    hdr = bytearray([0x81])
    if len(pl) < 126: hdr.append(0x80 | len(pl))
    elif len(pl) < 65536: hdr.append(0x80 | 126); hdr.extend(struct.pack("!H", len(pl)))
    else: hdr.append(0x80 | 127); hdr.extend(struct.pack("!Q", len(pl)))
    s.sendall(bytes(hdr) + mk + bytes(x ^ mk[i % 4] for i, x in enumerate(pl)))
req_n = 0
def call(rt, rd=None):
    global req_n
    req_n += 1
    rid = str(req_n)
    d = {"requestType": rt, "requestId": rid}
    if rd: d["requestData"] = rd
    tx_json({"op": 6, "d": d})
    while True:
        m = rx_json()
        if m.get("op") == 7 and m.get("d", {}).get("requestId") == rid:
            return m["d"]

hello = rx_json()
ident = {"rpcVersion": 1, "eventSubscriptions": 0}
auth = hello.get("d", {}).get("authentication")
if auth and pw:
    sec = base64.b64encode(hashlib.sha256((pw + auth["salt"]).encode()).digest()).decode()
    ident["authentication"] = base64.b64encode(hashlib.sha256((sec + auth["challenge"]).encode()).digest()).decode()
tx_json({"op": 1, "d": ident})
id_resp = rx_json()
if id_resp.get("op") != 2:
    raise RuntimeError(f"auth failed: {id_resp}")

sc = call("GetSceneList")
names = [x["sceneName"] for x in sc.get("responseData", {}).get("scenes", [])]
missing = [x for x in [s_live, s_brb] if x not in names]
if missing:
    print("MISSING:" + ",".join(missing))
    sys.exit(2)

st = call("GetStreamStatus").get("responseData", {})
active = st.get("outputActive", False)

brb_state = "SKIPPED_LIVE"
if not active:
    call("SetCurrentProgramScene", {"sceneName": s_brb})
    time.sleep(1.5)
    brb_state = (call("GetMediaInputStatus", {"inputName": "BRB_Video_Source"}).get("responseData") or {}).get("mediaState", "UNKNOWN")
    call("SetCurrentProgramScene", {"sceneName": s_live})

stats = call("GetStats").get("responseData", {})
s.close()
print(
    f"OK|scenes={','.join(names)}|standby={not active}|brb_state={brb_state}|"
    f"fps={stats.get('activeFps', 0):.1f}|cpu={stats.get('cpuUsage', 0):.1f}%|"
    f"render_skipped={stats.get('renderSkippedFrames', 0)}|output_skipped={stats.get('outputSkippedFrames', 0)}"
)
' 2>&1 || true)

        if [[ "$ws_check_out" == OK\|* ]]; then
            echo -e "  ${GREEN}[PASS]${NC} OBS WebSocket v5 connected & authenticated on port ${OBS_WS_PORT}."
            echo -e "  ${GREEN}[PASS]${NC} Server OBS dry-run (${OBS_SCENE_LIVE} -> ${OBS_SCENE_BRB} -> ${OBS_SCENE_LIVE}): ${ws_check_out#OK|}"
        else
            echo -e "  ${RED}[FAIL]${NC} OBS WebSocket v5 check failed: ${ws_check_out}"
            echo -e "         Inspect logs with: docker logs --tail 40 cookie-rtmps-obs"
        fi
        return 0
    fi

    # Non-managed OBS or Server-Side FFmpeg Video mode inside cookie-rtmps
    local env_dump
    env_dump=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' cookie-rtmps 2>/dev/null || true)
    local live_mode live_cloud live_low live_restore
    live_mode=$(echo "$env_dump" | awk -F= '$1=="FALLBACK_MODE"{print $2}')
    live_cloud=$(echo "$env_dump" | awk -F= '$1=="CLOUD_BRB"{print $2}')
    live_low=$(echo "$env_dump" | awk -F= '$1=="LOW_BITRATE"{print $2}')
    live_restore=$(echo "$env_dump" | awk -F= '$1=="RESTORE_BITRATE"{print $2}')

    echo -e "  ${GREEN}[PASS]${NC} Protection active: mode=${live_mode:-video}, cloud_brb=${live_cloud:-false}, low=${live_low}kbps, restore=${live_restore}kbps"

    if docker exec cookie-rtmps sh -c 'ps aux 2>/dev/null || ps -ef 2>/dev/null' | grep -iE 'noalbs|cloud_brb|brb_monitor|stream_validator' | grep -vq grep; then
        echo -e "  ${GREEN}[PASS]${NC} NOALBS / Cloud BRB monitor process is running inside 'cookie-rtmps'."
    else
        echo -e "  ${RED}[FAIL]${NC} No NOALBS or Cloud BRB monitor process detected inside 'cookie-rtmps'!"
    fi

    local stat_ok=0
    for stat_port in 8081 8080 8088 80; do
        if docker exec cookie-rtmps sh -c "curl -fsS --max-time 2 http://127.0.0.1:${stat_port}/stat 2>/dev/null | grep -q '<rtmp>'" 2>/dev/null; then
            echo -e "  ${GREEN}[PASS]${NC} Nginx-RTMP /stat XML telemetry responding on 127.0.0.1:${stat_port}."
            stat_ok=1
            break
        fi
    done
    [ "$stat_ok" -eq 0 ] && echo -e "  ${YELLOW}[WARN]${NC} Could not verify Nginx-RTMP /stat XML on standard ports."

    if docker exec cookie-rtmps nginx -T 2>/dev/null | grep -qE 'allow[[:space:]]+publish[[:space:]]+(127\.0\.0\.1|all);'; then
        echo -e "  ${GREEN}[PASS]${NC} Localhost (127.0.0.1) is allowed to publish BRB fallback streams."
    else
        echo -e "  ${RED}[FAIL]${NC} 127.0.0.1 is missing from Nginx-RTMP publish whitelist."
    fi

    if [ "$live_cloud" == "true" ] || [ "$live_mode" == "video" ]; then
        local brb_size
        brb_size=$(docker exec cookie-rtmps sh -c '[ -s /app/data/brb_video.mp4 ] && wc -c < /app/data/brb_video.mp4 || echo 0' 2>/dev/null | tr -d '[:space:]')
        if [[ "$brb_size" =~ ^[0-9]+$ ]] && [ "$brb_size" -gt 10240 ]; then
            echo -e "  ${GREEN}[PASS]${NC} BRB MP4 verified inside container (/app/data/brb_video.mp4, ${brb_size} bytes)."
        else
            echo -e "  ${RED}[FAIL]${NC} /app/data/brb_video.mp4 is missing or corrupted (${brb_size} bytes)."
        fi
    fi

    if [ "$live_mode" == "obs" ]; then
        local ws_host ws_port
        ws_host=$(echo "$env_dump" | awk -F= '$1=="OBS_WS_HOST"{print $2}')
        ws_port=$(echo "$env_dump" | awk -F= '$1=="OBS_WS_PORT"{print $2}')
        if docker exec cookie-rtmps sh -c "python3 -c \"import socket; s=socket.create_connection(('${ws_host}', ${ws_port}), 3); s.close()\"" 2>/dev/null; then
            echo -e "  ${GREEN}[PASS]${NC} External OBS WebSocket endpoint ${ws_host}:${ws_port} is reachable from container."
        else
            echo -e "  ${RED}[FAIL]${NC} External OBS WebSocket ${ws_host}:${ws_port} is NOT reachable from 'cookie-rtmps'."
        fi
    fi
}

write_config_to_path() {
    local target_file="$1"
    mkdir -p "$(dirname "$target_file")" 2>/dev/null || true
    : > "$target_file" 2>/dev/null || return 1
    for var in "${CONFIG_VARS[@]}"; do
        printf '%s="%s"\n' "$var" "${!var}" >> "$target_file"
    done
}

recover_config_from_container() {
    command -v docker &> /dev/null || return 1
    local cid
    cid=$(docker ps -a --format '{{.ID}} {{.Names}}' | grep -iE 'cookie-rtmps|rtmp' | head -n 1 | awk '{print $1}')
    [ -z "$cid" ] && return 1

    local env_lines recovered=0
    env_lines=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$cid" 2>/dev/null || true)
    [ -z "$env_lines" ] && return 1

    while IFS='=' read -r k v; do
        for allowed in "${CONFIG_VARS[@]}"; do
            if [ "$k" == "$allowed" ] && [ -n "$v" ] && [ "$k" != "NOALBS_ENABLED" ] && [ "$k" != "CLOUD_BRB" ]; then
                printf -v "$k" "%s" "$v"
                recovered=1
                break
            fi
        done
    done <<< "$env_lines"

    [ "$recovered" -eq 1 ]
}

sync_and_preserve_installation() {
    local SUDO
    SUDO=$(get_sudo)
    local found_config="" newest_mtime=0

    local candidate_configs=(
        "$CONFIG_FILE"
        "$PERSIST_USER_CONFIG"
        "$PERSIST_SYS_CONFIG"
        "$(dirname "$SCRIPT_DIR")/rtmp_config.env"
        "$HOME/cookie-rtmps/rtmp_config.env"
        "/root/cookie-rtmps/rtmp_config.env"
        "/opt/cookie-rtmps/rtmp_config.env"
        "/srv/cookie-rtmps/rtmp_config.env"
    )

    for home_cfg in /home/*/cookie-rtmps/rtmp_config.env; do
        [ -f "$home_cfg" ] && candidate_configs+=("$home_cfg")
    done

    for cfg in "${candidate_configs[@]}"; do
        if [ -f "$cfg" ] && [ -s "$cfg" ]; then
            local mtime
            mtime=$(stat -c %Y "$cfg" 2>/dev/null || stat -f %m "$cfg" 2>/dev/null || echo "1")
            if [ "$mtime" -ge "$newest_mtime" ]; then
                newest_mtime="$mtime"
                found_config="$cfg"
            fi
        fi
    done

    if [ -n "$found_config" ]; then
        [ "$found_config" != "$CONFIG_FILE" ] && cp -f "$found_config" "$CONFIG_FILE" 2>/dev/null || true
        source "$CONFIG_FILE"
        unset CHAT_TWITCH CHAT_YOUTUBE CHAT_KICK CHAT_TIKTOK STREAM_BASE_TITLE TWITCH_CLIENT_ID TWITCH_OAUTH_TOKEN TWITCH_BROADCASTER_ID PORT_HTTP PORT_STATS
    elif recover_config_from_container; then
        write_config_to_path "$CONFIG_FILE"
        found_config="$CONFIG_FILE"
    fi

    # Ensure sensible defaults for OBS & FPS threshold parameters
    [ -z "$OBS_WIDTH" ] && OBS_WIDTH="1280"
    [ -z "$OBS_HEIGHT" ] && OBS_HEIGHT="720"
    [ -z "$OBS_FPS" ] && OBS_FPS="30"
    [ -z "$OBS_BITRATE" ] && OBS_BITRATE="3500"
    [ -z "$LOW_FPS" ] && LOW_FPS="15"
    [ -z "$RESTORE_FPS" ] && RESTORE_FPS="20"
    [ -z "$CLOUD_BRB_TIMEOUT" ] && CLOUD_BRB_TIMEOUT="300"

    # Default to Server IP + WireGuard/OpenVPN ranges on fresh/auto setups
    if [ "$WHITELIST_MODE" == "auto" ] && [ -z "$ACCEPTED_IP" ]; then
        ACCEPTED_IP=$(build_default_whitelist)
    fi

    local old_install_dirs=(
        "$(dirname "$SCRIPT_DIR")"
        "$HOME/cookie-rtmps"
        "/root/cookie-rtmps"
        "/opt/cookie-rtmps"
        "/srv/cookie-rtmps"
    )

    for old_dir in "${old_install_dirs[@]}"; do
        if [ -d "$old_dir" ] && [ "$old_dir" != "$SCRIPT_DIR" ] && [ -f "$old_dir/install.sh" ]; then
            cp -f "$SCRIPT_DIR/install.sh" "$old_dir/install.sh" 2>/dev/null || true
            chmod +x "$old_dir/install.sh" 2>/dev/null || true
            for repo_item in Dockerfile docker-entrypoint.sh integration_test.sh stream_validator.py update_titles.py tiktok_pusher.py test_noalbs.py chat.html; do
                [ -f "$SCRIPT_DIR/$repo_item" ] && cp -f "$SCRIPT_DIR/$repo_item" "$old_dir/$repo_item" 2>/dev/null || true
            done
            for repo_dir in nginx stunnel cookie-nginx-rtmp noalbs; do
                if [ -d "$SCRIPT_DIR/$repo_dir" ]; then
                    rm -rf "$old_dir/$repo_dir" 2>/dev/null || true
                    cp -rf "$SCRIPT_DIR/$repo_dir" "$old_dir/$repo_dir" 2>/dev/null || true
                fi
            done
            [ -f "$CONFIG_FILE" ] && cp -f "$CONFIG_FILE" "$old_dir/rtmp_config.env" 2>/dev/null || true
        fi
    done

    if [ -n "$found_config" ] || [ -f "$CONFIG_FILE" ]; then
        write_config_to_path "$CONFIG_FILE"
        write_config_to_path "$PERSIST_USER_CONFIG"
        if [ "$EUID" -eq 0 ]; then
            write_config_to_path "$PERSIST_SYS_CONFIG"
        elif [ -n "$SUDO" ]; then
            $SUDO mkdir -p "$PERSIST_SYS_DIR" 2>/dev/null || true
            $SUDO cp -f "$CONFIG_FILE" "$PERSIST_SYS_CONFIG" 2>/dev/null || true
        fi
    fi
}

sync_and_preserve_installation

save_config() {
    local SUDO
    SUDO=$(get_sudo)
    write_config_to_path "$CONFIG_FILE"
    write_config_to_path "$PERSIST_USER_CONFIG"
    if [ "$EUID" -eq 0 ]; then
        write_config_to_path "$PERSIST_SYS_CONFIG"
    elif [ -n "$SUDO" ]; then
        $SUDO mkdir -p "$PERSIST_SYS_DIR" 2>/dev/null || true
        $SUDO cp -f "$CONFIG_FILE" "$PERSIST_SYS_CONFIG" 2>/dev/null || true
    fi
    echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
}

check_latest_plugins() {
    echo -e "${CYAN}Checking latest versions of active CookieRTMPS plugins (skipping OS apt-get updates/upgrades)...${NC}"

    if [ "$NOALBS_ENABLED" == "true" ]; then
        local noalbs_tag
        noalbs_tag=$(curl -fsSL --max-time 5 "https://api.github.com/repos/NOALBS/nginx-obs-automatic-low-bitrate-switching/releases/latest" 2>/dev/null \
            | grep -m 1 '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/' || true)
        if [ -n "$noalbs_tag" ]; then
            LATEST_NOALBS_VERSION="$noalbs_tag"
            echo -e "  ${GREEN}NOALBS latest release:${NC} $LATEST_NOALBS_VERSION"
        else
            echo -e "  ${YELLOW}NOALBS latest release:${NC} Could not query GitHub (using Dockerfile default)"
        fi
    else
        LATEST_NOALBS_VERSION=""
        echo -e "  ${YELLOW}NOALBS / OBS:${NC} Skipped (Disconnection protection disabled)"
    fi

    local rtmp_tag
    rtmp_tag=$(curl -fsSL --max-time 5 "https://api.github.com/repos/arut/nginx-rtmp-module/tags?per_page=1" 2>/dev/null \
        | grep -m 1 '"name"' | sed -E 's/.*"name":[[:space:]]*"([^"]+)".*/\1/' || true)
    if [ -n "$rtmp_tag" ]; then
        LATEST_NGINX_RTMP_VERSION="$rtmp_tag"
        echo -e "  ${GREEN}nginx-rtmp-module latest tag:${NC} $LATEST_NGINX_RTMP_VERSION"
    else
        echo -e "  ${YELLOW}nginx-rtmp-module latest tag:${NC} Could not query GitHub (using Dockerfile default)"
    fi

    if [ -f "$SCRIPT_DIR/Dockerfile" ] && grep -qE 'apt-get[[:space:]]+(dist-|full-)?upgrade' "$SCRIPT_DIR/Dockerfile"; then
        echo -e "  ${YELLOW}Notice:${NC} Your Dockerfile contains an 'apt-get upgrade' call. Consider removing it since the server handles updates automatically."
    fi
}

prompt_for_key() {
    local platform=$1
    local var_name=$2
    local current_value=${!var_name}

    echo -e "Enter Stream Key for ${YELLOW}$platform${NC} (Type 'disable' to remove key, or leave blank to keep current: ${current_value:-None}): "
    read -r input

    if [ "$input" == "disable" ] || [ "$input" == "DISABLE" ]; then
        printf -v "$var_name" "%s" ""
        save_config
        echo -e "${GREEN}Disabled stream to $platform.${NC}"
        sleep 1
    elif [ -n "$input" ]; then
        printf -v "$var_name" "%s" "$input"
        save_config
    fi
}

get_alternative_url() {
    local platform=$1
    local current_url=$2

    case $platform in
        "youtube")
            if [[ "$current_url" == *"x.rtmp.youtube.com"* ]] || [[ "$current_url" == *"a.rtmp.youtube.com"* ]] || [[ "$current_url" == *"127.0.0.1:19355"* ]]; then
                if [[ "$current_url" == *"127.0.0.1"* ]]; then
                    echo "rtmp://127.0.0.1:19357/live2?backup=1"
                else
                    echo "rtmp://b.rtmp.youtube.com/live2?backup=1"
                fi
            else
                if [[ "$current_url" == *"127.0.0.1"* ]]; then
                    echo "rtmp://127.0.0.1:19355/live2/"
                else
                    echo "rtmp://a.rtmp.youtube.com/live2/"
                fi
            fi
            ;;
        "twitch")
            if [[ "$current_url" == *"ingest.global"* ]]; then
                echo "rtmp://use10.contribute.live-video.net/app/"
            else
                echo "rtmp://ingest.global-contribute.live-video.net/app/"
            fi
            ;;
        "kick")
            if [[ "$current_url" == *"live.kick.com"* ]] || [[ "$current_url" == *"127.0.0.1:19356"* ]]; then
                echo "rtmp://kick.cisp.co.za/live"
            else
                echo "rtmp://127.0.0.1:19356/kick/"
            fi
            ;;
        *)
            echo "$current_url"
            ;;
    esac
}

select_twitch_server() {
    local url_var=$1
    local current_url=${!url_var}
    echo -e "Select Twitch Server:"
    echo "  1) Global (rtmp://ingest.global-contribute.live-video.net/app/)"
    echo "  2) Secure Global (rtmps://ingest.global-contribute.live-video.net:443 -> Stunnel)"
    echo "  3) US East: Ashburn (rtmp://use10.contribute.live-video.net/app/)"
    echo "  4) US East: Ohio (rtmp://use20.contribute.live-video.net/app/)"
    echo "  5) US West: Oregon (rtmp://usw20.contribute.live-video.net/app/)"
    echo "  6) EU: Ireland (rtmp://euw10.contribute.live-video.net/app/)"
    echo "  7) EU: Frankfurt (rtmp://euc10.contribute.live-video.net/app/)"
    echo "  8) EU: Paris (rtmp://euw30.contribute.live-video.net/app/)"
    echo "  9) EU: Stockholm (rtmp://eun10.contribute.live-video.net/app/)"
    echo "  10) Asia: Tokyo (rtmp://apn10.contribute.live-video.net/app/)"
    echo "  11) Asia: Seoul (rtmp://apn20.contribute.live-video.net/app/)"
    echo "  12) Asia: Singapore (rtmp://aps10.contribute.live-video.net/app/)"
    echo "  13) Asia: Sydney (rtmp://aps20.contribute.live-video.net/app/)"
    echo "  14) Asia: Mumbai (rtmp://aps30.contribute.live-video.net/app/)"
    echo "  15) South America: Brazil (rtmp://sae10.contribute.live-video.net/app/)"
    echo "  16) Custom URL"
    echo -e "Option (Current URL: $current_url): \c"
    read -r t_opt
    case $t_opt in
        1) printf -v "$url_var" "%s" "rtmp://ingest.global-contribute.live-video.net/app/" ;;
        2) printf -v "$url_var" "%s" "rtmp://127.0.0.1:19353/app/" ;;
        3) printf -v "$url_var" "%s" "rtmp://use10.contribute.live-video.net/app/" ;;
        4) printf -v "$url_var" "%s" "rtmp://use20.contribute.live-video.net/app/" ;;
        5) printf -v "$url_var" "%s" "rtmp://usw20.contribute.live-video.net/app/" ;;
        6) printf -v "$url_var" "%s" "rtmp://euw10.contribute.live-video.net/app/" ;;
        7) printf -v "$url_var" "%s" "rtmp://euc10.contribute.live-video.net/app/" ;;
        8) printf -v "$url_var" "%s" "rtmp://euw30.contribute.live-video.net/app/" ;;
        9) printf -v "$url_var" "%s" "rtmp://eun10.contribute.live-video.net/app/" ;;
        10) printf -v "$url_var" "%s" "rtmp://apn10.contribute.live-video.net/app/" ;;
        11) printf -v "$url_var" "%s" "rtmp://apn20.contribute.live-video.net/app/" ;;
        12) printf -v "$url_var" "%s" "rtmp://aps10.contribute.live-video.net/app/" ;;
        13) printf -v "$url_var" "%s" "rtmp://aps20.contribute.live-video.net/app/" ;;
        14) printf -v "$url_var" "%s" "rtmp://aps30.contribute.live-video.net/app/" ;;
        15) printf -v "$url_var" "%s" "rtmp://sae10.contribute.live-video.net/app/" ;;
        16)
            echo -e "Enter Custom Twitch Server URL: "
            read -r t_url
            [ -n "$t_url" ] && printf -v "$url_var" "%s" "$t_url"
            ;;
    esac
}

select_kick_server() {
    local url_var=$1
    local current_url=${!url_var}
    echo -e "Select Kick Server:"
    echo "  1) Standard (rtmp://live.kick.com/app/)"
    echo "  2) Secure (rtmps://fa723fc1b171.global-contribute.live-video.net:443 -> via Stunnel)"
    echo "  3) South Africa Relay (rtmp://kick.cisp.co.za/live)"
    echo "  4) Custom URL"
    echo -e "Option (Current URL: $current_url): \c"
    read -r k_opt
    case $k_opt in
        1) printf -v "$url_var" "%s" "rtmp://live.kick.com/app/" ;;
        2) printf -v "$url_var" "%s" "rtmp://127.0.0.1:19356/kick/" ;;
        3) printf -v "$url_var" "%s" "rtmp://kick.cisp.co.za/live" ;;
        4)
            echo -e "Enter Custom Kick Server URL: "
            read -r k_url
            [ -n "$k_url" ] && printf -v "$url_var" "%s" "$k_url"
            ;;
    esac
}

select_tiktok_server() {
    local url_var=$1
    local current_url=${!url_var}
    echo -e "Select TikTok Server:"
    echo "  1) Secure (rtmps://push.tiktok.com:443 -> via Stunnel)"
    echo "  2) Custom URL"
    echo "  3) Streamlabs Auto-Pusher (Bypass TikTok Studio)"
    echo -e "Option (Current URL: $current_url): \c"
    read -r tt_opt
    case $tt_opt in
        1) printf -v "$url_var" "%s" "rtmp://127.0.0.1:19358/s_v/" ;;
        2)
            echo -e "Enter Custom TikTok Server URL: "
            read -r tt_url
            [ -n "$tt_url" ] && printf -v "$url_var" "%s" "$tt_url"
            ;;
        3)
            printf -v "$url_var" "%s" "auto"
            echo -e "Enter Streamlabs Token: \c"
            read -r TIKTOK_SL_TOKEN
            echo -e "Enter Stream Title: \c"
            read -r TIKTOK_TITLE
            echo -e "Enter Game ID (Optional): \c"
            read -r TIKTOK_GAME_ID
            ;;
    esac
}

select_basic_server() {
    local label=$1
    local opt1_label=$2
    local opt1_url=$3
    local url_var=$4
    local current_url=${!url_var}
    echo -e "Select $label Server:"
    echo "  1) $opt1_label"
    echo "  2) Custom URL"
    echo -e "Option (Current URL: $current_url): \c"
    read -r s_opt
    case $s_opt in
        1) printf -v "$url_var" "%s" "$opt1_url" ;;
        2)
            echo -e "Enter Custom $label Server URL: "
            read -r s_url
            [ -n "$s_url" ] && printf -v "$url_var" "%s" "$s_url"
            ;;
    esac
}

configure_keys() {
    while true; do
        clear
        echo -e "${GREEN}=== Configure Horizontal Stream Keys ===${NC}"
        echo "1) YouTube (Current: ${YOUTUBE_KEY:-None})"
        echo "2) Twitch (Current: ${TWITCH_KEY:-None})"
        echo "3) Kick (Current: ${KICK_KEY:-None})"
        echo "4) TikTok (Current: ${TIKTOK_KEY:-None})"
        echo "5) Facebook (Current: ${FACEBOOK_KEY:-None})"
        echo "6) Instagram (Current: ${INSTAGRAM_KEY:-None})"
        echo "7) X (Twitter) (Current: ${X_KEY:-None})"
        echo "8) Trovo (Current: ${TROVO_KEY:-None})"
        echo "9) Custom RTMP (Current URL: ${RTMP1_URL:-None})"
        echo "10) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r choice

        case $choice in
            1)
               prompt_for_key "YouTube Key" "YOUTUBE_KEY"
               echo -e "Select YouTube Server:"
               echo "  1) Primary (rtmp://a.rtmp.youtube.com/live2/)"
               echo "  2) Backup (rtmp://b.rtmp.youtube.com/live2?backup=1)"
               echo "  3) Secure Primary (rtmps://a.rtmps.youtube.com/live2/ -> via Stunnel)"
               echo "  4) Secure Backup (rtmps://b.rtmps.youtube.com/live2?backup=1 -> via Stunnel)"
               echo "  5) Custom URL"
               echo -e "Option (Current URL: $YOUTUBE_URL): \c"
               read -r y_opt
               case $y_opt in
                   1) YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2/" ;;
                   2) YOUTUBE_URL="rtmp://b.rtmp.youtube.com/live2?backup=1" ;;
                   3) YOUTUBE_URL="rtmp://127.0.0.1:19355/live2/" ;;
                   4) YOUTUBE_URL="rtmp://127.0.0.1:19357/live2?backup=1" ;;
                   5)
                      echo -e "Enter Custom YouTube Server URL: "
                      read -r y_url
                      [ -n "$y_url" ] && YOUTUBE_URL="$y_url"
                      ;;
               esac
               save_config
               ;;
            2)
               prompt_for_key "Twitch Key" "TWITCH_KEY"
               select_twitch_server "TWITCH_URL"
               save_config
               ;;
            3)
               prompt_for_key "Kick" "KICK_KEY"
               select_kick_server "KICK_URL"
               save_config
               ;;
            4)
               prompt_for_key "TikTok" "TIKTOK_KEY"
               select_tiktok_server "TIKTOK_URL"
               save_config
               ;;
            5)
               prompt_for_key "Facebook" "FACEBOOK_KEY"
               select_basic_server "Facebook" "Secure (rtmps://live-api-s.facebook.com:443 -> via Stunnel)" "rtmp://127.0.0.1:19350/rtmp/" "FACEBOOK_URL"
               save_config
               ;;
            6)
               prompt_for_key "Instagram" "INSTAGRAM_KEY"
               select_basic_server "Instagram" "Secure (rtmps://live-upload.instagram.com:443 -> via Stunnel)" "rtmp://127.0.0.1:19351/rtmp/" "INSTAGRAM_URL"
               save_config
               ;;
            7)
               prompt_for_key "X (Twitter)" "X_KEY"
               select_basic_server "X" "Secure (rtmps://va.pscp.tv:443 -> via Stunnel)" "rtmp://127.0.0.1:19354/x/" "X_URL"
               save_config
               ;;
            8)
               prompt_for_key "Trovo" "TROVO_KEY"
               select_basic_server "Trovo" "Primary (rtmp://livepush.trovo.live/live/)" "rtmp://livepush.trovo.live/live/" "TROVO_URL"
               save_config
               ;;
            9)
               echo -e "Enter Custom RTMP Server URL (Current: $RTMP1_URL): "
               read -r c_url
               if [ -n "$c_url" ]; then
                   RTMP1_URL="$c_url"
                   save_config
               fi
               prompt_for_key "Custom RTMP Key" "RTMP1_KEY"
               ;;
            10) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ;;
        esac
    done
}

configure_vertical_keys() {
    while true; do
        clear
        echo -e "${GREEN}=== Configure Vertical Stream Keys ===${NC}"
        echo -e "${YELLOW}Note: Vertical is officially supported on: YouTube, Twitch and TikTok.${NC}"
        echo "1) YouTube (Current: ${V_YOUTUBE_KEY:-None})"
        echo "2) Twitch (Current: ${V_TWITCH_KEY:-None})"
        echo "3) Kick (Current: ${V_KICK_KEY:-None})"
        echo "4) TikTok (Current: ${V_TIKTOK_KEY:-None})"
        echo "5) Facebook (Current: ${V_FACEBOOK_KEY:-None})"
        echo "6) Instagram (Current: ${V_INSTAGRAM_KEY:-None})"
        echo "7) X (Twitter) (Current: ${V_X_KEY:-None})"
        echo "8) Trovo (Current: ${V_TROVO_KEY:-None})"
        echo "9) Custom RTMP (Current URL: ${V_RTMP1_URL:-None})"
        echo "10) Mirror Horizontal Keys (Auto-fill from Horizontal)"
        echo "11) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r choice

        case $choice in
            1)
               prompt_for_key "YouTube Vertical Key" "V_YOUTUBE_KEY"
               echo -e "Select YouTube Server:"
               echo "  1) Primary (rtmp://a.rtmp.youtube.com/live2/)"
               echo "  2) Secure Primary (rtmps://a.rtmps.youtube.com/live2/ -> via Stunnel)"
               echo "  3) Custom URL"
               echo -e "Option (Current URL: $V_YOUTUBE_URL): \c"
               read -r y_opt
               case $y_opt in
                   1) V_YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2/" ;;
                   2) V_YOUTUBE_URL="rtmp://127.0.0.1:19355/live2/" ;;
                   3)
                      echo -e "Enter Custom YouTube Server URL: "
                      read -r y_url
                      [ -n "$y_url" ] && V_YOUTUBE_URL="$y_url"
                      ;;
               esac
               if [ "$V_YOUTUBE_URL" == "$YOUTUBE_URL" ]; then
                   echo -e "${YELLOW}Warning: Same ingest server as Horizontal. Switching to alternative...${NC}"
                   V_YOUTUBE_URL=$(get_alternative_url "youtube" "$V_YOUTUBE_URL")
                   echo -e "New Vertical URL: $V_YOUTUBE_URL"
                   sleep 1
               fi
               save_config
               ;;
            2)
               prompt_for_key "Twitch Vertical Key" "V_TWITCH_KEY"
               select_twitch_server "V_TWITCH_URL"
               if [ "$V_TWITCH_URL" == "$TWITCH_URL" ]; then
                   echo -e "${YELLOW}Warning: Same ingest server as Horizontal. Switching to alternative...${NC}"
                   V_TWITCH_URL=$(get_alternative_url "twitch" "$V_TWITCH_URL")
                   echo -e "New Vertical URL: $V_TWITCH_URL"
                   sleep 1
               fi
               save_config
               ;;
            3)
               prompt_for_key "Kick Vertical Key" "V_KICK_KEY"
               select_kick_server "V_KICK_URL"
               if [ "$V_KICK_URL" == "$KICK_URL" ]; then
                   echo -e "${YELLOW}Warning: Same ingest server as Horizontal. Switching to alternative...${NC}"
                   V_KICK_URL=$(get_alternative_url "kick" "$V_KICK_URL")
                   echo -e "New Vertical URL: $V_KICK_URL"
                   sleep 1
               fi
               save_config
               ;;
            4)
               prompt_for_key "TikTok Vertical Key" "V_TIKTOK_KEY"
               select_tiktok_server "V_TIKTOK_URL"
               save_config
               ;;
            5)
               prompt_for_key "Facebook Vertical Key" "V_FACEBOOK_KEY"
               select_basic_server "Facebook" "Secure (rtmps://live-api-s.facebook.com:443 -> via Stunnel)" "rtmp://127.0.0.1:19350/rtmp/" "V_FACEBOOK_URL"
               save_config
               ;;
            6)
               prompt_for_key "Instagram Vertical Key" "V_INSTAGRAM_KEY"
               select_basic_server "Instagram" "Secure (rtmps://live-upload.instagram.com:443 -> via Stunnel)" "rtmp://127.0.0.1:19351/rtmp/" "V_INSTAGRAM_URL"
               save_config
               ;;
            7)
               prompt_for_key "X Vertical Key" "V_X_KEY"
               select_basic_server "X" "Secure (rtmps://va.pscp.tv:443 -> via Stunnel)" "rtmp://127.0.0.1:19354/x/" "V_X_URL"
               save_config
               ;;
            8)
               prompt_for_key "Trovo Vertical Key" "V_TROVO_KEY"
               select_basic_server "Trovo" "Primary (rtmp://livepush.trovo.live/live/)" "rtmp://livepush.trovo.live/live/" "V_TROVO_URL"
               save_config
               ;;
            9)
               echo -e "Enter Custom RTMP Vertical Server URL (Current: $V_RTMP1_URL): "
               read -r c_url
               if [ -n "$c_url" ]; then
                   V_RTMP1_URL="$c_url"
                   save_config
               fi
               prompt_for_key "Custom RTMP Vertical Key" "V_RTMP1_KEY"
               ;;
            10)
               echo -e "${YELLOW}Mirroring Horizontal keys with alternative ingest servers...${NC}"
               V_YOUTUBE_KEY="$YOUTUBE_KEY"
               V_YOUTUBE_URL=$(get_alternative_url "youtube" "$YOUTUBE_URL")
               V_TWITCH_KEY="$TWITCH_KEY"
               V_TWITCH_URL=$(get_alternative_url "twitch" "$TWITCH_URL")
               V_TIKTOK_KEY="$TIKTOK_KEY"
               V_TIKTOK_URL="$TIKTOK_URL"
               V_KICK_KEY="$KICK_KEY"
               V_KICK_URL=$(get_alternative_url "kick" "$KICK_URL")
               V_FACEBOOK_KEY="$FACEBOOK_KEY"
               V_FACEBOOK_URL="$FACEBOOK_URL"
               V_INSTAGRAM_KEY="$INSTAGRAM_KEY"
               V_INSTAGRAM_URL="$INSTAGRAM_URL"
               V_X_KEY="$X_KEY"
               V_X_URL="$X_URL"
               V_TROVO_KEY="$TROVO_KEY"
               V_TROVO_URL="$TROVO_URL"
               V_RTMP1_KEY="$RTMP1_KEY"
               V_RTMP1_URL="$RTMP1_URL"
               save_config
               echo -e "${GREEN}Mirrored with diversified ingest servers.${NC}"
               sleep 1
               ;;
            11) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ;;
        esac
    done
}

configure_obs() {
    clear
    echo -e "${GREEN}=== OBS Configuration ===${NC}"
    local DISPLAY_HOST=${SERVER_DOMAIN:-$(get_server_ip)}

    echo -e "To stream to this server from OBS or another encoder:"
    echo -e "  ${YELLOW}Horizontal URL:${NC} rtmp://${DISPLAY_HOST}:${PORT_RTMP}/${APP_NAME}"
    echo -e "  ${YELLOW}Vertical URL:${NC}   rtmp://${DISPLAY_HOST}:${PORT_RTMP}/vertical"
    echo ""
    echo -e "--- Security Key ---"
    echo -e "CookieRTMPS requires a matching stream key to accept your stream."
    echo -e "Current Custom OBS Key: ${OBS_KEY:-None}"
    echo -e "Enter new Custom OBS Key (Type 'disable' to remove, or press Enter to keep current): "
    read -r obs_input
    if [ "$obs_input" == "disable" ] || [ "$obs_input" == "DISABLE" ]; then
        OBS_KEY=""
        echo -e "${GREEN}Custom OBS Key removed.${NC}"
    elif [ -n "$obs_input" ]; then
        OBS_KEY="$obs_input"
        echo -e "${GREEN}Custom OBS Key updated.${NC}"
    fi

    echo ""
    echo -e "--- Custom Application Name ---"
    echo -e "Current Path: /${APP_NAME}"
    echo -e "Enter new RTMP Path/Application name (e.g. cookies):"
    echo -e "(Leave blank to keep current):"
    read -r app_input
    if [ -n "$app_input" ]; then
        app_input=$(echo "$app_input" | sed 's/[^a-zA-Z0-9]//g')
        if [ -n "$app_input" ]; then
            APP_NAME="$app_input"
            echo -e "${GREEN}Application name updated to: $APP_NAME${NC}"
        else
            echo -e "${RED}Invalid application name. Keeping current: $APP_NAME${NC}"
        fi
    fi

    save_config
    sleep 1
}

configure_domain() {
    clear
    echo -e "${GREEN}=== Domain / Reverse Proxy Configuration ===${NC}"
    echo -e "Current Domain: ${SERVER_DOMAIN:-None (Using IP)}"
    echo -e "Enter your domain or Cloudflare reverse proxy (e.g. stream.yourdomain.com):"
    echo -e "(Leave blank to keep current, type 'disable' to use IP)"
    read -r dom_input
    if [ "$dom_input" == "disable" ] || [ "$dom_input" == "DISABLE" ]; then
        SERVER_DOMAIN=""
        echo -e "${GREEN}Domain disabled, using IP.${NC}"
    elif [ -n "$dom_input" ]; then
        dom_input=$(echo "$dom_input" | sed 's/[^a-zA-Z0-9.-]//g')
        if [ -n "$dom_input" ]; then
            SERVER_DOMAIN="$dom_input"
            echo -e "${GREEN}Domain updated to: $SERVER_DOMAIN${NC}"
            echo -e "${YELLOW}Note: If using Cloudflare, ensure the record is 'DNS Only' (Grey Cloud).${NC}"
        else
            echo -e "${RED}Invalid domain name. Keeping current.${NC}"
        fi
    fi
    save_config
    sleep 1
}

configure_whitelist() {
    while true; do
        clear
        local AUTO_PREVIEW
        AUTO_PREVIEW=$(build_default_whitelist)
        echo -e "${GREEN}=== IP Whitelist Configuration ===${NC}"
        echo -e "Current Mode:        ${CYAN}${WHITELIST_MODE}${NC}"
        echo -e "Current Accepted IP: ${YELLOW}${ACCEPTED_IP:-None (Allow All)}${NC}"
        echo -e "Auto-Detected Pool:  ${GREEN}${AUTO_PREVIEW}${NC}"
        echo ""
        echo "1) Auto: Server IP + WireGuard / OpenVPN Ranges [Default]"
        echo "2) Manual IP Address / CIDR (comma-separated allowed)"
        echo "3) Clear IP Address (Allow All)"
        echo "4) Back to Main Menu"
        echo -e "Select an option [1]: \c"
        read -r wl_opt
        [ -z "$wl_opt" ] && wl_opt="1"

        case $wl_opt in
            1)
                WHITELIST_MODE="auto"
                ACCEPTED_IP="$AUTO_PREVIEW"
                if [ -n "$ACCEPTED_IP" ]; then
                    echo -e "${GREEN}IP Whitelist set to Auto (Server IP + WireGuard/OpenVPN):${NC}"
                    echo -e "  $ACCEPTED_IP"
                else
                    echo -e "${RED}Failed to auto-detect server/VPN IP ranges.${NC}"
                fi
                save_config
                sync_container_nginx_whitelist "cookie-rtmps" "true"
                [ "$NOALBS_ENABLED" == "true" ] && sync_obs_container_whitelist
                sleep 1
                ;;
            2)
                echo -e "Enter IP address or CIDR to whitelist (e.g. 203.0.113.5 or 203.0.113.5,10.8.0.0/24): \c"
                read -r ip_input
                ip_input=$(echo "$ip_input" | tr -d ' ')
                if [ -n "$ip_input" ]; then
                    WHITELIST_MODE="manual"
                    ACCEPTED_IP=$(ensure_localhost_in_whitelist "$ip_input")
                    echo -e "${GREEN}IP Whitelist updated to: $ACCEPTED_IP${NC}"
                    save_config
                    sync_container_nginx_whitelist "cookie-rtmps" "true"
                    [ "$NOALBS_ENABLED" == "true" ] && sync_obs_container_whitelist
                fi
                sleep 1
                ;;
            3)
                WHITELIST_MODE="disabled"
                ACCEPTED_IP=""
                echo -e "${GREEN}IP Whitelist disabled. All IPs allowed.${NC}"
                save_config
                sync_container_nginx_whitelist "cookie-rtmps" "false"
                [ "$NOALBS_ENABLED" == "true" ] && sync_obs_container_whitelist
                sleep 1
                ;;
            4) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

ensure_brb_video_transcoded() {
    local url="${1:-$BRB_VIDEO_URL}"
    local target="./data/brb_video.mp4"
    [ -z "$url" ] && url="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
    mkdir -p ./data
    rm -f "$target" "${target}.tmp"
    echo -e "${YELLOW}Downloading BRB video from $url ...${NC}"
    if ! curl -fsSL --max-time 60 "$url" -o "${target}.tmp"; then
        echo -e "${RED}Download failed (HTTP error or unreachable URL): $url${NC}"
        rm -f "${target}.tmp"
        return 1
    fi

    if [ -f "${target}.tmp" ] && [ -s "${target}.tmp" ]; then
        if head -c 512 "${target}.tmp" 2>/dev/null | grep -qiE '<!doctype html|<html'; then
            echo -e "${RED}Downloaded file appears to be an HTML page, not a direct MP4 video.${NC}"
            rm -f "${target}.tmp"
            return 1
        fi

        if command -v ffmpeg &> /dev/null; then
            echo -e "${YELLOW}Transcoding BRB video with FFmpeg for RTMP/OBS loop playback (H.264 30fps / AAC 48kHz)...${NC}"
            local duration=""
            if command -v ffprobe &> /dev/null; then
                duration=$(ffprobe -v error -show_entries format=duration -of default=noprintwrappers=1:nokey=1 "${target}.tmp" 2>/dev/null || true)
            fi
            if [ -z "$duration" ] || [ "$(awk -v d="$duration" 'BEGIN { print (d > 0) ? 1 : 0 }' 2>/dev/null)" -ne 1 ]; then
                local dur_str
                dur_str=$(ffmpeg -i "${target}.tmp" 2>&1 | grep "Duration" | awk '{print $2}' | tr -d ',')
                [ -n "$dur_str" ] && duration=$(echo "$dur_str" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
            fi

            ffmpeg -y -hide_banner -loglevel warning -i "${target}.tmp" \
                -c:v libx264 -preset veryfast -profile:v main -pix_fmt yuv420p \
                -r 30 -g 60 -keyint_min 60 -sc_threshold 0 \
                -b:v 2500k -maxrate 2500k -bufsize 5000k \
                -c:a aac -b:a 128k -ar 48000 -ac 2 \
                -movflags +faststart \
                -progress pipe:1 "$target" 2>/dev/null | while read -r line; do
                if [[ "$line" == out_time_us=* ]]; then
                    local us="${line#*=}"
                    if [[ "$us" =~ ^[0-9]+$ ]] && [ -n "$duration" ]; then
                        local pct filled unfilled bar=""
                        pct=$(awk -v us="$us" -v dur="$duration" 'BEGIN { if (dur>0) { p=(us/1000000/dur)*100; if (p>100) p=100; printf "%.1f", p } else { print "0.0" } }')
                        filled=$(awk -v pct="$pct" 'BEGIN { printf "%d", (pct * 30 / 100) }')
                        unfilled=$((30 - filled))
                        for ((i=0; i<filled; i++)); do bar="${bar}="; done
                        if [ $unfilled -gt 0 ]; then
                            bar="${bar}>"
                            for ((i=1; i<unfilled; i++)); do bar="${bar} "; done
                        fi
                        printf "\rTranscoding BRB Video: [%s] %s%%" "$bar" "$pct"
                    fi
                fi
            done
            echo ""

            if [ -f "$target" ] && [ -s "$target" ]; then
                chmod 644 "$target" 2>/dev/null || true
                echo -e "${GREEN}BRB video successfully downloaded and transcoded.${NC}"
                rm -f "${target}.tmp"
            else
                echo -e "${YELLOW}FFmpeg transcode warning. Using downloaded file directly.${NC}"
                mv "${target}.tmp" "$target"
                chmod 644 "$target" 2>/dev/null || true
            fi
        else
            echo -e "${YELLOW}FFmpeg not found on host; using downloaded MP4 directly.${NC}"
            mv "${target}.tmp" "$target"
            chmod 644 "$target" 2>/dev/null || true
        fi
    else
        echo -e "${RED}Download failed (empty file).${NC}"
        rm -f "${target}.tmp"
        return 1
    fi
}

configure_noalbs() {
    while true; do
        clear
        echo -e "${GREEN}=== Full Server OBS & Disconnection Protection ===${NC}"
        if [ "$NOALBS_ENABLED" == "true" ]; then
            echo -e "Status:        ${GREEN}ENABLED${NC}"
            if is_server_managed_obs; then
                echo -e "Fallback Mode: ${CYAN}obs (Full Server OBS | ${OBS_WIDTH}x${OBS_HEIGHT}@${OBS_FPS}fps | Standby -> Main <-> BRB -> Disconnect)${NC}"
            elif [ "$FALLBACK_MODE" == "obs" ]; then
                echo -e "Fallback Mode: ${CYAN}obs (External OBS WebSocket: ${OBS_WS_HOST}:${OBS_WS_PORT})${NC}"
            else
                echo -e "Fallback Mode: ${CYAN}video (Zero-Reencode Server-Side MP4 / Cloud BRB)${NC}"
            fi
            echo -e "${YELLOW}Note: After changing settings here, run Option 9 (Build & Start Server) to apply them.${NC}"
        else
            echo -e "Status:        ${RED}DISABLED${NC} (Pure RTMP passthrough — NOALBS, OBS & BRB will NOT be installed)"
        fi
        echo ""
        echo "1) Toggle Disconnection Protection (Currently: $NOALBS_ENABLED)"
        echo "2) Primary Fallback Mode (Current: ${FALLBACK_MODE:-obs} [obs = Full Server OBS, video = FFmpeg MP4])"
        echo "3) OBS WebSocket Host (Current: $OBS_WS_HOST [use 'cookie-rtmps-obs' for server OBS])"
        echo "4) OBS WebSocket Port (Current: $OBS_WS_PORT)"
        echo "5) OBS WebSocket Password (Current: ${OBS_WS_PASSWORD:-(None)})"
        echo "6) Main/Live Scene Name (Current: $OBS_SCENE_LIVE)"
        echo "7) BRB Scene Name (Current: $OBS_SCENE_BRB)"
        echo "8) Low Bitrate Threshold (Current: $LOW_BITRATE kbps)"
        echo "9) Restore Bitrate Threshold (Current: $RESTORE_BITRATE kbps)"
        echo "10) Low Frame Rate Drop Threshold (Current: ${LOW_FPS} fps [0 = disabled])"
        echo "11) Restore Frame Rate Threshold (Current: ${RESTORE_FPS} fps)"
        echo "12) Configure BRB Video URL (Current: ${BRB_VIDEO_URL:-(Default)})"
        echo "13) BRB Timeout Before Disconnect (Current: ${CLOUD_BRB_TIMEOUT} seconds)"
        echo "14) Server OBS Output Profile (Current: ${OBS_WIDTH}x${OBS_HEIGHT} @ ${OBS_FPS}fps, ${OBS_BITRATE}kbps)"
        echo "15) Run Disconnection Protection Health Check"
        echo "16) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r noalbs_opt

        case $noalbs_opt in
            1)
                if [ "$NOALBS_ENABLED" == "true" ]; then
                    NOALBS_ENABLED="false"
                    CLOUD_BRB="false"
                    echo -e "${YELLOW}Disconnection protection DISABLED.${NC}"
                    echo -e "${YELLOW}NOALBS, OBS, and BRB components will NOT be installed; server will run pure RTMP relay.${NC}"
                    sleep 2
                else
                    NOALBS_ENABLED="true"
                    CLOUD_BRB="true"
                    [ -z "$BRB_VIDEO_URL" ] && BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
                    if [ "$FALLBACK_MODE" == "obs" ] && { [ -z "$OBS_WS_HOST" ] || [ "$OBS_WS_HOST" == "127.0.0.1" ]; }; then
                        OBS_WS_HOST="cookie-rtmps-obs"
                    fi
                    echo -e "${GREEN}Disconnection protection ENABLED (${FALLBACK_MODE}).${NC}"
                    sleep 1
                fi
                save_config
                ;;
            2)
                if [ "$FALLBACK_MODE" == "obs" ]; then
                    FALLBACK_MODE="video"
                    [ "$NOALBS_ENABLED" == "true" ] && CLOUD_BRB="true"
                    echo -e "${GREEN}Primary Fallback Mode switched to: video (Zero-Reencode FFmpeg MP4)${NC}"
                else
                    FALLBACK_MODE="obs"
                    [ "$NOALBS_ENABLED" == "true" ] && CLOUD_BRB="true"
                    if [ -z "$OBS_WS_HOST" ] || [ "$OBS_WS_HOST" == "127.0.0.1" ]; then
                        OBS_WS_HOST="cookie-rtmps-obs"
                    fi
                    echo -e "${GREEN}Primary Fallback Mode switched to: obs (Full Server OBS)${NC}"
                fi
                save_config
                sleep 1
                ;;
            3) echo -e "Enter OBS WebSocket Host (use 'cookie-rtmps-obs' for server OBS, or an external IP):"; read -r input; [ -n "$input" ] && { OBS_WS_HOST="$input"; save_config; } ;;
            4) echo -e "Enter OBS WebSocket Port (Default: 4455):"; read -r input; [ -n "$input" ] && { OBS_WS_PORT="$input"; save_config; } ;;
            5) echo -e "Enter OBS WebSocket Password:"; read -r input; OBS_WS_PASSWORD="$input"; save_config ;;
            6) echo -e "Enter OBS Main Scene Name (Default: Main):"; read -r input; [ -n "$input" ] && { OBS_SCENE_LIVE="$input"; save_config; } ;;
            7) echo -e "Enter OBS BRB Scene Name (Default: BRB):"; read -r input; [ -n "$input" ] && { OBS_SCENE_BRB="$input"; save_config; } ;;
            8) echo -e "Enter Low Bitrate Threshold in kbps (Default: 1000):"; read -r input; [ -n "$input" ] && { LOW_BITRATE="$input"; save_config; } ;;
            9) echo -e "Enter Restore Bitrate Threshold in kbps (Default: 1500):"; read -r input; [ -n "$input" ] && { RESTORE_BITRATE="$input"; save_config; } ;;
            10) echo -e "Enter Low Frame Rate Drop Threshold in fps (e.g. 15, or 0 to disable):"; read -r input; [ -n "$input" ] && { LOW_FPS="$input"; save_config; } ;;
            11) echo -e "Enter Restore Frame Rate Threshold in fps (e.g. 20):"; read -r input; [ -n "$input" ] && { RESTORE_FPS="$input"; save_config; } ;;
            12)
                echo -e "Enter BRB Video URL (Direct MP4 link, or type 'disable'/'clear' to remove):"
                read -r input
                if [ "$input" == "disable" ] || [ "$input" == "clear" ] || [ "$input" == "DISABLE" ] || [ "$input" == "CLEAR" ]; then
                    BRB_VIDEO_URL=""
                    save_config
                    rm -f ./data/brb_video.mp4 ./data/brb_video.mp4.tmp
                    echo -e "${GREEN}Cleared BRB Video URL and removed cached video.${NC}"
                    sleep 1
                elif [ -n "$input" ]; then
                    BRB_VIDEO_URL="$input"
                    save_config
                    if [ "$NOALBS_ENABLED" == "true" ]; then
                        ensure_brb_video_transcoded "$BRB_VIDEO_URL"
                    fi
                    sleep 1
                fi
                ;;
            13)
                echo -e "Enter BRB Timeout in seconds before disconnecting stream (Default: 300):"
                read -r input
                if [ -n "$input" ]; then
                    CLOUD_BRB_TIMEOUT="$input"
                    save_config
                    echo -e "${GREEN}BRB timeout updated to $CLOUD_BRB_TIMEOUT seconds.${NC}"
                    sleep 1
                fi
                ;;
            14)
                echo -e "Select Server OBS Output Profile:"
                echo "  1) 1280x720 @ 30fps, 3500kbps [Recommended for 1-2 vCPU VPS — lowest lag]"
                echo "  2) 1280x720 @ 60fps, 4500kbps [2-4 vCPU recommended]"
                echo "  3) 1920x1080 @ 30fps, 5000kbps [2-4 vCPU recommended]"
                echo "  4) 1920x1080 @ 60fps, 6000kbps [4+ vCPU recommended]"
                echo "  5) 854x480 @ 30fps, 2000kbps  [Ultra-low CPU mode for busy 1-core VPS]"
                echo -e "Selection: \c"
                read -r prof_opt
                case $prof_opt in
                    1) OBS_WIDTH="1280"; OBS_HEIGHT="720"; OBS_FPS="30"; OBS_BITRATE="3500"; save_config ;;
                    2) OBS_WIDTH="1280"; OBS_HEIGHT="720"; OBS_FPS="60"; OBS_BITRATE="4500"; save_config ;;
                    3) OBS_WIDTH="1920"; OBS_HEIGHT="1080"; OBS_FPS="30"; OBS_BITRATE="5000"; save_config ;;
                    4) OBS_WIDTH="1920"; OBS_HEIGHT="1080"; OBS_FPS="60"; OBS_BITRATE="6000"; save_config ;;
                    5) OBS_WIDTH="854"; OBS_HEIGHT="480"; OBS_FPS="30"; OBS_BITRATE="2000"; save_config ;;
                esac
                sleep 1
                ;;
            15)
                verify_disconnection_protection
                echo -e "\nPress Enter to continue..."
                read -r
                ;;
            16) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

enable_bbr_and_tcp_optimizations() {
    echo -e "${GREEN}Configuring Google BBR & Network TCP Buffer Optimizations...${NC}"
    local SUDO
    SUDO=$(get_sudo)

    $SUDO modprobe tcp_bbr 2>/dev/null || true

    local SYSCTL_CONF="/etc/sysctl.d/99-stream-optimization.conf"
    cat << 'SYSCTL_EOF' | $SUDO tee "$SYSCTL_CONF" >/dev/null
# Google BBR Congestion Control & Buffer Tuning
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_notsent_lowat = 16384
SYSCTL_EOF

    $SUDO sysctl -p "$SYSCTL_CONF" 2>/dev/null || $SUDO sysctl --system 2>/dev/null || true
    echo -e "${GREEN}Network TCP buffer optimizations applied successfully.${NC}"
}

configure_optimizations() {
    clear
    echo -e "${GREEN}=== Optimizations ===${NC}"
    echo "Current Chunk Size: $CHUNK_SIZE (Default: 4096)"
    echo "Enter new Chunk Size (press Enter to keep current): "
    read -r input
    if [ -n "$input" ]; then
        CHUNK_SIZE="$input"
        save_config
        echo -e "${GREEN}Chunk size updated.${NC}"
    fi

    echo -e "\nApplying Google BBR and TCP optimizations..."
    enable_bbr_and_tcp_optimizations
    sleep 1
}

install_docker() {
    echo -e "${GREEN}Checking for Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Installing...${NC}"
        local SUDO
        SUDO=$(get_sudo)
        curl -4 -fsSL --max-time 20 https://get.docker.com -o get-docker.sh
        $SUDO sh get-docker.sh
        $SUDO systemctl enable --now docker
        rm -f get-docker.sh
        echo -e "${GREEN}Docker installed successfully.${NC}"
    else
        echo -e "${GREEN}Docker is already installed ($(docker --version 2>/dev/null)).${NC}"
    fi
    sleep 1
}

is_sensitive_port() {
    case "$1" in
        20|21|22|25|53|67|68|80|110|123|143|443|465|587|993|995|3000|3306|5432|6379|27017) return 0 ;;
        *) return 1 ;;
    esac
}

check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        ss -tuln | grep -qE ":${port}(\s|$)"
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep -qE ":${port}(\s|$)"
    else
        return 1
    fi
}

cleanup_old_rtmp_files() {
    local full_wipe=${1:-false}
    local SUDO
    SUDO=$(get_sudo)

    echo -e "${YELLOW}Cleaning up old RTMP temporary and cache files...${NC}"
    rm -f ./get-docker.sh ./*.tmp ./*.log 2>/dev/null || true

    if [ "$full_wipe" == "true" ]; then
        rm -f "$CONFIG_FILE" 2>/dev/null || true
        rm -rf ./data ./logs ./obs-server "$PERSIST_USER_DIR" 2>/dev/null || true
        $SUDO rm -rf "$PERSIST_SYS_DIR" 2>/dev/null || true
    elif [ -d "./data" ]; then
        rm -f ./data/*.tmp ./data/*.log ./data/*.pid ./data/*.sock ./data/*.flv ./data/*.ts ./data/*.m3u8 2>/dev/null || true
        if [ "$NOALBS_ENABLED" != "true" ]; then
            rm -f ./data/brb_video.mp4 ./data/brb_video.mp4.tmp 2>/dev/null || true
        fi
    fi

    for base_dir in /tmp /var/tmp /var/run /var/cache /dev/shm; do
        if [ -d "$base_dir" ]; then
            $SUDO find "$base_dir" -maxdepth 3 \( \
                -iname "*rtmp*" -o -iname "*rtmps*" -o \
                -iname "*cookie-rtmp*" -o -iname "*cookiertmp*" -o \
                -iname "*brb_video*" -o -iname "*noalbs*" -o \
                -iname "*stream_validator*" -o -iname "*tiktok_pusher*" -o \
                -iname "*nginx-client-body*" \
            \) -exec rm -rf {} + 2>/dev/null || true
        fi
    done
}

build_and_run() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed! Please run 'Install Docker' first.${NC}"
        sleep 2
        return
    fi

    # Refresh auto whitelist (Server IP + WireGuard/OpenVPN ranges) or ensure localhost is included in manual mode
    if [ "$WHITELIST_MODE" == "auto" ]; then
        ACCEPTED_IP=$(build_default_whitelist)
        save_config
        echo -e "${GREEN}Auto IP Whitelist active:${NC} $ACCEPTED_IP"
    elif [ -n "$ACCEPTED_IP" ]; then
        ACCEPTED_IP=$(ensure_localhost_in_whitelist "$ACCEPTED_IP")
        save_config
    fi

    # Determine deployment mode:
    # 1) NOALBS_ENABLED=false -> Pure RTMP/RTMPS passthrough (NO OBS, NO NOALBS, NO BRB)
    # 2) NOALBS_ENABLED=true + server-managed OBS -> Full OBS on standby (port 1935) -> cookie-rtmps relay (internal 19359)
    # 3) NOALBS_ENABLED=true + video/external-obs -> cookie-rtmps on port 1935 directly
    local INSTALL_PROTECTION="false"
    local USE_MANAGED_OBS="false"
    if [ "$NOALBS_ENABLED" == "true" ]; then
        INSTALL_PROTECTION="true"
        if is_server_managed_obs; then
            USE_MANAGED_OBS="true"
            OBS_WS_HOST="cookie-rtmps-obs"
            CLOUD_BRB="true"
            save_config
        elif [ "$FALLBACK_MODE" == "video" ] && [ "$CLOUD_BRB" != "true" ]; then
            CLOUD_BRB="true"
            save_config
        fi
    else
        CLOUD_BRB="false"
        echo -e "${CYAN}Disconnection protection is DISABLED.${NC}"
        echo -e "${CYAN}Skipping NOALBS, OBS, and BRB installation — starting pure RTMP/RTMPS relay.${NC}"
    fi

    echo -e "${YELLOW}Checking and removing old containers, port conflicts, and stale files...${NC}"
    local OLD_CONTAINERS OLD_VOLUMES
    OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -iE 'rtmp|rtmps|cookie|prism|nginx-rtmp|noalbs|obs' | awk '{print $1}' | sort -u)
    if [ -n "$OLD_CONTAINERS" ]; then
        docker rm -v -f $OLD_CONTAINERS 2>/dev/null || true
    fi
    OLD_VOLUMES=$(docker volume ls -q | grep -iE 'rtmp|rtmps|cookie|prism' || true)
    if [ -n "$OLD_VOLUMES" ]; then
        docker volume rm -f $OLD_VOLUMES 2>/dev/null || true
    fi

    deep_cleanup_ports_and_processes
    cleanup_old_rtmp_files "false"
    enable_bbr_and_tcp_optimizations

    echo -e "${YELLOW}Verifying target RTMP port is clear (excluding sensitive ports 80, 443, etc.)...${NC}"
    local CONFLICTS=0
    if ! is_sensitive_port "$PORT_RTMP" && check_port "$PORT_RTMP"; then
        echo -e "${RED}Warning: Port $PORT_RTMP appears to be in use on the host!${NC}"
        echo -e "${YELLOW}If this is another service, CookieRTMPS may fail to start.${NC}"
        CONFLICTS=1
    fi

    if [ $CONFLICTS -eq 1 ]; then
        echo -e "${YELLOW}Port conflicts detected. Do you want to continue anyway?${NC}"
        echo "1) Yes, continue (CookieRTMPS will attempt to bind)"
        echo "2) Abort and return to Main Menu"
        echo -e "Selection: \c"
        read -r conflict_choice
        case $conflict_choice in
            1) echo -e "${GREEN}Continuing...${NC}" ;;
            *) return ;;
        esac
    else
        echo -e "${GREEN}No port conflicts detected.${NC}"
    fi

    # Auto-fill vertical from horizontal using diversified ingest servers to prevent conflicts
    if [ -n "$YOUTUBE_KEY" ] && [ -z "$V_YOUTUBE_KEY" ]; then
        V_YOUTUBE_KEY="$YOUTUBE_KEY"
        V_YOUTUBE_URL=$(get_alternative_url "youtube" "$YOUTUBE_URL")
    fi
    if [ -n "$TWITCH_KEY" ] && [ -z "$V_TWITCH_KEY" ]; then
        V_TWITCH_KEY="$TWITCH_KEY"
        V_TWITCH_URL=$(get_alternative_url "twitch" "$TWITCH_URL")
    fi
    if [ -n "$KICK_KEY" ] && [ -z "$V_KICK_KEY" ]; then
        V_KICK_KEY="$KICK_KEY"
        V_KICK_URL=$(get_alternative_url "kick" "$KICK_URL")
    fi

    [ -n "$YOUTUBE_KEY" ] && [ "$YOUTUBE_URL" == "$V_YOUTUBE_URL" ] && V_YOUTUBE_URL=$(get_alternative_url "youtube" "$V_YOUTUBE_URL")
    [ -n "$TWITCH_KEY" ] && [ "$TWITCH_URL" == "$V_TWITCH_URL" ] && V_TWITCH_URL=$(get_alternative_url "twitch" "$V_TWITCH_URL")
    [ -n "$KICK_KEY" ] && [ "$KICK_URL" == "$V_KICK_URL" ] && V_KICK_URL=$(get_alternative_url "kick" "$V_KICK_URL")

    if [ -n "$TIKTOK_KEY" ] && [ -z "$V_TIKTOK_KEY" ]; then
        V_TIKTOK_KEY="$TIKTOK_KEY"
        V_TIKTOK_URL="$TIKTOK_URL"
    fi

    local ANY_KEY_SET=0
    for key in "$YOUTUBE_KEY" "$FACEBOOK_KEY" "$INSTAGRAM_KEY" "$TIKTOK_KEY" "$TWITCH_KEY" "$KICK_KEY" "$X_KEY" "$TROVO_KEY" "$RTMP1_KEY" \
               "$V_YOUTUBE_KEY" "$V_TWITCH_KEY" "$V_KICK_KEY" "$V_TIKTOK_KEY" "$V_FACEBOOK_KEY" "$V_INSTAGRAM_KEY" "$V_X_KEY" "$V_TROVO_KEY" "$V_RTMP1_KEY"; do
        if [ -n "$key" ]; then
            ANY_KEY_SET=1
            break
        fi
    done

    if [ "$ANY_KEY_SET" -eq 0 ]; then
        echo -e "${RED}No stream keys (Horizontal or Vertical) have been configured.${NC}"
        echo -e "${YELLOW}Aborting installation as per configuration rules.${NC}"
        echo -e "Press Enter to return to menu..."
        read -r
        return
    fi

    mkdir -p ./data
    if [ "$INSTALL_PROTECTION" == "true" ]; then
        if [ -f "./data/brb_video.mp4" ] && [ -s "./data/brb_video.mp4" ] && ! head -c 512 "./data/brb_video.mp4" 2>/dev/null | grep -qiE '<!doctype html|<html'; then
            chmod 644 "./data/brb_video.mp4" 2>/dev/null || true
            echo -e "${GREEN}Existing BRB video found at ./data/brb_video.mp4. Preserving video source.${NC}"
        else
            if [ -z "$BRB_VIDEO_URL" ]; then
                echo -e "${YELLOW}BRB Video URL is empty and no cached video exists. Setting to default...${NC}"
                BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
                save_config
            fi
            ensure_brb_video_transcoded "$BRB_VIDEO_URL"
        fi
    else
        rm -f ./data/brb_video.mp4 ./data/brb_video.mp4.tmp 2>/dev/null || true
    fi

    # Check latest plugin versions only (no host apt-get update/upgrade)
    check_latest_plugins

    local BUILD_ARGS=()
    if [ -f "$SCRIPT_DIR/Dockerfile" ]; then
        if grep -qE '^ARG[[:space:]]+INSTALL_NOALBS' "$SCRIPT_DIR/Dockerfile"; then
            BUILD_ARGS+=(--build-arg "INSTALL_NOALBS=$INSTALL_PROTECTION")
        fi
        if grep -qE '^ARG[[:space:]]+INSTALL_OBS' "$SCRIPT_DIR/Dockerfile"; then
            BUILD_ARGS+=(--build-arg "INSTALL_OBS=$INSTALL_PROTECTION")
        fi
        if [ "$INSTALL_PROTECTION" == "true" ] && [ -n "$LATEST_NOALBS_VERSION" ] && grep -qE '^ARG[[:space:]]+NOALBS_VERSION' "$SCRIPT_DIR/Dockerfile"; then
            BUILD_ARGS+=(--build-arg "NOALBS_VERSION=$LATEST_NOALBS_VERSION")
        fi
        if [ -n "$LATEST_NGINX_RTMP_VERSION" ] && grep -qE '^ARG[[:space:]]+NGINX_RTMP_VERSION' "$SCRIPT_DIR/Dockerfile"; then
            BUILD_ARGS+=(--build-arg "NGINX_RTMP_VERSION=$LATEST_NGINX_RTMP_VERSION")
        fi
    fi

    echo -e "${GREEN}Building CookieRTMPS Relay Docker Image...${NC}"
    DOCKER_BUILDKIT=1 docker build "${BUILD_ARGS[@]}" -t cookie-rtmps .

    if [ "$USE_MANAGED_OBS" == "true" ]; then
        echo -e "${GREEN}Preparing Dedicated Docker Network '${DOCKER_NET_NAME}' (${DOCKER_NET_SUBNET})...${NC}"
        if ! docker network inspect "$DOCKER_NET_NAME" >/dev/null 2>&1; then
            docker network create --driver bridge --subnet "$DOCKER_NET_SUBNET" "$DOCKER_NET_NAME" >/dev/null
        fi

        echo -e "${GREEN}Generating & Building Full Official OBS Studio Image (cookie-rtmps-obs)...${NC}"
        generate_obs_server_files
        DOCKER_BUILDKIT=1 docker build -t cookie-rtmps-obs "$SCRIPT_DIR/obs-server"
    fi

    echo -e "${GREEN}Starting containers...${NC}"
    docker rm -v -f cookie-rtmps cookie-rtmps-obs 2>/dev/null || true

    local ENV_ARGS=(
        -e "YOUTUBE_URL=$YOUTUBE_URL" -e "YOUTUBE_KEY=$YOUTUBE_KEY"
        -e "FACEBOOK_URL=$FACEBOOK_URL" -e "FACEBOOK_KEY=$FACEBOOK_KEY"
        -e "INSTAGRAM_URL=$INSTAGRAM_URL" -e "INSTAGRAM_KEY=$INSTAGRAM_KEY"
        -e "TIKTOK_URL=$TIKTOK_URL" -e "TIKTOK_KEY=$TIKTOK_KEY"
        -e "TIKTOK_SL_TOKEN=$TIKTOK_SL_TOKEN" -e "TIKTOK_TITLE=$TIKTOK_TITLE" -e "TIKTOK_GAME_ID=$TIKTOK_GAME_ID"
        -e "TWITCH_URL=$TWITCH_URL" -e "TWITCH_KEY=$TWITCH_KEY"
        -e "KICK_URL=$KICK_URL" -e "KICK_KEY=$KICK_KEY"
        -e "X_URL=$X_URL" -e "X_KEY=$X_KEY"
        -e "TROVO_URL=$TROVO_URL" -e "TROVO_KEY=$TROVO_KEY"
        -e "RTMP1_URL=$RTMP1_URL" -e "RTMP1_KEY=$RTMP1_KEY"
        -e "V_YOUTUBE_URL=$V_YOUTUBE_URL" -e "V_YOUTUBE_KEY=$V_YOUTUBE_KEY"
        -e "V_TWITCH_URL=$V_TWITCH_URL" -e "V_TWITCH_KEY=$V_TWITCH_KEY"
        -e "V_KICK_URL=$V_KICK_URL" -e "V_KICK_KEY=$V_KICK_KEY"
        -e "V_TIKTOK_URL=$V_TIKTOK_URL" -e "V_TIKTOK_KEY=$V_TIKTOK_KEY"
        -e "V_FACEBOOK_URL=$V_FACEBOOK_URL" -e "V_FACEBOOK_KEY=$V_FACEBOOK_KEY"
        -e "V_INSTAGRAM_URL=$V_INSTAGRAM_URL" -e "V_INSTAGRAM_KEY=$V_INSTAGRAM_KEY"
        -e "V_X_URL=$V_X_URL" -e "V_X_KEY=$V_X_KEY"
        -e "V_TROVO_URL=$V_TROVO_URL" -e "V_TROVO_KEY=$V_TROVO_KEY"
        -e "V_RTMP1_URL=$V_RTMP1_URL" -e "V_RTMP1_KEY=$V_RTMP1_KEY"
        -e "OBS_KEY=$OBS_KEY" -e "APP_NAME=$APP_NAME"
        -e "CHUNK_SIZE=$CHUNK_SIZE" -e "SERVER_DOMAIN=$SERVER_DOMAIN"
        -e "STREAM_BASE_TITLE=" -e "TWITCH_CLIENT_ID=" -e "TWITCH_OAUTH_TOKEN=" -e "TWITCH_BROADCASTER_ID="
    )

    if [ "$USE_MANAGED_OBS" == "true" ]; then
        # 1. Start cookie-rtmps strictly as the downstream RTMP/RTMPS (Stunnel) multi-push relay
        # NOALBS is disabled on cookie-rtmps so it NEVER fights cookie-rtmps-obs's obs_controller.py
        local RELAY_ACCEPTED_IP="127.0.0.1,${DOCKER_NET_SUBNET}"
        [ -n "$ACCEPTED_IP" ] && RELAY_ACCEPTED_IP="${ACCEPTED_IP},${DOCKER_NET_SUBNET}"

        docker run -d --name cookie-rtmps \
            --network "$DOCKER_NET_NAME" \
            -p "127.0.0.1:${PORT_RELAY_INTERNAL}:1935" \
            --restart unless-stopped \
            --add-host=host.docker.internal:host-gateway \
            "${ENV_ARGS[@]}" \
            -e "ACCEPTED_IP=$RELAY_ACCEPTED_IP" \
            -e "NOALBS_ENABLED=false" -e "FALLBACK_MODE=none" \
            -e "OBS_WS_HOST=" -e "OBS_WS_PORT=" -e "OBS_WS_PASSWORD=" \
            -e "OBS_SCENE_LIVE=" -e "OBS_SCENE_BRB=" \
            -e "LOW_BITRATE=0" -e "RESTORE_BITRATE=0" \
            -e "CLOUD_BRB=false" -e "CLOUD_BRB_TIMEOUT=0" \
            -e "BRB_VIDEO_URL=" -e "BRB_VIDEO_PATH=" \
            -v "$(pwd)/data:/app/data" \
            cookie-rtmps

        # 2. Start Full OBS (always on standby) + jitter-hardened Nginx-RTMP ingest + workflow controller on public port 1935
        local OBS_ACCEPTED_IP="$ACCEPTED_IP"
        [ -n "$OBS_ACCEPTED_IP" ] && OBS_ACCEPTED_IP="${OBS_ACCEPTED_IP},${DOCKER_NET_SUBNET}"

        docker run -d --name cookie-rtmps-obs \
            --network "$DOCKER_NET_NAME" \
            --shm-size=1g \
            -p "${PORT_RTMP}:1935" \
            -p "127.0.0.1:${OBS_WS_PORT}:${OBS_WS_PORT}" \
            --restart unless-stopped \
            -e "APP_NAME=$APP_NAME" \
            -e "OBS_KEY=$OBS_KEY" \
            -e "CHUNK_SIZE=$CHUNK_SIZE" \
            -e "ACCEPTED_IP=$OBS_ACCEPTED_IP" \
            -e "OBS_WS_PORT=$OBS_WS_PORT" \
            -e "OBS_WS_PASSWORD=$OBS_WS_PASSWORD" \
            -e "OBS_SCENE_LIVE=$OBS_SCENE_LIVE" \
            -e "OBS_SCENE_BRB=$OBS_SCENE_BRB" \
            -e "LOW_BITRATE=$LOW_BITRATE" \
            -e "RESTORE_BITRATE=$RESTORE_BITRATE" \
            -e "LOW_FPS=$LOW_FPS" \
            -e "RESTORE_FPS=$RESTORE_FPS" \
            -e "CLOUD_BRB_TIMEOUT=$CLOUD_BRB_TIMEOUT" \
            -e "OBS_WIDTH=$OBS_WIDTH" \
            -e "OBS_HEIGHT=$OBS_HEIGHT" \
            -e "OBS_FPS=$OBS_FPS" \
            -e "OBS_BITRATE=$OBS_BITRATE" \
            -e "RELAY_HOST=cookie-rtmps" \
            -e "RELAY_PORT=1935" \
            -e "BRB_VIDEO_PATH=/app/data/brb_video.mp4" \
            -v "$(pwd)/data:/app/data" \
            cookie-rtmps-obs
    else
        # Pure RTMP passthrough (NOALBS_ENABLED=false) OR FFmpeg Cloud BRB / External OBS mode
        local EXTRA_DOCKER_ARGS=()
        if [ "$INSTALL_PROTECTION" == "true" ]; then
            EXTRA_DOCKER_ARGS+=(--add-host=host.docker.internal:host-gateway)
            ENV_ARGS+=(
                -e "ACCEPTED_IP=$ACCEPTED_IP"
                -e "NOALBS_ENABLED=true" -e "FALLBACK_MODE=$FALLBACK_MODE"
                -e "OBS_WS_HOST=$OBS_WS_HOST" -e "OBS_WS_PORT=$OBS_WS_PORT" -e "OBS_WS_PASSWORD=$OBS_WS_PASSWORD"
                -e "OBS_SCENE_LIVE=$OBS_SCENE_LIVE" -e "OBS_SCENE_BRB=$OBS_SCENE_BRB"
                -e "LOW_BITRATE=$LOW_BITRATE" -e "RESTORE_BITRATE=$RESTORE_BITRATE"
                -e "CLOUD_BRB=$CLOUD_BRB" -e "CLOUD_BRB_TIMEOUT=$CLOUD_BRB_TIMEOUT"
                -e "BRB_VIDEO_URL=$BRB_VIDEO_URL" -e "BRB_VIDEO_PATH=/app/data/brb_video.mp4"
            )
        else
            ENV_ARGS+=(
                -e "ACCEPTED_IP=$ACCEPTED_IP"
                -e "NOALBS_ENABLED=false" -e "FALLBACK_MODE=none"
                -e "OBS_WS_HOST=" -e "OBS_WS_PORT=" -e "OBS_WS_PASSWORD="
                -e "OBS_SCENE_LIVE=" -e "OBS_SCENE_BRB="
                -e "LOW_BITRATE=0" -e "RESTORE_BITRATE=0"
                -e "CLOUD_BRB=false" -e "CLOUD_BRB_TIMEOUT=0"
                -e "BRB_VIDEO_URL=" -e "BRB_VIDEO_PATH="
            )
        fi

        docker run -d --name cookie-rtmps \
            -p "${PORT_RTMP}:1935" \
            --restart unless-stopped \
            "${EXTRA_DOCKER_ARGS[@]}" \
            "${ENV_ARGS[@]}" \
            -v "$(pwd)/data:/app/data" \
            cookie-rtmps
    fi

    if [ $? -eq 0 ]; then
        local DISPLAY_HOST=${SERVER_DOMAIN:-$(get_server_ip)}
        echo -e "${GREEN}Container 'cookie-rtmps' is running!${NC}"

        if [ "$USE_MANAGED_OBS" == "true" ]; then
            echo -e "${YELLOW}Waiting for Full OBS Studio WebSocket v5 to initialize in standby (up to 25s)...${NC}"
            for i in $(seq 1 25); do
                if docker exec cookie-rtmps-obs python3 -c "import socket; s=socket.create_connection(('127.0.0.1', ${OBS_WS_PORT}), 1); s.close()" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            sync_container_nginx_whitelist "cookie-rtmps" "true"
            sync_obs_container_whitelist
            echo -e "${CYAN}Mode:${NC} Full Server OBS (${OBS_WIDTH}x${OBS_HEIGHT}@${OBS_FPS}fps | Standby -> ${OBS_SCENE_LIVE} <-> ${OBS_SCENE_BRB} -> ${CLOUD_BRB_TIMEOUT}s Disconnect)"
            verify_disconnection_protection
        elif [ "$INSTALL_PROTECTION" == "true" ]; then
            sleep 2
            sync_container_nginx_whitelist "cookie-rtmps" "false"
            echo -e "${CYAN}Mode:${NC} Disconnection Protection ENABLED (${FALLBACK_MODE})"
            verify_disconnection_protection
        else
            sleep 2
            sync_container_nginx_whitelist "cookie-rtmps" "false"
            echo -e "${GREEN}Mode:${NC} Pure RTMP/RTMPS Passthrough (NOALBS/OBS/BRB disabled)"
        fi

        echo -e "\nYou can stream to: rtmp://${DISPLAY_HOST}:${PORT_RTMP}/${APP_NAME}"
        echo -e "Vertical stream:  rtmp://${DISPLAY_HOST}:${PORT_RTMP}/vertical"

        if [ -f "./integration_test.sh" ]; then
            echo -e "${YELLOW}Running repository integration tests...${NC}"
            sleep 1
            chmod +x ./integration_test.sh
            ./integration_test.sh
        fi
    else
        echo -e "${RED}Failed to start container(s).${NC}"
    fi
    echo -e "Press Enter to continue..."
    read -r
}

view_logs() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed!${NC}"
        sleep 2
        return
    fi

    local target_container="cookie-rtmps"
    if docker ps --format '{{.Names}}' | grep -qx 'cookie-rtmps-obs'; then
        echo -e "${GREEN}Select container logs to view:${NC}"
        echo "1) cookie-rtmps (Upstream RTMP/RTMPS Stunnel Relay)"
        echo "2) cookie-rtmps-obs (Full Server OBS, Standby/Auto-Live, Metrics & BRB Controller)"
        echo -e "Selection [1]: \c"
        read -r c_choice
        [ "$c_choice" == "2" ] && target_container="cookie-rtmps-obs"
    fi

    echo -e "${YELLOW}Showing live logs for ${target_container}...${NC}"
    echo -e "${YELLOW}(Press Ctrl+C to exit log view)${NC}\n"
    (
        trap 'exit 0' INT
        docker logs --since 24h -f "$target_container" 2>&1 | awk '
            /GET \/stat HTTP/ { next }
            /ERROR|error|FAIL|fail|REJECTED|disconnect|Disconnect|failed|Failed/ {
                print "\033[0;31m" $0 "\033[0m"
                fflush()
                next
            }
            /WARNING|warning|LOW|low|taking over|Switched to|Protection triggered/ {
                print "\033[1;33m" $0 "\033[0m"
                fflush()
                next
            }
            /NOALBS|Cloud BRB|OBS-Controller|GOING ONLINE|Returned automatically|STANDBY|LIVE Metrics/ {
                print "\033[0;36m" $0 "\033[0m"
                fflush()
                next
            }
            {
                print $0
                fflush()
            }
        '
    )

    while true; do
        echo -e "\n${GREEN}=== Log Options ===${NC}"
        echo "1) Return to Main Menu"
        echo "2) Clear Logs"
        echo -e "Select an option: \c"
        read -r log_opt

        case $log_opt in
            1) break ;;
            2)
                echo -e "${YELLOW}Clearing logs...${NC}"
                for c in cookie-rtmps cookie-rtmps-obs; do
                    if docker ps -a --format '{{.Names}}' | grep -qx "$c"; then
                        docker exec "$c" sh -c 'truncate -s 0 /var/log/nginx/access.log /var/log/nginx/error.log /var/log/obs.log' 2>/dev/null || true
                        LOG_PATH=$(docker inspect --format='{{.LogPath}}' "$c" 2>/dev/null)
                        if [ -n "$LOG_PATH" ]; then
                            sudo truncate -s 0 "$LOG_PATH" 2>/dev/null || truncate -s 0 "$LOG_PATH" 2>/dev/null || true
                        fi
                    fi
                done
                echo -e "${GREEN}Logs cleared.${NC}"
                sleep 1
                ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

deep_cleanup_ports_and_processes() {
    echo -e "${YELLOW}Cleaning up RTMP processes and unbinding RTMP/web ports (excluding sensitive ports 80, 443, 22, 53, etc.)...${NC}"
    local SUDO
    SUDO=$(get_sudo)

    local RAW_PORTS=("$PORT_RTMP" "$PORT_RELAY_INTERNAL" 81 1935 1936 3000 4455 8080 8081 8088 8443 8888 9997 9998 19350 19351 19352 19353 19354 19355 19356 19357 19358 19359)
    local PORTS=()
    for p in "${RAW_PORTS[@]}"; do
        [ -n "$p" ] && ! is_sensitive_port "$p" && PORTS+=("$p")
    done

    if command -v docker &> /dev/null; then
        local active_cids
        active_cids=$(docker ps --format '{{.ID}} {{.Ports}}' | grep -E ":(193[5-6]|4455|808[018]|8443|8888|999[78]|1935[0-9]|${PORT_RTMP})->" | awk '{print $1}' | sort -u || true)
        [ -n "$active_cids" ] && docker rm -v -f $active_cids 2>/dev/null || true
    fi

    local port_regex
    port_regex=$(IFS='|'; echo "${PORTS[*]}")
    if command -v ss &> /dev/null; then
        local pids
        pids=$($SUDO ss -tulnp 2>/dev/null | grep -E ":(${port_regex})(\s|$)" | grep -oP 'pid=\K\d+' | sort -u || true)
        [ -n "$pids" ] && $SUDO kill -9 $pids 2>/dev/null || true
    elif command -v lsof &> /dev/null; then
        for port in "${PORTS[@]}"; do
            local pids
            pids=$($SUDO lsof -t -i :"$port" 2>/dev/null || true)
            [ -n "$pids" ] && $SUDO kill -9 $pids 2>/dev/null || true
        done
    fi

    $SUDO pkill -f "tiktok_pusher|noalbs|stream_validator|update_titles|cookie-rtmps|obs_controller|stunnel.*1935|nginx.*rtmp" 2>/dev/null || true
}

stop_and_uninstall() {
    echo -e "${YELLOW}Stopping services, unbinding RTMP ports, and performing deep uninstall & removal...${NC}"

    if command -v docker &> /dev/null; then
        local OLD_CONTAINERS
        OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Names}} {{.Image}} {{.Labels}}' | grep -iE 'rtmp|rtmps|cookie|prism|nginx-rtmp|noalbs|obs' | awk '{print $1}' | sort -u)
        if [ -n "$OLD_CONTAINERS" ]; then
            docker rm -v -f $OLD_CONTAINERS 2>/dev/null && echo -e "${GREEN}RTMP/RTMPS containers and volumes removed.${NC}" || true
        else
            docker rm -v -f cookie-rtmps cookie-rtmps-obs 2>/dev/null || true
        fi
    fi

    deep_cleanup_ports_and_processes

    if command -v docker &> /dev/null; then
        local OLD_VOLUMES OLD_NETWORKS OLD_IMAGES
        OLD_VOLUMES=$(docker volume ls -q | grep -iE 'rtmp|rtmps|cookie|prism' || true)
        [ -n "$OLD_VOLUMES" ] && docker volume rm -f $OLD_VOLUMES 2>/dev/null && echo -e "${GREEN}Matching Docker volumes removed.${NC}" || true

        OLD_NETWORKS=$(docker network ls --format '{{.ID}} {{.Name}}' | grep -iE 'rtmp|rtmps|cookie|prism' | awk '{print $1}' || true)
        [ -n "$OLD_NETWORKS" ] && docker network rm $OLD_NETWORKS 2>/dev/null && echo -e "${GREEN}Matching Docker networks removed.${NC}" || true

        OLD_IMAGES=$(docker images --format '{{.ID}} {{.Repository}} {{.Tag}}' | grep -iE 'rtmp|rtmps|cookie|prism' | awk '{print $1}' | sort -u)
        if [ -n "$OLD_IMAGES" ]; then
            docker rmi -f $OLD_IMAGES 2>/dev/null && echo -e "${GREEN}RTMP/RTMPS images removed.${NC}" || true
        else
            docker rmi -f cookie-rtmps cookie-rtmps-obs 2>/dev/null || true
        fi

        echo -e "${YELLOW}Pruning Docker build cache, volumes, networks, and unused images...${NC}"
        docker volume prune -f 2>/dev/null || true
        docker network prune -f 2>/dev/null || true
        docker image prune -a -f 2>/dev/null || true
        docker builder prune -a -f 2>/dev/null || true
        docker system prune -a -f 2>/dev/null || true
    fi

    cleanup_old_rtmp_files "true"
    echo -e "${GREEN}CookieRTMPS and all RTMP/RTMPS components have been completely uninstalled and RTMP ports unbound.${NC}"
    sleep 2
}

SERVER_IP=$(get_server_ip)

while true; do
    clear
    DISPLAY_HOST=${SERVER_DOMAIN:-$SERVER_IP}
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}     CookieRTMPS Quick Installer      ${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${YELLOW}Quick Reference:${NC}"
    echo -e "  RTMP Ingest:     rtmp://${DISPLAY_HOST}:${PORT_RTMP}/${APP_NAME}"
    echo -e "  Vertical Ingest: rtmp://${DISPLAY_HOST}:${PORT_RTMP}/vertical"
    echo -e "  IP Whitelist:    ${WHITELIST_MODE} (${ACCEPTED_IP:-Allow All})"
    if [ "$NOALBS_ENABLED" == "true" ]; then
        if is_server_managed_obs; then
            echo -e "  Protection:      ${GREEN}ENABLED${NC} (Full Server OBS | ${OBS_WIDTH}x${OBS_HEIGHT}@${OBS_FPS}fps | Low ${LOW_BITRATE}kbps/${LOW_FPS}fps | BRB ${CLOUD_BRB_TIMEOUT}s)"
        else
            echo -e "  Protection:      ${GREEN}ENABLED${NC} (NOALBS / ${FALLBACK_MODE} | BRB ${CLOUD_BRB_TIMEOUT}s)"
        fi
    else
        echo -e "  Protection:      ${YELLOW}DISABLED${NC} (Pure RTMP Passthrough — No OBS/NOALBS)"
    fi
    echo "-------------------------------------"
    echo "1) Install Docker (if not installed)"
    echo "2) Configure Stream Keys (Horizontal)"
    echo "3) Configure Stream Keys (Vertical)"
    echo "4) Configure OBS Setup & Security Key"
    echo "5) Configure IP Whitelist (Auto VPN/WireGuard + Server IP)"
    echo "6) Configure Domain / Reverse Proxy (Optional)"
    echo "7) Configure Optimizations (Chunk Size)"
    echo "8) Configure Full Server OBS & Disconnection Protection"
    echo "9) Build & Start Server"
    echo "10) Run Integration Tests"
    echo "11) Stop Server & Uninstall"
    echo "12) View Logs"
    echo "13) Quit"
    echo -e "Select an option: \c"
    read -r option

    case $option in
        1) install_docker ;;
        2) configure_keys ;;
        3) configure_vertical_keys ;;
        4) configure_obs ;;
        5) configure_whitelist ;;
        6) configure_domain ;;
        7) configure_optimizations ;;
        8) configure_noalbs ;;
        9) build_and_run ;;
        10)
            sync_container_nginx_whitelist "cookie-rtmps" "$(is_server_managed_obs && echo true || echo false)"
            if [ "$NOALBS_ENABLED" == "true" ]; then
                sync_obs_container_whitelist
                verify_disconnection_protection
            fi
            if [ -f "./integration_test.sh" ]; then
                chmod +x ./integration_test.sh
                ./integration_test.sh
            else
                echo -e "${RED}Test script not found.${NC}"
            fi
            echo -e "Press Enter to continue..."
            read -r
            ;;
        11) stop_and_uninstall ;;
        12) view_logs ;;
        13) clear; echo -e "${GREEN}Goodbye!${NC}"; break ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
