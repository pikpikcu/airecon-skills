# Supabase Security Assessment

## Overview
Assess Supabase projects for weak RLS policies, exposed tables via PostgREST,
misconfigured Storage buckets, and permissive Auth endpoints.

## Prerequisites
```bash
apt-get install -y jq
```

## Phase 1: Identify Supabase URL & Keys
```bash
# Search frontend bundles for Supabase config
rg -n "supabaseUrl|supabaseKey|anon key|supabase.co" /workspace/output/ \
  > /workspace/output/TARGET_supabase_config_hits.txt

SUPABASE_URL="https://PROJECT.supabase.co"
ANON_KEY="SUPABASE_ANON_KEY"
```

## Phase 2: PostgREST Table Access (RLS)
```bash
# List tables (if exposed)
curl -s "$SUPABASE_URL/rest/v1/" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  | tee /workspace/output/TARGET_supabase_rest_root.json

# Read from a table (replace TABLE)
curl -s "$SUPABASE_URL/rest/v1/TABLE?select=*" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  | tee /workspace/output/TARGET_supabase_table.json
```

## Phase 3: Auth Endpoint Behavior
```bash
# Health check
curl -s "$SUPABASE_URL/auth/v1/health" \
  | tee /workspace/output/TARGET_supabase_auth_health.json

# Signup enabled check
curl -s -X POST "$SUPABASE_URL/auth/v1/signup" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  --data '{"email":"test@example.com","password":"Password123!"}' \
  | tee /workspace/output/TARGET_supabase_signup.json
```

## Phase 4: Storage Buckets
```bash
# List buckets (if allowed)
curl -s "$SUPABASE_URL/storage/v1/bucket" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  | tee /workspace/output/TARGET_supabase_buckets.json

# List objects in a bucket (replace BUCKET)
curl -s "$SUPABASE_URL/storage/v1/object/list/BUCKET" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  | tee /workspace/output/TARGET_supabase_objects.json
```

## Phase 5: Realtime Exposure (Optional)
```bash
# Check realtime endpoint
curl -s "$SUPABASE_URL/realtime/v1/" \
  | tee /workspace/output/TARGET_supabase_realtime.txt
```

## Report Template

```
Target: TARGET
Supabase URL: https://PROJECT.supabase.co
Assessment Date: <DATE>

## Confirmed Findings
- [ ] RLS missing or permissive on tables
- [ ] Anonymous read/write via PostgREST
- [ ] Storage buckets public
- [ ] Signup enabled without controls

## Evidence
- REST root: /workspace/output/TARGET_supabase_rest_root.json
- Table data: /workspace/output/TARGET_supabase_table.json
- Buckets: /workspace/output/TARGET_supabase_buckets.json

## Recommendations
1. Enforce RLS on all tables
2. Limit anon key permissions to minimal operations
3. Restrict Storage buckets and validate uploads
4. Harden Auth settings (email confirmation, rate limits)
```

## Output Files
- `/workspace/output/TARGET_supabase_config_hits.txt` — config hits
- `/workspace/output/TARGET_supabase_table.json` — table read
- `/workspace/output/TARGET_supabase_buckets.json` — bucket list
- `/workspace/output/TARGET_supabase_signup.json` — signup response

indicators: supabase, postgrest, gotrue, supabase storage, supabase rls, supabase anon key
