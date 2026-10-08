#!/usr/bin/env bash
set -euo pipefail

TOOLS=(git python3)
for t in "${TOOLS[@]}"; do command -v "$t" &>/dev/null || { echo "$t not found"; exit 1; }; done

PLIST="${1:-config.plist}"

if [ ! -f esp/EFI/OC/config.plist ]; then
echo "config.plist not found, did you run setup.sh"
exit 1
fi

if [ -d propertree ]; then
    git -C propertree pull --ff-only
else
    echo "propertree not found, cloning"
    git clone --depth 1 https://github.com/corpnewt/ProperTree.git propertree
fi

python3 propertree/ProperTree.py "$PLIST"

if [ "$PLIST" = "config.plist" ]; then
echo "re-run setup.sh to update esp!"
fi
