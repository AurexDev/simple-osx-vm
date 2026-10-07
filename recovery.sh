#!/usr/bin/env bash

TOOLS=(python3 dmg2img)
for t in "${TOOLS[@]}"; do command -v "$t" &>/dev/null || { echo "$t not found"; exit 1; }; done

OC_DIR="opencore"
RECOVERY_DIR="recovery"
MACRECOVERY_PY="$OC_DIR/Utilities/macrecovery/macrecovery.py"
VERSION_FILE="$RECOVERY_DIR/version.txt"

if [ ! -f "$MACRECOVERY_PY" ]; then
    echo "macrecovery.py not found, did you run setup.sh?"
    exit 1
fi

echo "select macOS recovery version to download:"

names=(
    "High Sierra"
    "Mojave"
    "Catalina"
    "Big Sur"
    "Monterey"
    "Ventura"
    "Sonoma"
    "Sequoia"
    "Tahoe (Latest)"
)

boards=(
    "Mac-7BA5B2D9E42DDD94"
    "Mac-7BA5B2DFE22DDD8C"
    "Mac-CFF7D910A743CAAF"
    "Mac-2BD1B31983FE1663"
    "Mac-E43C1C25D4880AD6"
    "Mac-B4831CEBD52A0C4C"
    "Mac-827FAC58A8FDFA22"
    "Mac-7BA5B2D9E42DDD94"
    "Mac-CFF7D910A743CAAF"
)

models=(
    "00000000000J80300"
    "00000000000KXPG00"
    "00000000000PHCD00"
    "00000000000000000"
    "00000000000000000"
    "00000000000000000"
    "00000000000000000"
    "00000000000000000"
    "00000000000000000"
)

extras=(
    ""
    ""
    ""
    ""
    ""
    ""
    ""
    ""
    "-os latest"
)

PS3="enter choice [1-${#names[@]}]: "
select opt in "${names[@]}"; do
    if [ -n "$opt" ]; then
        idx=$((REPLY - 1))
        name="${names[$idx]}"
        board="${boards[$idx]}"
        model="${models[$idx]}"
        extra="${extras[$idx]}"

        DMG_PATH="$RECOVERY_DIR/com.apple.recovery.boot/BaseSystem.dmg"
        IMG_PATH="$RECOVERY_DIR/BaseSystem.img"

        current_cached_version=""
        if [ -f "$VERSION_FILE" ]; then
            current_cached_version=$(cat "$VERSION_FILE")
        fi

		if [ -n "$current_cached_version" ] && [ "$current_cached_version" != "$name" ]; then
            echo "Cached recovery is for '$current_cached_version', but you selected '$name'. Clearing old cache..."
            rm -rf "$RECOVERY_DIR"
        fi

        mkdir -p "$RECOVERY_DIR"

        if [ -f "$DMG_PATH" ]; then
            echo "using cached recovery for $name"
        else
            echo "downloading $name recovery"
            cd "$RECOVERY_DIR" || exit 1
            if [ -n "$extra" ]; then
                python3 "../$MACRECOVERY_PY" -b "$board" -m "$model" $extra download
            else
                python3 "../$MACRECOVERY_PY" -b "$board" -m "$model" download
            fi
            cd - >/dev/null || exit 1
            
            echo "$name" > "$VERSION_FILE"
        fi

        if [ ! -f "$IMG_PATH" ] && [ -f "$DMG_PATH" ]; then
            echo "converting BaseSystem.dmg to raw image..."
            dmg2img "$DMG_PATH" "$IMG_PATH"
        fi

        echo "recovery image ready at $IMG_PATH"
        break
    else
        echo "invalid selection"
    fi
done
