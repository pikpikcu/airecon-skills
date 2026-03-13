# IoT / Firmware Security Analysis

## Overview
Firmware analysis extracts and analyzes embedded device software to find hardcoded
credentials, command injection, insecure defaults, and unauthenticated services.

## Firmware Acquisition

```bash
# Direct download (vendor site / update mechanism)
curl -O https://vendor.com/firmware-v1.2.3.bin

# From device via UART/JTAG (hardware required)
# From SPI/NAND flash chips

# Via binwalk scan
binwalk TARGET_FIRMWARE.bin

# Extract filesystem
binwalk -e TARGET_FIRMWARE.bin -C /workspace/output/firmware_extracted/
```

## Static Analysis

### Filesystem Extraction
```bash
# Install tools
apt-get install -y binwalk squashfs-tools cramfs-tools jefferson

# Extract all nested archives
binwalk --extract --recurse --depth 5 FIRMWARE.bin

# Unsquash squashfs
unsquashfs squashfs-root.sqsh
```

### Credential Hunting
```bash
# Find hardcoded passwords
find . -name "passwd" -o -name "shadow" 2>/dev/null | xargs cat

# Grep for credentials
grep -rEi "(password|passwd|pwd|secret|token|api_key)\s*[:=]\s*['\"]?[^\s'\"]{4,}" . 2>/dev/null

# Private keys
find . -name "*.pem" -o -name "*.key" -o -name "*.rsa" 2>/dev/null

# SSL certificates with private keys
find . -name "*.crt" -exec grep -l "PRIVATE KEY" {} \;

# Default credentials in web configs
grep -rn "admin" . --include="*.conf" --include="*.cfg" --include="*.json" 2>/dev/null | head -30
```

### Binary Analysis
```bash
# Check security mitigations
checksec --file=BINARY

# Find command injection sinks
grep -rn "system\|popen\|exec" . --include="*.c" --include="*.h" 2>/dev/null
strings BINARY | grep -E "(system|popen|/bin/sh)"

# Find web server binaries
find . -name "httpd" -o -name "lighttpd" -o -name "uhttpd" 2>/dev/null

# Analyze with Ghidra (headless)
ghidra_headless /tmp/ghidra_project FIRMWARE_ANALYSIS \
  -import /workspace/output/firmware_extracted/bin/BINARY \
  -postScript analyzeHeadless.java
```

## Emulation (Dynamic Analysis)

```bash
# Install QEMU + firmwalker
apt-get install -y qemu-user-static qemu-system-arm

# Simple userspace emulation
cp $(which qemu-arm-static) ./squashfs-root/usr/bin/
chroot ./squashfs-root/ /bin/sh

# Full system emulation with FirmAE
git clone https://github.com/pr0v3rbs/FirmAE /workspace/FirmAE
cd /workspace/FirmAE && ./download.sh && ./install.sh
./run.sh -r BRAND FIRMWARE.bin

# Firmwalker automated scan
git clone https://github.com/craigz28/firmwalker /workspace/firmwalker
cd /workspace/firmwalker && bash firmwalker.sh /path/to/squashfs-root/
```

## Network Services Analysis

```bash
# After emulation, scan internal services
nmap -sV 192.168.0.1  # default gateway IP

# Common IoT web admin ports
curl -v http://192.168.0.1:80/
curl -v http://192.168.0.1:8080/
curl -v http://192.168.0.1:8443/

# Telnet (often enabled by default)
telnet 192.168.0.1

# MQTT (IoT messaging protocol)
mosquitto_sub -h 192.168.0.1 -t '#' -v

# UPnP discovery
upnp-inspector -i eth0
```

## Common Vulnerabilities

### Command Injection via Web Interface
```bash
# Test form fields that might execute system commands
curl -X POST http://192.168.0.1/ping.cgi \
  -d "host=127.0.0.1;id;ls+/"

# Common injection parameters: ping_target, host, ip, domain
```

### Hardcoded Backdoors
```bash
# Check for hardcoded admin users
grep -rn "root\|admin\|backdoor" squashfs-root/etc/passwd 2>/dev/null

# Telnet backdoor services
grep -rn "telnet\|backdoor" squashfs-root/etc/init.d/ 2>/dev/null
```

## Reporting Template
```
Target: [DEVICE MODEL / FIRMWARE VERSION]
Attack Surface: [Web UI | Telnet | UART | API]

Finding 1: Hardcoded Credentials
  Location: /etc/passwd or /etc/config/xxx
  Credentials: admin:PASSWORD
  Impact: Full device compromise

Finding 2: Command Injection
  Endpoint: POST /cgi-bin/ping.cgi?host=
  Payload: 127.0.0.1;id
  Evidence: uid=0(root) gid=0(root)
  Impact: RCE as root

Remediation:
  - Remove hardcoded credentials, use randomized defaults
  - Validate/sanitize all user input before passing to shell
  - Enable firmware signing and secure boot
  - Disable telnet, use SSH only
```

indicators: iot firmware embedded binwalk qemu
