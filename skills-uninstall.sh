#!/usr/bin/env bash
# AIRecon Skills Uninstaller — removes skills installed from this repo
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

PROXY_DIR=$(python3 -c "import airecon.proxy.system; import os; print(os.path.dirname(airecon.proxy.system.__file__))" 2>/dev/null) || \
  error "AIRecon is not installed."

SKILLS_DIR="$PROXY_DIR/skills"
SKILLS_JSON="$PROXY_DIR/data/skills.json"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SKILLS="$REPO_DIR/skills"
MANIFEST="$REPO_DIR/manifest.json"

echo ""
info "Uninstalling airecon-skills from $SKILLS_DIR..."

REMOVED=0
while IFS= read -r -d '' src_file; do
  rel="${src_file#$SRC_SKILLS/}"
  dst_file="$SKILLS_DIR/$rel"
  if [[ -f "$dst_file" ]]; then
    rm "$dst_file"
    success "Removed: $rel"
    REMOVED=$((REMOVED + 1))
  fi
done < <(find "$SRC_SKILLS" -name "*.md" -print0)

# Remove registered keywords
if [[ -f "$SKILLS_JSON" && -f "$MANIFEST" ]]; then
  info "Removing keywords from skills.json..."
  python3 - "$SKILLS_JSON" "$MANIFEST" << 'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    skills_data = json.load(f)

with open(sys.argv[2]) as f:
    manifest = json.load(f)

kw_map = skills_data.get("skill_keywords", {})
to_remove = set()
for entry in manifest.get("skills", []):
    for kw in entry.get("keywords", []):
        if kw in kw_map and kw_map[kw] == entry["path"]:
            to_remove.add(kw)

for kw in to_remove:
    del kw_map[kw]

skills_data["skill_keywords"] = kw_map
with open(sys.argv[1], "w") as f:
    json.dump(skills_data, f, indent=2)

print(f"Removed {len(to_remove)} keyword mappings from skills.json")
PYEOF
fi

echo ""
success "Uninstall complete. Removed $REMOVED skill files."
echo ""
