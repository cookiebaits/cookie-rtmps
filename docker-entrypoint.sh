#!/bin/bash
set -e

export SERVER_DOMAIN="${SERVER_DOMAIN:-localhost}"

NGINX_TEMPLATE=/etc/nginx/nginx.conf.template
NGINX_CONF=/etc/nginx/nginx.conf
VALIDATOR_LOG=/tmp/validator.log
MAX_WAIT_VALIDATOR_SECONDS=15
VALIDATOR_CHECK_INTERVAL_SECONDS=0.2

echo "Starting stream key validation server..."
export PYTHONPATH=$PYTHONPATH:/app
gunicorn \
    --workers 1 \
    --bind 127.0.0.1:8080 \
    --log-level info \
    --access-logfile "$VALIDATOR_LOG" \
    --error-logfile "$VALIDATOR_LOG" \
    --chdir /app \
    stream_validator:app &
VALIDATOR_PID=$!
echo "Validator PID: $VALIDATOR_PID"

echo "Waiting for validator to be ready..."
VALIDATOR_READY=0
MAX_ATTEMPTS=$(awk -v max_wait="$MAX_WAIT_VALIDATOR_SECONDS" -v interval="$VALIDATOR_CHECK_INTERVAL_SECONDS" 'BEGIN {printf "%.0f", max_wait / interval}')
CURRENT_ATTEMPT=0

while [ $CURRENT_ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if kill -0 $VALIDATOR_PID 2>/dev/null && curl --fail --silent --connect-timeout 0.1 --max-time 0.4 http://127.0.0.1:8080/health > /dev/null; then
        echo "Validator is running and responding."
        VALIDATOR_READY=1
        break
    fi
    sleep $VALIDATOR_CHECK_INTERVAL_SECONDS
    CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))
done

if [ $VALIDATOR_READY -eq 0 ]; then
    echo "ERROR: Stream key validator failed to start within ${MAX_WAIT_VALIDATOR_SECONDS}s."
    echo "Check validator logs:"
    cat "$VALIDATOR_LOG"
    exit 1
fi

echo "Generating Nginx configuration..."
EXPORT_VARS=$(printf '${%s} ' $(env | cut -d= -f1))
envsubst "$EXPORT_VARS" < $NGINX_TEMPLATE > $NGINX_CONF

if [ -n "${DEBUG}" ]; then
    echo "--- Final Nginx Configuration (${NGINX_CONF}) ---"
    cat $NGINX_CONF
    echo "-------------------------------------------------"
fi

echo "Starting Stunnel..."
stunnel4 /etc/stunnel/stunnel.conf

if [ -n "$SERVER_DOMAIN" ]; then
    CERT_DIR="/etc/letsencrypt/live/${SERVER_DOMAIN}"
    if [ ! -f "${CERT_DIR}/fullchain.pem" ]; then
        echo "SSL certificate not found for ${SERVER_DOMAIN}. Generating dummy certificate..."
        mkdir -p "${CERT_DIR}"
        openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
            -keyout "${CERT_DIR}/privkey.pem" \
            -out "${CERT_DIR}/fullchain.pem" \
            -subj "/CN=${SERVER_DOMAIN}"
        chmod 600 "${CERT_DIR}/privkey.pem" "${CERT_DIR}/fullchain.pem"
    fi
fi

if [ -n "$SERVER_DOMAIN" ] && [ "$SERVER_DOMAIN" != "localhost" ]; then
    mkdir -p /var/www/certbot
    echo "Starting Certbot renewal background loop..."
    (
        while true; do
            FULLCHAIN="/etc/letsencrypt/live/${SERVER_DOMAIN}/fullchain.pem"
            IS_DUMMY=0
            if [ -f "$FULLCHAIN" ]; then
                ISSUER=$(openssl x509 -noout -issuer -in "$FULLCHAIN")
                if [[ "$ISSUER" == *"/CN=${SERVER_DOMAIN}"* ]] || [[ "$ISSUER" == *"CN = ${SERVER_DOMAIN}"* ]]; then
                    IS_DUMMY=1
                fi
            fi

            if [ $IS_DUMMY -eq 1 ]; then
                echo "Dummy certificate detected. Attempting to obtain real certificate..."
                if certbot certonly --webroot -w /var/www/certbot -d "${SERVER_DOMAIN}" --non-interactive --agree-tos --register-unsafely-without-email; then
                    echo "Real certificate obtained successfully. Reloading Nginx."
                    nginx -s reload
                else
                    echo "Failed to obtain real certificate. Will retry in 1 hour."
                    sleep 1h
                    continue
                fi
            else
                echo "Checking for certificate renewal..."
                certbot renew --webroot -w /var/www/certbot --quiet --post-hook "nginx -s reload"
            fi
            sleep 12h
        done
    ) &
fi

echo "Starting Stream Protection relay supervisor..."
(
    while true; do
        python3 /app/protection/stream_protection.py 2>&1 | tee -a /tmp/stream_protection.log
        echo "Stream Protection supervisor exited. Restarting in 2s..." | tee -a /tmp/stream_protection.log
        sleep 2
    done
) &

echo "Starting Nginx..."
exec "$@"
