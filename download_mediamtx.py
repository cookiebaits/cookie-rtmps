import urllib.request
import json
import subprocess
import sys
import os

version = os.getenv("MEDIAMTX_VERSION", "v1.21.3")
arch_res = subprocess.run(["dpkg", "--print-architecture"], capture_output=True, text=True)
arch = arch_res.stdout.strip()
if arch == "amd64":
    mtx_arch = "amd64"
elif arch == "arm64":
    mtx_arch = "arm64"
elif arch == "armhf":
    mtx_arch = "armv7"
else:
    print(f"Unsupported architecture: {arch}")
    sys.exit(1)

target_name = f"mediamtx_{version}_linux_{mtx_arch}.tar.gz"
out_file = "/tmp/mediamtx.tar.gz"

# 1. Try direct GitHub releases download with curl
direct_url = f"https://github.com/bluenviron/mediamtx/releases/download/{version}/{target_name}"
print(f"Downloading MediaMTX {version} for {mtx_arch} from {direct_url}...")
res = subprocess.run(["curl", "-fsSL", "--retry", "5", "--retry-delay", "3", "--retry-connrefused", direct_url, "-o", out_file])

# 2. Resilient fallback to GitHub API asset octet-stream endpoint if CDN returns 504 Gateway Timeout
if res.returncode != 0 or not os.path.exists(out_file) or os.path.getsize(out_file) == 0:
    print("Direct release download failed or timed out. Falling back to GitHub API endpoint...")
    try:
        api_url = f"https://api.github.com/repos/bluenviron/mediamtx/releases/tags/{version}"
        req = urllib.request.Request(api_url, headers={"User-Agent": "CookieRTMPS"})
        with urllib.request.urlopen(req, timeout=15) as r:
            release_data = json.loads(r.read())
        asset_url = None
        for asset in release_data.get("assets", []):
            if asset.get("name") == target_name:
                asset_url = asset.get("url")
                break
        if asset_url:
            print(f"Downloading from API asset endpoint: {asset_url}...")
            subprocess.run(["curl", "-fsSL", "--retry", "5", "--retry-delay", "3", "-H", "Accept: application/octet-stream", asset_url, "-o", out_file], check=True)
    except Exception as e:
        print(f"GitHub API asset fallback failed: {e}")

# 3. Fallback to wget if curl failed
if not os.path.exists(out_file) or os.path.getsize(out_file) == 0:
    print("Falling back to wget...")
    subprocess.run(["wget", "-t", "5", "-w", "3", "-O", out_file, direct_url])

if not os.path.exists(out_file) or os.path.getsize(out_file) == 0:
    print("Fatal: Could not download MediaMTX tarball.")
    sys.exit(1)

print(f"MediaMTX downloaded successfully ({os.path.getsize(out_file)} bytes).")
