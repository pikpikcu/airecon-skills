# Subdomain Enumeration Playbook

## Overview
Subdomain enumeration expands attack surface by mapping hostnames, resolving to IPs,
and identifying live services for follow-on testing.

## Prerequisites
```bash
# Optional tooling
# go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
# go install github.com/owasp-amass/amass/v4/...@latest
# go install github.com/tomnomnom/assetfinder@latest
# go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
# go install github.com/projectdiscovery/httpx/cmd/httpx@latest
```

## Phase 1: Passive Enumeration
```bash
TARGET=TARGET

subfinder -d $TARGET -all -silent \
  | tee /workspace/output/TARGET_subfinder.txt

assetfinder --subs-only $TARGET \
  | tee /workspace/output/TARGET_assetfinder.txt

amass enum -passive -d $TARGET \
  | tee /workspace/output/TARGET_amass_passive.txt

cat /workspace/output/TARGET_* \
  | rg -n "\.${TARGET}$" \
  | sort -u > /workspace/output/TARGET_subdomains_all.txt
```

## Phase 2: Permutation & Brute Force (Optional)
```bash
# Use custom wordlists to brute force or permute
# Example with dnsx wordlist if available
# dnsx -d $TARGET -w /path/to/wordlist.txt -silent \
#   | tee /workspace/output/TARGET_dnsx_bruteforce.txt

# Merge permutations
cat /workspace/output/TARGET_subdomains_all.txt \
  | sort -u > /workspace/output/TARGET_subdomains_final.txt
```

## Phase 3: Resolve & Validate
```bash
# Resolve to IPs
cat /workspace/output/TARGET_subdomains_final.txt \
  | dnsx -silent -a -resp \
  | tee /workspace/output/TARGET_subdomains_resolved.txt

# Fallback if dnsx is unavailable
# while read -r sub; do host $sub; done < /workspace/output/TARGET_subdomains_final.txt \
#   | tee /workspace/output/TARGET_subdomains_resolved.txt

# Probe live HTTP services
cat /workspace/output/TARGET_subdomains_final.txt \
  | httpx -silent -title -status-code -ip -tech-detect \
  | tee /workspace/output/TARGET_subdomains_live.txt

# Fallback if httpx is unavailable
# while read -r sub; do curl -s -I https://$sub | rg -n "HTTP/|server:"; done \
#   < /workspace/output/TARGET_subdomains_final.txt > /workspace/output/TARGET_subdomains_live.txt
```

## Phase 4: Prioritize Targets
```bash
# Focus on admin/staging/dev keywords
rg -n "admin|staging|dev|test|internal|vpn|jira|git" \
  /workspace/output/TARGET_subdomains_final.txt \
  > /workspace/output/TARGET_subdomains_priority.txt
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Summary
- Total subdomains found: <N>
- Resolved hosts: <N>
- Live HTTP(S): <N>

## Evidence
- All subdomains: /workspace/output/TARGET_subdomains_all.txt
- Resolved: /workspace/output/TARGET_subdomains_resolved.txt
- Live services: /workspace/output/TARGET_subdomains_live.txt

## Recommendations
1. Remove or restrict unused subdomains
2. Enforce authentication on admin/staging hosts
3. Monitor DNS for unexpected subdomain creation
```

## Output Files
- `/workspace/output/TARGET_subfinder.txt` — subfinder results
- `/workspace/output/TARGET_amass_passive.txt` — amass passive results
- `/workspace/output/TARGET_subdomains_all.txt` — merged list
- `/workspace/output/TARGET_subdomains_resolved.txt` — DNS resolution
- `/workspace/output/TARGET_subdomains_live.txt` — live HTTP services

indicators: subdomain enumeration, subdomain enum, subfinder, amass, assetfinder, dns brute
