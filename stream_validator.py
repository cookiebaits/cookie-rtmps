from flask import Flask, request, Response
import os
import logging
from urllib.parse import parse_qs
import threading
import subprocess
from datetime import datetime

app = Flask(__name__)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Configuration
VALID_KEYS = []
DESTINATION_KEYS = {
    'youtube': os.getenv('YOUTUBE_KEY', ''),
    'twitch': os.getenv('TWITCH_KEY', ''),
    'kick': os.getenv('KICK_KEY', ''),
    'x': os.getenv('X_KEY', ''),
    'facebook': os.getenv('FACEBOOK_KEY', ''),
    'instagram': os.getenv('INSTAGRAM_KEY', ''),
    'tiktok': os.getenv('TIKTOK_KEY', ''),
    'rtmp1': os.getenv('RTMP1_KEY', ''),
    'rtmp2': os.getenv('RTMP2_KEY', ''),
    'rtmp3': os.getenv('RTMP3_KEY', ''),
    'trovo': os.getenv('TROVO_KEY', ''),
    'obs': os.getenv('OBS_KEY', ''),
}

# Vertical Keys
for i in ['YOUTUBE', 'TWITCH', 'TIKTOK', 'KICK', 'FACEBOOK', 'INSTAGRAM', 'X', 'TROVO', 'RTMP1']:
    DESTINATION_KEYS[f'v_{i.lower()}'] = os.getenv(f'V_{i}_KEY', '')

ACCEPTED_IP = os.getenv('ACCEPTED_IP', '')
EPISODE_FILE = '/app/data/episode_count.txt'
TITLE_LOCK = threading.Lock()

# Populate VALID_KEYS
for key_name, key_value in DESTINATION_KEYS.items():
    if key_value:
        VALID_KEYS.append(key_value)

if VALID_KEYS:
    obscured_keys = [k[:2] + '...' + k[-2:] if len(k) > 4 else '****' for k in VALID_KEYS]
    app.logger.info(f"Stream validator starting. Valid keys: {obscured_keys}")
else:
    app.logger.warning("Stream validator starting. No keys found in environment.")

if ACCEPTED_IP:
    app.logger.info(f"IP Whitelist active: {ACCEPTED_IP}")

def get_episode_count():
    try:
        if not os.path.exists(EPISODE_FILE):
            os.makedirs(os.path.dirname(EPISODE_FILE), exist_ok=True)
            with open(EPISODE_FILE, 'w') as f:
                f.write('1')
            return 1
        with open(EPISODE_FILE, 'r') as f:
            return int(f.read().strip())
    except Exception as e:
        app.logger.error(f"Error reading episode count: {e}")
        return 1

def increment_episode_count():
    with TITLE_LOCK:
        count = get_episode_count()
        try:
            with open(EPISODE_FILE, 'w') as f:
                f.write(str(count + 1))
        except Exception as e:
            app.logger.error(f"Error writing episode count: {e}")

def run_update_titles():
    # Only run if Twitch credentials exist
    if not (os.getenv('TWITCH_CLIENT_ID') and os.getenv('TWITCH_OAUTH_TOKEN') and os.getenv('TWITCH_BROADCASTER_ID')):
        return

    count = get_episode_count()
    date_str = datetime.now().strftime('%Y-%m-%d')
    base_title = os.getenv('STREAM_BASE_TITLE', 'Live Stream')
    full_title = f"{base_title} | Ep.{count} | {date_str}"

    app.logger.info(f"Updating Twitch title to: {full_title}")

    try:
        # Call the update script
        subprocess.run(['python3', '/app/update_titles.py', full_title], check=False)
        # Note: We don't increment here to avoid double increments from dual horizontal/vertical streams
        # We'll increment on publish_done of the primary app.
    except Exception as e:
        app.logger.error(f"Failed to update titles: {e}")

@app.route('/validate', methods=['POST'])
def validate():
    raw_data = request.get_data(as_text=True)
    parsed_data = parse_qs(raw_data)
    stream_key_attempt = parsed_data.get('name', [''])[0]

    # Cloudflare Real IP or fallback
    client_ip = request.headers.get('CF-Connecting-IP', request.remote_addr)
    if not client_ip or client_ip == '127.0.0.1':
        client_ip = parsed_data.get('addr', [request.remote_addr])[0]

    # IP Whitelist Check
    if ACCEPTED_IP and client_ip != ACCEPTED_IP:
        app.logger.warning(f"REJECTED IP: {client_ip}")
        return Response('IP not whitelisted', status=403)

    # Key Check
    if not VALID_KEYS:
        return Response('No keys configured', status=403)

    if stream_key_attempt in VALID_KEYS:
        app.logger.info(f"ACCEPTED stream from {client_ip}")
        # Update titles in background to not block Nginx
        threading.Thread(target=run_update_titles).start()
        return Response('OK', status=200)
    else:
        app.logger.warning(f"REJECTED invalid key from {client_ip}")
        return Response('Invalid stream key', status=403)

@app.route('/publish_done', methods=['POST', 'GET'])
def publish_done():
    # Nginx sends GET by default for on_publish_done in some versions, but usually POST
    app_name = request.args.get('app', '')
    if app_name == os.getenv('APP_NAME', 'live'):
        # Increment episode count when horizontal stream finishes
        increment_episode_count()
        app.logger.info("Horizontal stream finished. Episode count incremented.")
    return Response('OK', status=200)

@app.route('/health', methods=['GET'])
def health_check():
    return Response('OK', status=200)

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8080, debug=False)
