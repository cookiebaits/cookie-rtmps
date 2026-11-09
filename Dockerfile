FROM buildpack-deps:trixie

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION=nginx-1.30.3
ENV NGINX_RTMP_MODULE_VERSION=cookie-nginx-rtmp

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip && \
    pip3 install --break-system-packages flask gunicorn requests obsws-python flask-session twitchio google-api-python-client eventlet flask-socketio edge-tts defusedxml && \
    apt-get install -y --no-install-recommends ca-certificates openssl libssl-dev stunnel4 gettext certbot ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 cache purge

# Download and install MediaMTX (serves the looping backup video during disconnects / low bitrate)
ENV MEDIAMTX_VERSION=v1.21.3
COPY download_mediamtx.py /tmp/download_mediamtx.py
RUN python3 /tmp/download_mediamtx.py && \
    tar -xzf /tmp/mediamtx.tar.gz -C /usr/local/bin mediamtx && \
    chmod +x /usr/local/bin/mediamtx && \
    rm -f /tmp/mediamtx.tar.gz /tmp/download_mediamtx.py
	
# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Copy RTMP module
COPY cookie-nginx-rtmp /tmp/build/cookie-nginx-rtmp
COPY chat.html /tmp/build/chat.html

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-threads \
        --add-module=/tmp/build/cookie-nginx-rtmp && \
    make -j $(getconf _NPROCESSORS_ONLN) CFLAGS="-Wno-error" && \
    make install && \
    cp /tmp/build/cookie-nginx-rtmp/stat.xsl /usr/local/nginx/html/stat.xsl && \
    cp /tmp/build/chat.html /usr/local/nginx/html/chat.html && \
    cp /tmp/build/nginx/${NGINX_VERSION}/conf/mime.types /etc/nginx/mime.types && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Set up config file
COPY nginx/nginx.conf.template /etc/nginx/nginx.conf.template

# Copy the validation server and supporting scripts
COPY stream_validator.py /app/stream_validator.py
COPY stream_protection.py /app/stream_protection.py
COPY update_titles.py /app/update_titles.py
COPY tiktok_pusher.py /app/tiktok_pusher.py
COPY test_noalbs.py /app/test_noalbs.py
COPY noalbs /app/noalbs

# Config Stunnel
RUN mkdir -p /etc/stunnel/conf.d /var/run/stunnel4 /var/log/stunnel4
COPY stunnel/stunnel.conf /etc/stunnel/stunnel.conf
COPY stunnel/stunnel4 /etc/default/stunnel4
COPY stunnel/*.conf /etc/stunnel/conf.d/
RUN rm -f /etc/stunnel/conf.d/stunnel.conf && \
    sed -i '/reconnect/d' /etc/stunnel/conf.d/*.conf /etc/stunnel/*.conf 2>/dev/null || true && \
    chmod -R 755 /etc/stunnel && \
    touch /var/log/stunnel4/stunnel.log /tmp/stunnel.log /tmp/stunnel.pid && \
    chmod 777 /tmp/stunnel.log /tmp/stunnel.pid /var/log/stunnel4 /var/run/stunnel4

RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# Define generic non-sensitive environment variables
ENV YOUTUBE_URL=rtmp://a.rtmp.youtube.com/live2/
ENV FACEBOOK_URL=rtmp://127.0.0.1:19350/rtmp/
ENV INSTAGRAM_URL=rtmp://127.0.0.1:19351/rtmp/
ENV TIKTOK_URL=rtmp://127.0.0.1:19358/s_v/
ENV TWITCH_URL=rtmp://ingest.global-contribute.live-video.net/app/
ENV TROVO_URL=rtmp://livepush.trovo.live/live/
ENV KICK_URL=rtmp://127.0.0.1:19356/kick/
ENV X_URL=rtmp://127.0.0.1:19354/x/
ENV APP_NAME=live
ENV CHUNK_SIZE=8192

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 1935 80 8081

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
