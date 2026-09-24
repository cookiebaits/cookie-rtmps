# CookieRTMPS: Secure, Self-hosted Multistreaming Solution

**PROJECT CONTEXT (Read First!)**

This project (`cookiebaits/cookie-rtmps`) is a standalone codebase that provides a robust, self-hosted RTMP relay for multistreaming, built heavily on secure practices, stream key validation, and automatic quality-of-life integrations. It guarantees secure access and stability when streaming to multiple platforms simultaneously.

*   **The Problem with Obscurity:** Historically, some RTMP relays relied on randomizing the RTMP application path or URL as their sole security measure, effectively claiming "Your Stream Key Does Not Matter." While this adds a minor layer of *obscurity*, it **does not fundamentally fix stream hijacking vulnerabilities**. If the random path is ever leaked or discovered, anyone can stream to your server because the key itself is never checked.
*   **The CookieRTMPS Solution:** CookieRTMPS implements **strict stream key validation** (`on_publish` check). When a stream connects, its key is checked securely via `stream_validator.py` against your configured destination keys. Only streams with a perfect matching key are authorized and relayed. This is the industry-standard approach to securing RTMP ingest points.

## Introduction

Would you like to stream to Twitch, YouTube, Kick, Trovo, Facebook, Instagram, X (Twitter), Cloudflare, and custom RTMP destinations at once, without the upload strain on your computer or recurring fees of commercial services?

You can host **CookieRTMPS** on a server to act as a **secure and efficient** relay for your streamed content!

You stream **one** high-quality feed to your CookieRTMPS server, and it will:
1.  **Validate** the incoming stream to ensure it's from you, preventing unauthorized access.
2.  **Relay** your stream to all the platforms you configure.

This project includes performance tuning (optimized `chunk_size`), updated core components for better stability and security, and active maintenance.

### Key Features
*   **Server IP Auto-Whitelisting:** Configure an IP Whitelist dynamically by auto-fetching your host IP (useful for VPN/Wireguard setups).
*   **NOALBS Scene Switcher & Cloud BRB Integration:** Automatic bitrate monitoring to dynamically switch OBS scenes and trigger fallback `.mp4` video looping on stream disconnects—enabled by default for maximum stream stability.
*   **Vertical Streaming Support:** Optimized for use with the **OBS Aitum Vertical plugin**. Push a second, independent vertical feed to specialized targets (TikTok, YouTube Vertical, Twitch Vertical) alongside your horizontal stream.
*   **Automated Stream Titles:** Automatically set and update your stream titles in the format: `Base Title / Episode # / Date`. Episode numbers are persisted and increment automatically! (Current support: Twitch API).
*   **Aggressive Cleanup & Testing:** Built-in scripts to aggressively purge old Docker instances to avoid port conflicts and ensure smooth upgrades, backed by instant integration testing.
*   **Cloudflare Reverse Proxy:** Built-in support for Cloudflare Real IP, allowing you to secure your stats page behind a Cloudflare proxy.
*   **Nginx 1.30.3 & Custom RTMP:** Updated to the latest stable Nginx with a custom, hardened RTMP module (including strict memory limits and recursion bounds) for maximum reliability.

## Prequisites

You'd need a VPS server. Key considerations:
*   **Network Performance:** Good bandwidth, low latency, and stable routing between your VPS and your chosen streaming platforms are crucial, especially for 1080p 60fps.
*   **Resources:** A 2 vCore, 2GB RAM VPS (like those from Ionos, Linode, Digital Ocean, Vultr, Hetzner Cloud) is often sufficient. This project has been tested and runs effectively on such configurations. Choose a location strategically.

## How To Set up CookieRTMPS

*   1- **SSH into your VPS server:**
    ```bash
    ssh root@<your_server_ip_address>
    ```

*   2- **Clone, Set permissions, & Run the Repository:**
    ```bash
    git clone https://github.com/cookiebaits/cookie-rtmps.git && cd cookie-rtmps && chmod +x install.sh && ./install.sh
    ```
    *   Use the menu to easily install Docker (if needed).
    *   Configure your stream keys and set any desired optimizations (like NGINX `chunk_size`).
    *   Select "Build & Start Server" to launch your customized RTMP relay.

*   3- **Configure OBS (or other streaming software):**
    *   Service: `Custom...`
    *   **Horizontal Server:** `rtmp://<your_vps_ip_address>:1935/live`
    *   **Vertical Server:** `rtmp://<your_vps_ip_address>:1935/vertical` (For Aitum Vertical)
    *   Stream Key: **Use ONE of the actual stream keys you configured during the setup process** (or the custom Master OBS Key if you set one).

*   4- **Begin streaming from OBS!**

We advise testing with one or two destinations first.

## How To Manage CookieRTMPS

*   **STOP** the container: `docker stop cookie-rtmps`
*   **START** the container: `docker start cookie-rtmps`
*   **VIEW LOGS:** `docker logs cookie-rtmps` (or `docker logs -f cookie-rtmps` for live logs)
*   **EDIT Destinations / Keys:** Stop, remove (`docker rm cookie-rtmps`), and re-run the `docker run` command.
*   **UNINSTALL:** Stop, remove container, then `docker rmi cookie-rtmps`.

## Troubleshooting Common Issues

*   **Lag / Falling Behind Stream:** Often a network bottleneck. This fork uses `chunk_size: 8192` for improved performance.
    *   **Diagnosis:** Test one destination at a time. Use `mtr <destination_hostname>` from VPS.
    *   **Solutions:** Different ingest servers, different VPS location, or lower stream bitrate.
*   **Stream Rejects / "Invalid Key":**
    *   OBS key *must exactly match* one key from `docker run`.
    *   Ensure at least one destination key is active in `docker run`.
    *   Check validator logs: `docker exec cookie-rtmps tail /tmp/validator.log` or `docker logs cookie-rtmps`.
*   **One Destination Not Working:** Check URL/Key in `docker run`. Check Nginx/Stunnel logs. Ensure stream is active on the platform.

## Support & Contributing

Need help or have suggestions for **CookieRTMPS**? Your contributions and feedback are welcome!

*   Raise an Issue: [https://github.com/cookiebaits/cookie-rtmps/issues](https://github.com/cookiebaits/cookie-rtmps/issues)
*   Join our Discord: [http://wubu.cookiebaits.com](http://wubu.cookiebaits.com) (Shield above also links here)

---
**Historical Note:**

CookieRTMPS was originally born as a fork to address a critical security vulnerability in an older RTMP relay project that lacked proper stream key validation (allowing unauthorized individuals to hijack streams if they found the server IP/port). CookieRTMPS has since evolved into a standalone, feature-rich multistreaming platform that prioritizes strict security, stability, and ease-of-use for the community.

---
**Legal, Disclaimer and Licensing:**

CookieRTMPS is not for public use. This is not a open source licensing, this is a program with no warranty, no support and we are not responsible for any data leaks, security breaches, etc. This program was strictly and only made for Cookiebaits and the Ruinscam brands. This is not recommend and completely restricted from commercial use without explicit permission. 
