# QEMU Emulation — Cross-Architecture Binary & Firmware Testing

Run ARM/MIPS/PowerPC/RISC-V binaries on x86-64 without physical hardware. Essential for IoT firmware analysis, embedded CTF, and testing cross-compiled payloads.

## Install

```bash
# Full QEMU (system + user-mode):
sudo apt-get install -y qemu-system-x86 qemu-system-arm qemu-system-mips \
  qemu-user qemu-user-static binfmt-support

# For chroot emulation:
sudo apt-get install -y debootstrap schroot

# Cross-compilation toolchains:
sudo apt-get install -y gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu \
  gcc-mips-linux-gnu gcc-mipsel-linux-gnu

# pwntools for scripting:
pip install pwntools --break-system-packages

# firmwalker (firmware analysis):
git clone https://github.com/craigz28/firmwalker /opt/firmwalker

# binwalk (firmware extraction):
sudo apt-get install -y binwalk
```

---

## Phase 1: User-Mode QEMU (Single Binary)

```bash
# Run ARM binary directly on x86-64:
qemu-arm ./arm_binary
qemu-arm-static ./arm_binary   # static version (works in chroot)

# Run AArch64 (ARM64):
qemu-aarch64 ./aarch64_binary
qemu-aarch64-static ./aarch64_binary

# Run MIPS (big-endian):
qemu-mips ./mips_binary

# Run MIPSel (little-endian):
qemu-mipsel ./mipsel_binary

# Run RISC-V:
qemu-riscv64 ./riscv64_binary

# With library path (for dynamically linked binaries):
qemu-arm -L /usr/arm-linux-gnueabihf ./arm_binary
qemu-mips -L /usr/mips-linux-gnu ./mips_binary

# Set environment variables:
qemu-arm -E LD_LIBRARY_PATH=/lib:./lib ./arm_binary

# Pass arguments:
qemu-arm ./arm_binary arg1 arg2 "arg3 with spaces"

# Stdin input:
echo "test_input" | qemu-arm ./arm_binary
qemu-arm ./arm_binary < input_file

# With GDB stub (remote debugging):
qemu-arm -g 1234 ./arm_binary   # waits on port 1234
# In GDB: target remote :1234
```

---

## Phase 2: GDB Debugging Cross-Arch Binaries

```bash
# Debug ARM binary with GDB:
# Terminal 1:
qemu-arm -g 1234 ./arm_binary

# Terminal 2:
gdb-multiarch ./arm_binary
(gdb) target remote :1234
(gdb) break main
(gdb) continue
(gdb) info registers
(gdb) x/20wx $sp   # ARM stack pointer
(gdb) disassemble   # current function

# ARM-specific registers:
# r0-r3 = arguments/return
# r13 (sp), r14 (lr), r15 (pc)
# (gdb) p $r0
# (gdb) p $pc

# MIPS-specific registers:
# a0-a3 = arguments, v0-v1 = return values
# sp, ra (return address), pc
```

---

## Phase 3: Firmware Extraction & Analysis

```bash
# Identify firmware file type:
file firmware.bin
binwalk firmware.bin   # scan for embedded filesystems/archives

# Extract firmware:
binwalk -e firmware.bin -C firmware_extracted/
ls firmware_extracted/

# Common firmware structures:
# Squashfs filesystem → mounted as read-only
# JFFS2 → flash filesystem
# CRAMFS → compressed ROM filesystem
# Raw rootfs → tar/gzip archive

# Mount squashfs:
sudo mount -o loop firmware_extracted/_firmware.bin.extracted/squashfs-root/ /mnt/firmware

# OR extract squashfs directly:
sudo unsquashfs firmware_extracted/*.squashfs
ls squashfs-root/

# firmwalker — analyze extracted firmware:
bash /opt/firmwalker/firmwalker.sh ./squashfs-root/ output.txt
cat output.txt | grep -E "passwd|shadow|config|ssl|private|key|certificate"
```

---

## Phase 4: Chroot Emulation (Full Environment)

```bash
# Run firmware binaries in emulated chroot environment:

# Identify target architecture:
file squashfs-root/bin/busybox
# → ELF 32-bit MSB executable, MIPS, MIPS32

# Copy static QEMU to firmware root:
cp /usr/bin/qemu-mips-static squashfs-root/usr/bin/
cp /usr/bin/qemu-arm-static squashfs-root/usr/bin/

# Chroot into firmware:
sudo chroot squashfs-root /bin/sh

# Inside chroot:
ls /
uname -a
cat /etc/passwd
cat /etc/shadow   # may have hashed passwords
netstat -tlnp     # open ports in firmware

# Start web service (common in IoT):
/usr/sbin/httpd &   # or whatever the web server is
/bin/busybox httpd -p 8080 -h /www &

# Test from host:
curl http://localhost:8080/

# Mount proc/sys for full compatibility:
sudo mount -t proc proc squashfs-root/proc
sudo mount -t sysfs sys squashfs-root/sys
sudo mount -o bind /dev squashfs-root/dev
sudo chroot squashfs-root /bin/sh
```

---

## Phase 5: QEMU System Mode (Full VM)

```bash
# Full ARM system emulation:

# Create disk image:
qemu-img create -f qcow2 arm_disk.qcow2 4G

# Boot ARM Linux:
qemu-system-arm \
  -M virt \
  -cpu cortex-a15 \
  -m 512M \
  -kernel vmlinuz-arm \
  -initrd initrd.img-arm \
  -drive if=virtio,file=arm_disk.qcow2 \
  -append "root=/dev/vda1 console=ttyAMA0" \
  -nographic \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-device,netdev=net0

# SSH into emulated ARM system:
ssh -p 2222 root@localhost

# MIPS system emulation:
qemu-system-mips \
  -M malta \
  -cpu MIPS32r2-generic \
  -m 256M \
  -kernel vmlinux-mips \
  -nographic \
  -append "root=/dev/hda1 console=ttyS0" \
  -netdev user,id=net0,hostfwd=tcp::2223-:22 \
  -device e1000,netdev=net0

# Kernel CTF setup (from ctf/kernel_exploitation.md):
qemu-system-x86_64 \
  -kernel bzImage \
  -initrd rootfs.cpio \
  -append "console=ttyS0 nokaslr nopti" \
  -m 128M \
  -nographic \
  -s    # GDB stub on port 1234
```

---

## Phase 6: Network Service Testing in Emulation

```bash
# After chroot/system emulation, test exposed services:

# Port forwarding in QEMU user networking:
# -netdev user,hostfwd=tcp::8080-:80,hostfwd=tcp::8443-:443

# Find listening services in chroot:
# (using netstat inside chroot or ps)
ps aux | grep -v "\[" | head -20
netstat -tlnp 2>/dev/null || ss -tlnp

# Common IoT services to test:
curl http://localhost:8080/                     # web interface
curl http://localhost:8080/cgi-bin/admin.cgi    # CGI admin
curl -u admin:admin http://localhost:8080/      # default creds

# Test for command injection in web params:
curl "http://localhost:8080/cgi-bin/ping.cgi?host=127.0.0.1;id"
curl "http://localhost:8080/cgi-bin/exec.cgi" -d "cmd=ls /etc/&"
```

---

## Phase 7: Cross-Compile for Exploitation

```bash
# Compile exploit for ARM target:
arm-linux-gnueabihf-gcc exploit.c -o exploit_arm -static
qemu-arm ./exploit_arm

# Compile for MIPS:
mips-linux-gnu-gcc exploit.c -o exploit_mips -static
qemu-mips ./exploit_mips

# Shellcode testing:
python3 -c "
from pwn import *
context.arch = 'arm'     # or 'mips', 'aarch64', 'powerpc'
context.endian = 'big'   # or 'little'
shellcode = asm(shellcraft.sh())
print(hexdump(shellcode))
"

# Test shellcode with QEMU:
python3 -c "
from pwn import *
context.arch = 'arm'
sc = asm(shellcraft.arm.sh())
open('/tmp/sc', 'wb').write(sc)
"
# Run with execve in minimal wrapper:
gcc -o runner runner.c -static   # runner.c: cast sc to function ptr and call
qemu-arm ./runner
```

---

## Phase 8: CVE Testing on Emulated Devices

```bash
# Common IoT vulnerability testing in emulated firmware:

# Directory traversal:
curl "http://localhost:8080/../../etc/passwd"
curl "http://localhost:8080/?file=../../etc/shadow"

# Command injection:
curl "http://localhost:8080/cgi-bin/apply.cgi" -d "submit_button=ping&ping_ip=127.0.0.1;id"

# Buffer overflow in CGI (check with ASAN or GDB):
python3 -c "print('A'*1000)" | curl "http://localhost:8080/cgi-bin/vuln.cgi" -d @-

# Hard-coded credentials (from firmwalker output):
grep -r "admin:admin\|root:root\|password=" squashfs-root/etc/ squashfs-root/www/

# SSL private keys:
find squashfs-root/ -name "*.pem" -o -name "*.key" -o -name "*.crt" 2>/dev/null
grep -r "BEGIN PRIVATE KEY\|BEGIN RSA PRIVATE KEY" squashfs-root/ 2>/dev/null
```

---

## Quick Reference — Architecture Flags

```bash
# Architecture detection:
file binary
readelf -h binary | grep "Machine\|Class\|Data"

# Machine values:
# ARM (32-bit):   EM_ARM (40)       → qemu-arm, gcc-arm-linux-gnueabihf
# AArch64:        EM_AARCH64 (183)  → qemu-aarch64, gcc-aarch64-linux-gnu
# MIPS big:       EM_MIPS (8) MSB   → qemu-mips, mips-linux-gnu-gcc
# MIPS little:    EM_MIPS (8) LSB   → qemu-mipsel, mipsel-linux-gnu-gcc
# PowerPC:        EM_PPC (20)       → qemu-ppc, powerpc-linux-gnu-gcc
# RISC-V:         EM_RISCV (243)    → qemu-riscv64, riscv64-linux-gnu-gcc
```

---

## Pro Tips

1. **User-mode first** — `qemu-arm ./binary` is fastest; only switch to system mode for kernel/network testing
2. **Copy qemu-*-static to firmware root** before chroot — dynamic QEMU won't work in chroot
3. **`-g 1234` flag** — enables GDB stub; use `gdb-multiarch` + `target remote :1234`
4. **binwalk -e** sometimes fails on custom formats — use `dd` to extract at known offsets
5. **firmwalker** — automated sensitive file finder; check output for hardcoded creds/keys first
6. **Port forwarding** — `hostfwd=tcp::8080-:80` in user networking maps host:8080 → guest:80
7. **Static binaries** — compile exploits with `-static` for chroot environments without libc

## Summary

QEMU flow: `file firmware.bin` → `binwalk -e` extract → `file squashfs-root/bin/busybox` for arch → `cp qemu-*-static squashfs-root/usr/bin/` → `chroot squashfs-root /bin/sh` → test services + firmwalker for creds/keys → or `qemu-<arch> -g 1234 ./binary` + `gdb-multiarch` for binary CTF debugging.
