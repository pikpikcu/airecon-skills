# Cloud Asset Discovery

## Overview
Discover cloud assets tied to a target domain: buckets, storage endpoints,
CDN distributions, and exposed services across AWS, Azure, and GCP.

## Prerequisites
```bash
# Optional tooling
# go install github.com/projectdiscovery/httpx/cmd/httpx@latest
# go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

## Phase 1: Identify Cloud-Hosted Subdomains
```bash
TARGET=TARGET

subfinder -d $TARGET -silent \
  | tee /workspace/output/TARGET_cloud_subdomains.txt

# Filter common cloud patterns
rg -n "amazonaws\.com|cloudfront\.net|azurewebsites\.net|blob\.core\.windows\.net|storage\.googleapis\.com" \
  /workspace/output/TARGET_cloud_subdomains.txt \
  > /workspace/output/TARGET_cloud_candidates.txt

# Extract keywords for bucket naming patterns
cut -d. -f1 /workspace/output/TARGET_cloud_candidates.txt \
  | sort -u > /workspace/output/TARGET_cloud_keywords.txt
```

## Phase 2: Bucket & Storage Enumeration
```bash
# AWS S3 (virtual-host style)
while read -r name; do
  echo "https://$name.s3.amazonaws.com";
done < /workspace/output/TARGET_cloud_keywords.txt \
  > /workspace/output/TARGET_s3_candidates.txt

# Azure Blob Storage
while read -r name; do
  echo "https://$name.blob.core.windows.net";
done < /workspace/output/TARGET_cloud_keywords.txt \
  > /workspace/output/TARGET_azure_blob_candidates.txt

# GCP Storage
while read -r name; do
  echo "https://storage.googleapis.com/$name";
done < /workspace/output/TARGET_cloud_keywords.txt \
  > /workspace/output/TARGET_gcp_bucket_candidates.txt
```

## Phase 3: Verify Accessibility
```bash
cat /workspace/output/TARGET_*_candidates.txt \
  | httpx -silent -status-code -title -content-length \
  | tee /workspace/output/TARGET_cloud_assets_live.txt
```

## Phase 4: Certificate Transparency (Optional)
```bash
# Pull subdomains from crt.sh (best-effort)
# curl -s "https://crt.sh/?q=%25.$TARGET&output=json" \
#   | jq -r '.[].name_value' | sort -u \
#   > /workspace/output/TARGET_crtsh_subdomains.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Summary
- Cloud endpoints identified: <N>
- Publicly accessible assets: <N>

## Evidence
- Cloud candidates: /workspace/output/TARGET_cloud_candidates.txt
- Live assets: /workspace/output/TARGET_cloud_assets_live.txt

## Recommendations
1. Restrict public access to storage buckets
2. Disable unused cloud endpoints
3. Monitor CT logs for new assets
```

## Output Files
- `/workspace/output/TARGET_cloud_candidates.txt` — cloud-related subdomains
- `/workspace/output/TARGET_cloud_keywords.txt` — bucket keyword list
- `/workspace/output/TARGET_s3_candidates.txt` — S3 URLs
- `/workspace/output/TARGET_azure_blob_candidates.txt` — Azure Blob URLs
- `/workspace/output/TARGET_gcp_bucket_candidates.txt` — GCP URLs
- `/workspace/output/TARGET_cloud_assets_live.txt` — verified assets

indicators: cloud asset discovery, s3 bucket discovery, azure blob, gcp bucket, cloudfront, cdn discovery
