#!/bin/bash
# install.sh - Menu style configuration and installation for CookieRTMPS
# Ensure script is run with bash

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# NOALBS Settings (Disabled by default)
NOALBS_ENABLED="false"
FALLBACK_MODE="video"
OBS_WS_HOST="127.0.0.1"
OBS_WS_PORT="4455"
OBS_WS_PASSWORD=""
OBS_SCENE_LIVE="Main"
OBS_SCENE_BRB="BRB"
LOW_BITRATE="1000"
RESTORE_BITRATE="1500"
CLOUD_BRB="false"
BRB_VIDEO_URL=""
CLOUD_BRB_TIMEOUT="300"

CONFIG_FILE="$SCRIPT_DIR/rtmp_config.env"
PERSIST_USER_DIR="$HOME/.cookie-rtmps"
PERSIST_USER_CONFIG="$PERSIST_USER_DIR/rtmp_config.env"
PERSIST_SYS_DIR="/etc/cookie-rtmps"
PERSIST_SYS_CONFIG="$PERSIST_SYS_DIR/rtmp_config.env"

write_config_to_path() {
    local target_file="$1"
    local target_dir
    target_dir="$(dirname "$target_file")"
    mkdir -p "$target_dir" 2>/dev/null || true
    cat <<ENV_EOF > "$target_file" 2>/dev/null
YOUTUBE_URL="$YOUTUBE_URL"
YOUTUBE_KEY="$YOUTUBE_KEY"
FACEBOOK_URL="$FACEBOOK_URL"
FACEBOOK_KEY="$FACEBOOK_KEY"
INSTAGRAM_URL="$INSTAGRAM_URL"
INSTAGRAM_KEY="$INSTAGRAM_KEY"
TIKTOK_URL="$TIKTOK_URL"
TIKTOK_KEY="$TIKTOK_KEY"
TIKTOK_SL_TOKEN="$TIKTOK_SL_TOKEN"
TIKTOK_TITLE="$TIKTOK_TITLE"
TIKTOK_GAME_ID="$TIKTOK_GAME_ID"
TWITCH_URL="$TWITCH_URL"
TWITCH_KEY="$TWITCH_KEY"
KICK_URL="$KICK_URL"
KICK_KEY="$KICK_KEY"
X_URL="$X_URL"
X_KEY="$X_KEY"
TROVO_URL="$TROVO_URL"
TROVO_KEY="$TROVO_KEY"
RTMP1_URL="$RTMP1_URL"
RTMP1_KEY="$RTMP1_KEY"
V_YOUTUBE_URL="$V_YOUTUBE_URL"
V_YOUTUBE_KEY="$V_YOUTUBE_KEY"
V_TWITCH_URL="$V_TWITCH_URL"
V_TWITCH_KEY="$V_TWITCH_KEY"
V_KICK_URL="$V_KICK_URL"
V_KICK_KEY="$V_KICK_KEY"
V_TIKTOK_URL="$V_TIKTOK_URL"
V_TIKTOK_KEY="$V_TIKTOK_KEY"
V_FACEBOOK_URL="$V_FACEBOOK_URL"
V_FACEBOOK_KEY="$V_FACEBOOK_KEY"
V_INSTAGRAM_URL="$V_INSTAGRAM_URL"
V_INSTAGRAM_KEY="$V_INSTAGRAM_KEY"
V_X_URL="$V_X_URL"
V_X_KEY="$V_X_KEY"
V_TROVO_URL="$V_TROVO_URL"
V_TROVO_KEY="$V_TROVO_KEY"
V_RTMP1_URL="$V_RTMP1_URL"
V_RTMP1_KEY="$V_RTMP1_KEY"
OBS_KEY="$OBS_KEY"
APP_NAME="$APP_NAME"
ACCEPTED_IP="$ACCEPTED_IP"
SERVER_DOMAIN="$SERVER_DOMAIN"
CHUNK_SIZE="$CHUNK_SIZE"
NOALBS_ENABLED="$NOALBS_ENABLED"
FALLBACK_MODE="$FALLBACK_MODE"
OBS_WS_HOST="$OBS_WS_HOST"
OBS_WS_PORT="$OBS_WS_PORT"
OBS_WS_PASSWORD="$OBS_WS_PASSWORD"
OBS_SCENE_LIVE="$OBS_SCENE_LIVE"
OBS_SCENE_BRB="$OBS_SCENE_BRB"
LOW_BITRATE="$LOW_BITRATE"
RESTORE_BITRATE="$RESTORE_BITRATE"
CLOUD_BRB="$CLOUD_BRB"
BRB_VIDEO_URL="$BRB_VIDEO_URL"
CLOUD_BRB_TIMEOUT="$CLOUD_BRB_TIMEOUT"
PORT_RTMP="$PORT_RTMP"
ENV_EOF
}

recover_config_from_container() {
    if ! command -v docker &> /dev/null; then
        return 1
    fi
    local cid
    cid=$(docker ps -a --format '{{.ID}} {{.Names}}' | grep -iE 'cookie-rtmps|rtmp' | head -n 1 | awk '{print $1}')
    if [ -z "$cid" ]; then
        return 1
    fi

    local env_lines
    env_lines=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$cid" 2>/dev/null || true)
    if [ -z "$env_lines" ]; then
        return 1
    fi

    local allowed_vars="YOUTUBE_URL YOUTUBE_KEY FACEBOOK_URL FACEBOOK_KEY INSTAGRAM_URL INSTAGRAM_KEY TIKTOK_URL TIKTOK_KEY TIKTOK_SL_TOKEN TIKTOK_TITLE TIKTOK_GAME_ID TWITCH_URL TWITCH_KEY KICK_URL KICK_KEY X_URL X_KEY TROVO_URL TROVO_KEY RTMP1_URL RTMP1_KEY V_YOUTUBE_URL V_YOUTUBE_KEY V_TWITCH_URL V_TWITCH_KEY V_KICK_URL V_KICK_KEY V_TIKTOK_URL V_TIKTOK_KEY V_FACEBOOK_URL V_FACEBOOK_KEY V_INSTAGRAM_URL V_INSTAGRAM_KEY V_X_URL V_X_KEY V_TROVO_URL V_TROVO_KEY V_RTMP1_URL V_RTMP1_KEY OBS_KEY APP_NAME ACCEPTED_IP SERVER_DOMAIN CHUNK_SIZE FALLBACK_MODE OBS_WS_HOST OBS_WS_PORT OBS_WS_PASSWORD OBS_SCENE_LIVE OBS_SCENE_BRB LOW_BITRATE RESTORE_BITRATE BRB_VIDEO_URL CLOUD_BRB_TIMEOUT"
    local recovered=0
    while IFS='=' read -r k v; do
        if [[ " $allowed_vars " == *" $k "* ]] && [ -n "$v" ]; then
            printf -v "$k" "%s" "$v"
            recovered=1
        fi
    done <<< "$env_lines"

    if [ "$recovered" -eq 1 ]; then
        return 0
    fi
    return 1
}

sync_and_preserve_installation() {
    local found_config=""
    local newest_mtime=0

    # Search local, persistent, parent, and standard installation paths for existing settings
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
        if [ -f "$home_cfg" ]; then
            candidate_configs+=("$home_cfg")
        fi
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
        if [ "$found_config" != "$CONFIG_FILE" ]; then
            cp -f "$found_config" "$CONFIG_FILE" 2>/dev/null || true
        fi
        source "$CONFIG_FILE"
        unset CHAT_TWITCH CHAT_YOUTUBE CHAT_KICK CHAT_TIKTOK STREAM_BASE_TITLE TWITCH_CLIENT_ID TWITCH_OAUTH_TOKEN TWITCH_BROADCASTER_ID PORT_HTTP PORT_STATS
    else
        # Fallback: recover keys/settings from an existing container if folder was freshly cloned
        if recover_config_from_container; then
            write_config_to_path "$CONFIG_FILE"
            found_config="$CONFIG_FILE"
        fi
    fi

    # Replace existing install.sh and updated repo files in any previous installation directory while keeping settings
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
                if [ -f "$SCRIPT_DIR/$repo_item" ]; then
                    cp -f "$SCRIPT_DIR/$repo_item" "$old_dir/$repo_item" 2>/dev/null || true
                fi
            done
            for repo_dir in nginx stunnel cookie-nginx-rtmp noalbs; do
                if [ -d "$SCRIPT_DIR/$repo_dir" ]; then
                    rm -rf "$old_dir/$repo_dir" 2>/dev/null || true
                    cp -rf "$SCRIPT_DIR/$repo_dir" "$old_dir/$repo_dir" 2>/dev/null || true
                fi
            done
            if [ -f "$CONFIG_FILE" ]; then
                cp -f "$CONFIG_FILE" "$old_dir/rtmp_config.env" 2>/dev/null || true
            fi
        fi
    done

    # Persist current settings to local and backup locations so future redeploys retain all menu configurations
    if [ -n "$found_config" ] || [ -f "$CONFIG_FILE" ]; then
        write_config_to_path "$CONFIG_FILE"
        write_config_to_path "$PERSIST_USER_CONFIG"
        if [ "$EUID" -eq 0 ]; then
            write_config_to_path "$PERSIST_SYS_CONFIG"
        elif command -v sudo &> /dev/null; then
            sudo mkdir -p "$PERSIST_SYS_DIR" 2>/dev/null || true
            sudo cp -f "$CONFIG_FILE" "$PERSIST_SYS_CONFIG" 2>/dev/null || true
        fi
    fi
}

sync_and_preserve_installation

save_config() {
    write_config_to_path "$CONFIG_FILE"
    write_config_to_path "$PERSIST_USER_CONFIG"
    if [ "$EUID" -eq 0 ]; then
        write_config_to_path "$PERSIST_SYS_CONFIG"
    elif command -v sudo &> /dev/null; then
        sudo mkdir -p "$PERSIST_SYS_DIR" 2>/dev/null || true
        sudo cp -f "$CONFIG_FILE" "$PERSIST_SYS_CONFIG" 2>/dev/null || true
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
    elif [ ! -z "$input" ]; then
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
                # It is a primary URL, return the corresponding backup URL
                if [[ "$current_url" == *"127.0.0.1"* ]]; then
                    echo "rtmp://127.0.0.1:19357/live2?backup=1"
                else
                    echo "rtmp://b.rtmp.youtube.com/live2?backup=1"
                fi
            else
                # It is a backup URL or something else, return the corresponding primary URL
                if [[ "$current_url" == *"127.0.0.1"* ]]; then
                    echo "rtmp://127.0.0.1:19355/live2/"
                else
                    echo "rtmp://a.rtmp.youtube.com/live2/"
                fi
            fi
            ;;
        "twitch")
            # If it is using the global ingest, switch to US East (Ashburn) as a reliable alternative
            if [[ "$current_url" == *"ingest.global"* ]]; then
                echo "rtmp://use10.contribute.live-video.net/app/"
            else
                # If it is using a regional ingest, switch to the global ingest
                echo "rtmp://ingest.global-contribute.live-video.net/app/"
            fi
            ;;
        "kick")
            # If it is using standard/secure, switch to the South Africa relay as an alternative
            if [[ "$current_url" == *"live.kick.com"* ]] || [[ "$current_url" == *"127.0.0.1:19356"* ]]; then
                echo "rtmp://kick.cisp.co.za/live"
            else
                # Otherwise switch to the secure global endpoint
                echo "rtmp://127.0.0.1:19356/kick/"
            fi
            ;;
        *)
            echo "$current_url"
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
                      if [ ! -z "$y_url" ]; then
                          YOUTUBE_URL="$y_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            2)
               prompt_for_key "Twitch Key" "TWITCH_KEY"
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
               echo -e "Option (Current URL: $TWITCH_URL): \c"
               read -r t_opt
               case $t_opt in
                   1) TWITCH_URL="rtmp://ingest.global-contribute.live-video.net/app/" ;;
                   2) TWITCH_URL="rtmp://127.0.0.1:19353/app/" ;;
                   3) TWITCH_URL="rtmp://use10.contribute.live-video.net/app/" ;;
                   4) TWITCH_URL="rtmp://use20.contribute.live-video.net/app/" ;;
                   5) TWITCH_URL="rtmp://usw20.contribute.live-video.net/app/" ;;
                   6) TWITCH_URL="rtmp://euw10.contribute.live-video.net/app/" ;;
                   7) TWITCH_URL="rtmp://euc10.contribute.live-video.net/app/" ;;
                   8) TWITCH_URL="rtmp://euw30.contribute.live-video.net/app/" ;;
                   9) TWITCH_URL="rtmp://eun10.contribute.live-video.net/app/" ;;
                   10) TWITCH_URL="rtmp://apn10.contribute.live-video.net/app/" ;;
                   11) TWITCH_URL="rtmp://apn20.contribute.live-video.net/app/" ;;
                   12) TWITCH_URL="rtmp://aps10.contribute.live-video.net/app/" ;;
                   13) TWITCH_URL="rtmp://aps20.contribute.live-video.net/app/" ;;
                   14) TWITCH_URL="rtmp://aps30.contribute.live-video.net/app/" ;;
                   15) TWITCH_URL="rtmp://sae10.contribute.live-video.net/app/" ;;
                   16)
                      echo -e "Enter Custom Twitch Server URL: "
                      read -r t_url
                      if [ ! -z "$t_url" ]; then
                          TWITCH_URL="$t_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            3)
               prompt_for_key "Kick" "KICK_KEY"
               echo -e "Select Kick Server:"
               echo "  1) Standard (rtmp://live.kick.com/app/)"
               echo "  2) Secure (rtmps://fa723fc1b171.global-contribute.live-video.net:443 -> via Stunnel)"
               echo "  3) South Africa Relay (rtmp://kick.cisp.co.za/live)"
               echo "  4) Custom URL"
               echo -e "Option (Current URL: $KICK_URL): \c"
               read -r k_opt
               case $k_opt in
                   1) KICK_URL="rtmp://live.kick.com/app/" ;;
                   2) KICK_URL="rtmp://127.0.0.1:19356/kick/" ;;
                   3) KICK_URL="rtmp://kick.cisp.co.za/live" ;;
                   4)
                      echo -e "Enter Custom Kick Server URL: "
                      read -r k_url
                      if [ ! -z "$k_url" ]; then
                          KICK_URL="$k_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            4)
               prompt_for_key "TikTok" "TIKTOK_KEY"
               echo -e "Select TikTok Server:"
               echo "  1) Secure (rtmps://push.tiktok.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo "  3) Streamlabs Auto-Pusher (Bypass TikTok Studio)"
               echo -e "Option (Current URL: $TIKTOK_URL): \c"
               read -r tt_opt
               case $tt_opt in
                   1) TIKTOK_URL="rtmp://127.0.0.1:19358/s_v/" ;;
                   2)
                      echo -e "Enter Custom TikTok Server URL: "
                      read -r tt_url
                      if [ ! -z "$tt_url" ]; then
                          TIKTOK_URL="$tt_url"
                      fi
                      ;;
                   3)
                      TIKTOK_URL="auto"
                      echo -e "Enter Streamlabs Token: \c"
                      read -r TIKTOK_SL_TOKEN
                      echo -e "Enter Stream Title: \c"
                      read -r TIKTOK_TITLE
                      echo -e "Enter Game ID (Optional): \c"
                      read -r TIKTOK_GAME_ID
                      ;;
               esac
               save_config
               ;;
            5)
               prompt_for_key "Facebook" "FACEBOOK_KEY"
               echo -e "Select Facebook Server:"
               echo "  1) Secure (rtmps://live-api-s.facebook.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $FACEBOOK_URL): \c"
               read -r f_opt
               case $f_opt in
                   1) FACEBOOK_URL="rtmp://127.0.0.1:19350/rtmp/" ;;
                   2)
                      echo -e "Enter Custom Facebook Server URL: "
                      read -r f_url
                      if [ ! -z "$f_url" ]; then
                          FACEBOOK_URL="$f_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            6)
               prompt_for_key "Instagram" "INSTAGRAM_KEY"
               echo -e "Select Instagram Server:"
               echo "  1) Secure (rtmps://live-upload.instagram.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $INSTAGRAM_URL): \c"
               read -r i_opt
               case $i_opt in
                   1) INSTAGRAM_URL="rtmp://127.0.0.1:19351/rtmp/" ;;
                   2)
                      echo -e "Enter Custom Instagram Server URL: "
                      read -r i_url
                      if [ ! -z "$i_url" ]; then
                          INSTAGRAM_URL="$i_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            7)
               prompt_for_key "X (Twitter)" "X_KEY"
               echo -e "Select X Server:"
               echo "  1) Secure (rtmps://va.pscp.tv:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $X_URL): \c"
               read -r x_opt
               case $x_opt in
                   1) X_URL="rtmp://127.0.0.1:19354/x/" ;;
                   2)
                      echo -e "Enter Custom X Server URL: "
                      read -r x_url
                      if [ ! -z "$x_url" ]; then
                          X_URL="$x_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            8)
               prompt_for_key "Trovo" "TROVO_KEY"
               echo -e "Select Trovo Server:"
               echo "  1) Primary (rtmp://livepush.trovo.live/live/)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $TROVO_URL): \c"
               read -r tr_opt
               case $tr_opt in
                   1) TROVO_URL="rtmp://livepush.trovo.live/live/" ;;
                   2)
                      echo -e "Enter Custom Trovo Server URL: "
                      read -r tr_url
                      if [ ! -z "$tr_url" ]; then
                          TROVO_URL="$tr_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            9)
               echo -e "Enter Custom RTMP Server URL (Current: $RTMP1_URL): "
               read -r c_url
               if [ ! -z "$c_url" ]; then
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
                      if [ ! -z "$y_url" ]; then
                          V_YOUTUBE_URL="$y_url"
                      fi
                      ;;
               esac
               if [ "$V_YOUTUBE_URL" == "$YOUTUBE_URL" ]; then
                   echo -e "${YELLOW}Warning: Same ingest server as Horizontal. Switching to alternative...${NC}"
                   V_YOUTUBE_URL=$(get_alternative_url "youtube" "$V_YOUTUBE_URL")
                   echo -e "New Vertical URL: $V_YOUTUBE_URL"
                   sleep 2
               fi
               save_config
               ;;
            2)
               prompt_for_key "Twitch Vertical Key" "V_TWITCH_KEY"
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
               echo -e "Option (Current URL: $V_TWITCH_URL): \c"
               read -r t_opt
               case $t_opt in
                   1) V_TWITCH_URL="rtmp://ingest.global-contribute.live-video.net/app/" ;;
                   2) V_TWITCH_URL="rtmp://127.0.0.1:19353/app/" ;;
                   3) V_TWITCH_URL="rtmp://use10.contribute.live-video.net/app/" ;;
                   4) V_TWITCH_URL="rtmp://use20.contribute.live-video.net/app/" ;;
                   5) V_TWITCH_URL="rtmp://usw20.contribute.live-video.net/app/" ;;
                   6) V_TWITCH_URL="rtmp://euw10.contribute.live-video.net/app/" ;;
                   7) V_TWITCH_URL="rtmp://euc10.contribute.live-video.net/app/" ;;
                   8) V_TWITCH_URL="rtmp://euw30.contribute.live-video.net/app/" ;;
                   9) V_TWITCH_URL="rtmp://eun10.contribute.live-video.net/app/" ;;
                   10) V_TWITCH_URL="rtmp://apn10.contribute.live-video.net/app/" ;;
                   11) V_TWITCH_URL="rtmp://apn20.contribute.live-video.net/app/" ;;
                   12) V_TWITCH_URL="rtmp://aps10.contribute.live-video.net/app/" ;;
                   13) V_TWITCH_URL="rtmp://aps20.contribute.live-video.net/app/" ;;
                   14) V_TWITCH_URL="rtmp://aps30.contribute.live-video.net/app/" ;;
                   15) V_TWITCH_URL="rtmp://sae10.contribute.live-video.net/app/" ;;
                   16)
                      echo -e "Enter Custom Twitch Server URL: "
                      read -r t_url
                      if [ ! -z "$t_url" ]; then
                          V_TWITCH_URL="$t_url"
                      fi
                      ;;
               esac
               if [ "$V_TWITCH_URL" == "$TWITCH_URL" ]; then
                   echo -e "${YELLOW}Warning: Same ingest server as Horizontal. Switching to alternative...${NC}"
                   V_TWITCH_URL=$(get_alternative_url "twitch" "$V_TWITCH_URL")
                   echo -e "New Vertical URL: $V_TWITCH_URL"
                   sleep 2
               fi
               save_config
               ;;
            3)
               prompt_for_key "Kick Vertical Key" "V_KICK_KEY"
               echo -e "Select Kick Server:"
               echo "  1) Standard (rtmp://live.kick.com/app/)"
               echo "  2) Secure (rtmps://fa723fc1b171.global-contribute.live-video.net:443 -> via Stunnel)"
               echo "  3) South Africa Relay (rtmp://kick.cisp.co.za/live)"
               echo "  4) Custom URL"
               echo -e "Option (Current URL: $V_KICK_URL): \c"
               read -r k_opt
               case $k_opt in
                   1) V_KICK_URL="rtmp://live.kick.com/app/" ;;
                   2) V_KICK_URL="rtmp://127.0.0.1:19356/kick/" ;;
                   3) V_KICK_URL="rtmp://kick.cisp.co.za/live" ;;
                   4)
                      echo -e "Enter Custom Kick Server URL: "
                      read -r k_url
                      if [ ! -z "$k_url" ]; then
                          V_KICK_URL="$k_url"
                      fi
                      ;;
               esac
               if [ "$V_KICK_URL" == "$KICK_URL" ]; then
                   echo -e "${YELLOW}Warning: Same ingest server as Horizontal. Switching to alternative...${NC}"
                   V_KICK_URL=$(get_alternative_url "kick" "$V_KICK_URL")
                   echo -e "New Vertical URL: $V_KICK_URL"
                   sleep 2
               fi
               save_config
               ;;
            4)
               prompt_for_key "TikTok Vertical Key" "V_TIKTOK_KEY"
               echo -e "Select TikTok Server:"
               echo "  1) Secure (rtmps://push.tiktok.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo "  3) Streamlabs Auto-Pusher (Bypass TikTok Studio)"
               echo -e "Option (Current URL: $V_TIKTOK_URL): \c"
               read -r tt_opt
               case $tt_opt in
                   1) V_TIKTOK_URL="rtmp://127.0.0.1:19358/s_v/" ;;
                   2)
                      echo -e "Enter Custom TikTok Server URL: "
                      read -r tt_url
                      if [ ! -z "$tt_url" ]; then
                          V_TIKTOK_URL="$tt_url"
                      fi
                      ;;
                   3)
                      V_TIKTOK_URL="auto"
                      echo -e "Enter Streamlabs Token: \c"
                      read -r TIKTOK_SL_TOKEN
                      echo -e "Enter Stream Title: \c"
                      read -r TIKTOK_TITLE
                      echo -e "Enter Game ID (Optional): \c"
                      read -r TIKTOK_GAME_ID
                      ;;
               esac
               save_config
               ;;
            5)
               prompt_for_key "Facebook Vertical Key" "V_FACEBOOK_KEY"
               echo -e "Select Facebook Server:"
               echo "  1) Secure (rtmps://live-api-s.facebook.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $V_FACEBOOK_URL): \c"
               read -r f_opt
               case $f_opt in
                   1) V_FACEBOOK_URL="rtmp://127.0.0.1:19350/rtmp/" ;;
                   2)
                      echo -e "Enter Custom Facebook Server URL: "
                      read -r f_url
                      if [ ! -z "$f_url" ]; then
                          V_FACEBOOK_URL="$f_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            6)
               prompt_for_key "Instagram Vertical Key" "V_INSTAGRAM_KEY"
               echo -e "Select Instagram Server:"
               echo "  1) Secure (rtmps://live-upload.instagram.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $V_INSTAGRAM_URL): \c"
               read -r i_opt
               case $i_opt in
                   1) V_INSTAGRAM_URL="rtmp://127.0.0.1:19351/rtmp/" ;;
                   2)
                      echo -e "Enter Custom Instagram Server URL: "
                      read -r i_url
                      if [ ! -z "$i_url" ]; then
                          V_INSTAGRAM_URL="$i_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            7)
               prompt_for_key "X Vertical Key" "V_X_KEY"
               echo -e "Select X Server:"
               echo "  1) Secure (rtmps://va.pscp.tv:443 -> via Stunnel)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $V_X_URL): \c"
               read -r x_opt
               case $x_opt in
                   1) V_X_URL="rtmp://127.0.0.1:19354/x/" ;;
                   2)
                      echo -e "Enter Custom X Server URL: "
                      read -r x_url
                      if [ ! -z "$x_url" ]; then
                          V_X_URL="$x_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            8)
               prompt_for_key "Trovo Vertical Key" "V_TROVO_KEY"
               echo -e "Select Trovo Server:"
               echo "  1) Primary (rtmp://livepush.trovo.live/live/)"
               echo "  2) Custom URL"
               echo -e "Option (Current URL: $V_TROVO_URL): \c"
               read -r tr_opt
               case $tr_opt in
                   1) V_TROVO_URL="rtmp://livepush.trovo.live/live/" ;;
                   2)
                      echo -e "Enter Custom Trovo Server URL: "
                      read -r tr_url
                      if [ ! -z "$tr_url" ]; then
                          V_TROVO_URL="$tr_url"
                      fi
                      ;;
               esac
               save_config
               ;;
            9)
               echo -e "Enter Custom RTMP Vertical Server URL (Current: $V_RTMP1_URL): "
               read -r c_url
               if [ ! -z "$c_url" ]; then
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
    # Determine the public IP if possible, or fallback to placeholder
    SERVER_IP=$(curl -4 -s ifconfig.me || echo "<your_server_ip>")

    # Use Domain if set, otherwise IP
    DISPLAY_HOST=${SERVER_DOMAIN:-$SERVER_IP}

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
    elif [ ! -z "$obs_input" ]; then
        OBS_KEY="$obs_input"
        echo -e "${GREEN}Custom OBS Key updated.${NC}"
    fi

    echo ""
    echo -e "--- Custom Application Name ---"
    echo -e "Current Path: /${APP_NAME}"
    echo -e "Enter new RTMP Path/Application name (e.g. cookies):"
    echo -e "(Leave blank to keep current):"
    read -r app_input
    if [ ! -z "$app_input" ]; then
        # Basic sanitization: remove everything except alphanumeric
        app_input=$(echo "$app_input" | sed 's/[^a-zA-Z0-9]//g')
        if [ ! -z "$app_input" ]; then
            APP_NAME="$app_input"
            echo -e "${GREEN}Application name updated to: $APP_NAME${NC}"
        else
             echo -e "${RED}Invalid application name. Keeping current: $APP_NAME${NC}"
        fi
    fi

    save_config
    sleep 2
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
    elif [ ! -z "$dom_input" ]; then
        # Basic sanitization for domain
        dom_input=$(echo "$dom_input" | sed 's/[^a-zA-Z0-9.-]//g')
        if [ ! -z "$dom_input" ]; then
            SERVER_DOMAIN="$dom_input"
            echo -e "${GREEN}Domain updated to: $SERVER_DOMAIN${NC}"
            echo -e "${YELLOW}Note: If using Cloudflare, ensure the record is 'DNS Only' (Grey Cloud).${NC}"
        else
            echo -e "${RED}Invalid domain name. Keeping current.${NC}"
        fi
    fi
    save_config
    sleep 2
}

configure_whitelist() {
    while true; do
        clear
        echo -e "${GREEN}=== IP Whitelist Configuration ===${NC}"
        echo -e "Current Accepted IP: ${YELLOW}${ACCEPTED_IP:-None (Allow All)}${NC}"
        echo ""
        echo "1) Server's IP Address (For those who proxy, VPN or Wireguard Into the Server)"
        echo "2) Manual IP Address"
        echo "3) Clear IP Address"
        echo "4) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r wl_opt

        case $wl_opt in
            1)
                SERVER_IP_FETCH=$(curl -4 -s ifconfig.me || echo "")
                if [ ! -z "$SERVER_IP_FETCH" ]; then
                    ACCEPTED_IP="$SERVER_IP_FETCH"
                    echo -e "${GREEN}IP Whitelist updated to server IP: $ACCEPTED_IP${NC}"
                else
                    echo -e "${RED}Failed to fetch server IP.${NC}"
                fi
                save_config
                sleep 2
                ;;
            2)
                echo -e "Enter IP address to whitelist: \c"
                read -r ip_input
                if [ ! -z "$ip_input" ]; then
                    ACCEPTED_IP="$ip_input"
                    echo -e "${GREEN}IP Whitelist updated to: $ACCEPTED_IP${NC}"
                    save_config
                fi
                sleep 2
                ;;
            3)
                ACCEPTED_IP=""
                echo -e "${GREEN}IP Whitelist disabled. All IPs allowed.${NC}"
                save_config
                sleep 2
                ;;
            4|"")
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

ensure_brb_video_transcoded() {
    local url="${1:-$BRB_VIDEO_URL}"
    local target="./data/brb_video.mp4"
    if [ -z "$url" ]; then
        url="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
    fi
    mkdir -p ./data
    rm -f "$target"
    echo -e "${YELLOW}Downloading BRB video from $url ...${NC}"
    curl -L "$url" -o "${target}.tmp"
    if [ -f "${target}.tmp" ] && [ -s "${target}.tmp" ]; then
        if command -v ffmpeg &> /dev/null; then
            echo -e "${YELLOW}Transcoding BRB video with FFmpeg to ensure AAC audio and H.264 video compatibility...${NC}"

            local duration=""
            if command -v ffprobe &> /dev/null; then
                duration=$(ffprobe -v error -show_entries format=duration -of default=noprintwrappers=1:nokey=1 "${target}.tmp" 2>/dev/null || true)
            fi
            if [ -z "$duration" ] || [ "$(awk -v d="$duration" 'BEGIN { print (d > 0) ? 1 : 0 }' 2>/dev/null)" -ne 1 ]; then
                local dur_str
                dur_str=$(ffmpeg -i "${target}.tmp" 2>&1 | grep "Duration" | awk '{print $2}' | tr -d ',')
                if [ -n "$dur_str" ]; then
                    duration=$(echo "$dur_str" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
                fi
            fi

            ffmpeg -y -hide_banner -loglevel warning -i "${target}.tmp" -c:v libx264 -pix_fmt yuv420p -g 60 -c:a aac -ar 48000 -ac 2 -progress pipe:1 "$target" 2>/dev/null | while read -r line; do
                if [[ "$line" == out_time_us=* ]]; then
                    local us="${line#*=}"
                    if [[ "$us" =~ ^[0-9]+$ ]] && [ -n "$duration" ]; then
                        local pct
                        pct=$(awk -v us="$us" -v dur="$duration" 'BEGIN { if (dur>0) { p=(us/1000000/dur)*100; if (p>100) p=100; printf "%.1f", p } else { print "0.0" } }')
                        local filled
                        filled=$(awk -v pct="$pct" 'BEGIN { printf "%d", (pct * 30 / 100) }')
                        local unfilled=$((30 - filled))
                        local bar=""
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
                echo -e "${GREEN}BRB video successfully downloaded and transcoded.${NC}"
                rm -f "${target}.tmp"
            else
                echo -e "${YELLOW}FFmpeg transcode warning. Using downloaded file directly.${NC}"
                mv "${target}.tmp" "$target"
            fi
        else
            mv "${target}.tmp" "$target"
        fi
    else
        echo -e "${RED}Download failed.${NC}"
        rm -f "${target}.tmp"
    fi
}

configure_noalbs() {
    while true; do
        clear
        echo -e "${GREEN}=== NOALBS Scene Switcher Configuration ===${NC}"
        echo -e "Status: $([ "$NOALBS_ENABLED" == "true" ] && echo -e "${GREEN}ENABLED${NC}" || echo -e "${RED}DISABLED${NC}")"
        echo ""
        echo "1) Toggle Enabled (Currently: $NOALBS_ENABLED)"
        echo "2) Primary Fallback Mode (Current: ${FALLBACK_MODE:-video} [video = MP4, obs = OBS Scene Switch])"
        echo "3) OBS WebSocket Host (Current: $OBS_WS_HOST)"
        echo "4) OBS WebSocket Port (Current: $OBS_WS_PORT)"
        echo "5) OBS WebSocket Password (Current: ${OBS_WS_PASSWORD:-(None)})"
        echo "6) Main/Live Scene Name (Current: $OBS_SCENE_LIVE)"
        echo "7) BRB Scene Name (Current: $OBS_SCENE_BRB)"
        echo "8) Low Bitrate Threshold (Current: $LOW_BITRATE kbps)"
        echo "9) Restore Bitrate Threshold (Current: $RESTORE_BITRATE kbps)"
        echo "10) Toggle Cloud BRB (Currently: $CLOUD_BRB)"
        echo "11) Configure BRB Video URL (Current: ${BRB_VIDEO_URL:-(None)})"
        echo "12) Disconnection Protection Duration (Current: ${CLOUD_BRB_TIMEOUT} seconds)"
        echo "13) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r noalbs_opt

        case $noalbs_opt in
            1)
                if [ "$NOALBS_ENABLED" == "true" ]; then NOALBS_ENABLED="false"; else NOALBS_ENABLED="true"; fi
                save_config
                ;;
            2)
                if [ "$FALLBACK_MODE" == "obs" ]; then
                    FALLBACK_MODE="video"
                else
                    FALLBACK_MODE="obs"
                fi
                echo -e "${GREEN}Primary Fallback Mode switched to: $FALLBACK_MODE${NC}"
                save_config
                sleep 1
                ;;
            3)
                echo -e "Enter OBS WebSocket Host (e.g. 192.168.1.50 or host.docker.internal):"
                read -r input
                if [ ! -z "$input" ]; then OBS_WS_HOST="$input"; save_config; fi
                ;;
            4)
                echo -e "Enter OBS WebSocket Port (Default: 4455):"
                read -r input
                if [ ! -z "$input" ]; then OBS_WS_PORT="$input"; save_config; fi
                ;;
            5)
                echo -e "Enter OBS WebSocket Password:"
                read -r input
                OBS_WS_PASSWORD="$input"
                save_config
                ;;
            6)
                echo -e "Enter OBS Main Scene Name (e.g. 'Main' or 'Streaming'):"
                read -r input
                if [ ! -z "$input" ]; then OBS_SCENE_LIVE="$input"; save_config; fi
                ;;
            7)
                echo -e "Enter OBS BRB Scene Name (e.g. 'BRB' or 'LowBitrate'):"
                read -r input
                if [ ! -z "$input" ]; then OBS_SCENE_BRB="$input"; save_config; fi
                ;;
            8)
                echo -e "Enter Low Bitrate Threshold in kbps (e.g. 1000):"
                read -r input
                if [ ! -z "$input" ]; then LOW_BITRATE="$input"; save_config; fi
                ;;
            9)
                echo -e "Enter Restore Bitrate Threshold in kbps (e.g. 1500):"
                read -r input
                if [ ! -z "$input" ]; then RESTORE_BITRATE="$input"; save_config; fi
                ;;
            10)
                if [ "$CLOUD_BRB" == "true" ]; then CLOUD_BRB="false"; else CLOUD_BRB="true"; fi
                save_config
                ;;
            11)
                echo -e "Enter BRB Video URL (Direct MP4 link, or type 'disable'/'clear' to remove):"
                read -r input
                if [ "$input" == "disable" ] || [ "$input" == "clear" ] || [ "$input" == "DISABLE" ] || [ "$input" == "CLEAR" ]; then
                    BRB_VIDEO_URL=""
                    save_config
                    rm -f ./data/brb_video.mp4 ./data/brb_video.mp4.tmp
                    echo -e "${GREEN}Cleared BRB Video URL and removed cached video.${NC}"
                    sleep 1
                elif [ ! -z "$input" ]; then
                    BRB_VIDEO_URL="$input"
                    save_config
                    if [ "$NOALBS_ENABLED" == "true" ] && [ "$CLOUD_BRB" == "true" ]; then
                        ensure_brb_video_transcoded "$BRB_VIDEO_URL"
                    fi
                    sleep 2
                fi
                ;;
            12)
                echo -e "Enter Disconnection Video Protection Duration in seconds (e.g. 300):"
                read -r input
                if [ ! -z "$input" ]; then
                    CLOUD_BRB_TIMEOUT="$input"
                    save_config
                    echo -e "${GREEN}Disconnection protection duration updated to $CLOUD_BRB_TIMEOUT seconds.${NC}"
                    sleep 1
                fi
                ;;
            13) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ;;
        esac
    done
}

enable_bbr_and_tcp_optimizations() {
    echo -e "${GREEN}Configuring Google BBR & Network TCP Buffer Optimizations...${NC}"
    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
        SUDO="sudo"
    else
        SUDO=""
    fi

    $SUDO modprobe tcp_bbr 2>/dev/null || true

    SYSCTL_CONF="/etc/sysctl.d/99-stream-optimization.conf"
    echo -e "${YELLOW}Writing sysctl network tuning parameters to $SYSCTL_CONF ...${NC}"

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
    if [ ! -z "$input" ]; then
        CHUNK_SIZE="$input"
        save_config
        echo -e "${GREEN}Chunk size updated.${NC}"
    fi

    echo -e "\nApplying Google BBR and TCP optimizations..."
    enable_bbr_and_tcp_optimizations
    sleep 2
}

install_docker() {
    echo -e "${GREEN}Checking for Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Installing...${NC}"
        # Basic docker install via official script
        curl -4 -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo systemctl start docker
        sudo systemctl enable docker
        rm -f get-docker.sh
        echo -e "${GREEN}Docker installed successfully.${NC}"
    else
        echo -e "${GREEN}Docker is already installed.${NC}"
    fi
    sleep 2
}

is_sensitive_port() {
    local port=$1
    case "$port" in
        20|21|22|25|53|67|68|80|110|123|143|443|465|587|993|995|3306|5432|6379|27017)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        ss -tuln | grep -qE ":${port}(\s|$)"
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep -qE ":${port}(\s|$)"
    else
        return 1 # Cannot check
    fi
}

cleanup_old_rtmp_files() {
    local full_wipe=${1:-false}
    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
        SUDO="sudo"
    else
        SUDO=""
    fi

    echo -e "${YELLOW}Cleaning up old RTMP temporary and cache files...${NC}"
    rm -f ./get-docker.sh ./*.tmp ./*.log 2>/dev/null || true

    if [ "$full_wipe" == "true" ]; then
        rm -f "$CONFIG_FILE" 2>/dev/null || true
        rm -rf ./data ./logs "$PERSIST_USER_DIR" 2>/dev/null || true
        $SUDO rm -rf "$PERSIST_SYS_DIR" 2>/dev/null || true
    else
        if [ -d "./data" ]; then
            rm -f ./data/*.tmp ./data/*.log ./data/*.pid ./data/*.sock ./data/*.flv ./data/*.ts ./data/*.m3u8 2>/dev/null || true
            if [ "$NOALBS_ENABLED" != "true" ] || [ "$CLOUD_BRB" != "true" ]; then
                rm -f ./data/brb_video.mp4 ./data/brb_video.mp4.tmp 2>/dev/null || true
            fi
        fi
    fi

    # Deep remove temp and cache artifacts across system temp/cache directories
    for base_dir in /tmp /var/tmp /var/run /var/cache /dev/shm; do
        if [ -d "$base_dir" ]; then
            $SUDO find "$base_dir" -maxdepth 3 \( \
                -iname "*rtmp*" -o \
                -iname "*rtmps*" -o \
                -iname "*cookie-rtmp*" -o \
                -iname "*cookiertmp*" -o \
                -iname "*brb_video*" -o \
                -iname "*noalbs*" -o \
                -iname "*stream_validator*" -o \
                -iname "*tiktok_pusher*" -o \
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
    OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -iE 'rtmp|rtmps|cookie|prism|nginx-rtmp' | awk '{print $1}' | sort -u)
    if [ ! -z "$OLD_CONTAINERS" ]; then
        docker stop $OLD_CONTAINERS 2>/dev/null || true
        docker rm -v -f $OLD_CONTAINERS 2>/dev/null || true
    fi
    OLD_VOLUMES=$(docker volume ls -q | grep -iE 'rtmp|rtmps|cookie|prism' || true)
    if [ ! -z "$OLD_VOLUMES" ]; then
        docker volume rm -f $OLD_VOLUMES 2>/dev/null || true
    fi
    docker image prune -f 2>/dev/null || true

    # Clear non-sensitive RTMP port conflicts and stale files before building
    deep_cleanup_ports_and_processes
    cleanup_old_rtmp_files "false"

    enable_bbr_and_tcp_optimizations

    echo -e "${YELLOW}Verifying target RTMP port is clear (excluding sensitive ports 80, 443, etc.)...${NC}"
    CONFLICTS=0
    declare -a PORTS_TO_CHECK=("$PORT_RTMP")

    for port in "${PORTS_TO_CHECK[@]}"; do
        if is_sensitive_port "$port"; then
            continue
        fi
        if check_port "$port"; then
            echo -e "${RED}Warning: Port $port appears to be in use on the host!${NC}"
            echo -e "${YELLOW}If this is another service, CookieRTMPS may fail to start.${NC}"
            CONFLICTS=1
        fi
    done

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

    # Auto-fill vertical from horizontal if horizontal is set but vertical is not (YouTube, Twitch, TikTok, Kick)
    # Automatically chooses an alternative ingest server to avoid conflicts
    if [ ! -z "$YOUTUBE_KEY" ] && [ -z "$V_YOUTUBE_KEY" ]; then
        V_YOUTUBE_KEY="$YOUTUBE_KEY"
        V_YOUTUBE_URL=$(get_alternative_url "youtube" "$YOUTUBE_URL")
    fi
    if [ ! -z "$TWITCH_KEY" ] && [ -z "$V_TWITCH_KEY" ]; then
        V_TWITCH_KEY="$TWITCH_KEY"
        V_TWITCH_URL=$(get_alternative_url "twitch" "$TWITCH_URL")
    fi
    if [ ! -z "$KICK_KEY" ] && [ -z "$V_KICK_KEY" ]; then
        V_KICK_KEY="$KICK_KEY"
        V_KICK_URL=$(get_alternative_url "kick" "$KICK_URL")
    fi

    # Hard Enforcement: Always ensure horizontal and vertical ingest URLs are different for YT, Twitch, Kick
    if [ ! -z "$YOUTUBE_KEY" ] && [ "$YOUTUBE_URL" == "$V_YOUTUBE_URL" ]; then
        V_YOUTUBE_URL=$(get_alternative_url "youtube" "$V_YOUTUBE_URL")
    fi
    if [ ! -z "$TWITCH_KEY" ] && [ "$TWITCH_URL" == "$V_TWITCH_URL" ]; then
        V_TWITCH_URL=$(get_alternative_url "twitch" "$V_TWITCH_URL")
    fi
    if [ ! -z "$KICK_KEY" ] && [ "$KICK_URL" == "$V_KICK_URL" ]; then
        V_KICK_URL=$(get_alternative_url "kick" "$V_KICK_URL")
    fi

    if [ ! -z "$TIKTOK_KEY" ] && [ -z "$V_TIKTOK_KEY" ]; then
        V_TIKTOK_KEY="$TIKTOK_KEY"
        V_TIKTOK_URL="$TIKTOK_URL"
    fi

    # Check if any keys are set
    ANY_KEY_SET=0
    for key in "$YOUTUBE_KEY" "$FACEBOOK_KEY" "$INSTAGRAM_KEY" "$TIKTOK_KEY" "$TWITCH_KEY" "$KICK_KEY" "$X_KEY" "$TROVO_KEY" "$RTMP1_KEY" \
               "$V_YOUTUBE_KEY" "$V_TWITCH_KEY" "$V_KICK_KEY" "$V_TIKTOK_KEY" "$V_FACEBOOK_KEY" "$V_INSTAGRAM_KEY" "$V_X_KEY" "$V_TROVO_KEY" "$V_RTMP1_KEY"; do
        if [ ! -z "$key" ]; then
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
    if [ "$NOALBS_ENABLED" == "true" ] && [ "$CLOUD_BRB" == "true" ]; then
        if [ -f "./data/brb_video.mp4" ] && [ -s "./data/brb_video.mp4" ]; then
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

    echo -e "${GREEN}Building Docker Image...${NC}"
    docker build -t cookie-rtmps .

    echo -e "${GREEN}Stopping any existing container...${NC}"
    docker stop cookie-rtmps 2>/dev/null || true
    docker rm -v -f cookie-rtmps 2>/dev/null || true

    echo -e "${GREEN}Starting container...${NC}"

    # Expose only RTMP port on host (no web/HTML/stats ports exposed)
    PORT_MAPS="-p ${PORT_RTMP}:1935"

    # Start the container (pass empty defaults for internal validator env vars so on_publish always works)
    docker run -d --name cookie-rtmps \
        $PORT_MAPS \
        --restart unless-stopped \
        -e YOUTUBE_URL="$YOUTUBE_URL" \
        -e YOUTUBE_KEY="$YOUTUBE_KEY" \
        -e FACEBOOK_URL="$FACEBOOK_URL" \
        -e FACEBOOK_KEY="$FACEBOOK_KEY" \
        -e INSTAGRAM_URL="$INSTAGRAM_URL" \
        -e INSTAGRAM_KEY="$INSTAGRAM_KEY" \
        -e TIKTOK_URL="$TIKTOK_URL" \
        -e TIKTOK_KEY="$TIKTOK_KEY" \
        -e TIKTOK_SL_TOKEN="$TIKTOK_SL_TOKEN" \
        -e TIKTOK_TITLE="$TIKTOK_TITLE" \
        -e TIKTOK_GAME_ID="$TIKTOK_GAME_ID" \
        -e TWITCH_URL="$TWITCH_URL" \
        -e TWITCH_KEY="$TWITCH_KEY" \
        -e KICK_URL="$KICK_URL" \
        -e KICK_KEY="$KICK_KEY" \
        -e X_URL="$X_URL" \
        -e X_KEY="$X_KEY" \
        -e TROVO_URL="$TROVO_URL" \
        -e TROVO_KEY="$TROVO_KEY" \
        -e RTMP1_URL="$RTMP1_URL" \
        -e RTMP1_KEY="$RTMP1_KEY" \
        -e V_YOUTUBE_URL="$V_YOUTUBE_URL" \
        -e V_YOUTUBE_KEY="$V_YOUTUBE_KEY" \
        -e V_TWITCH_URL="$V_TWITCH_URL" \
        -e V_TWITCH_KEY="$V_TWITCH_KEY" \
        -e V_KICK_URL="$V_KICK_URL" \
        -e V_KICK_KEY="$V_KICK_KEY" \
        -e V_TIKTOK_URL="$V_TIKTOK_URL" \
        -e V_TIKTOK_KEY="$V_TIKTOK_KEY" \
        -e V_FACEBOOK_URL="$V_FACEBOOK_URL" \
        -e V_FACEBOOK_KEY="$V_FACEBOOK_KEY" \
        -e V_INSTAGRAM_URL="$V_INSTAGRAM_URL" \
        -e V_INSTAGRAM_KEY="$V_INSTAGRAM_KEY" \
        -e V_X_URL="$V_X_URL" \
        -e V_X_KEY="$V_X_KEY" \
        -e V_TROVO_URL="$V_TROVO_URL" \
        -e V_TROVO_KEY="$V_TROVO_KEY" \
        -e V_RTMP1_URL="$V_RTMP1_URL" \
        -e V_RTMP1_KEY="$V_RTMP1_KEY" \
        -e OBS_KEY="$OBS_KEY" \
        -e APP_NAME="$APP_NAME" \
        -e ACCEPTED_IP="$ACCEPTED_IP" \
        -e CHUNK_SIZE="$CHUNK_SIZE" \
        -e STREAM_BASE_TITLE="" \
        -e TWITCH_CLIENT_ID="" \
        -e TWITCH_OAUTH_TOKEN="" \
        -e TWITCH_BROADCASTER_ID="" \
        -e SERVER_DOMAIN="$SERVER_DOMAIN" \
        -e NOALBS_ENABLED="$NOALBS_ENABLED" \
        -e FALLBACK_MODE="$FALLBACK_MODE" \
        -e OBS_WS_HOST="$OBS_WS_HOST" \
        -e OBS_WS_PORT="$OBS_WS_PORT" \
        -e OBS_WS_PASSWORD="$OBS_WS_PASSWORD" \
        -e OBS_SCENE_LIVE="$OBS_SCENE_LIVE" \
        -e OBS_SCENE_BRB="$OBS_SCENE_BRB" \
        -e LOW_BITRATE="$LOW_BITRATE" \
        -e RESTORE_BITRATE="$RESTORE_BITRATE" \
        -e CLOUD_BRB="$CLOUD_BRB" \
        -e CLOUD_BRB_TIMEOUT="$CLOUD_BRB_TIMEOUT" \
        -v "$(pwd)/data:/app/data" \
        cookie-rtmps

    if [ $? -eq 0 ]; then
        SERVER_IP=$(curl -4 -s ifconfig.me || echo "<your_server_ip>")
        DISPLAY_HOST=${SERVER_DOMAIN:-$SERVER_IP}
        echo -e "${GREEN}Container 'cookie-rtmps' is running!${NC}"
        echo -e "You can stream to: rtmp://${DISPLAY_HOST}:${PORT_RTMP}/${APP_NAME}"
        echo -e "Vertical stream:  rtmp://${DISPLAY_HOST}:${PORT_RTMP}/vertical"

        echo -e "${YELLOW}Resetting services and running integration tests...${NC}"
        docker restart cookie-rtmps
        sleep 3

        # Run Integration Tests
        if [ -f "./integration_test.sh" ]; then
            chmod +x ./integration_test.sh
            ./integration_test.sh
        fi
    else
        echo -e "${RED}Failed to start container.${NC}"
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

    echo -e "${YELLOW}Showing live logs for cookie-rtmps...${NC}"
    echo -e "${YELLOW}(Press Ctrl+C to exit log view)${NC}\n"
    # Use a subshell and trap INT to ensure script doesn't exit on Ctrl+C
    (
        trap 'exit 0' INT
        docker logs --since 24h -f cookie-rtmps 2>&1 | awk '
            /GET \/stat HTTP/ { next }
            /ERROR|error|FAIL|fail|REJECTED|disconnect|Disconnect|failed|Failed/ {
                print "\033[0;31m" $0 "\033[0m"
                fflush()
                next
            }
            /WARNING|warning|LOW|low|taking over/ {
                print "\033[1;33m" $0 "\033[0m"
                fflush()
                next
            }
            /NOALBS|Cloud BRB/ {
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
                # Truncate internal logs
                docker exec cookie-rtmps sh -c 'truncate -s 0 /var/log/nginx/access.log /var/log/nginx/error.log' 2>/dev/null || true
                # Truncate Docker's own log file for the container
                LOG_PATH=$(docker inspect --format='{{.LogPath}}' cookie-rtmps 2>/dev/null)
                if [ ! -z "$LOG_PATH" ]; then
                    sudo truncate -s 0 "$LOG_PATH" 2>/dev/null || truncate -s 0 "$LOG_PATH" 2>/dev/null || echo -e "${RED}Failed to truncate Docker log file. You may need sudo.${NC}"
                fi
                echo -e "${GREEN}Logs cleared.${NC}"
                sleep 1
                ;;
            *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ;;
        esac
    done
}

deep_cleanup_ports_and_processes() {
    echo -e "${YELLOW}Cleaning up RTMP processes and unbinding RTMP/web ports (excluding sensitive ports 80, 443, 22, 53, etc.)...${NC}"
    if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
        SUDO="sudo"
    else
        SUDO=""
    fi

    local RAW_PORTS=("$PORT_RTMP" 81 1935 1936 8080 8081 8088 8443 8888 9997 9998 19350 19351 19352 19353 19354 19355 19356 19357 19358 19359)
    local PORTS=()
    for p in "${RAW_PORTS[@]}"; do
        if [ -n "$p" ] && ! is_sensitive_port "$p"; then
            PORTS+=("$p")
        fi
    done

    # Find and stop any docker containers publishing non-sensitive RTMP/web application ports
    if command -v docker &> /dev/null; then
        for port in "${PORTS[@]}"; do
            local cids
            cids=$(docker ps -q --filter "publish=$port" 2>/dev/null || true)
            if [ -n "$cids" ]; then
                docker stop $cids 2>/dev/null || true
                docker rm -v -f $cids 2>/dev/null || true
            fi
        done
    fi

    for port in "${PORTS[@]}"; do
        if command -v fuser &> /dev/null; then
            $SUDO fuser -k -9 "${port}/tcp" 2>/dev/null || true
            $SUDO fuser -k -9 "${port}/udp" 2>/dev/null || true
        fi
        if command -v lsof &> /dev/null; then
            local pids
            pids=$($SUDO lsof -t -i :"$port" 2>/dev/null || true)
            if [ -n "$pids" ]; then
                $SUDO kill -9 $pids 2>/dev/null || true
            fi
        fi
        if command -v ss &> /dev/null; then
            local pids
            pids=$($SUDO ss -lptn "sport = :$port" 2>/dev/null | grep -oP 'pid=\K\d+' | sort -u || true)
            if [ -n "$pids" ]; then
                $SUDO kill -9 $pids 2>/dev/null || true
            fi
        fi
    done

    # Terminate any leftover RTMP/RTMPS host processes without touching host web servers on ports 80/443
    $SUDO pkill -f "tiktok_pusher" 2>/dev/null || true
    $SUDO pkill -f "noalbs" 2>/dev/null || true
    $SUDO pkill -f "stream_validator" 2>/dev/null || true
    $SUDO pkill -f "update_titles" 2>/dev/null || true
    $SUDO pkill -f "cookie-rtmps" 2>/dev/null || true
    $SUDO pkill -f "stunnel.*1935" 2>/dev/null || true
    $SUDO pkill -f "nginx.*rtmp" 2>/dev/null || true
}

stop_and_uninstall() {
    echo -e "${YELLOW}Stopping services, unbinding RTMP ports, and performing deep uninstall & removal...${NC}"

    if command -v docker &> /dev/null; then
        # Deep search all containers (running or stopped) mentioning RTMP, RTMPS, cookie, or prism
        OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Names}} {{.Image}} {{.Labels}}' | grep -iE 'rtmp|rtmps|cookie|prism|nginx-rtmp' | awk '{print $1}' | sort -u)
        if [ ! -z "$OLD_CONTAINERS" ]; then
            docker stop $OLD_CONTAINERS 2>/dev/null && echo -e "${GREEN}RTMP/RTMPS containers stopped.${NC}" || true
            docker rm -v -f $OLD_CONTAINERS 2>/dev/null && echo -e "${GREEN}RTMP/RTMPS containers and volumes removed.${NC}" || true
        else
            docker stop cookie-rtmps 2>/dev/null || true
            docker rm -v -f cookie-rtmps 2>/dev/null || true
        fi
    fi

    echo -e "${YELLOW}Unbinding RTMP-related ports (excluding sensitive ports 80, 443, etc.) and stopping RTMP processes...${NC}"
    deep_cleanup_ports_and_processes

    if command -v docker &> /dev/null; then
        OLD_VOLUMES=$(docker volume ls -q | grep -iE 'rtmp|rtmps|cookie|prism' || true)
        if [ ! -z "$OLD_VOLUMES" ]; then
            docker volume rm -f $OLD_VOLUMES 2>/dev/null && echo -e "${GREEN}Matching Docker volumes removed.${NC}" || true
        fi

        OLD_NETWORKS=$(docker network ls --format '{{.ID}} {{.Name}}' | grep -iE 'rtmp|rtmps|cookie|prism' | awk '{print $1}' || true)
        if [ ! -z "$OLD_NETWORKS" ]; then
            docker network rm $OLD_NETWORKS 2>/dev/null && echo -e "${GREEN}Matching Docker networks removed.${NC}" || true
        fi

        OLD_IMAGES=$(docker images --format '{{.ID}} {{.Repository}} {{.Tag}}' | grep -iE 'rtmp|rtmps|cookie|prism' | awk '{print $1}' | sort -u)
        if [ ! -z "$OLD_IMAGES" ]; then
            docker rmi -f $OLD_IMAGES 2>/dev/null && echo -e "${GREEN}RTMP/RTMPS images removed.${NC}" || true
        else
            docker rmi -f cookie-rtmps 2>/dev/null || true
        fi

        echo -e "${YELLOW}Pruning Docker build cache, volumes, networks, and unused images...${NC}"
        docker volume prune -f 2>/dev/null || true
        docker network prune -f 2>/dev/null || true
        docker image prune -a -f 2>/dev/null || true
        docker builder prune -a -f 2>/dev/null || true
        docker system prune -a -f 2>/dev/null || true
    fi

    echo -e "${YELLOW}Deep cleaning all local configuration, temp files, and cache files...${NC}"
    cleanup_old_rtmp_files "true"
    echo -e "${GREEN}Local configuration, temp files, and data cache removed.${NC}"

    echo -e "${GREEN}CookieRTMPS and all RTMP/RTMPS components have been completely uninstalled and RTMP ports unbound.${NC}"
    sleep 3
}

# Cache Server IP for UI Performance
SERVER_IP=$(curl -4 -s ifconfig.me || echo "<your_server_ip>")

while true; do
    clear
    DISPLAY_HOST=${SERVER_DOMAIN:-$SERVER_IP}
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}     CookieRTMPS Quick Installer      ${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${YELLOW}Quick Reference:${NC}"
    echo -e "  RTMP Ingest:     rtmp://${DISPLAY_HOST}:${PORT_RTMP}/${APP_NAME}"
    echo -e "  Vertical Ingest: rtmp://${DISPLAY_HOST}:${PORT_RTMP}/vertical"
    echo "-------------------------------------"
    echo "1) Install Docker (if not installed)"
    echo "2) Configure Stream Keys (Horizontal)"
    echo "3) Configure Stream Keys (Vertical)"
    echo "4) Configure OBS Setup & Security Key"
    echo "5) Configure IP Whitelist (Optional)"
    echo "6) Configure Domain / Reverse Proxy (Optional)"
    echo "7) Configure Optimizations (Chunk Size)"
    echo "8) Configure NOALBS Scene Switcher"
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
        10) if [ -f "./integration_test.sh" ]; then chmod +x ./integration_test.sh; ./integration_test.sh; else echo -e "${RED}Test script not found.${NC}"; fi; echo -e "Press Enter to continue..."; read -r ;;
        11) stop_and_uninstall ;;
        12) view_logs ;;
        13) clear; echo -e "${GREEN}Goodbye!${NC}"; break ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
