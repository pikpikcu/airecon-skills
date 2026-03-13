# Favicon Hash — Asset Discovery & Fingerprinting

## Overview
Favicon hashes (MurmurHash3 / mmh3) identify web stacks and discover
hidden assets via Shodan, FOFA, and Censys.

## Compute Hash

```python
# Python — compute mmh3 from favicon
import requests, mmh3, base64, sys

def get_favicon_hash(url: str) -> int:
    resp = requests.get(url, timeout=10, verify=False)
    favicon_b64 = base64.encodebytes(resp.content)
    return mmh3.hash(favicon_b64)

target = sys.argv[1]
for path in ["/favicon.ico", "/static/favicon.ico", "/assets/favicon.ico"]:
    try:
        h = get_favicon_hash(f"{target}{path}")
        print(f"{path} → {h}")
    except Exception as e:
        print(f"{path} → error: {e}")
```

```bash
# Install dependency
pip install mmh3 requests
python3 favicon_hash.py https://TARGET
```

## Shodan Queries

```bash
# Search by known hash
shodan search "http.favicon.hash:116323821"

# Common framework hashes
# Jenkins: 81586312
# Grafana: -1148433978
# GitLab: -1767557375
# Kibana: -626052864
# Jira: -1944575552
# Confluence: 2052814846
# Splunk: -1116028607

shodan search "http.favicon.hash:81586312" --fields ip_str,port,hostnames
```

## FOFA Queries

```
icon_hash="116323821"
icon_hash="-1767557375" && country="US"
```

## Censys

```
services.http.response.favicons.hashes="sha256:HASH"
```

## Attack Surface Discovery

```bash
# Find all IPs hosting a specific app via favicon
#!/bin/bash
TARGET_HASH=$(python3 favicon_hash.py https://TARGET | grep favicon.ico | awk '{print $NF}')
echo "Hash: $TARGET_HASH"

# Shodan CLI
shodan search "http.favicon.hash:$TARGET_HASH" --fields ip_str,port,org | \
  tee /workspace/output/favicon_assets.txt

# httpx verify live assets
awk '{print $1":"$2}' /workspace/output/favicon_assets.txt | \
  httpx -silent -title -status-code -o /workspace/output/favicon_live.txt
```

indicators: favicon hash fingerprint shodan fofa mmh3
