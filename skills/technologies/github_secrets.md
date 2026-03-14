# GitHub Secrets Discovery

## Overview
Find leaked credentials and tokens across GitHub organizations, repos, and CI workflows.
Focus on git history, code search, and workflow misconfigurations.

## Prerequisites
```bash
apt-get install -y git gh jq
pip install trufflehog3
# Install gitleaks binary (https://github.com/gitleaks/gitleaks)
```

## Phase 1: Organization Recon
```bash
# List all repositories in an org
gh api orgs/TARGET_ORG/repos --paginate \
  --jq '.[].full_name' > /workspace/output/TARGET_repos.txt

# Clone all repos shallowly
while read -r repo; do
  git clone --depth=1 "https://github.com/$repo.git" \
    "/workspace/output/TARGET_repos/$(basename $repo)" 2>/dev/null
  echo "$repo" >> /workspace/output/TARGET_repos_cloned.txt
done
```

## Phase 2: Secret Scanning (TruffleHog / Gitleaks)
```bash
# TruffleHog on each repo
while read -r repo; do
  name=$(basename "$repo")
  trufflehog git "file:///workspace/output/TARGET_repos/$name" \
    --json > "/workspace/output/${name}_trufflehog.json" 2>&1
done

# Gitleaks on each repo
while read -r repo; do
  name=$(basename "$repo")
  gitleaks detect --source "/workspace/output/TARGET_repos/$name" \
    --report-path "/workspace/output/${name}_gitleaks.json" \
    --report-format json 2>&1
done
```

## Phase 3: Git History Searches
```bash
# Common token patterns
rg -n "ghp_[A-Za-z0-9]{36}|ghs_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{80}" \
  /workspace/output/TARGET_repos/ \
  > /workspace/output/TARGET_gh_tokens_rg.txt

# Search for AWS keys in history
for repo in /workspace/output/TARGET_repos/*; do
  git -C "$repo" log -p -S "AKIA" --all \
    > "/workspace/output/$(basename $repo)_aws_history.txt"
done
```

## Phase 4: GitHub Code Search
```bash
# Org-wide code search (requires GH auth)
gh search code "AKIA" --owner TARGET_ORG --limit 100 \
  > /workspace/output/TARGET_gh_code_search.txt

gh search code "ghp_" --owner TARGET_ORG --limit 100 \
  >> /workspace/output/TARGET_gh_code_search.txt
```

## Phase 5: Workflow & Actions Review
```bash
# Check workflow files for secret handling patterns
rg -n "secrets\.|GITHUB_TOKEN|AWS_ACCESS_KEY_ID|SECRET" \
  /workspace/output/TARGET_repos/ --glob "*.yml" \
  > /workspace/output/TARGET_gh_workflows_secrets.txt

# Find actions/checkout with persist-credentials enabled
rg -n "actions/checkout@|persist-credentials" \
  /workspace/output/TARGET_repos/ --glob "*.yml" \
  > /workspace/output/TARGET_gh_checkout.txt
```

## Report Template

```
Target: TARGET_ORG
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Secrets in git history
- [ ] Secrets in current code
- [ ] Tokens in workflows or CI logs
- [ ] Over-permissive GITHUB_TOKEN usage

## Evidence
- TruffleHog: /workspace/output/<repo>_trufflehog.json
- Gitleaks: /workspace/output/<repo>_gitleaks.json
- Code search: /workspace/output/TARGET_gh_code_search.txt

## Recommendations
1. Rotate exposed credentials immediately
2. Enable GitHub secret scanning + push protection
3. Remove secrets from git history (filter-repo) and rebase
4. Use OIDC instead of long-lived tokens in Actions
5. Minimize GITHUB_TOKEN permissions
```

## Output Files
- `/workspace/output/TARGET_repos.txt` — repo list
- `/workspace/output/TARGET_gh_code_search.txt` — code search results
- `/workspace/output/TARGET_gh_workflows_secrets.txt` — workflow findings

indicators: github secrets, github token leak, github credential leak, gitleaks github, trufflehog github, github actions secrets, secret scanning, gh secrets
