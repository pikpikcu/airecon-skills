<h1 align="center">airecon-skills</h1>
<h4 align="center">Community skill packs for <a href="https://github.com/pikpikcu/airecon">AIRecon</a></h4>

<p align="center">
  <img src="https://img.shields.io/badge/AIRecon-compatible-green.svg">
  <img src="https://img.shields.io/badge/skills-122-blue.svg">
  <img src="https://img.shields.io/badge/LICENSE-MIT-red.svg">
</p>

Extend AIRecon's built-in knowledge base with community-contributed skill files.
Each skill is a Markdown file the agent auto-loads when it detects relevant keywords in
your prompts — no configuration required after install.

---

## Requirements

- [AIRecon](https://github.com/pikpikcu/airecon) installed (`airecon --version`)
- Python 3.12+

---

## Installation

```bash
git clone https://github.com/pikpikcu/airecon-skills.git
cd airecon-skills
chmod +x skills-install.sh
./skills-install.sh
```

### Preview before installing

```bash
./skills-install.sh --dry-run
```

### Custom AIRecon location

```bash
./skills-install.sh --skills-dir=/path/to/airecon/proxy/skills
```

---

## Uninstall

```bash
./skills-uninstall.sh
```

Removes all skill files installed by this repo and cleans up keyword mappings
from `skills.json`. Does not affect AIRecon's built-in skills.

---

## Included Skills

| Skill | Category | Keywords |
|-------|----------|---------|
| `log4shell.md` | vulnerabilities | log4shell, log4j, jndi injection, CVE-2021-44228 |
| `blind_xss.md` | vulnerabilities | blind xss, oob xss, xsshunter |
| `spring4shell.md` | vulnerabilities | spring4shell, CVE-2022-22965, tomcat jsp |
| `ssrf_advanced_bypass.md` | vulnerabilities | ssrf bypass, metadata ssrf, dns rebinding |
| `cache_deception.md` | vulnerabilities | cache deception, web cache deception, cdn cache |
| `clickjacking.md` | vulnerabilities | clickjacking, ui redressing, x-frame-options |
| `xs_leaks.md` | vulnerabilities | xs-leaks, cross-site leaks, timing attack |
| `password_reset_poisoning.md` | vulnerabilities | password reset poisoning, host header injection |
| `dom_based_vulnerabilities.md` | vulnerabilities | dom xss, dom clobbering, postmessage |
| `web_llm_attacks.md` | vulnerabilities | web llm attacks, prompt injection, rag injection |
| `exploit_validation.md` | vulnerabilities | exploit validation, vulnerability verification |
| `vnc.md` | protocols | vnc, rfb, vnc brute, vnc exploit |
| `mssql.md` | protocols | mssql, sql server, xp_cmdshell, linked server |
| `graphql_complex.md` | protocols | graphql, introspection, batching, persisted query |
| `iot_firmware.md` | technologies | iot, firmware, binwalk, qemu emulation |
| `aws_pentest.md` | technologies | aws pentest, iam, s3, ec2 metadata |
| `cicd_attacks.md` | technologies | cicd, github actions, gitlab ci, jenkins |
| `kubernetes_pentest.md` | technologies | kubernetes, k8s, kubelet, rbac |
| `github_secrets.md` | technologies | github secrets, gitleaks, trufflehog, secret scanning |
| `supabase_security.md` | technologies | supabase, postgrest, gotrue, rls |
| `wordpress_security.md` | technologies | wordpress, wp-json, wpscan, xmlrpc |
| `enterprise_web_pentest.md` | technologies | enterprise web pentest, web assessment workflow |
| `config_hardening.md` | technologies | config hardening, security headers, tls hardening |
| `web3.md` | ctf | web3, blockchain, smart contract, reentrancy |
| `android_ctf.md` | ctf | android ctf, apk reverse, smali |
| `heap_advanced.md` | ctf | heap ctf, heap exploitation, tcache |
| `kernel_exploitation.md` | ctf | kernel ctf, kernel exploit, lkm |
| `wasm_challenge.md` | ctf | wasm ctf, webassembly ctf |
| `ctf/crypto/rsa-attacks.md` | ctf/crypto | rsa attack, rsa ctf, factor rsa |
| `ctf/crypto/classic-ciphers.md` | ctf/crypto | caesar cipher, vigenere, substitution cipher |
| `ctf/crypto/ecc-attacks.md` | ctf/crypto | ecc attack, ecdsa nonce reuse, discrete log ecc |
| `ctf/crypto/advanced-math.md` | ctf/crypto | lattice attack, lll algorithm, coppersmith |
| `ctf/crypto/modern-ciphers.md` | ctf/crypto | aes ctf, padding oracle, bit flipping attack |
| `ctf/crypto/prng.md` | ctf/crypto | prng attack, mersenne twister, mt19937 crack |
| `ctf/crypto/historical.md` | ctf/crypto | enigma cipher, one time pad ctf, otp reuse |
| `ctf/crypto/exotic-crypto.md` | ctf/crypto | homomorphic encryption ctf, paillier, lattice based |
| `ctf/crypto/zkp-and-advanced.md` | ctf/crypto | zero knowledge proof ctf, zk snark, fiat shamir |
| `ctf/forensics/steganography.md` | ctf/forensics | steganography ctf, steghide, lsb steganography |
| `ctf/forensics/stego-advanced.md` | ctf/forensics | advanced steganography, dct steganography, sonic visualizer |
| `ctf/forensics/network.md` | ctf/forensics | pcap analysis, wireshark ctf, network forensics |
| `ctf/forensics/network-advanced.md` | ctf/forensics | advanced pcap, tls decryption ctf, covert channel |
| `ctf/forensics/disk-and-memory.md` | ctf/forensics | disk forensics ctf, volatility ctf, memory dump |
| `ctf/forensics/disk-recovery.md` | ctf/forensics | disk recovery ctf, file carving, foremost ctf |
| `ctf/forensics/linux-forensics.md` | ctf/forensics | linux forensics ctf, bash history forensics |
| `ctf/forensics/windows.md` | ctf/forensics | windows forensics ctf, registry forensics |
| `ctf/forensics/3d-printing.md` | ctf/forensics | 3d printing ctf, gcode analysis |
| `ctf/forensics/signals-and-hardware.md` | ctf/forensics | signal analysis ctf, sdr ctf, hardware forensics |
| `ctf/malware/pe-and-dotnet.md` | ctf/malware | pe analysis ctf, dotnet malware, dnspy |
| `ctf/malware/scripts-and-obfuscation.md` | ctf/malware | obfuscated script ctf, deobfuscation, powershell obfuscation |
| `ctf/malware/c2-and-protocols.md` | ctf/malware | c2 analysis ctf, beacon analysis, malware protocol |
| `ctf/misc/pyjails.md` | ctf/misc | pyjail ctf, python jail, python sandbox escape |
| `ctf/misc/bashjails.md` | ctf/misc | bash jail ctf, rbash escape, shell jail |
| `ctf/misc/encodings.md` | ctf/misc | encoding ctf, base64 ctf, morse code ctf |
| `ctf/misc/dns.md` | ctf/misc | dns ctf, dns tunneling ctf, txt record ctf |
| `ctf/misc/games-and-vms.md` | ctf/misc | game ctf, vm ctf, game hacking |
| `ctf/misc/games-and-vms-2.md` | ctf/misc | advanced game ctf, qemu ctf, custom vm bytecode |
| `ctf/misc/linux-privesc.md` | ctf/misc | linux privilege escalation ctf, suid exploit ctf |
| `ctf/misc/rf-sdr.md` | ctf/misc | rf ctf, sdr ctf, software defined radio ctf |
| `ctf/osint/web-and-dns.md` | ctf/osint | osint web ctf, domain osint, certificate transparency |
| `ctf/osint/social-media.md` | ctf/osint | social media osint ctf, username osint, sherlock |
| `ctf/osint/geolocation-and-media.md` | ctf/osint | geolocation ctf, image geolocation, exif osint |
| `ctf/pwn/overflow-basics.md` | ctf/pwn | buffer overflow ctf, ret2win, stack overflow ctf |
| `ctf/pwn/rop-and-shellcode.md` | ctf/pwn | rop chain ctf, shellcode ctf, ret2libc |
| `ctf/pwn/rop-advanced.md` | ctf/pwn | advanced rop ctf, srop ctf, sigreturn rop |
| `ctf/pwn/format-string.md` | ctf/pwn | format string ctf, printf vulnerability, %n format |
| `ctf/pwn/advanced.md` | ctf/pwn | heap exploitation ctf, use after free ctf, tcache |
| `ctf/pwn/advanced-exploits.md` | ctf/pwn | advanced exploit ctf, type confusion ctf, race condition |
| `ctf/pwn/advanced-exploits-2.md` | ctf/pwn | vtable overwrite, io file exploit, fsop exploit |
| `ctf/pwn/kernel.md` | ctf/pwn | kernel pwn ctf, kernel exploit, cred overwrite |
| `ctf/pwn/kernel-techniques.md` | ctf/pwn | kernel technique ctf, ret2usr, smep bypass |
| `ctf/pwn/kernel-bypass.md` | ctf/pwn | kernel mitigation bypass, kpti bypass, ebpf exploit |
| `ctf/pwn/sandbox-escape.md` | ctf/pwn | sandbox escape ctf, seccomp escape, container escape |
| `ctf/reverse/tools.md` | ctf/reverse | ghidra ctf, ida pro ctf, radare2 ctf |
| `ctf/reverse/tools-dynamic.md` | ctf/reverse | dynamic analysis ctf, gdb ctf, frida ctf |
| `ctf/reverse/tools-advanced.md` | ctf/reverse | angr symbolic ctf, z3 reverse ctf, triton ctf |
| `ctf/reverse/patterns.md` | ctf/reverse | crackme ctf, license check reverse, serial key |
| `ctf/reverse/patterns-ctf.md` | ctf/reverse | obfuscated binary ctf, anti debug ctf, packed binary |
| `ctf/reverse/patterns-ctf-2.md` | ctf/reverse | custom vm reverse, bytecode reverse, vm protection |
| `ctf/reverse/languages.md` | ctf/reverse | python bytecode ctf, pyc decompile, java reverse |
| `ctf/reverse/languages-compiled.md` | ctf/reverse | rust reverse ctf, go reverse ctf, golang binary |
| `ctf/reverse/platforms.md` | ctf/reverse | android apk reverse, ios reverse ctf, arm reverse |
| `ctf/reverse/anti-analysis.md` | ctf/reverse | anti debug reverse, debugger detection ctf, anti vm |
| `ctf/web/server-side.md` | ctf/web | sqli ctf, lfi ctf, command injection ctf, xxe ctf |
| `ctf/web/server-side-advanced.md` | ctf/web | ssrf ctf, blind sqli ctf, nosql injection ctf |
| `ctf/web/server-side-exec.md` | ctf/web | rce ctf, deserialization rce ctf, log4j ctf |
| `ctf/web/server-side-deser.md` | ctf/web | deserialization ctf, java deserialization, ysoserial |
| `ctf/web/client-side.md` | ctf/web | xss ctf, csp bypass ctf, dom xss ctf, csrf ctf |
| `ctf/web/auth-and-access.md` | ctf/web | authentication ctf, idor ctf, oauth ctf |
| `ctf/web/auth-jwt.md` | ctf/web | jwt ctf, jwt algorithm confusion, alg none jwt |
| `ctf/web/auth-infra.md` | ctf/web | saml ctf, oidc ctf, kerberos ctf, azure ad ctf |
| `ctf/web/node-and-prototype.md` | ctf/web | prototype pollution ctf, nodejs ctf, vm2 escape |
| `ctf/web/cves.md` | ctf/web | cve web ctf, wordpress ctf, drupal ctf |
| `ctf/web/web3.md` | ctf/web | web3 ctf, smart contract ctf, solidity ctf |
| `active_directory_chain.md` | postexploit | active directory, bloodhound, kerberoasting, dcsync |
| `credential_dumping.md` | postexploit | credential dumping, lsass, mimikatz, ntds |
| `http_parameter_pollution.md` | payloads | http parameter pollution, hpp, duplicate parameters |
| `csv_formula_injection.md` | payloads | csv injection, formula injection, excel injection |
| `ldap_injection.md` | payloads | ldap injection, ldap filter injection |
| `xpath_injection.md` | payloads | xpath injection, xml injection |
| `ssi_injection.md` | payloads | ssi injection, server side include |
| `redos.md` | payloads | redos, regex dos, catastrophic backtracking |
| `subdomain_enum.md` | reconnaissance | subdomain enumeration, subfinder, amass |
| `tech_stack_fingerprint.md` | reconnaissance | tech fingerprint, httpx, whatweb |
| `cloud_asset_discovery.md` | reconnaissance | cloud asset discovery, s3 bucket discovery, cdn |
| `favicon_hash.md` | reconnaissance | favicon hash, shodan favicon, mmh3 |

---

## How It Works

1. `skills-install.sh` copies `.md` files into AIRecon's `skills/` directory
2. Keywords from `manifest.json` are merged into AIRecon's `skills.json`
3. When you type a prompt containing a registered keyword, AIRecon auto-loads
   the matching skill into the agent's context

```
you: "exploit log4shell on target.com"
     ↓ keyword match: "log4shell" → skills/vulnerabilities/log4shell.md
     ↓ skill auto-loaded into context
agent: [uses log4shell skill to guide exploitation]
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add new skills and register keywords.

**Skill format summary:**

```
skills/
└── category/
    └── your_skill.md   ← practical commands, no hardcoded IPs, /workspace/output/ for files
manifest.json           ← keyword → skill path mapping
```

---

## Credits & Attribution

Some skills in this repository are derived from third-party open-source projects:

| Source | Author | License | Skills directory |
|--------|--------|---------|-----------------|
| [ljagiello/ctf-skills](https://github.com/ljagiello/ctf-skills) | [Lukasz Jagiello](https://github.com/ljagiello) | MIT | `skills/ctf/crypto/`, `skills/ctf/forensics/`, `skills/ctf/malware/`, `skills/ctf/misc/`, `skills/ctf/osint/`, `skills/ctf/pwn/`, `skills/ctf/reverse/`, `skills/ctf/web/` |

Full attribution and reproduced license text: [`skills/ctf/CREDITS.md`](skills/ctf/CREDITS.md)

---

## Disclaimer

For authorized security testing and educational purposes only.
Do not use against systems you do not own or have explicit permission to test.
