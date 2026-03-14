# IoT / Firmware Security Analysis

## Overview
Firmware analysis extracts and inspects embedded device software to identify
hardcoded credentials, command injection, insecure defaults, and exposed services.

## Prerequisites
```bash
apt-get install -y binwalk squashfs-tools cramfs-tools jefferson qemu-user-static
```

## Phase 1: Firmware Acquisition
```bash
# Direct download (vendor site / update mechanism)
curl -O https://VENDOR/firmware.bin

# From device via UART/JTAG (hardware required)
# From SPI/NAND flash chips

# Quick file identification
file TARGET_FIRMWARE.bin | tee /workspace/output/TARGET_firmware_fileinfo.txt
```

## Phase 2: Extraction & Filesystem Mapping
```bash
# Initial scan
binwalk TARGET_FIRMWARE.bin | tee /workspace/output/TARGET_binwalk.txt

# Extract filesystem
binwalk -e TARGET_FIRMWARE.bin -C /workspace/output/firmware_extracted/

# Unsquash if detected
unsquashfs /workspace/output/firmware_extracted/squashfs-root.sqsh \
  -d /workspace/output/firmware_unsquash/
```

## Phase 3: Credential & Secret Hunting
```bash
# Find password files
find /workspace/output/firmware_unsquash/ -name "passwd" -o -name "shadow" \
  2>/dev/null | tee /workspace/output/TARGET_password_files.txt

# Grep for common secret patterns
rg -n "(password|passwd|pwd|secret|token|api_key)\s*[:=]" \
  /workspace/output/firmware_unsquash/ \
  > /workspace/output/TARGET_secret_grep.txt

# Private keys
find /workspace/output/firmware_unsquash/ -name "*.pem" -o -name "*.key" \
  -o -name "*.rsa" 2>/dev/null | tee /workspace/output/TARGET_private_keys.txt
```

## Phase 4: Binary & Service Analysis
```bash
# Find command execution sinks
rg -n "system\(|popen\(|exec\(" /workspace/output/firmware_unsquash/ \
  --glob "*.c" --glob "*.h" > /workspace/output/TARGET_cmd_sinks.txt

# Identify embedded web servers
find /workspace/output/firmware_unsquash/ -name "httpd" -o -name "lighttpd" \
  -o -name "uhttpd" 2>/dev/null | tee /workspace/output/TARGET_web_binaries.txt

# Extract strings for quick triage
strings /workspace/output/firmware_unsquash/**/bin/* 2>/dev/null | \
  rg -n "http|admin|password" > /workspace/output/TARGET_strings_hits.txt
```

## Phase 5: Emulation (Optional)
```bash
# Simple userspace emulation (if filesystem is complete)
cp $(which qemu-arm-static) /workspace/output/firmware_unsquash/usr/bin/ 2>/dev/null
chroot /workspace/output/firmware_unsquash/ /bin/sh
```

## Phase 6: Network Service Testing (Post-Emulation)
```bash
# Scan services after emulation
nmap -sV TARGET_IP -oN /workspace/output/TARGET_iot_nmap.txt

# Common web admin ports
curl -v http://TARGET_IP:80/ 2>&1 | tee /workspace/output/TARGET_iot_http_80.txt
curl -v http://TARGET_IP:8080/ 2>&1 | tee /workspace/output/TARGET_iot_http_8080.txt
curl -v https://TARGET_IP:8443/ 2>&1 | tee /workspace/output/TARGET_iot_http_8443.txt
```

## Common Vulnerabilities to Validate
```bash
# Command injection (example path)
# curl -X POST http://TARGET_IP/ping.cgi -d "host=127.0.0.1;id"

# Default credentials (example)
# admin:admin, admin:password, root:root
```

## Report Template

```
Target: TARGET_DEVICE
Firmware: TARGET_FIRMWARE.bin
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Hardcoded credentials found
- [ ] Private keys embedded in firmware
- [ ] Command injection reachable via web interface
- [ ] Exposed services with weak auth

## Evidence
- Binwalk: /workspace/output/TARGET_binwalk.txt
- Secrets: /workspace/output/TARGET_secret_grep.txt
- Services: /workspace/output/TARGET_iot_nmap.txt

## Recommendations
1. Remove secrets and keys from firmware images
2. Enforce strong auth and disable default credentials
3. Validate and sanitize all web interface inputs
4. Disable unused services and block admin ports by default
```

## Output Files
- `/workspace/output/TARGET_firmware_fileinfo.txt` — file identification
- `/workspace/output/TARGET_binwalk.txt` — binwalk scan
- `/workspace/output/TARGET_secret_grep.txt` — secret hits
- `/workspace/output/TARGET_cmd_sinks.txt` — command sinks
- `/workspace/output/TARGET_iot_nmap.txt` — service scan

indicators: iot firmware embedded binwalk qemu
