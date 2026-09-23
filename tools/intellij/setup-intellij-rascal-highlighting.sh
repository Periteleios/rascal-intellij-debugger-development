#!/bin/bash
# Copyright (c) 2026, Periteleios
# All rights reserved. This file is licensed under the BSD 2-Clause
# License -- see the LICENSE file in this directory.

set -euo pipefail

# SUMMARY:
# Wires up IntelliJ IDEA's TextMate Bundles + File Types so that *.rsc
# (Rascal) source files get real syntax highlighting. IntelliJ has no
# built-in Rascal support, and the grammar in ../../scripts/intellij-rascal-bundle/
# has been patched (relative to its thron7/vsc-rascal upstream) to cover
# Rascal's actual keyword set and to stop doc-comment prose from being
# re-tokenized as code -- see docs/intellij_rascal_highlighting.md.
#
# Safe to re-run (idempotent) and safe to run on a machine that already
# has an ad-hoc registration from an older manual setup -- any existing
# "rascal-basic" bundle entry is replaced with one pointing at this repo.
#
# Usage:
#   tools/intellij/setup-intellij-rascal-highlighting.sh [path-to-IntelliJIdea-profile-dir]
#
# If no profile dir is given, the most recently modified "IntelliJIdea*"
# profile under the JetBrains config root is used.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_DIR="$REPO_ROOT/scripts/intellij-rascal-bundle"

if [ ! -f "$BUNDLE_DIR/syntaxes/rascal.tmLanguage.json" ]; then
  echo "error: bundle files not found at $BUNDLE_DIR" >&2
  exit 1
fi

if ! command -v python3 &> /dev/null; then
  echo "error: python3 is required (used to edit IntelliJ's XML/JSON settings)" >&2
  exit 1
fi

# --- 1. Locate the JetBrains config root ---
if [ -d "$HOME/.config/JetBrains" ]; then
  JB_ROOT="$HOME/.config/JetBrains"
elif [ -d "$HOME/Library/Application Support/JetBrains" ]; then
  JB_ROOT="$HOME/Library/Application Support/JetBrains"
else
  echo "error: no JetBrains config directory found under ~/.config or ~/Library/Application Support" >&2
  echo "       (launch IntelliJ at least once first)" >&2
  exit 1
fi

# --- 2. Pick the IntelliJ profile to configure ---
if [ "${1:-}" != "" ]; then
  PROFILE_DIR="$1"
else
  PROFILES=()
  while IFS= read -r -d '' dir; do
    PROFILES+=("$dir")
  done < <(find -L "$JB_ROOT" -maxdepth 1 -iname "IntelliJIdea*" -type d -print0)
  if [ "${#PROFILES[@]}" -eq 0 ]; then
    echo "error: no IntelliJIdea* profile found under $JB_ROOT" >&2
    exit 1
  fi
  PROFILE_DIR="$(ls -dt "${PROFILES[@]}" | head -1)"
fi

echo "=========================================================="
echo "   IntelliJ Rascal highlighting setup"
echo "=========================================================="
echo "   Bundle:   $BUNDLE_DIR"
echo "   Profile:  $PROFILE_DIR"
echo "=========================================================="

# --- 3. Warn if IntelliJ is currently running ---
if pgrep -f "jetbrains.*idea\|IntelliJ" > /dev/null 2>&1 || pgrep -x "idea" > /dev/null 2>&1; then
  echo "warning: IntelliJ appears to be running." >&2
  echo "         It can overwrite these edits on exit if left open." >&2
  read -r -p "Continue anyway? [y/N] " ans
  [ "$ans" = "y" ] || [ "$ans" = "Y" ] || exit 1
fi

OPTIONS_DIR="$PROFILE_DIR/options"
mkdir -p "$OPTIONS_DIR"

python3 - "$OPTIONS_DIR" "$BUNDLE_DIR" <<'PYEOF'
import sys, json, re, os

options_dir, bundle_dir = sys.argv[1], sys.argv[2]

# --- filetypes.xml: make sure nothing forces .rsc away from the bundle ---
ft_path = os.path.join(options_dir, "filetypes.xml")
if os.path.exists(ft_path):
    content = open(ft_path).read()
else:
    content = (
        '<application>\n'
        '  <component name="FileTypeManager" version="19">\n'
        '    <extensionMap>\n'
        '    </extensionMap>\n'
        '  </component>\n'
        '</application>\n'
    )

new_content = re.sub(r'\n?[ \t]*<mapping ext="rsc"[^>]*/>', '', content)
if new_content != content:
    print("filetypes.xml: removed existing rsc override")
with open(ft_path, 'w') as f:
    f.write(new_content)

# --- textmate.xml: register (or migrate) the rascal-basic bundle ---
tm_path = os.path.join(options_dir, "textmate.xml")
if os.path.exists(tm_path):
    tm_content = open(tm_path).read()
else:
    tm_content = (
        '<application>\n'
        '  <component name="TextMateUserBundlesSettings"><![CDATA[{}]]></component>\n'
        '</application>\n'
    )
    print("textmate.xml: creating new file")

m = re.search(r'<!\[CDATA\[(.*?)\]\]>', tm_content, re.S)
data = json.loads(m.group(1)) if m and m.group(1).strip() else {}
bundles = data.setdefault("bundles", {})

# Drop any prior registration of this bundle under a different path
# (e.g. an old ad-hoc setup) so we don't end up with two copies.
for path in [p for p, v in bundles.items() if v.get("name") == "rascal-basic"]:
    del bundles[path]

bundles[bundle_dir] = {"name": "rascal-basic", "enabled": True}
new_blob = json.dumps(data)

if m:
    tm_content = tm_content[:m.start(1)] + new_blob + tm_content[m.end(1):]
elif '<application>' in tm_content:
    tm_content = tm_content.replace(
        '<application>',
        '<application>\n  <component name="TextMateUserBundlesSettings">'
        f'<![CDATA[{new_blob}]]></component>',
        1,
    )
else:
    tm_content = (
        '<application>\n'
        f'  <component name="TextMateUserBundlesSettings"><![CDATA[{new_blob}]]></component>\n'
        '</application>\n'
    )

with open(tm_path, 'w') as f:
    f.write(tm_content)

print(f"textmate.xml: registered rascal-basic bundle -> {bundle_dir}")
PYEOF

echo "=========================================================="
echo "Done. Restart IntelliJ, then verify:"
echo "  Settings > Editor > TextMate Bundles"
echo "    -> 'rascal-basic' listed and enabled"
echo "  Settings > Editor > File Types -> search 'rsc'"
echo "    -> owned by the bundle, not Plain Text or a custom 'Rascal' type"
echo "=========================================================="
