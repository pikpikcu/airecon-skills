# Tech Stack Fingerprinting

## Overview
Fingerprint web technology stacks to prioritize relevant tests and identify
outdated components. Combine headers, response bodies, TLS, and active probes.

## Prerequisites
```bash
# Optional tools
# go install github.com/projectdiscovery/httpx/cmd/httpx@latest
# go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
# apt-get install -y whatweb
```

## Phase 1: HTTP Fingerprinting
```bash
echo https://TARGET > /workspace/output/targets.txt

cat /workspace/output/targets.txt \
  | httpx -silent -title -status-code -tech-detect -web-server -ip -cname \
  | tee /workspace/output/TARGET_httpx_fingerprint.txt
```

## Phase 2: Header & Cookie Analysis
```bash
TARGET_URL=https://TARGET

curl -s -I $TARGET_URL \
  | tee /workspace/output/TARGET_headers.txt

rg -n "server:|x-powered-by|set-cookie" \
  /workspace/output/TARGET_headers.txt \
  > /workspace/output/TARGET_header_signals.txt
```

## Phase 3: WhatWeb (Optional)
```bash
whatweb -a 3 -v $TARGET_URL \
  | tee /workspace/output/TARGET_whatweb.txt
```

## Phase 4: Nuclei Tech Tags (Optional)
```bash
nuclei -l /workspace/output/targets.txt -tags tech \
  -o /workspace/output/TARGET_nuclei_tech.txt
```

## Phase 5: Prioritize by Exposure
```bash
rg -n "wordpress|drupal|joomla|struts|spring|nginx|apache" \
  /workspace/output/TARGET_httpx_fingerprint.txt \
  > /workspace/output/TARGET_tech_priority.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Summary
- Detected stacks: <list>
- High-risk/outdated components: <list>

## Evidence
- httpx: /workspace/output/TARGET_httpx_fingerprint.txt
- headers: /workspace/output/TARGET_headers.txt
- whatweb: /workspace/output/TARGET_whatweb.txt

## Recommendations
1. Patch outdated components
2. Remove version banners from headers
3. Segment high-risk applications
```

## Output Files
- `/workspace/output/TARGET_httpx_fingerprint.txt` — httpx tech detect
- `/workspace/output/TARGET_headers.txt` — raw headers
- `/workspace/output/TARGET_header_signals.txt` — header signals
- `/workspace/output/TARGET_nuclei_tech.txt` — nuclei tech results

indicators: tech fingerprint, technology fingerprint, httpx, whatweb, wappalyzer, stack detection
