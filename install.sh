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
SERVER_DOMAIN=""
CHUNK_SIZE="8192"

# Host Port Settings
PORT_RTMP="1935"
INTERNAL_RTMP_PORT="19359"

# NOALBS & Lightweight OBS Disconnection Protection Settings
NOALBS_ENABLED="false"
FALLBACK_MODE="obs"
OBS_WS_HOST="127.0.0.1"
OBS_WS_PORT="4455"
OBS_WS_PASSWORD=""
OBS_SCENE_LIVE="main"
OBS_SCENE_BRB="brb"
LOW_BITRATE="1000"
RESTORE_BITRATE="1500"
CLOUD_BRB="true"
BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
BRB_VIDEO_LOOP="true"
CLOUD_BRB_TIMEOUT="300"
OBS_BRIDGE_BITRATE="6000"

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
    V_RTMP1_URL V_RTMP1_KEY OBS_KEY APP_NAME ACCEPTED_IP SERVER_DOMAIN CHUNK_SIZE
    NOALBS_ENABLED FALLBACK_MODE OBS_WS_HOST OBS_WS_PORT OBS_WS_PASSWORD
    OBS_SCENE_LIVE OBS_SCENE_BRB LOW_BITRATE RESTORE_BITRATE CLOUD_BRB
    BRB_VIDEO_URL BRB_VIDEO_LOOP CLOUD_BRB_TIMEOUT OBS_BRIDGE_BITRATE PORT_RTMP
)

get_sudo() {
    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
        echo "sudo"
    fi
}

get_server_ip() {
    if [ -z "$CACHED_SERVER_IP" ]; then
        CACHED_SERVER_IP=$(curl -4 -s --max-time 2 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
        [ -z "$CACHED_SERVER_IP" ] && CACHED_SERVER_IP="<your_server_ip>"
    fi
    echo "$CACHED_SERVER_IP"
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

    # Normalize defaults if missing from older config files
    [ -z "$OBS_SCENE_LIVE" ] && OBS_SCENE_LIVE="main"
    [ -z "$OBS_SCENE_BRB" ] && OBS_SCENE_BRB="brb"
    [ -z "$BRB_VIDEO_URL" ] && BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
    [ -z "$BRB_VIDEO_LOOP" ] && BRB_VIDEO_LOOP="true"
    [ -z "$CLOUD_BRB_TIMEOUT" ] && CLOUD_BRB_TIMEOUT="300"
    [ -z "$OBS_BRIDGE_BITRATE" ] && OBS_BRIDGE_BITRATE="6000"

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

detect_wireguard_ips() {
    local SUDO
    SUDO=$(get_sudo)
    local raw_entries=()

    # 1. Active WireGuard network interfaces (wg0, wg1, etc.)
    if command -v ip &> /dev/null; then
        while IFS= read -r cidr; do
            [ -n "$cidr" ] && raw_entries+=("$cidr")
        done < <(ip -4 -o addr show 2>/dev/null | awk '$2 ~ /^wg/ {print $4}')

        while IFS= read -r route_cidr; do
            [ -n "$route_cidr" ] && [ "$route_cidr" != "default" ] && raw_entries+=("$route_cidr")
        done < <(ip -4 route show 2>/dev/null | awk '/dev wg/ {print $1}')
    fi

    # 2. Active WireGuard peer allowed-ips via wg CLI
    if command -v wg &> /dev/null; then
        while IFS= read -r allowed_cidr; do
            [ -n "$allowed_cidr" ] && raw_entries+=("$allowed_cidr")
        done < <($SUDO wg show all allowed-ips 2>/dev/null | tr '\t ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$' | grep -v '^0\.0\.0\.0/0$' || true)
    fi

    # 3. /etc/wireguard/*.conf fallback (Address and AllowedIPs)
    if [ -d "/etc/wireguard" ] || $SUDO test -d "/etc/wireguard" 2>/dev/null; then
        while IFS= read -r conf_cidr; do
            [ -n "$conf_cidr" ] && raw_entries+=("$conf_cidr")
        done < <($SUDO grep -hE '^\s*(Address|AllowedIPs)\s*=' /etc/wireguard/*.conf 2>/dev/null \
            | sed 's/^[^=]*=//' \
            | tr ',' '\n' \
            | tr -d ' \t\r' \
            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$' \
            | grep -v '^0\.0\.0\.0/0$' || true)
    fi

    [ ${#raw_entries[@]} -eq 0 ] && return 0

    if command -v python3 &> /dev/null; then
        python3 - "${raw_entries[@]}" << 'PY_WG_EOF'
import ipaddress
import sys

networks = []
hosts = []
for token in sys.argv[1:]:
    token = token.strip()
    if not token:
        continue
    try:
        if "/" in token:
            iface = ipaddress.ip_interface(token)
            if iface.version != 4 or iface.network.prefixlen == 0:
                continue
            if iface.network.prefixlen == 32:
                hosts.append(str(iface.ip))
            else:
                networks.append(iface.network)
        else:
            addr = ipaddress.ip_address(token)
            if addr.version == 4:
                hosts.append(str(addr))
    except ValueError:
        continue

unique_nets = []
for net in sorted(set(networks), key=lambda n: n.prefixlen):
    if not any(net.subnet_of(existing) for existing in unique_nets):
        unique_nets.append(net)

result = [str(net) for net in unique_nets]
for h in dict.fromkeys(hosts):
    ip_obj = ipaddress.ip_address(h)
    if not any(ip_obj in net for net in unique_nets):
        result.append(h)

print(" ".join(result))
PY_WG_EOF
    else
        printf '%s\n' "${raw_entries[@]}" | sed 's|/32$||' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/[[:space:]]*$//'
    fi
}

append_unique_whitelist_entries() {
    local current="$1"
    local additions="$2"
    local combined=()
    for item in $current $additions; do
        [ -z "$item" ] && continue
        local exists=0
        for existing in "${combined[@]}"; do
            if [ "$existing" == "$item" ]; then
                exists=1
                break
            fi
        done
        [ "$exists" -eq 0 ] && combined+=("$item")
    done
    echo "${combined[*]}"
}

configure_whitelist() {
    while true; do
        clear
        echo -e "${GREEN}=== IP Whitelist Configuration ===${NC}"
        echo -e "Current Accepted IP(s): ${YELLOW}${ACCEPTED_IP:-None (Allow All)}${NC}"
        echo ""
        echo "1) Server Public IP + WireGuard VPN IPs/Subnets (Auto-Detect)"
        echo "2) Add Manual IP Address or CIDR Subnet (e.g. 10.66.66.0/24)"
        echo "3) Clear IP Whitelist (Allow All)"
        echo "4) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r wl_opt

        case $wl_opt in
            1)
                local SERVER_IP_FETCH WG_IPS NEW_WHITELIST=""
                SERVER_IP_FETCH=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null || ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n 1)
                if [ -n "$SERVER_IP_FETCH" ]; then
                    CACHED_SERVER_IP="$SERVER_IP_FETCH"
                    NEW_WHITELIST=$(append_unique_whitelist_entries "$NEW_WHITELIST" "$SERVER_IP_FETCH")
                    echo -e "${GREEN}Detected Server Public IP: $SERVER_IP_FETCH${NC}"
                else
                    echo -e "${YELLOW}Warning: Could not fetch server public IP.${NC}"
                fi

                WG_IPS=$(detect_wireguard_ips)
                if [ -n "$WG_IPS" ]; then
                    NEW_WHITELIST=$(append_unique_whitelist_entries "$NEW_WHITELIST" "$WG_IPS")
                    echo -e "${GREEN}Detected WireGuard IP(s)/Subnet(s): $WG_IPS${NC}"
                else
                    echo -e "${YELLOW}No active WireGuard interface or /etc/wireguard/*.conf detected.${NC}"
                    echo -e "Enter custom WireGuard subnet/IP to include (e.g. 10.66.66.0/24, or press Enter to skip): \c"
                    read -r custom_wg
                    if [ -n "$custom_wg" ]; then
                        NEW_WHITELIST=$(append_unique_whitelist_entries "$NEW_WHITELIST" "$custom_wg")
                    fi
                fi

                if [ -n "$NEW_WHITELIST" ]; then
                    ACCEPTED_IP="$NEW_WHITELIST"
                    echo -e "${GREEN}IP Whitelist updated to: $ACCEPTED_IP${NC}"
                    save_config
                else
                    echo -e "${RED}No IPs detected to add.${NC}"
                fi
                sleep 1
                ;;
            2)
                echo -e "Enter IP address or CIDR subnet to add (space-separated supported): \c"
                read -r ip_input
                if [ -n "$ip_input" ]; then
                    ACCEPTED_IP=$(append_unique_whitelist_entries "$ACCEPTED_IP" "$ip_input")
                    echo -e "${GREEN}IP Whitelist updated to: $ACCEPTED_IP${NC}"
                    save_config
                fi
                sleep 1
                ;;
            3)
                ACCEPTED_IP=""
                echo -e "${GREEN}IP Whitelist disabled. All IPs allowed.${NC}"
                save_config
                sleep 1
                ;;
            4|"") break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

configure_noalbs() {
    while true; do
        clear
        echo -e "${GREEN}=== Disconnection Protection & Lightweight OBS (NOALBS) ===${NC}"
        echo -e "Status: $([ "$NOALBS_ENABLED" == "true" ] && echo -e "${GREEN}ENABLED (Lightweight Headless OBS Active)${NC}" || echo -e "${RED}DISABLED${NC}")"
        echo -e "${CYAN}Architecture: Ingest RTMP -> Headless OBS ['${OBS_SCENE_LIVE}' / '${OBS_SCENE_BRB}'] -> CookieRTMPS Relay${NC}"
        echo ""
        echo "1) Toggle Disconnection Protection (Currently: $NOALBS_ENABLED)"
        echo "2) BRB Video MP4 URL [OBS Browser Source] (Current: ${BRB_VIDEO_URL:-(None)})"
        echo "3) Loop BRB Video While Disconnected (Currently: $BRB_VIDEO_LOOP)"
        echo "4) Disconnect Stream Timeout After BRB Starts (Current: ${CLOUD_BRB_TIMEOUT} seconds)"
        echo "5) Low Bitrate Threshold -> Switch to '${OBS_SCENE_BRB}' (Current: $LOW_BITRATE kbps)"
        echo "6) Restore Bitrate Threshold -> Switch to '${OBS_SCENE_LIVE}' (Current: $RESTORE_BITRATE kbps)"
        echo "7) Main/Live Scene Name (Current: $OBS_SCENE_LIVE)"
        echo "8) BRB Scene Name (Current: $OBS_SCENE_BRB)"
        echo "9) Lightweight OBS Output Bitrate (Current: ${OBS_BRIDGE_BITRATE} kbps)"
        echo "10) OBS WebSocket Port (Current: $OBS_WS_PORT)"
        echo "11) OBS WebSocket Password (Current: ${OBS_WS_PASSWORD:-(Disabled/Local Only)})"
        echo "12) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r noalbs_opt

        case $noalbs_opt in
            1)
                if [ "$NOALBS_ENABLED" == "true" ]; then
                    NOALBS_ENABLED="false"
                    CLOUD_BRB="false"
                else
                    NOALBS_ENABLED="true"
                    CLOUD_BRB="true"
                    FALLBACK_MODE="obs"
                fi
                save_config
                ;;
            2)
                echo -e "Enter Direct .mp4 URL for OBS Browser Source (or type 'default' / 'clear'):"
                read -r input
                if [ "$input" == "clear" ] || [ "$input" == "CLEAR" ]; then
                    BRB_VIDEO_URL=""
                    save_config
                    echo -e "${GREEN}Cleared BRB Video URL.${NC}"
                    sleep 1
                elif [ "$input" == "default" ] || [ "$input" == "DEFAULT" ]; then
                    BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
                    save_config
                    echo -e "${GREEN}BRB Video URL set to default MP4 (direct browser source, no transcoding).${NC}"
                    sleep 1
                elif [ -n "$input" ]; then
                    BRB_VIDEO_URL="$input"
                    save_config
                    echo -e "${GREEN}BRB Video URL updated (direct browser source, no transcoding).${NC}"
                    sleep 1
                fi
                ;;
            3)
                [ "$BRB_VIDEO_LOOP" == "true" ] && BRB_VIDEO_LOOP="false" || BRB_VIDEO_LOOP="true"
                echo -e "${GREEN}BRB Video Loop set to: $BRB_VIDEO_LOOP${NC}"
                save_config
                sleep 1
                ;;
            4)
                echo -e "Enter seconds to loop BRB video before disconnecting stream (Default: 300):"
                read -r input
                if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -gt 0 ]; then
                    CLOUD_BRB_TIMEOUT="$input"
                    save_config
                    echo -e "${GREEN}Stream disconnect timeout updated to $CLOUD_BRB_TIMEOUT seconds.${NC}"
                    sleep 1
                elif [ -n "$input" ]; then
                    echo -e "${RED}Please enter a valid positive number of seconds.${NC}"
                    sleep 1
                fi
                ;;
            5)
                echo -e "Enter Low Bitrate Threshold in kbps (switches to '${OBS_SCENE_BRB}' below this, e.g. 1000):"
                read -r input
                if [[ "$input" =~ ^[0-9]+$ ]]; then
                    LOW_BITRATE="$input"
                    save_config
                fi
                ;;
            6)
                echo -e "Enter Restore Bitrate Threshold in kbps (switches back to '${OBS_SCENE_LIVE}' above this, e.g. 1500):"
                read -r input
                if [[ "$input" =~ ^[0-9]+$ ]]; then
                    RESTORE_BITRATE="$input"
                    save_config
                fi
                ;;
            7)
                echo -e "Enter Main/Live Scene Name (Default: main):"
                read -r input
                [ -n "$input" ] && { OBS_SCENE_LIVE="$input"; save_config; }
                ;;
            8)
                echo -e "Enter BRB Scene Name (Default: brb):"
                read -r input
                [ -n "$input" ] && { OBS_SCENE_BRB="$input"; save_config; }
                ;;
            9)
                echo -e "Enter Lightweight OBS Output Video Bitrate in kbps (Default: 6000):"
                read -r input
                if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 500 ]; then
                    OBS_BRIDGE_BITRATE="$input"
                    save_config
                fi
                ;;
            10)
                echo -e "Enter OBS WebSocket Port (Default: 4455):"
                read -r input
                if [[ "$input" =~ ^[0-9]+$ ]]; then
                    OBS_WS_PORT="$input"
                    save_config
                fi
                ;;
            11)
                echo -e "Enter OBS WebSocket Password (leave blank to disable auth on local loopback):"
                read -r input
                OBS_WS_PASSWORD="$input"
                save_config
                ;;
            12) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

generate_lightweight_obs_bridge() {
    local BRIDGE_DIR="$SCRIPT_DIR/obs-bridge"
    mkdir -p "$BRIDGE_DIR"

    cat << 'DOCKERFILE_EOF' > "$BRIDGE_DIR/Dockerfile"
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV MESA_GL_VERSION_OVERRIDE=3.3
ENV QT_QPA_PLATFORM=xcb

RUN apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=15 update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libgl1-mesa-dri \
        libglx-mesa0 \
        libnginx-mod-rtmp \
        nginx-light \
        obs-studio \
        pulseaudio \
        python3 \
        python3-websockets \
        xvfb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && command -v obs >/dev/null \
    && find /usr/lib -name "obs-websocket.so" | grep -q .

WORKDIR /opt/obs-bridge
COPY setup_obs.py noalbs_controller.py brb.html entrypoint.sh /opt/obs-bridge/
RUN chmod +x /opt/obs-bridge/entrypoint.sh /opt/obs-bridge/setup_obs.py /opt/obs-bridge/noalbs_controller.py

EXPOSE 1935
ENTRYPOINT ["/opt/obs-bridge/entrypoint.sh"]
DOCKERFILE_EOF

    cat << 'HTML_EOF' > "$BRIDGE_DIR/brb.html"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>BRB Stream Protection</title>
<style>
  html, body {
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    background: #000000;
    overflow: hidden;
  }
  video {
    width: 100vw;
    height: 100vh;
    object-fit: cover;
    display: block;
    background: #000000;
  }
  video::-webkit-media-controls {
    display: none !important;
  }
</style>
</head>
<body>
  <video id="brbVideo" autoplay playsinline></video>
  <script>
    (function () {
      const params = new URLSearchParams(window.location.search);
      const src = params.get("src") || "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4";
      const loopParam = (params.get("loop") || "true").toLowerCase();
      const shouldLoop = loopParam === "true" || loopParam === "1";
      const video = document.getElementById("brbVideo");

      video.loop = shouldLoop;
      video.muted = false;
      video.volume = 1.0;
      video.src = src;

      video.play().catch(function () {
        video.muted = true;
        video.play().catch(function () {});
      });
    })();
  </script>
</body>
</html>
HTML_EOF

    cat << 'SETUP_PY_EOF' > "$BRIDGE_DIR/setup_obs.py"
#!/usr/bin/env python3
import configparser
import glob
import json
import os
import urllib.parse

PORT_RTMP = os.environ.get("PORT_RTMP", "1935")
APP_NAME = os.environ.get("APP_NAME", "live")
OBS_KEY = os.environ.get("OBS_KEY", "")
OBS_WS_PORT = os.environ.get("OBS_WS_PORT", "4455")
OBS_WS_PASSWORD = os.environ.get("OBS_WS_PASSWORD", "")
OBS_SCENE_LIVE = os.environ.get("OBS_SCENE_LIVE", "main")
OBS_SCENE_BRB = os.environ.get("OBS_SCENE_BRB", "brb")
BRB_VIDEO_URL = os.environ.get("BRB_VIDEO_URL", "https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4")
BRB_VIDEO_LOOP = os.environ.get("BRB_VIDEO_LOOP", "true")
OBS_BRIDGE_BITRATE = os.environ.get("OBS_BRIDGE_BITRATE", "6000")
INTERNAL_RTMP_PORT = os.environ.get("INTERNAL_RTMP_PORT", "19359")
CHUNK_SIZE = os.environ.get("CHUNK_SIZE", "8192")
ACCEPTED_IP = os.environ.get("ACCEPTED_IP", "").strip()
RELAY_HOST = os.environ.get("RELAY_HOST", "127.0.0.1")

obs_root = "/root/.config/obs-studio"
profile_dir = os.path.join(obs_root, "basic", "profiles", "CookieRTMPS")
scenes_dir = os.path.join(obs_root, "basic", "scenes")
os.makedirs(profile_dir, exist_ok=True)
os.makedirs(scenes_dir, exist_ok=True)

# 1. Global / User INI (disables first-run wizards and configures obs-websocket v5)
for ini_name in ("global.ini", "user.ini"):
    cfg = configparser.ConfigParser()
    cfg.optionxform = str
    cfg["General"] = {
        "FirstRun": "false",
        "EnableAutoUpdates": "false",
        "ConfirmOnExit": "false",
    }
    cfg["Basic"] = {
        "Profile": "CookieRTMPS",
        "ProfileDir": "CookieRTMPS",
        "SceneCollection": "CookieRTMPS",
        "SceneCollectionFile": "CookieRTMPS",
    }
    cfg["BasicWindow"] = {
        "Migrated": "true",
    }
    cfg["OBSWebSocket"] = {
        "FirstLoad": "false",
        "ServerEnabled": "true",
        "ServerPort": str(OBS_WS_PORT),
        "AuthRequired": "true" if OBS_WS_PASSWORD else "false",
        "ServerPassword": OBS_WS_PASSWORD,
        "AlertsEnabled": "false",
    }
    with open(os.path.join(obs_root, ini_name), "w", encoding="utf-8") as f:
        cfg.write(f, space_around_delimiters=False)

# 2. OBS Encoding Profile (1080p, 30fps, 2s keyframe interval, x264 veryfast, 48kHz stereo AAC)
basic_ini = configparser.ConfigParser()
basic_ini.optionxform = str
basic_ini["General"] = {"Name": "CookieRTMPS"}
basic_ini["Video"] = {
    "BaseCX": "1920",
    "BaseCY": "1080",
    "OutputCX": "1920",
    "OutputCY": "1080",
    "FPSType": "0",
    "FPSCommon": "30",
}
basic_ini["Output"] = {"Mode": "Simple"}
basic_ini["SimpleOutput"] = {
    "VBitrate": str(OBS_BRIDGE_BITRATE),
    "ABitrate": "160",
    "StreamEncoder": "x264",
    "Preset": "veryfast",
    "UseAdvanced": "true",
    "Profile": "main",
    "KeyframeIntervalSec": "2",
}
basic_ini["Audio"] = {
    "SampleRate": "48000",
    "ChannelSetup": "Stereo",
}
with open(os.path.join(profile_dir, "basic.ini"), "w", encoding="utf-8") as f:
    basic_ini.write(f, space_around_delimiters=False)

# 3. OBS Output Target -> CookieRTMPS internal relay (ensure non-empty RTMP stream name)
relay_stream_key = OBS_KEY if OBS_KEY else "cookiertmps"
service_json = {
    "type": "rtmp_custom",
    "settings": {
        "server": f"rtmp://{RELAY_HOST}:{INTERNAL_RTMP_PORT}/{APP_NAME}",
        "key": relay_stream_key,
        "use_auth": False,
    },
}
with open(os.path.join(profile_dir, "service.json"), "w", encoding="utf-8") as f:
    json.dump(service_json, f, indent=2)

# 4. OBS Scene Collection with 2 scenes: 'main' (RTMP feed) and 'brb' (Full-screen MP4 URL)
ingest_url = f"rtmp://127.0.0.1:{PORT_RTMP}/{APP_NAME}"
if OBS_KEY:
    ingest_url = f"{ingest_url}/{OBS_KEY}"

has_obs_browser = bool(
    glob.glob("/usr/lib/**/obs-browser.so", recursive=True)
    or glob.glob("/usr/local/lib/**/obs-browser.so", recursive=True)
)

encoded_mp4 = urllib.parse.quote(BRB_VIDEO_URL, safe="")
brb_browser_url = f"http://127.0.0.1:8090/brb.html?src={encoded_mp4}&loop={BRB_VIDEO_LOOP}"
should_loop = BRB_VIDEO_LOOP.lower() == "true"

if has_obs_browser:
    brb_source_def = {
        "prev_ver": 503316480,
        "name": "BRB_Browser_Source",
        "uuid": "44444444-4444-4444-8444-444444444444",
        "id": "browser_source",
        "versioned_id": "browser_source",
        "settings": {
            "url": brb_browser_url,
            "width": 1920,
            "height": 1080,
            "fps": 30,
            "reroute_audio": True,
            "restart_when_active": True,
            "shutdown": False,
        },
        "mixers": 255,
        "sync": 0,
        "flags": 0,
        "volume": 1.0,
        "balance": 0.5,
        "enabled": True,
        "muted": False,
        "push-to-mute": False,
        "push-to-mute-delay": 0,
        "push-to-talk": False,
        "push-to-talk-delay": 0,
        "hotkeys": {},
        "deinterlace_mode": 0,
        "deinterlace_field_order": 0,
        "monitoring_type": 0,
        "private_settings": {},
    }
else:
    brb_source_def = {
        "prev_ver": 503316480,
        "name": "BRB_Browser_Source",
        "uuid": "44444444-4444-4444-8444-444444444444",
        "id": "ffmpeg_source",
        "versioned_id": "ffmpeg_source",
        "settings": {
            "is_local_file": False,
            "input": BRB_VIDEO_URL,
            "looping": should_loop,
            "restart_on_activate": True,
            "clear_on_media_end": False,
            "reconnect_delay_sec": 2,
            "hw_decode": False,
        },
        "mixers": 255,
        "sync": 0,
        "flags": 0,
        "volume": 1.0,
        "balance": 0.5,
        "enabled": True,
        "muted": False,
        "push-to-mute": False,
        "push-to-mute-delay": 0,
        "push-to-talk": False,
        "push-to-talk-delay": 0,
        "hotkeys": {},
        "deinterlace_mode": 0,
        "deinterlace_field_order": 0,
        "monitoring_type": 0,
        "private_settings": {},
    }

def make_scene_item(item_id, name, source_uuid):
    return {
        "name": name,
        "source_uuid": source_uuid,
        "visible": True,
        "locked": False,
        "rot": 0.0,
        "pos": {"x": 0.0, "y": 0.0},
        "scale": {"x": 1.0, "y": 1.0},
        "align": 5,
        "bounds_type": 2,
        "bounds_align": 0,
        "bounds": {"x": 1920.0, "y": 1080.0},
        "crop_left": 0,
        "crop_top": 0,
        "crop_right": 0,
        "crop_bottom": 0,
        "id": item_id,
        "group_item_backup": False,
        "scale_filter": "disable",
        "blend_method": "default",
        "blend_type": "normal",
        "show_transition": {"duration": 0},
        "hide_transition": {"duration": 0},
        "private_settings": {},
    }

scene_collection = {
    "current_scene": OBS_SCENE_LIVE,
    "current_program_scene": OBS_SCENE_LIVE,
    "scene_order": [
        {"name": OBS_SCENE_LIVE},
        {"name": OBS_SCENE_BRB},
    ],
    "name": "CookieRTMPS",
    "sources": [
        {
            "prev_ver": 503316480,
            "name": OBS_SCENE_LIVE,
            "uuid": "11111111-1111-4111-8111-111111111111",
            "id": "scene",
            "versioned_id": "scene",
            "settings": {
                "id_counter": 1,
                "custom_size": False,
                "items": [
                    make_scene_item(1, "RTMP_Ingest_Source", "22222222-2222-4222-8222-222222222222")
                ],
            },
            "mixers": 0,
            "sync": 0,
            "flags": 0,
            "volume": 1.0,
            "balance": 0.5,
            "enabled": True,
            "muted": False,
            "push-to-mute": False,
            "push-to-mute-delay": 0,
            "push-to-talk": False,
            "push-to-talk-delay": 0,
            "hotkeys": {},
            "deinterlace_mode": 0,
            "deinterlace_field_order": 0,
            "monitoring_type": 0,
            "private_settings": {},
        },
        {
            "prev_ver": 503316480,
            "name": "RTMP_Ingest_Source",
            "uuid": "22222222-2222-4222-8222-222222222222",
            "id": "ffmpeg_source",
            "versioned_id": "ffmpeg_source",
            "settings": {
                "is_local_file": False,
                "input": ingest_url,
                "input_format": "flv",
                "buffering_mb": 1,
                "reconnect_delay_sec": 1,
                "restart_on_activate": True,
                "clear_on_media_end": False,
                "hw_decode": False,
            },
            "mixers": 255,
            "sync": 0,
            "flags": 0,
            "volume": 1.0,
            "balance": 0.5,
            "enabled": True,
            "muted": False,
            "push-to-mute": False,
            "push-to-mute-delay": 0,
            "push-to-talk": False,
            "push-to-talk-delay": 0,
            "hotkeys": {},
            "deinterlace_mode": 0,
            "deinterlace_field_order": 0,
            "monitoring_type": 0,
            "private_settings": {},
        },
        {
            "prev_ver": 503316480,
            "name": OBS_SCENE_BRB,
            "uuid": "33333333-3333-4333-8333-333333333333",
            "id": "scene",
            "versioned_id": "scene",
            "settings": {
                "id_counter": 1,
                "custom_size": False,
                "items": [
                    make_scene_item(1, "BRB_Browser_Source", "44444444-4444-4444-8444-444444444444")
                ],
            },
            "mixers": 0,
            "sync": 0,
            "flags": 0,
            "volume": 1.0,
            "balance": 0.5,
            "enabled": True,
            "muted": False,
            "push-to-mute": False,
            "push-to-mute-delay": 0,
            "push-to-talk": False,
            "push-to-talk-delay": 0,
            "hotkeys": {},
            "deinterlace_mode": 0,
            "deinterlace_field_order": 0,
            "monitoring_type": 0,
            "private_settings": {},
        },
        brb_source_def,
    ],
}
with open(os.path.join(scenes_dir, "CookieRTMPS.json"), "w", encoding="utf-8") as f:
    json.dump(scene_collection, f, indent=2)

# 5. Local Nginx-RTMP Ingest Receiver (notify_method get ensures $arg_name matches OBS_KEY)
allow_rules = "            allow publish 127.0.0.1;\n"
ip_entries = [ip.strip() for ip in ACCEPTED_IP.replace(",", " ").split() if ip.strip()]
if ip_entries:
    if RELAY_HOST != "127.0.0.1":
        allow_rules += "            allow publish 172.16.0.0/12;\n"
    for ip_entry in ip_entries:
        allow_rules += f"            allow publish {ip_entry};\n"
    allow_rules += "            deny publish all;\n"
else:
    allow_rules += "            allow publish all;\n"

on_publish_directive = ""
if OBS_KEY:
    on_publish_directive = (
        "            notify_method get;\n"
        "            on_publish http://127.0.0.1:8090/auth;\n"
    )

nginx_conf = f"""load_module modules/ngx_rtmp_module.so;
worker_processes 1;
events {{
    worker_connections 1024;
}}

rtmp {{
    server {{
        listen {PORT_RTMP};
        chunk_size {CHUNK_SIZE};

        application {APP_NAME} {{
            live on;
            record off;
            meta copy;
{allow_rules}{on_publish_directive}            allow play 127.0.0.1;
            deny play all;
        }}

        application vertical {{
            live on;
            record off;
            meta copy;
{allow_rules}{on_publish_directive}            push rtmp://{RELAY_HOST}:{INTERNAL_RTMP_PORT}/vertical;
        }}
    }}
}}

http {{
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log off;

    server {{
        listen 127.0.0.1:8090;

        location /stat {{
            rtmp_stat all;
        }}

        location /control {{
            rtmp_control all;
        }}

        location /auth {{
            if ($arg_name = "{OBS_KEY}") {{
                return 200 "OK";
            }}
            return 403 "Forbidden";
        }}

        location = /brb.html {{
            alias /opt/obs-bridge/brb.html;
        }}
    }}
}}
"""
with open("/etc/nginx/nginx.conf", "w", encoding="utf-8") as f:
    f.write(nginx_conf)
SETUP_PY_EOF

    cat << 'CONTROLLER_PY_EOF' > "$BRIDGE_DIR/noalbs_controller.py"
#!/usr/bin/env python3
import asyncio
import base64
import hashlib
import json
import os
import time
import urllib.request
import uuid
import xml.etree.ElementTree as ET
import websockets

PORT_RTMP = os.environ.get("PORT_RTMP", "1935")
APP_NAME = os.environ.get("APP_NAME", "live")
OBS_KEY = os.environ.get("OBS_KEY", "")
OBS_WS_HOST = os.environ.get("OBS_WS_HOST", "127.0.0.1")
OBS_WS_PORT = int(os.environ.get("OBS_WS_PORT", "4455"))
OBS_WS_PASSWORD = os.environ.get("OBS_WS_PASSWORD", "")
OBS_SCENE_LIVE = os.environ.get("OBS_SCENE_LIVE", "main")
OBS_SCENE_BRB = os.environ.get("OBS_SCENE_BRB", "brb")
LOW_BITRATE = float(os.environ.get("LOW_BITRATE", "1000"))
RESTORE_BITRATE = float(os.environ.get("RESTORE_BITRATE", "1500"))
BRB_VIDEO_LOOP = os.environ.get("BRB_VIDEO_LOOP", "true").lower() == "true"
CLOUD_BRB_TIMEOUT = int(os.environ.get("CLOUD_BRB_TIMEOUT", "300"))


def get_ingest_stats():
    try:
        with urllib.request.urlopen("http://127.0.0.1:8090/stat", timeout=1.5) as resp:
            xml_data = resp.read()
        root = ET.fromstring(xml_data)
        for app in root.findall(".//application"):
            name_el = app.find("name")
            if name_el is not None and name_el.text == APP_NAME:
                live = app.find("live")
                if live is None:
                    return False, 0.0, ""
                for stream in live.findall("stream"):
                    publishing = stream.find("publishing")
                    if publishing is not None:
                        bw_el = stream.find("bw_in")
                        sname_el = stream.find("name")
                        bw_bps = float(bw_el.text) if (bw_el is not None and bw_el.text) else 0.0
                        sname = sname_el.text.strip() if (sname_el is not None and sname_el.text) else ""
                        return True, bw_bps / 1000.0, sname
        return False, 0.0, ""
    except Exception:
        return False, 0.0, ""


def drop_ingest_publisher():
    try:
        url = f"http://127.0.0.1:8090/control/drop/publisher?app={APP_NAME}"
        urllib.request.urlopen(url, timeout=1.5).read()
    except Exception:
        pass


class OBSClient:
    def __init__(self, host, port, password):
        self.uri = f"ws://{host}:{port}"
        self.password = password
        self.ws = None

    async def connect(self):
        self.ws = await websockets.connect(self.uri, ping_interval=20, ping_timeout=20)
        hello_raw = await self.ws.recv()
        hello = json.loads(hello_raw)
        auth_obj = hello.get("d", {}).get("authentication")
        identify_d = {"rpcVersion": 1}
        if auth_obj and self.password:
            secret_hash = hashlib.sha256((self.password + auth_obj["salt"]).encode("utf-8")).digest()
            secret = base64.b64encode(secret_hash).decode("utf-8")
            auth_hash = hashlib.sha256((secret + auth_obj["challenge"]).encode("utf-8")).digest()
            identify_d["authentication"] = base64.b64encode(auth_hash).decode("utf-8")
        await self.ws.send(json.dumps({"op": 1, "d": identify_d}))
        identified_raw = await self.ws.recv()
        identified = json.loads(identified_raw)
        if identified.get("op") != 2:
            raise RuntimeError(f"OBS WebSocket identify failed: {identified}")

    async def call(self, request_type, request_data=None):
        req_id = str(uuid.uuid4())
        payload = {
            "op": 6,
            "d": {
                "requestType": request_type,
                "requestId": req_id,
            },
        }
        if request_data is not None:
            payload["d"]["requestData"] = request_data
        await self.ws.send(json.dumps(payload))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("op") == 7 and msg.get("d", {}).get("requestId") == req_id:
                return msg.get("d", {})

    async def set_scene(self, scene_name):
        await self.call("SetCurrentProgramScene", {"sceneName": scene_name})

    async def start_stream(self):
        await self.call("StartStream")

    async def stop_stream(self):
        await self.call("StopStream")

    async def restart_rtmp_source(self, active_stream_name):
        target_url = f"rtmp://127.0.0.1:{PORT_RTMP}/{APP_NAME}"
        if active_stream_name:
            target_url = f"{target_url}/{active_stream_name}"
        elif OBS_KEY:
            target_url = f"{target_url}/{OBS_KEY}"
        await self.call(
            "SetInputSettings",
            {
                "inputName": "RTMP_Ingest_Source",
                "inputSettings": {"input": target_url},
                "overlay": True,
            },
        )
        await self.call(
            "TriggerMediaInputAction",
            {
                "inputName": "RTMP_Ingest_Source",
                "mediaAction": "OBS_WEBSOCKET_MEDIA_INPUT_ACTION_RESTART",
            },
        )

    async def refresh_brb_source(self):
        try:
            await self.call(
                "PressInputPropertiesButton",
                {
                    "inputName": "BRB_Browser_Source",
                    "propertyName": "refreshnocache",
                },
            )
        except Exception:
            pass
        try:
            await self.call(
                "TriggerMediaInputAction",
                {
                    "inputName": "BRB_Browser_Source",
                    "mediaAction": "OBS_WEBSOCKET_MEDIA_INPUT_ACTION_RESTART",
                },
            )
        except Exception:
            pass


async def run_controller():
    obs = OBSClient(OBS_WS_HOST, OBS_WS_PORT, OBS_WS_PASSWORD)
    while True:
        try:
            await obs.connect()
            print(
                f"[NOALBS] Connected to Lightweight OBS WebSocket. "
                f"Live='{OBS_SCENE_LIVE}', BRB='{OBS_SCENE_BRB}', "
                f"Low=<{LOW_BITRATE}kbps, Restore>={RESTORE_BITRATE}kbps, "
                f"Loop={BRB_VIDEO_LOOP}, Timeout={CLOUD_BRB_TIMEOUT}s",
                flush=True,
            )
            break
        except Exception as exc:
            print(f"[NOALBS] Waiting for OBS WebSocket ({exc})...", flush=True)
            await asyncio.sleep(2)

    state = "IDLE"  # IDLE -> LIVE <-> BRB -> IDLE
    low_streak = 0
    restore_streak = 0
    brb_started_at = None

    while True:
        try:
            publishing, kbps, active_name = get_ingest_stats()

            if state == "IDLE":
                if publishing and kbps > 50:
                    print(f"[NOALBS] Live ingest detected ({kbps:.0f} kbps). Switching to '{OBS_SCENE_LIVE}' and starting stream...", flush=True)
                    await obs.restart_rtmp_source(active_name)
                    await obs.set_scene(OBS_SCENE_LIVE)
                    await obs.start_stream()
                    state = "LIVE"
                    low_streak = 0
                    restore_streak = 0
                    brb_started_at = None

            elif state == "LIVE":
                if (not publishing) or (kbps < LOW_BITRATE):
                    low_streak += 1
                    if low_streak >= 3:
                        print(
                            f"[NOALBS] Bitrate dropped ({kbps:.0f} kbps < {LOW_BITRATE:.0f} kbps). "
                            f"Switching to '{OBS_SCENE_BRB}' (loop={BRB_VIDEO_LOOP}, timeout={CLOUD_BRB_TIMEOUT}s).",
                            flush=True,
                        )
                        await obs.refresh_brb_source()
                        await obs.set_scene(OBS_SCENE_BRB)
                        state = "BRB"
                        brb_started_at = time.monotonic()
                        restore_streak = 0
                else:
                    low_streak = 0

            elif state == "BRB":
                elapsed = time.monotonic() - (brb_started_at or time.monotonic())
                if publishing and kbps >= RESTORE_BITRATE:
                    restore_streak += 1
                    if restore_streak >= 3:
                        print(
                            f"[NOALBS] Connection restored ({kbps:.0f} kbps >= {RESTORE_BITRATE:.0f} kbps). "
                            f"Switching back to '{OBS_SCENE_LIVE}'.",
                            flush=True,
                        )
                        await obs.restart_rtmp_source(active_name)
                        await obs.set_scene(OBS_SCENE_LIVE)
                        state = "LIVE"
                        low_streak = 0
                        restore_streak = 0
                        brb_started_at = None
                else:
                    restore_streak = 0
                    if elapsed >= CLOUD_BRB_TIMEOUT:
                        print(
                            f"[NOALBS] Disconnection timeout ({CLOUD_BRB_TIMEOUT}s) reached. "
                            f"Disconnecting stream and returning to IDLE.",
                            flush=True,
                        )
                        await obs.stop_stream()
                        drop_ingest_publisher()
                        await obs.set_scene(OBS_SCENE_LIVE)
                        state = "IDLE"
                        low_streak = 0
                        restore_streak = 0
                        brb_started_at = None

        except Exception as exc:
            print(f"[NOALBS] Controller warning: {exc}. Reconnecting OBS WebSocket...", flush=True)
            await asyncio.sleep(2)
            try:
                await obs.connect()
            except Exception:
                pass

        await asyncio.sleep(1.0)


if __name__ == "__main__":
    asyncio.run(run_controller())
CONTROLLER_PY_EOF

    cat << 'ENTRYPOINT_EOF' > "$BRIDGE_DIR/entrypoint.sh"
#!/bin/bash
set -e

export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

python3 /opt/obs-bridge/setup_obs.py

# Start Nginx-RTMP Ingest Receiver
nginx

# Start Virtual Display (Xvfb) & Virtual Audio Sink (PulseAudio)
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
sleep 1

pulseaudio --start --exit-idle-time=-1 --log-target=file:/tmp/pulse.log 2>/dev/null || true
pactl load-module module-null-sink sink_name=obs_virtual_sink sink_properties=device.description="OBS_Virtual_Audio" >/dev/null 2>&1 || true
pactl set-default-sink obs_virtual_sink >/dev/null 2>&1 || true

# Launch Lightweight Headless OBS with preconfigured 'main' & 'brb' scenes
obs --profile CookieRTMPS --collection CookieRTMPS --disable-shutdown-check >/tmp/obs.log 2>&1 &

# Wait up to 15s for OBS WebSocket to bind before starting controller
OBS_WS_PORT_VAL="${OBS_WS_PORT:-4455}"
for _ in $(seq 1 30); do
    if python3 -c "import socket; s=socket.create_connection(('127.0.0.1', int('$OBS_WS_PORT_VAL')), 0.5); s.close()" 2>/dev/null; then
        break
    fi
    sleep 0.5
done

# Start NOALBS Bitrate Monitor & Automatic Scene Switcher
exec python3 /opt/obs-bridge/noalbs_controller.py
ENTRYPOINT_EOF

    chmod +x "$BRIDGE_DIR/entrypoint.sh" "$BRIDGE_DIR/setup_obs.py" "$BRIDGE_DIR/noalbs_controller.py"
}

run_full_integration_tests() {
    echo ""
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}  CookieRTMPS & Lightweight OBS Integration Test ${NC}"
    echo -e "${GREEN}=================================================${NC}"

    local PASS_COUNT=0
    local FAIL_COUNT=0
    local WARN_COUNT=0

    record_pass() {
        echo -e "  [${GREEN}PASS${NC}] $1"
        PASS_COUNT=$((PASS_COUNT + 1))
    }

    record_fail() {
        echo -e "  [${RED}FAIL${NC}] $1"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    }

    record_warn() {
        echo -e "  [${YELLOW}WARN${NC}] $1"
        WARN_COUNT=$((WARN_COUNT + 1))
    }

    if ! command -v docker &> /dev/null; then
        record_fail "Docker CLI not found."
        return 1
    fi

    # 1. Core CookieRTMPS Relay Container Checks
    echo -e "${CYAN}--- 1. Core RTMP/RTMPS Relay Checks ---${NC}"
    if docker ps --format '{{.Names}}' | grep -qx "cookie-rtmps"; then
        record_pass "Container 'cookie-rtmps' is running."
    else
        record_fail "Container 'cookie-rtmps' is NOT running."
    fi

    # Wait up to 10s for cookie-rtmps entrypoint to bring up nginx & stunnel
    for _ in $(seq 1 20); do
        if docker exec cookie-rtmps pgrep -f "nginx" >/dev/null 2>&1; then
            break
        fi
        sleep 0.5
    done

    if docker exec cookie-rtmps pgrep -f "nginx" >/dev/null 2>&1; then
        record_pass "Nginx-RTMP relay daemon is active inside 'cookie-rtmps'."
    else
        record_fail "Nginx-RTMP relay daemon is not running inside 'cookie-rtmps'."
    fi

    if docker exec cookie-rtmps nginx -t >/dev/null 2>&1; then
        record_pass "Nginx configuration syntax inside 'cookie-rtmps' is valid."
    else
        record_fail "Nginx configuration syntax check failed inside 'cookie-rtmps'."
    fi

    if docker exec cookie-rtmps pgrep -f "stunnel" >/dev/null 2>&1; then
        record_pass "Stunnel RTMPS TLS bridge is running."
    else
        record_warn "Stunnel process not active (normal if only plain rtmp:// targets are configured)."
    fi

    local EXPECTED_RELAY_PORT="$PORT_RTMP"
    [ "$NOALBS_ENABLED" == "true" ] && EXPECTED_RELAY_PORT="$INTERNAL_RTMP_PORT"
    if python3 -c "import socket; s=socket.create_connection(('127.0.0.1', int('$EXPECTED_RELAY_PORT')), 2); s.close()" 2>/dev/null; then
        record_pass "CookieRTMPS RTMP port ${EXPECTED_RELAY_PORT} is accepting TCP connections."
    else
        record_fail "CookieRTMPS RTMP port ${EXPECTED_RELAY_PORT} is not reachable."
    fi

    # 2. WireGuard & IP Whitelist Checks
    echo -e "${CYAN}--- 2. IP Whitelist & WireGuard Checks ---${NC}"
    if [ -n "$ACCEPTED_IP" ]; then
        record_pass "IP Whitelist configured: ${ACCEPTED_IP}"
        local TARGET_NGINX_CONTAINER="cookie-rtmps"
        [ "$NOALBS_ENABLED" == "true" ] && TARGET_NGINX_CONTAINER="cookie-rtmps-obs"
        local missing_ips=""
        for ip_entry in $ACCEPTED_IP; do
            if ! docker exec "$TARGET_NGINX_CONTAINER" grep -Fq "allow publish ${ip_entry};" /etc/nginx/nginx.conf 2>/dev/null; then
                missing_ips="$missing_ips $ip_entry"
            fi
        done
        if [ -z "$missing_ips" ]; then
            record_pass "All whitelisted IPs/WireGuard subnets are loaded in ${TARGET_NGINX_CONTAINER} nginx.conf."
        else
            record_fail "Missing whitelist rules in ${TARGET_NGINX_CONTAINER} for:${missing_ips}"
        fi
    else
        record_pass "IP Whitelist is open (all source IPs allowed)."
    fi

    # 3. Lightweight OBS Disconnection Protection & Client Handshake Checks
    if [ "$NOALBS_ENABLED" == "true" ]; then
        echo -e "${CYAN}--- 3. Lightweight OBS & Disconnection Protection Checks ---${NC}"
        if docker ps --format '{{.Names}}' | grep -qx "cookie-rtmps-obs"; then
            record_pass "Container 'cookie-rtmps-obs' is running."
        else
            record_fail "Container 'cookie-rtmps-obs' is NOT running."
        fi

        if docker exec cookie-rtmps-obs nginx -t >/dev/null 2>&1; then
            record_pass "Nginx-RTMP ingest config inside 'cookie-rtmps-obs' is valid."
        else
            record_fail "Nginx-RTMP ingest config syntax check failed inside 'cookie-rtmps-obs'."
        fi

        if python3 -c "
import socket
s = socket.create_connection(('127.0.0.1', int('$PORT_RTMP')), 2)
c1 = b'\x03' + b'\x00' * 1536
s.sendall(c1)
s0 = s.recv(1)
assert s0 == b'\x03', f'Expected RTMP version 3, got {s0}'
s.close()
" 2>/dev/null; then
            record_pass "Public RTMP ingest port ${PORT_RTMP} completed RTMP C0/S0 handshake."
        else
            record_fail "Public RTMP ingest port ${PORT_RTMP} failed RTMP handshake."
        fi

        if [ -n "$OBS_KEY" ]; then
            local AUTH_HTTP_CODE
            AUTH_HTTP_CODE=$(docker exec cookie-rtmps-obs curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/auth?name=${OBS_KEY}" 2>/dev/null || echo "000")
            if [ "$AUTH_HTTP_CODE" == "200" ]; then
                record_pass "Stream key /auth endpoint verified (HTTP 200 for configured OBS_KEY)."
            else
                record_fail "Stream key /auth endpoint returned HTTP ${AUTH_HTTP_CODE} instead of 200."
            fi
        fi

        if docker exec cookie-rtmps-obs pgrep -x Xvfb >/dev/null 2>&1; then
            record_pass "Headless virtual display (Xvfb :99) is running."
        else
            record_fail "Xvfb virtual display is not running in 'cookie-rtmps-obs'."
        fi

        if docker exec cookie-rtmps-obs pgrep -x obs >/dev/null 2>&1; then
            record_pass "Lightweight OBS Studio process is running."
        else
            local OBS_ERR_TAIL
            OBS_ERR_TAIL=$(docker exec cookie-rtmps-obs tail -n 5 /tmp/obs.log 2>/dev/null | tr '\n' ' ')
            record_fail "OBS Studio process is not running in 'cookie-rtmps-obs' (${OBS_ERR_TAIL})."
        fi

        if docker exec cookie-rtmps-obs pgrep -f noalbs_controller.py >/dev/null 2>&1; then
            record_pass "NOALBS bitrate monitor & scene switcher is running."
        else
            record_fail "NOALBS controller process is not running in 'cookie-rtmps-obs'."
        fi

        if docker exec cookie-rtmps-obs curl -fsS http://127.0.0.1:8090/stat >/dev/null 2>&1; then
            record_pass "Local Nginx-RTMP /stat endpoint is serving XML telemetry."
        else
            record_fail "Local Nginx-RTMP /stat endpoint failed."
        fi

        if docker exec cookie-rtmps-obs curl -fsS "http://127.0.0.1:8090/brb.html" | grep -q "brbVideo"; then
            record_pass "BRB Browser Source HTML wrapper is serving on 127.0.0.1:8090."
        else
            record_fail "BRB Browser Source HTML wrapper failed to load."
        fi

        if [ -n "$BRB_VIDEO_URL" ]; then
            if curl -fsSIL --max-time 6 "$BRB_VIDEO_URL" >/dev/null 2>&1; then
                record_pass "Remote BRB MP4 URL is reachable (${BRB_VIDEO_URL})."
            else
                record_warn "Remote BRB MP4 URL could not be verified via HEAD request (${BRB_VIDEO_URL})."
            fi
        fi

        # Live OBS WebSocket v5 API & Scene Verification
        local OBS_TEST_OUTPUT
        OBS_TEST_OUTPUT=$(docker exec cookie-rtmps-obs python3 - << 'PY_OBS_TEST' 2>&1
import asyncio
import base64
import hashlib
import json
import os
import urllib.request
import uuid
import xml.etree.ElementTree as ET
import websockets

ws_port = int(os.environ.get("OBS_WS_PORT", "4455"))
ws_pass = os.environ.get("OBS_WS_PASSWORD", "")
scene_live = os.environ.get("OBS_SCENE_LIVE", "main")
scene_brb = os.environ.get("OBS_SCENE_BRB", "brb")
app_name = os.environ.get("APP_NAME", "live")
internal_port = os.environ.get("INTERNAL_RTMP_PORT", "19359")

def is_live_publishing():
    try:
        with urllib.request.urlopen("http://127.0.0.1:8090/stat", timeout=1.5) as resp:
            root = ET.fromstring(resp.read())
        for app in root.findall(".//application"):
            name_el = app.find("name")
            if name_el is not None and name_el.text == app_name:
                for stream in app.findall(".//stream"):
                    if stream.find("publishing") is not None:
                        return True
    except Exception:
        pass
    return False

async def main():
    async with websockets.connect(f"ws://127.0.0.1:{ws_port}", ping_interval=None) as ws:
        hello = json.loads(await ws.recv())
        auth = hello.get("d", {}).get("authentication")
        ident = {"rpcVersion": 1}
        if auth and ws_pass:
            s = base64.b64encode(hashlib.sha256((ws_pass + auth["salt"]).encode()).digest()).decode()
            a = base64.b64encode(hashlib.sha256((s + auth["challenge"]).encode()).digest()).decode()
            ident["authentication"] = a
        await ws.send(json.dumps({"op": 1, "d": ident}))
        res = json.loads(await ws.recv())
        assert res.get("op") == 2, f"Auth failed: {res}"
        print("OK:OBS_WS_AUTH")

        async def call(req, data=None):
            rid = str(uuid.uuid4())
            msg = {"op": 6, "d": {"requestType": req, "requestId": rid}}
            if data is not None:
                msg["d"]["requestData"] = data
            await ws.send(json.dumps(msg))
            while True:
                r = json.loads(await ws.recv())
                if r.get("op") == 7 and r.get("d", {}).get("requestId") == rid:
                    assert r["d"]["requestStatus"]["result"], f"{req} failed: {r}"
                    return r["d"].get("responseData", {})

        scenes_data = await call("GetSceneList")
        scene_names = [s["sceneName"] for s in scenes_data.get("scenes", [])]
        assert scene_live in scene_names, f"Missing live scene '{scene_live}' in {scene_names}"
        assert scene_brb in scene_names, f"Missing brb scene '{scene_brb}' in {scene_names}"
        print(f"OK:SCENES_VERIFIED:{scene_live},{scene_brb}")

        main_items = await call("GetSceneItemList", {"sceneName": scene_live})
        main_sources = [i["sourceName"] for i in main_items.get("sceneItems", [])]
        assert "RTMP_Ingest_Source" in main_sources, f"Missing RTMP_Ingest_Source in {main_sources}"
        print("OK:MAIN_SOURCE_VERIFIED")

        brb_items = await call("GetSceneItemList", {"sceneName": scene_brb})
        brb_sources = [i["sourceName"] for i in brb_items.get("sceneItems", [])]
        assert "BRB_Browser_Source" in brb_sources, f"Missing BRB_Browser_Source in {brb_sources}"
        print("OK:BRB_SOURCE_VERIFIED")

        svc = await call("GetStreamServiceSettings")
        server_url = svc.get("streamServiceSettings", {}).get("server", "")
        assert f":{internal_port}/{app_name}" in server_url, f"Unexpected OBS output server: {server_url}"
        print(f"OK:OBS_OUTPUT_RELAY:{server_url}")

        if not is_live_publishing():
            await call("SetCurrentProgramScene", {"sceneName": scene_brb})
            cur1 = (await call("GetCurrentProgramScene")).get("currentProgramSceneName")
            assert cur1 == scene_brb, f"Expected '{scene_brb}', got '{cur1}'"
            await call("SetCurrentProgramScene", {"sceneName": scene_live})
            cur2 = (await call("GetCurrentProgramScene")).get("currentProgramSceneName")
            assert cur2 == scene_live, f"Expected '{scene_live}', got '{cur2}'"
            print("OK:SCENE_SWITCH_ROUNDTRIP")
        else:
            print("SKIP:LIVE_STREAM_ACTIVE")

asyncio.run(main())
PY_OBS_TEST
        )

        if echo "$OBS_TEST_OUTPUT" | grep -q "OK:OBS_WS_AUTH"; then
            record_pass "OBS WebSocket v5 connected and authenticated on port ${OBS_WS_PORT}."
        else
            record_fail "OBS WebSocket v5 connection failed: ${OBS_TEST_OUTPUT}"
        fi

        if echo "$OBS_TEST_OUTPUT" | grep -q "OK:SCENES_VERIFIED"; then
            record_pass "OBS scenes '${OBS_SCENE_LIVE}' and '${OBS_SCENE_BRB}' verified."
        else
            record_fail "OBS scene verification failed."
        fi

        if echo "$OBS_TEST_OUTPUT" | grep -q "OK:MAIN_SOURCE_VERIFIED"; then
            record_pass "Scene '${OBS_SCENE_LIVE}' contains full-screen RTMP_Ingest_Source."
        else
            record_fail "Scene '${OBS_SCENE_LIVE}' missing RTMP_Ingest_Source."
        fi

        if echo "$OBS_TEST_OUTPUT" | grep -q "OK:BRB_SOURCE_VERIFIED"; then
            record_pass "Scene '${OBS_SCENE_BRB}' contains full-screen BRB_Browser_Source (Loop=${BRB_VIDEO_LOOP}, Timeout=${CLOUD_BRB_TIMEOUT}s)."
        else
            record_fail "Scene '${OBS_SCENE_BRB}' missing BRB_Browser_Source."
        fi

        if echo "$OBS_TEST_OUTPUT" | grep -q "OK:OBS_OUTPUT_RELAY"; then
            record_pass "OBS output target properly chained into CookieRTMPS relay."
        else
            record_fail "OBS output target verification failed."
        fi

        if echo "$OBS_TEST_OUTPUT" | grep -q "OK:SCENE_SWITCH_ROUNDTRIP"; then
            record_pass "OBS WebSocket scene-switch dry-run ('${OBS_SCENE_LIVE}' -> '${OBS_SCENE_BRB}' -> '${OBS_SCENE_LIVE}') succeeded."
        elif echo "$OBS_TEST_OUTPUT" | grep -q "SKIP:LIVE_STREAM_ACTIVE"; then
            record_warn "Skipped live scene-switch test because a live stream is currently active."
        else
            record_fail "OBS WebSocket scene-switch roundtrip failed."
        fi
    else
        record_warn "Disconnection Protection (Lightweight OBS) is DISABLED — enable Option 8 -> 1 to deploy 'cookie-rtmps-obs'."
    fi

    # 4. Run Repository integration_test.sh if present
    if [ -f "./integration_test.sh" ]; then
        echo -e "${CYAN}--- 4. Running Repository integration_test.sh ---${NC}"
        chmod +x ./integration_test.sh
        if ./integration_test.sh; then
            record_pass "Repository ./integration_test.sh completed successfully."
        else
            record_warn "Repository ./integration_test.sh returned non-zero status (check output above)."
        fi
    fi

    echo ""
    echo -e "${GREEN}=================================================${NC}"
    echo -e "  Integration Test Summary: ${GREEN}${PASS_COUNT} Passed${NC}, ${RED}${FAIL_COUNT} Failed${NC}, ${YELLOW}${WARN_COUNT} Warnings${NC}"
    echo -e "${GREEN}=================================================${NC}"

    [ "$FAIL_COUNT" -eq 0 ]
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
    echo "Current Chunk Size: $CHUNK_SIZE (Default: 8192)"
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
        echo -e "${GREEN}Docker is already installed.${NC}"
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
    rm -f ./get-docker.sh ./*.tmp ./*.log ./data/brb_video.mp4 ./data/brb_video.mp4.tmp 2>/dev/null || true

    if [ "$full_wipe" == "true" ]; then
        rm -f "$CONFIG_FILE" 2>/dev/null || true
        rm -rf ./data ./logs ./obs-bridge "$PERSIST_USER_DIR" 2>/dev/null || true
        $SUDO rm -rf "$PERSIST_SYS_DIR" 2>/dev/null || true
    elif [ -d "./data" ]; then
        rm -f ./data/*.tmp ./data/*.log ./data/*.pid ./data/*.sock ./data/*.flv ./data/*.ts ./data/*.m3u8 2>/dev/null || true
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

    echo -e "${YELLOW}Checking and removing old containers, port conflicts, and stale files...${NC}"
    local OLD_CONTAINERS OLD_VOLUMES
    OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -iE 'rtmp|rtmps|cookie|prism|nginx-rtmp' | awk '{print $1}' | sort -u)
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
    if [ "$NOALBS_ENABLED" == "true" ] && [ -z "$BRB_VIDEO_URL" ]; then
        BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
        save_config
    fi

    echo -e "${GREEN}Building CookieRTMPS Docker Image...${NC}"
    DOCKER_BUILDKIT=1 docker build -t cookie-rtmps .

    echo -e "${GREEN}Starting CookieRTMPS container...${NC}"
    docker rm -v -f cookie-rtmps cookie-rtmps-obs 2>/dev/null || true

    # When Disconnection Protection is enabled, cookie-rtmps listens on loopback 127.0.0.1:19359
    # while the Lightweight OBS Bridge receives public/WireGuard RTMP on PORT_RTMP and feeds cookie-rtmps seamlessly.
    local RTMP_PORT_BINDING="${PORT_RTMP}:1935"
    local RELAY_ACCEPTED_IP="$ACCEPTED_IP"
    if [ "$NOALBS_ENABLED" == "true" ]; then
        RTMP_PORT_BINDING="127.0.0.1:${INTERNAL_RTMP_PORT}:1935"
        RELAY_ACCEPTED_IP=""
    fi

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
        -e "OBS_KEY=$OBS_KEY" -e "APP_NAME=$APP_NAME" -e "ACCEPTED_IP=$RELAY_ACCEPTED_IP"
        -e "CHUNK_SIZE=$CHUNK_SIZE" -e "SERVER_DOMAIN=$SERVER_DOMAIN"
        -e "STREAM_BASE_TITLE=" -e "TWITCH_CLIENT_ID=" -e "TWITCH_OAUTH_TOKEN=" -e "TWITCH_BROADCASTER_ID="
        -e "NOALBS_ENABLED=false" -e "FALLBACK_MODE=$FALLBACK_MODE"
        -e "OBS_WS_HOST=$OBS_WS_HOST" -e "OBS_WS_PORT=$OBS_WS_PORT" -e "OBS_WS_PASSWORD=$OBS_WS_PASSWORD"
        -e "OBS_SCENE_LIVE=$OBS_SCENE_LIVE" -e "OBS_SCENE_BRB=$OBS_SCENE_BRB"
        -e "LOW_BITRATE=$LOW_BITRATE" -e "RESTORE_BITRATE=$RESTORE_BITRATE"
        -e "CLOUD_BRB=false" -e "CLOUD_BRB_TIMEOUT=$CLOUD_BRB_TIMEOUT"
    )

    docker run -d --name cookie-rtmps \
        -p "${RTMP_PORT_BINDING}" \
        --restart unless-stopped \
        "${ENV_ARGS[@]}" \
        -v "$(pwd)/data:/app/data" \
        cookie-rtmps

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to start cookie-rtmps container.${NC}"
        echo -e "Press Enter to continue..."
        read -r
        return
    fi

    echo -e "${YELLOW}Waiting for CookieRTMPS services (nginx, stunnel, gunicorn) to initialize...${NC}"
    for _ in $(seq 1 30); do
        if docker exec cookie-rtmps pgrep -f "nginx" >/dev/null 2>&1; then
            break
        fi
        sleep 0.5
    done

    # Ensure multi-IP / WireGuard CIDR whitelist entries are split into separate Nginx directives if running direct mode
    if [ "$NOALBS_ENABLED" != "true" ] && [[ "$ACCEPTED_IP" == *" "* ]]; then
        docker exec cookie-rtmps python3 -c '
import pathlib
p = pathlib.Path("/etc/nginx/nginx.conf")
if p.exists():
    lines = []
    for line in p.read_text().splitlines():
        s = line.strip()
        if s.startswith("allow publish ") and s.endswith(";") and len(s[:-1].split()) > 3:
            indent = line[:len(line) - len(line.lstrip())]
            for ip in s[len("allow publish "):-1].split():
                lines.append(f"{indent}allow publish {ip};")
        else:
            lines.append(line)
    p.write_text("\n".join(lines) + "\n")
' 2>/dev/null || true
        docker exec cookie-rtmps nginx -s reload 2>/dev/null || true
    fi

    if [ "$NOALBS_ENABLED" == "true" ]; then
        echo -e "${GREEN}Building Slimline Lightweight Headless OBS Disconnection Protection Bridge...${NC}"
        generate_lightweight_obs_bridge
        DOCKER_BUILDKIT=1 docker build -t cookie-rtmps-obs ./obs-bridge

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to build Lightweight OBS Bridge image.${NC}"
            echo -e "Press Enter to continue..."
            read -r
            return
        fi

        echo -e "${GREEN}Starting Lightweight Headless OBS container ('${OBS_SCENE_LIVE}' & '${OBS_SCENE_BRB}')...${NC}"
        local OBS_NET_ARGS=()
        local RELAY_HOST_TARGET="127.0.0.1"
        if [ "$(uname -s)" == "Linux" ]; then
            OBS_NET_ARGS=(--network host)
            RELAY_HOST_TARGET="127.0.0.1"
        else
            OBS_NET_ARGS=(-p "${PORT_RTMP}:${PORT_RTMP}" --add-host=host.docker.internal:host-gateway)
            RELAY_HOST_TARGET="host.docker.internal"
        fi

        docker run -d --name cookie-rtmps-obs \
            "${OBS_NET_ARGS[@]}" \
            --shm-size=512m \
            --restart unless-stopped \
            -e "PORT_RTMP=$PORT_RTMP" \
            -e "APP_NAME=$APP_NAME" \
            -e "OBS_KEY=$OBS_KEY" \
            -e "ACCEPTED_IP=$ACCEPTED_IP" \
            -e "CHUNK_SIZE=$CHUNK_SIZE" \
            -e "INTERNAL_RTMP_PORT=$INTERNAL_RTMP_PORT" \
            -e "RELAY_HOST=$RELAY_HOST_TARGET" \
            -e "OBS_WS_HOST=127.0.0.1" \
            -e "OBS_WS_PORT=$OBS_WS_PORT" \
            -e "OBS_WS_PASSWORD=$OBS_WS_PASSWORD" \
            -e "OBS_SCENE_LIVE=$OBS_SCENE_LIVE" \
            -e "OBS_SCENE_BRB=$OBS_SCENE_BRB" \
            -e "LOW_BITRATE=$LOW_BITRATE" \
            -e "RESTORE_BITRATE=$RESTORE_BITRATE" \
            -e "BRB_VIDEO_URL=$BRB_VIDEO_URL" \
            -e "BRB_VIDEO_LOOP=$BRB_VIDEO_LOOP" \
            -e "CLOUD_BRB_TIMEOUT=$CLOUD_BRB_TIMEOUT" \
            -e "OBS_BRIDGE_BITRATE=$OBS_BRIDGE_BITRATE" \
            -v "$(pwd)/data:/app/data" \
            cookie-rtmps-obs

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to start Lightweight OBS Bridge container.${NC}"
            echo -e "Press Enter to continue..."
            read -r
            return
        fi

        echo -e "${YELLOW}Waiting for Lightweight OBS & WebSocket server to initialize...${NC}"
        for _ in $(seq 1 20); do
            if python3 -c "import socket; s=socket.create_connection(('127.0.0.1', int('$PORT_RTMP')), 0.5); s.close()" 2>/dev/null \
               && docker exec cookie-rtmps-obs pgrep -x obs >/dev/null 2>&1; then
                break
            fi
            sleep 0.5
        done
    fi

    local DISPLAY_HOST=${SERVER_DOMAIN:-$(get_server_ip)}
    echo -e "${GREEN}Server is running!${NC}"
    echo -e "You can stream to: rtmp://${DISPLAY_HOST}:${PORT_RTMP}/${APP_NAME}"
    echo -e "Vertical stream:  rtmp://${DISPLAY_HOST}:${PORT_RTMP}/vertical"
    if [ "$NOALBS_ENABLED" == "true" ]; then
        echo -e "${CYAN}Disconnection Protection: ACTIVE${NC}"
        echo -e "  - Main Scene: '${OBS_SCENE_LIVE}' (RTMP Ingest)"
        echo -e "  - BRB Scene:  '${OBS_SCENE_BRB}' (Direct Browser Source MP4: ${BRB_VIDEO_URL}, Loop=${BRB_VIDEO_LOOP})"
        echo -e "  - Trigger:    < ${LOW_BITRATE} kbps -> '${OBS_SCENE_BRB}' | >= ${RESTORE_BITRATE} kbps -> '${OBS_SCENE_LIVE}'"
        echo -e "  - Timeout:    Disconnects stream after ${CLOUD_BRB_TIMEOUT} seconds in BRB"
    else
        echo -e "${YELLOW}Disconnection Protection (Lightweight OBS): DISABLED (Toggle ON in Menu Option 8 -> 1 to enable)${NC}"
    fi

    run_full_integration_tests

    echo -e "Press Enter to continue..."
    read -r
}

view_logs() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed!${NC}"
        sleep 2
        return
    fi

    local TARGET_CONTAINER="cookie-rtmps"
    if docker ps --format '{{.Names}}' | grep -qx "cookie-rtmps-obs"; then
        echo -e "${GREEN}=== Select Log Stream ===${NC}"
        echo "1) CookieRTMPS Relay Logs (cookie-rtmps)"
        echo "2) Lightweight OBS & Disconnection Protection Logs (cookie-rtmps-obs)"
        echo -e "Select an option [1-2]: \c"
        read -r log_target_opt
        [ "$log_target_opt" == "2" ] && TARGET_CONTAINER="cookie-rtmps-obs"
    fi

    echo -e "${YELLOW}Showing live logs for ${TARGET_CONTAINER}...${NC}"
    echo -e "${YELLOW}(Press Ctrl+C to exit log view)${NC}\n"
    (
        trap 'exit 0' INT
        docker logs --since 24h -f "$TARGET_CONTAINER" 2>&1 | awk '
            /GET \/stat HTTP/ { next }
            /ERROR|error|FAIL|fail|REJECTED|disconnect|Disconnect|failed|Failed/ {
                print "\033[0;31m" $0 "\033[0m"
                fflush()
                next
            }
            /WARNING|warning|LOW|low|taking over|Bitrate dropped|timeout/ {
                print "\033[1;33m" $0 "\033[0m"
                fflush()
                next
            }
            /NOALBS|Cloud BRB|Connection restored|Live ingest/ {
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
                docker exec cookie-rtmps sh -c 'truncate -s 0 /var/log/nginx/access.log /var/log/nginx/error.log' 2>/dev/null || true
                for cname in cookie-rtmps cookie-rtmps-obs; do
                    LOG_PATH=$(docker inspect --format='{{.LogPath}}' "$cname" 2>/dev/null)
                    if [ -n "$LOG_PATH" ]; then
                        sudo truncate -s 0 "$LOG_PATH" 2>/dev/null || truncate -s 0 "$LOG_PATH" 2>/dev/null || true
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

    local RAW_PORTS=("$PORT_RTMP" "$INTERNAL_RTMP_PORT" 81 1935 1936 3000 8080 8081 8088 8443 8888 9997 9998 19350 19351 19352 19353 19354 19355 19356 19357 19358 19359)
    local PORTS=()
    for p in "${RAW_PORTS[@]}"; do
        [ -n "$p" ] && ! is_sensitive_port "$p" && PORTS+=("$p")
    done

    if command -v docker &> /dev/null; then
        local active_cids
        active_cids=$(docker ps --format '{{.ID}} {{.Ports}}' | grep -E ":(193[5-6]|808[018]|8443|8888|999[78]|1935[0-9]|${PORT_RTMP})->" | awk '{print $1}' | sort -u || true)
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

    $SUDO pkill -f "tiktok_pusher|noalbs|stream_validator|update_titles|cookie-rtmps|stunnel.*1935|nginx.*rtmp" 2>/dev/null || true
}

stop_and_uninstall() {
    echo -e "${YELLOW}Stopping services, unbinding RTMP ports, and performing deep uninstall & removal...${NC}"

    if command -v docker &> /dev/null; then
        local OLD_CONTAINERS
        OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Names}} {{.Image}} {{.Labels}}' | grep -iE 'rtmp|rtmps|cookie|prism|nginx-rtmp' | awk '{print $1}' | sort -u)
        if [ -n "$OLD_CONTAINERS" ]; then
            docker rm -v -f $OLD_CONTAINERS 2>/dev/null && echo -e "${GREEN}RTMP/RTMPS and OBS containers removed.${NC}" || true
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
            docker rmi -f $OLD_IMAGES 2>/dev/null && echo -e "${GREEN}RTMP/RTMPS and OBS images removed.${NC}" || true
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
    echo -e "${GREEN}CookieRTMPS and all RTMP/RTMPS/OBS components have been completely uninstalled and RTMP ports unbound.${NC}"
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
    if [ "$NOALBS_ENABLED" == "true" ]; then
        echo -e "  OBS Protection:  ${GREEN}ENABLED${NC} ['${OBS_SCENE_LIVE}' <-> '${OBS_SCENE_BRB}' | <${LOW_BITRATE}kbps | Loop:${BRB_VIDEO_LOOP} | Timeout:${CLOUD_BRB_TIMEOUT}s]"
    else
        echo -e "  OBS Protection:  ${RED}DISABLED${NC}"
    fi
    echo "-------------------------------------"
    echo "1) Install Docker (if not installed)"
    echo "2) Configure Stream Keys (Horizontal)"
    echo "3) Configure Stream Keys (Vertical)"
    echo "4) Configure OBS Setup & Security Key"
    echo "5) Configure IP Whitelist (Optional)"
    echo "6) Configure Domain / Reverse Proxy (Optional)"
    echo "7) Configure Optimizations (Chunk Size)"
    echo "8) Configure Disconnection Protection & Lightweight OBS (NOALBS)"
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
        10) run_full_integration_tests; echo -e "Press Enter to continue..."; read -r ;;
        11) stop_and_uninstall ;;
        12) view_logs ;;
        13) clear; echo -e "${GREEN}Goodbye!${NC}"; break ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
