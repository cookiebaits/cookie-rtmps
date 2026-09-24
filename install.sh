#!/bin/bash
# install.sh - Menu style configuration and installation for CookieRTMPS
# Ensure script is run with bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
YOUTUBE_URL="rtmp://x.rtmp.youtube.com/live2/"
YOUTUBE_KEY=""
FACEBOOK_URL="rtmp://127.0.0.1:19350/rtmp/"
FACEBOOK_KEY=""
INSTAGRAM_URL="rtmp://127.0.0.1:19351/rtmp/"
INSTAGRAM_KEY=""
TIKTOK_URL="rtmp://127.0.0.1:19358/s_v/"
TIKTOK_KEY=""
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
V_YOUTUBE_URL="rtmp://x.rtmp.youtube.com/live2/"
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
STREAM_BASE_TITLE="Live Stream"
TWITCH_CLIENT_ID=""
TWITCH_OAUTH_TOKEN=""
TWITCH_BROADCASTER_ID=""

# Combined Chat Settings
CHAT_TWITCH=""
CHAT_YOUTUBE=""
CHAT_KICK=""
CHAT_TIKTOK=""

# Host Port Settings
PORT_RTMP="1935"
PORT_HTTP="8443"
PORT_STATS="8081"

# NOALBS Settings
NOALBS_ENABLED="true"
OBS_WS_HOST="127.0.0.1"
OBS_WS_PORT="4455"
OBS_WS_PASSWORD=""
OBS_SCENE_LIVE="Main"
OBS_SCENE_BRB="BRB"
LOW_BITRATE="1000"
RESTORE_BITRATE="1500"
CLOUD_BRB="true"
BRB_VIDEO_URL=""

CONFIG_FILE="rtmp_config.env"

# Load saved configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

save_config() {
    cat <<ENV_EOF > "$CONFIG_FILE"
YOUTUBE_URL="$YOUTUBE_URL"
YOUTUBE_KEY="$YOUTUBE_KEY"
FACEBOOK_URL="$FACEBOOK_URL"
FACEBOOK_KEY="$FACEBOOK_KEY"
INSTAGRAM_URL="$INSTAGRAM_URL"
INSTAGRAM_KEY="$INSTAGRAM_KEY"
TIKTOK_URL="$TIKTOK_URL"
TIKTOK_KEY="$TIKTOK_KEY"
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
CHAT_TWITCH="$CHAT_TWITCH"
CHAT_YOUTUBE="$CHAT_YOUTUBE"
CHAT_KICK="$CHAT_KICK"
CHAT_TIKTOK="$CHAT_TIKTOK"
SERVER_DOMAIN="$SERVER_DOMAIN"
CHUNK_SIZE="$CHUNK_SIZE"
STREAM_BASE_TITLE="$STREAM_BASE_TITLE"
TWITCH_CLIENT_ID="$TWITCH_CLIENT_ID"
TWITCH_OAUTH_TOKEN="$TWITCH_OAUTH_TOKEN"
TWITCH_BROADCASTER_ID="$TWITCH_BROADCASTER_ID"
NOALBS_ENABLED="$NOALBS_ENABLED"
OBS_WS_HOST="$OBS_WS_HOST"
OBS_WS_PORT="$OBS_WS_PORT"
OBS_WS_PASSWORD="$OBS_WS_PASSWORD"
OBS_SCENE_LIVE="$OBS_SCENE_LIVE"
OBS_SCENE_BRB="$OBS_SCENE_BRB"
LOW_BITRATE="$LOW_BITRATE"
RESTORE_BITRATE="$RESTORE_BITRATE"
CLOUD_BRB="$CLOUD_BRB"
BRB_VIDEO_URL="$BRB_VIDEO_URL"
PORT_RTMP="$PORT_RTMP"
PORT_HTTP="$PORT_HTTP"
PORT_STATS="$PORT_STATS"
ENV_EOF
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
            if [[ "$current_url" == *"x.rtmp.youtube.com"* ]] || [[ "$current_url" == *"127.0.0.1:19355"* ]]; then
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
                    echo "rtmp://x.rtmp.youtube.com/live2/"
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
               echo "  1) Primary (rtmp://x.rtmp.youtube.com/live2/)"
               echo "  2) Backup (rtmp://b.rtmp.youtube.com/live2?backup=1)"
               echo "  3) Secure Primary (rtmps://a.rtmps.youtube.com/live2/ -> via Stunnel)"
               echo "  4) Secure Backup (rtmps://b.rtmps.youtube.com/live2?backup=1 -> via Stunnel)"
               echo "  5) Custom URL"
               echo -e "Option (Current URL: $YOUTUBE_URL): \c"
               read -r y_opt
               case $y_opt in
                   1) YOUTUBE_URL="rtmp://x.rtmp.youtube.com/live2/" ;;
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
               echo "  9) Asia: Tokyo (rtmp://apn10.contribute.live-video.net/app/)"
               echo "  10) Asia: Seoul (rtmp://apn20.contribute.live-video.net/app/)"
               echo "  11) Asia: Singapore (rtmp://aps10.contribute.live-video.net/app/)"
               echo "  12) Asia: Sydney (rtmp://aps20.contribute.live-video.net/app/)"
               echo "  13) South America: Brazil (rtmp://sae10.contribute.live-video.net/app/)"
               echo "  14) Custom URL"
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
                   9) TWITCH_URL="rtmp://apn10.contribute.live-video.net/app/" ;;
                   10) TWITCH_URL="rtmp://apn20.contribute.live-video.net/app/" ;;
                   11) TWITCH_URL="rtmp://aps10.contribute.live-video.net/app/" ;;
                   12) TWITCH_URL="rtmp://aps20.contribute.live-video.net/app/" ;;
                   13) TWITCH_URL="rtmp://sae10.contribute.live-video.net/app/" ;;
                   14)
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
               echo "  1) Secure (rtmps://push-rtmp-f5-ap-southeast-1.tiktokcdn.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
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
               echo "  1) Primary (rtmp://x.rtmp.youtube.com/live2/)"
               echo "  2) Secure Primary (rtmps://a.rtmps.youtube.com/live2/ -> via Stunnel)"
               echo "  3) Custom URL"
               echo -e "Option (Current URL: $V_YOUTUBE_URL): \c"
               read -r y_opt
               case $y_opt in
                   1) V_YOUTUBE_URL="rtmp://x.rtmp.youtube.com/live2/" ;;
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
               echo "  9) Asia: Tokyo (rtmp://apn10.contribute.live-video.net/app/)"
               echo "  10) Asia: Seoul (rtmp://apn20.contribute.live-video.net/app/)"
               echo "  11) Asia: Singapore (rtmp://aps10.contribute.live-video.net/app/)"
               echo "  12) Asia: Sydney (rtmp://aps20.contribute.live-video.net/app/)"
               echo "  13) South America: Brazil (rtmp://sae10.contribute.live-video.net/app/)"
               echo "  14) Custom URL"
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
                   9) V_TWITCH_URL="rtmp://apn10.contribute.live-video.net/app/" ;;
                   10) V_TWITCH_URL="rtmp://apn20.contribute.live-video.net/app/" ;;
                   11) V_TWITCH_URL="rtmp://aps10.contribute.live-video.net/app/" ;;
                   12) V_TWITCH_URL="rtmp://aps20.contribute.live-video.net/app/" ;;
                   13) V_TWITCH_URL="rtmp://sae10.contribute.live-video.net/app/" ;;
                   14)
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
               echo "  1) Secure (rtmps://push-rtmp-f5-ap-southeast-1.tiktokcdn.com:443 -> via Stunnel)"
               echo "  2) Custom URL"
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
    echo -e "--- Combined Chat ---"
    echo -e "You can use the combined chat as a browser source in OBS:"
    echo -e "  ${YELLOW}URL:${NC} http://${DISPLAY_HOST}/chat.html?twitch=YOUR_CHANNEL&youtube=YOUR_VIDEO_ID"
    echo -e "  (Replace YOUR_CHANNEL and YOUR_VIDEO_ID as needed)"
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

configure_titles() {
    while true; do
        clear
        echo -e "${GREEN}=== Stream Titles & Twitch API Configuration ===${NC}"
        echo "1) Base Title (Current: $STREAM_BASE_TITLE)"
        echo "2) Twitch Client ID (Current: ${TWITCH_CLIENT_ID:-None})"
        echo "3) Twitch OAuth Token (Current: ${TWITCH_OAUTH_TOKEN:-None})"
        echo "4) Twitch Broadcaster ID (Current: ${TWITCH_BROADCASTER_ID:-None})"
        echo "5) Reset Episode Count"
        echo "6) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r title_opt

        case $title_opt in
            1)
                echo -e "Enter Base Stream Title:"
                read -r title_input
                STREAM_BASE_TITLE="$title_input"
                save_config
                ;;
            2)
                echo -e "Enter Twitch Client ID:"
                read -r title_input
                TWITCH_CLIENT_ID="$title_input"
                save_config
                ;;
            3)
                echo -e "Enter Twitch OAuth Token (Bearer):"
                read -r title_input
                TWITCH_OAUTH_TOKEN="$title_input"
                save_config
                ;;
            4)
                echo -e "Enter Twitch Broadcaster ID (Numeric):"
                read -r title_input
                TWITCH_BROADCASTER_ID="$title_input"
                save_config
                ;;
            5)
                mkdir -p ./data
                echo "1" > ./data/episode_count.txt
                echo -e "${GREEN}Episode count reset to 1.${NC}"
                sleep 1
                ;;
            6) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ;;
        esac
    done
}

configure_chat() {
    while true; do
        clear
        echo -e "${GREEN}=== Combined Chat Configuration ===${NC}"
        echo "Enter Channel Names/IDs for browser source embeds:"
        echo ""
        echo "1) Twitch Channel (Current: ${CHAT_TWITCH:-None})"
        echo "2) YouTube Video ID (Current: ${CHAT_YOUTUBE:-None})"
        echo "3) Kick Channel (Current: ${CHAT_KICK:-None})"
        echo "4) TikTok Channel (Current: ${CHAT_TIKTOK:-None})"
        echo "5) Show Browser Source URL"
        echo "6) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r chat_opt

        case $chat_opt in
            1)
                echo -e "Enter Twitch Channel Name:"
                read -r chat_input
                CHAT_TWITCH="$chat_input"
                save_config
                ;;
            2)
                echo -e "Enter YouTube Video ID (from URL v=XXXX):"
                read -r chat_input
                CHAT_YOUTUBE="$chat_input"
                save_config
                ;;
            3)
                echo -e "Enter Kick Channel Name:"
                read -r chat_input
                CHAT_KICK="$chat_input"
                save_config
                ;;
            4)
                echo -e "Enter TikTok Username (without @):"
                read -r chat_input
                CHAT_TIKTOK="$chat_input"
                save_config
                ;;
            5)
                SERVER_IP=$(curl -4 -s ifconfig.me || echo "<your_server_ip>")
                DISPLAY_HOST=${SERVER_DOMAIN:-$SERVER_IP}
                CHAT_URL="http://${DISPLAY_HOST}/chat.html?"
                if [ ! -z "$CHAT_TWITCH" ]; then CHAT_URL="${CHAT_URL}twitch=${CHAT_TWITCH}&"; fi
                if [ ! -z "$CHAT_YOUTUBE" ]; then CHAT_URL="${CHAT_URL}youtube=${CHAT_YOUTUBE}&"; fi
                if [ ! -z "$CHAT_KICK" ]; then CHAT_URL="${CHAT_URL}kick=${CHAT_KICK}&"; fi
                if [ ! -z "$CHAT_TIKTOK" ]; then CHAT_URL="${CHAT_URL}tiktok=${CHAT_TIKTOK}&"; fi
                echo -e "\n${YELLOW}OBS Browser Source URL:${NC}"
                echo -e "${GREEN}${CHAT_URL%&}${NC}"
                echo -e "\nPress Enter to continue..."
                read -r
                ;;
            6) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ;;
        esac
    done
}

configure_noalbs() {
    while true; do
        clear
        echo -e "${GREEN}=== NOALBS Scene Switcher Configuration ===${NC}"
        echo -e "Status: $([ "$NOALBS_ENABLED" == "true" ] && echo -e "${GREEN}ENABLED${NC}" || echo -e "${RED}DISABLED${NC}")"
        echo ""
        echo "1) Toggle Enabled (Currently: $NOALBS_ENABLED)"
        echo "2) OBS WebSocket Host (Current: $OBS_WS_HOST)"
        echo "3) OBS WebSocket Port (Current: $OBS_WS_PORT)"
        echo "4) OBS WebSocket Password (Current: ${OBS_WS_PASSWORD:-(None)})"
        echo "5) Main/Live Scene Name (Current: $OBS_SCENE_LIVE)"
        echo "6) BRB Scene Name (Current: $OBS_SCENE_BRB)"
        echo "7) Low Bitrate Threshold (Current: $LOW_BITRATE kbps)"
        echo "8) Restore Bitrate Threshold (Current: $RESTORE_BITRATE kbps)"
        echo "9) Toggle Cloud BRB (Currently: $CLOUD_BRB)"
        echo "10) Configure BRB Video URL (Current: ${BRB_VIDEO_URL:-(None)})"
        echo "11) Back to Main Menu"
        echo -e "Select an option: \c"
        read -r noalbs_opt

        case $noalbs_opt in
            1)
                if [ "$NOALBS_ENABLED" == "true" ]; then NOALBS_ENABLED="false"; else NOALBS_ENABLED="true"; fi
                save_config
                ;;
            2)
                echo -e "Enter OBS WebSocket Host (e.g. 192.168.1.50 or host.docker.internal):"
                read -r input
                if [ ! -z "$input" ]; then OBS_WS_HOST="$input"; save_config; fi
                ;;
            3)
                echo -e "Enter OBS WebSocket Port (Default: 4455):"
                read -r input
                if [ ! -z "$input" ]; then OBS_WS_PORT="$input"; save_config; fi
                ;;
            4)
                echo -e "Enter OBS WebSocket Password:"
                read -r input
                OBS_WS_PASSWORD="$input"
                save_config
                ;;
            5)
                echo -e "Enter OBS Main Scene Name (e.g. 'Main' or 'Streaming'):"
                read -r input
                if [ ! -z "$input" ]; then OBS_SCENE_LIVE="$input"; save_config; fi
                ;;
            6)
                echo -e "Enter OBS BRB Scene Name (e.g. 'BRB' or 'LowBitrate'):"
                read -r input
                if [ ! -z "$input" ]; then OBS_SCENE_BRB="$input"; save_config; fi
                ;;
            7)
                echo -e "Enter Low Bitrate Threshold in kbps (e.g. 1000):"
                read -r input
                if [ ! -z "$input" ]; then LOW_BITRATE="$input"; save_config; fi
                ;;
            8)
                echo -e "Enter Restore Bitrate Threshold in kbps (e.g. 1500):"
                read -r input
                if [ ! -z "$input" ]; then RESTORE_BITRATE="$input"; save_config; fi
                ;;
            9)
                if [ "$CLOUD_BRB" == "true" ]; then CLOUD_BRB="false"; else CLOUD_BRB="true"; fi
                save_config
                ;;
            10)
                echo -e "Enter BRB Video URL (Direct MP4 link):"
                read -r input
                if [ ! -z "$input" ]; then
                    BRB_VIDEO_URL="$input"
                    save_config
                    mkdir -p ./data
                    echo -e "${YELLOW}Downloading BRB video...${NC}"
                    curl -L "$BRB_VIDEO_URL" -o ./data/brb_video.mp4 && echo -e "${GREEN}Downloaded.${NC}" || echo -e "${RED}Download failed.${NC}"
                    sleep 2
                fi
                ;;
            11) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ;;
        esac
    done
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
        sleep 1
    fi
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
        rm get-docker.sh
        echo -e "${GREEN}Docker installed successfully.${NC}"
    else
        echo -e "${GREEN}Docker is already installed.${NC}"
    fi
    sleep 2
}

check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        ss -tuln | grep -q ":$port "
    elif command -v netstat &> /dev/null; then
        netstat -tuln | grep -q ":$port "
    else
        return 1 # Cannot check
    fi
}

build_and_run() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed! Please run 'Install Docker' first.${NC}"
        sleep 2
        return
    fi

    echo -e "${YELLOW}Stopping and removing any old rtmps instances...${NC}"
    OLD_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Names}}' | grep -i rtmps | awk '{print $1}')
    if [ ! -z "$OLD_CONTAINERS" ]; then
        docker stop $OLD_CONTAINERS 2>/dev/null || true
        docker rm $OLD_CONTAINERS 2>/dev/null || true
    fi
    OLD_IMAGES=$(docker images --format '{{.ID}} {{.Repository}}' | grep -i rtmps | awk '{print $1}')
    if [ ! -z "$OLD_IMAGES" ]; then
        docker rmi -f $OLD_IMAGES 2>/dev/null || true
    fi

    echo -e "${YELLOW}Checking for port conflicts...${NC}"
    CONFLICTS=0
    declare -a PORTS_TO_CHECK=("$PORT_RTMP")
    if [ ! -z "$SERVER_DOMAIN" ]; then
        PORTS_TO_CHECK+=("$PORT_HTTP")
    fi

    for port in "${PORTS_TO_CHECK[@]}"; do
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

    if [ "$CLOUD_BRB" == "true" ] && [ -z "$BRB_VIDEO_URL" ]; then
        echo -e "${YELLOW}Cloud BRB is enabled but BRB Video URL is empty. Setting to default...${NC}"
        BRB_VIDEO_URL="https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4"
        save_config
        mkdir -p ./data
        rm -f ./data/brb_video.mp4
        echo -e "${YELLOW}Downloading default BRB video...${NC}"
        curl -L "$BRB_VIDEO_URL" -o ./data/brb_video.mp4 && echo -e "${GREEN}Downloaded default BRB video.${NC}" || echo -e "${RED}Failed to download BRB video.${NC}"
    fi

    echo -e "${GREEN}Building Docker Image...${NC}"
    docker build -t cookie-rtmps .

    echo -e "${GREEN}Stopping any existing container...${NC}"
    docker stop cookie-rtmps 2>/dev/null || true
    docker rm cookie-rtmps 2>/dev/null || true

    echo -e "${GREEN}Starting container...${NC}"

    # Port mapping logic: Map HTTP/HTTPS only if domain is set
    PORT_MAPS="-p ${PORT_RTMP}:1935"
    if [ ! -z "$SERVER_DOMAIN" ]; then
        PORT_MAPS="$PORT_MAPS -p ${PORT_HTTP}:80"
    fi

    # Start the container
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
        -e STREAM_BASE_TITLE="$STREAM_BASE_TITLE" \
        -e TWITCH_CLIENT_ID="$TWITCH_CLIENT_ID" \
        -e TWITCH_OAUTH_TOKEN="$TWITCH_OAUTH_TOKEN" \
        -e TWITCH_BROADCASTER_ID="$TWITCH_BROADCASTER_ID" \
        -e SERVER_DOMAIN="$SERVER_DOMAIN" \
        -e NOALBS_ENABLED="$NOALBS_ENABLED" \
        -e OBS_WS_HOST="$OBS_WS_HOST" \
        -e OBS_WS_PORT="$OBS_WS_PORT" \
        -e OBS_WS_PASSWORD="$OBS_WS_PASSWORD" \
        -e OBS_SCENE_LIVE="$OBS_SCENE_LIVE" \
        -e OBS_SCENE_BRB="$OBS_SCENE_BRB" \
        -e LOW_BITRATE="$LOW_BITRATE" \
        -e RESTORE_BITRATE="$RESTORE_BITRATE" \
        -e CLOUD_BRB="$CLOUD_BRB" \
        -v "$(pwd)/data:/app/data" \
        cookie-rtmps

    if [ $? -eq 0 ]; then
        SERVER_IP=$(curl -4 -s ifconfig.me || echo "<your_server_ip>")
        DISPLAY_HOST=${SERVER_DOMAIN:-$SERVER_IP}
        echo -e "${GREEN}Container 'cookie-rtmps' is running!${NC}"
        echo -e "You can stream to: rtmp://${DISPLAY_HOST}:${PORT_RTMP}/${APP_NAME}"
        echo -e "Vertical stream:  rtmp://${DISPLAY_HOST}:${PORT_RTMP}/vertical"
        echo -e "Stats available at: http://${DISPLAY_HOST}/stat"

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

    echo -e "${YELLOW}Showing logs for cookie-rtmps... (Press Ctrl+C to exit log view)${NC}"
    # Use a subshell and trap INT to ensure script doesn't exit on Ctrl+C
    (trap 'exit 0' INT; docker logs -f cookie-rtmps)

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

stop_and_uninstall() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed!${NC}"
        sleep 2
        return
    fi
    echo -e "${YELLOW}Stopping services and uninstalling...${NC}"
    docker stop cookie-rtmps 2>/dev/null && echo -e "${GREEN}Container stopped.${NC}" || echo -e "${RED}Container not running.${NC}"
    docker rm cookie-rtmps 2>/dev/null && echo -e "${GREEN}Container removed, ports unbound.${NC}" || true
    docker rmi cookie-rtmps 2>/dev/null && echo -e "${GREEN}Image removed. CookieRTMPS has been completely removed from Docker.${NC}" || true
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
    echo -e "  Stats URL:       http://${DISPLAY_HOST}/stat"
    echo -e "  Combined Chat:   http://${DISPLAY_HOST}/chat.html?twitch=USER&youtube=ID"
    echo "-------------------------------------"
    echo "1) Install Docker (if not installed)"
    echo "2) Configure Stream Keys (Horizontal)"
    echo "3) Configure Stream Keys (Vertical)"
    echo "4) Configure OBS Setup & Security Key"
    echo "5) Configure IP Whitelist (Optional)"
    echo "6) Configure Combined Chat (Optional)"
        echo "7) Configure Stream Titles & Twitch API (Optional)"
        echo "8) Configure Domain / Reverse Proxy (Optional)"
        echo "9) Configure Optimizations (Chunk Size)"
        echo "10) Configure NOALBS Scene Switcher"
        echo "11) Build & Start Server"
        echo "12) Run Integration Tests"
        echo "13) Stop Server & Uninstall"
        echo "14) View Logs"
        echo "15) Quit"
    echo -e "Select an option: \c"
    read -r option

    case $option in
        1) install_docker ;;
        2) configure_keys ;;
        3) configure_vertical_keys ;;
        4) configure_obs ;;
        5) configure_whitelist ;;
        6) configure_chat ;;
        7) configure_titles ;;
        8) configure_domain ;;
        9) configure_optimizations ;;
        10) configure_noalbs ;;
        11) build_and_run ;;
        12) if [ -f "./integration_test.sh" ]; then chmod +x ./integration_test.sh; ./integration_test.sh; else echo -e "${RED}Test script not found.${NC}"; fi; echo -e "Press Enter to continue..."; read -r ;;
        13) stop_and_uninstall ;;
        14) view_logs ;;
        15) clear; echo -e "${GREEN}Goodbye!${NC}"; break ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
