# WordPress Security Assessment

## Overview
Assess WordPress deployments for outdated core/plugins, weak auth endpoints,
misconfigurations, and exposure via REST/XML-RPC.

## Prerequisites
```bash
# WPScan (optional, API token improves vulnerability data)
# apt-get install -y wpscan
```

## Phase 1: Detection & Enumeration
```bash
TARGET_URL="https://TARGET"

# Core indicators
curl -s $TARGET_URL/wp-json/ \
  | tee /workspace/output/TARGET_wp_json.txt

curl -s -I $TARGET_URL/wp-login.php \
  | tee /workspace/output/TARGET_wp_login_headers.txt
```

## Phase 2: WPScan (Optional)
```bash
wpscan --url $TARGET_URL --enumerate ap,at,cb,dbe,u,m \
  --output /workspace/output/TARGET_wpscan.txt
```

## Phase 3: User Enumeration
```bash
# REST API user listing (if exposed)
curl -s "$TARGET_URL/wp-json/wp/v2/users" \
  | tee /workspace/output/TARGET_wp_users.json

# Author ID enumeration
for id in $(seq 1 10); do
  curl -s -I "$TARGET_URL/?author=$id" | rg -n "location:";
done | tee /workspace/output/TARGET_wp_author_enum.txt
```

## Phase 4: XML-RPC Exposure
```bash
curl -s -I "$TARGET_URL/xmlrpc.php" \
  | tee /workspace/output/TARGET_xmlrpc_headers.txt
```

## Phase 5: Plugin & Theme Surface
```bash
# Check exposed plugin/theme directories
curl -s -I "$TARGET_URL/wp-content/plugins/" \
  | tee /workspace/output/TARGET_wp_plugins_headers.txt

curl -s -I "$TARGET_URL/wp-content/themes/" \
  | tee /workspace/output/TARGET_wp_themes_headers.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Outdated WordPress core/plugins
- [ ] User enumeration possible
- [ ] XML-RPC enabled
- [ ] Exposed plugin/theme directories

## Evidence
- WP JSON: /workspace/output/TARGET_wp_json.txt
- Users: /workspace/output/TARGET_wp_users.json
- WPScan: /workspace/output/TARGET_wpscan.txt

## Recommendations
1. Update core, plugins, and themes regularly
2. Disable XML-RPC if not required
3. Restrict user enumeration endpoints
4. Enforce strong auth + MFA
```

## Output Files
- `/workspace/output/TARGET_wp_json.txt` — REST API response
- `/workspace/output/TARGET_wp_users.json` — user list
- `/workspace/output/TARGET_wpscan.txt` — wpscan results

indicators: wordpress, wp-admin, wp-json, wpscan, xmlrpc, wordpress plugin
