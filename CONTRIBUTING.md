# Contributing to airecon-skills

## Adding a New Skill

### 1. Create the skill file

Place your `.md` file in the correct category directory:

| Directory | Content |
|-----------|---------|
| `skills/vulnerabilities/` | Specific vuln classes (CVEs, techniques) |
| `skills/payloads/` | Payload collections for active exploitation |
| `skills/protocols/` | Protocol-specific attack & enumeration |
| `skills/technologies/` | Framework / platform / technology testing |
| `skills/reconnaissance/` | Discovery and fingerprinting techniques |
| `skills/postexploit/` | Post-exploitation, pivoting, persistence |
| `skills/ctf/` | CTF-specific techniques |

### 2. Skill file format

```markdown
# Skill Title

## Overview
Brief description of what this skill covers.

## [Section]
Content...

indicators: keyword1 keyword2 keyword3
```

The `indicators:` line at the bottom is optional but helps AIRecon auto-detect
when to load this skill (it's a machine-readable hint, not the primary mechanism).

### 3. Register keywords in manifest.json

Add an entry to `manifest.json`:

```json
{
  "path": "vulnerabilities/your_skill.md",
  "keywords": [
    "your keyword", "alternate name", "tool name", "cve-xxxx-xxxxx"
  ]
}
```

**Keyword rules:**
- All lowercase
- Single words or short phrases (no uppercase, no leading/trailing spaces)
- Be specific — avoid generic words like "test", "attack", "hack"
- Cover both the technique name AND common tool names users might mention

### 4. Quality checklist

- [ ] Includes practical commands (not just theory)
- [ ] Commands use `/workspace/output/` for output files (AIRecon convention)
- [ ] No hardcoded IPs — use `TARGET`, `ATTACKER_IP`, `CALLBACK` as placeholders
- [ ] Includes a report template section for confirmed findings
- [ ] Keywords in `manifest.json` are specific and won't cause false-positive loading

### 5. Submit a PR

```bash
git checkout -b skill/your-skill-name
# add files
git add skills/category/your_skill.md manifest.json
git commit -m "feat(skill): add your-skill-name"
gh pr create
```

## Skill Quality Standards

Skills in this repo should be:
- **Practical** — runnable commands, not just descriptions
- **Tested** — verified against real targets or lab environments
- **Ethical** — for authorized testing only
- **Focused** — one topic per file, ~50-200 lines
