# DOM-Based Vulnerabilities

## Overview
DOM-based vulnerabilities happen when client-side JavaScript reads attacker-controlled
input (sources) and writes it to dangerous sinks without proper sanitization.
This can lead to DOM XSS, open redirects, HTML injection, or data exfiltration.

## Prerequisites
```bash
# Optional: Burp DOM Invader extension
# Optional: browser devtools
```

## Phase 1: Identify Sources & Sinks
```bash
# Common sources
# - location (href, search, hash)
# - document.referrer
# - window.name
# - localStorage / sessionStorage
# - postMessage events

# Common sinks
# - innerHTML / outerHTML
# - document.write / writeln
# - eval / setTimeout / setInterval
# - location.assign / location.replace
# - jQuery.html / jQuery.append
```

## Phase 2: Quick Source Discovery
```bash
# Look for URLs that include user input in the DOM
# Example test URL
# https://TARGET/page?name=TEST#hash=TEST
```

## Phase 3: DOM XSS Payloads
```bash
cat > /workspace/output/TARGET_domxss_payloads.txt <<'PAYLOADS'
"><img src=x onerror=alert(1)>
"><svg/onload=alert(1)>
</script><script>alert(1)</script>
PAYLOADS
```

## Phase 4: DOM Clobbering
```bash
# Inject elements that override DOM properties
# Example:
# <form id="action"></form>
# If code uses: document.action
```

## Phase 5: postMessage Testing
```bash
# If app listens to postMessage, test origin validation
# In browser console (target page open):
# window.postMessage({type:'test', data:'<img src=x onerror=alert(1)>'}, '*')
```

## Phase 6: Storage-Based Injection
```bash
# If app reads from localStorage/sessionStorage
# Set a payload and reload
# localStorage.setItem('key', '<img src=x onerror=alert(1)>')
```

## Phase 7: DOM-Based Open Redirect
```bash
# Check for client-side redirects
# Examples:
# https://TARGET/redirect?next=https://ATTACKER
# https://TARGET/#next=https://ATTACKER
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] DOM XSS via source → sink
- [ ] postMessage origin validation missing
- [ ] Storage-based injection
- [ ] DOM-based open redirect

## Evidence
- Payloads: /workspace/output/TARGET_domxss_payloads.txt
- Repro steps: <steps>

## Recommendations
1. Use safe sinks (textContent) or robust sanitization
2. Validate postMessage origin and schema
3. Avoid constructing HTML/JS from untrusted input
4. Enforce allowlists for redirects
```

## Output Files
- `/workspace/output/TARGET_domxss_payloads.txt` — payload list

indicators: dom-based vulnerabilities, dom xss, dom clobbering, postmessage, client-side injection
