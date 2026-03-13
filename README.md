<h1 align="center">airecon-skills</h1>
<h4 align="center">Community skill packs for <a href="https://github.com/pikpikcu/airecon">AIRecon</a></h4>

<p align="center">
  <img src="https://img.shields.io/badge/AIRecon-compatible-green.svg">
  <img src="https://img.shields.io/badge/skills-6-blue.svg">
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
| `vnc.md` | protocols | vnc, rfb, vnc brute, vnc exploit |
| `iot_firmware.md` | technologies | iot, firmware, binwalk, qemu emulation |
| `web3.md` | ctf | web3, blockchain, smart contract, reentrancy |
| `open_redirect.md` | payloads | open redirect payload, redirect bypass |
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

## Disclaimer

For authorized security testing and educational purposes only.
Do not use against systems you do not own or have explicit permission to test.
