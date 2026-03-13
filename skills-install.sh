#!/usr/bin/env bash
# AIRecon Skills Installer
# Usage: ./skills-install.sh [--dry-run] [--skills-dir PATH]
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

DRY_RUN=false
SKILLS_DIR_OVERRIDE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run)       DRY_RUN=true ;;
    --skills-dir=*)  SKILLS_DIR_OVERRIDE="${arg#*=}" ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--skills-dir=PATH]"
      echo ""
      echo "Options:"
      echo "  --dry-run          Show what would be installed without making changes"
      echo "  --skills-dir=PATH  Override auto-detected AIRecon skills directory"
      exit 0 ;;
  esac
done

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   AIRecon Community Skills Installer     ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

# ── Detect AIRecon installation ───────────────────────────────────────────────
if [[ -n "$SKILLS_DIR_OVERRIDE" ]]; then
  PROXY_DIR="$SKILLS_DIR_OVERRIDE/.."
  SKILLS_DIR="$SKILLS_DIR_OVERRIDE"
else
  info "Detecting AIRecon installation..."
  PROXY_DIR=$(python3 -c "import airecon.proxy.system; import os; print(os.path.dirname(airecon.proxy.system.__file__))" 2>/dev/null) || \
    error "AIRecon is not installed. Install it first: pip install airecon"
  SKILLS_DIR="$PROXY_DIR/skills"
fi

if [[ ! -d "$SKILLS_DIR" ]]; then
  error "Skills directory not found: $SKILLS_DIR"
fi

SKILLS_JSON="$PROXY_DIR/data/skills.json"
if [[ ! -f "$SKILLS_JSON" ]]; then
  error "skills.json not found: $SKILLS_JSON"
fi

success "AIRecon proxy dir: $PROXY_DIR"
success "Skills dir:        $SKILLS_DIR"

# ── Install skill files ───────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SKILLS="$REPO_DIR/skills"

if [[ ! -d "$SRC_SKILLS" ]]; then
  error "skills/ directory not found in repo: $SRC_SKILLS"
fi

INSTALLED=0
SKIPPED=0

info "Installing skill files..."
while IFS= read -r -d '' src_file; do
  rel="${src_file#$SRC_SKILLS/}"
  dst_file="$SKILLS_DIR/$rel"
  dst_dir="$(dirname "$dst_file")"

  if [[ -f "$dst_file" ]]; then
    warn "Skipping (already exists): $rel"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if $DRY_RUN; then
    info "[DRY-RUN] Would install: $rel"
  else
    mkdir -p "$dst_dir"
    cp "$src_file" "$dst_file"
    success "Installed: $rel"
  fi
  INSTALLED=$((INSTALLED + 1))
done < <(find "$SRC_SKILLS" -name "*.md" -print0)

# ── Update skills.json keyword mapping ───────────────────────────────────────
MANIFEST="$REPO_DIR/manifest.json"
if [[ ! -f "$MANIFEST" ]]; then
  warn "manifest.json not found — skipping keyword registration"
else
  info "Registering keywords in skills.json..."

  if $DRY_RUN; then
    info "[DRY-RUN] Would merge manifest.json keywords into skills.json"
  else
    python3 - "$SKILLS_JSON" "$MANIFEST" << 'PYEOF'
import json, sys

skills_json_path = sys.argv[1]
manifest_path    = sys.argv[2]

with open(skills_json_path) as f:
    skills_data = json.load(f)

with open(manifest_path) as f:
    manifest = json.load(f)

kw_map = skills_data.get("skill_keywords", {})
added = 0

for entry in manifest.get("skills", []):
    skill_path = entry["path"]
    for kw in entry.get("keywords", []):
        if kw not in kw_map:
            kw_map[kw] = skill_path
            added += 1
        # else: don't override existing mappings

skills_data["skill_keywords"] = kw_map

with open(skills_json_path, "w") as f:
    json.dump(skills_data, f, indent=2)

print(f"Added {added} new keyword mappings to skills.json")
PYEOF
    success "Keywords registered in skills.json"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "  ──────────────────────────────────────────"
if $DRY_RUN; then
  echo -e "  ${YELLOW}DRY-RUN complete — no files were modified${NC}"
  echo "  Skills that would be installed: $INSTALLED"
else
  echo -e "  ${GREEN}Installation complete!${NC}"
  echo "  Installed: $INSTALLED  |  Skipped (already exist): $SKIPPED"
fi
echo "  ──────────────────────────────────────────"
echo ""
