# Favicon Hash — Asset Discovery & Fingerprinting

## Overview
Favicon hashes (MurmurHash3 / mmh3) identify web stacks and discover
hidden assets via Shodan, FOFA, and Censys.

## Prerequisites
```bash
pip install mmh3 requests
```

## Phase 1: Compute Hash
```bash
cat > /workspace/output/favicon_hash.py <<'PY'
import base64
import mmh3
import requests
import sys

URL = sys.argv[1].rstrip("/")
paths = ["/favicon.ico", "/static/favicon.ico", "/assets/favicon.ico"]

for path in paths:
    try:
        resp = requests.get(URL + path, timeout=10, verify=False)
        favicon_b64 = base64.encodebytes(resp.content)
        h = mmh3.hash(favicon_b64)
        print(f"{path} {h}")
    except Exception as e:
        print(f"{path} error {e}")
PY

python3 /workspace/output/favicon_hash.py https://TARGET \
  | tee /workspace/output/TARGET_favicon_hashes.txt
```

## Phase 2: Search Engines
```bash
# Shodan
shodan search "http.favicon.hash:HASH" --fields ip_str,port,hostnames \
  | tee /workspace/output/TARGET_shodan_favicon.txt

# FOFA
# icon_hash="HASH"
# icon_hash="HASH" && country="US"

# Censys
# services.http.response.favicons.hashes="sha256:HASH"
```

## Phase 3: Verify Live Assets
```bash
awk '{print $1":"$2}' /workspace/output/TARGET_shodan_favicon.txt \
  | httpx -silent -title -status-code \
  | tee /workspace/output/TARGET_favicon_live.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Matching favicon hashes in external indexes
- [ ] Hidden assets discovered

## Evidence
- Hashes: /workspace/output/TARGET_favicon_hashes.txt
- Shodan: /workspace/output/TARGET_shodan_favicon.txt
- Live: /workspace/output/TARGET_favicon_live.txt

## Recommendations
1. Limit exposure of internal services
2. Use auth on admin interfaces even if discoverable
3. Monitor asset indexes for unintended exposure
```

## Output Files
- `/workspace/output/TARGET_favicon_hashes.txt` — computed hashes
- `/workspace/output/TARGET_shodan_favicon.txt` — Shodan results
- `/workspace/output/TARGET_favicon_live.txt` — verified assets

indicators: favicon hash fingerprint shodan fofa mmh3
