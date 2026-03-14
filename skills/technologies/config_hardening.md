# Web/App Config Hardening Review

## Overview
Systematic review of web/app hardening: headers, TLS, error handling, debug
endpoints, file exposure, and safe defaults.

## Phase 1: Security Headers
```bash
TARGET_URL="https://TARGET"

curl -s -I "$TARGET_URL" \
  | tee /workspace/output/TARGET_headers.txt

rg -n "content-security-policy|x-frame-options|x-content-type-options|strict-transport-security|referrer-policy|permissions-policy" \
  /workspace/output/TARGET_headers.txt \
  > /workspace/output/TARGET_header_findings.txt
```

## Phase 2: TLS Baseline
```bash
# Basic TLS check
openssl s_client -connect TARGET:443 -servername TARGET </dev/null \
  | tee /workspace/output/TARGET_tls.txt
```

## Phase 3: Error & Debug Exposure
```bash
# Force errors to check verbosity
curl -s "$TARGET_URL/does-not-exist" \
  | tee /workspace/output/TARGET_404.txt

# Common debug endpoints
cat > /workspace/output/TARGET_debug_paths.txt <<'PATHS'
/actuator
/actuator/env
/debug
/metrics
/phpinfo.php
/.env
/.git/
PATHS

while read -r p; do
  curl -s -I "$TARGET_URL$p" \
    | tee -a /workspace/output/TARGET_debug_headers.txt
  echo "---" >> /workspace/output/TARGET_debug_headers.txt
done
done < /workspace/output/TARGET_debug_paths.txt
```

## Phase 4: File & Backup Exposure
```bash
# Common backup/config files
cat > /workspace/output/TARGET_backup_paths.txt <<'PATHS'
/.env
/.env.bak
/config.php.bak
/backup.zip
/db.sql
PATHS

while read -r p; do
  curl -s -I "$TARGET_URL$p" \
    | tee -a /workspace/output/TARGET_backup_headers.txt
  echo "---" >> /workspace/output/TARGET_backup_headers.txt
done
done < /workspace/output/TARGET_backup_paths.txt
```

## Phase 5: CORS & Cookie Flags
```bash
# Check CORS
curl -s -I "$TARGET_URL" -H "Origin: https://evil.example" \
  | tee /workspace/output/TARGET_cors.txt

# Check cookie flags
rg -n "set-cookie" /workspace/output/TARGET_headers.txt \
  > /workspace/output/TARGET_cookie_flags.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Missing security headers
- [ ] Verbose error pages or debug endpoints exposed
- [ ] Backup/config files accessible
- [ ] Weak CORS or cookie flags

## Evidence
- Headers: /workspace/output/TARGET_headers.txt
- Debug endpoints: /workspace/output/TARGET_debug_headers.txt
- Backup files: /workspace/output/TARGET_backup_headers.txt

## Recommendations
1. Enforce CSP, HSTS, X-Content-Type-Options, X-Frame-Options
2. Disable debug endpoints in production
3. Remove backups and sensitive files from web root
4. Harden CORS and cookie flags
```

## Output Files
- `/workspace/output/TARGET_headers.txt` — baseline headers
- `/workspace/output/TARGET_header_findings.txt` — header signals
- `/workspace/output/TARGET_debug_headers.txt` — debug endpoints
- `/workspace/output/TARGET_backup_headers.txt` — backup exposure
- `/workspace/output/TARGET_cors.txt` — CORS headers

indicators: config hardening, security headers, tls hardening, debug endpoints, backup exposure
