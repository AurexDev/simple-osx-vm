#!/usr/bin/env bash

CACHE_MINUTES=1440

TOOLS=(grep tail cut sed sha256sum curl unzip find python3 tar)
for t in "${TOOLS[@]}"; do command -v "$t" &>/dev/null || { echo "$t not found"; exit 1; }; done

BUILD_TYPE="${1:-release}"
BUILD_TYPE=$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')

if [ "$BUILD_TYPE" != "release" ] && [ "$BUILD_TYPE" != "debug" ]; then
    echo "unknown build type '$BUILD_TYPE'. use 'release' or 'debug'."
    exit 1
fi

TMP_DIR="tmp"
OC_DIR="opencore"
OVMF_DIR="edk2-ovmf"
ESP_DIR="esp/EFI/OC"
KEXTS_DIR="$ESP_DIR/Kexts"
ACPI_DIR="$ESP_DIR/ACPI"
DRIVERS_DIR="$ESP_DIR/Drivers"
TOOLS_DIR="$ESP_DIR/Tools"

mkdir -p "$TMP_DIR" "$KEXTS_DIR"

get_release_json() {
    local repo="$1"
    local safe_name
    safe_name=$(echo "$repo" | tr '/' '_')
    local json_path="$TMP_DIR/${safe_name}_release.json"

    if [ ! -f "$json_path" ] || [ -n "$(find "$json_path" -mmin +"$CACHE_MINUTES" 2>/dev/null)" ]; then
        echo "fetching release info for $repo"
        curl -s "https://api.github.com/repos/$repo/releases/latest" > "$json_path"
    else
        echo "using cached release info for $repo"
    fi
    cat "$json_path"
}

fetch_oc() {
    local repo="acidanthera/OpenCorePkg"
    local json
    json=$(get_release_json "$repo")

    local suffix="RELEASE.zip"
    if [ "$BUILD_TYPE" = "debug" ]; then
        suffix="DEBUG.zip"
    fi

    local url
    url=$(echo "$json" | grep "browser_download_url" | grep "$suffix" | head -n 1 | cut -d'"' -f4)

    if [ -z "$url" ] && [ "$BUILD_TYPE" = "debug" ]; then
        echo "debug build for OpenCore not found, falling back to RELEASE"
        suffix="RELEASE.zip"
        url=$(echo "$json" | grep "browser_download_url" | grep "$suffix" | head -n 1 | cut -d'"' -f4)
    fi

    local exp_sha
    exp_sha=$(echo "$json" | grep -B 6 "$suffix" | grep "digest" | tail -n 1 | cut -d'"' -f4 | sed 's/sha256://')

    local zip_path="$TMP_DIR/opencore_${BUILD_TYPE}.zip"

    if [ ! -f "$zip_path" ] || [ -n "$(find "$zip_path" -mmin +"$CACHE_MINUTES" 2>/dev/null)" ]; then
        echo "downloading opencorepkg ($suffix)"
        curl -L -o "$zip_path" "$url"
    else
        echo "using cached opencorepkg ($suffix)"
    fi

    echo "verifying opencore"
    local local_sha
    local_sha=$(sha256sum "$zip_path" | awk '{print $1}')

    if [ "$exp_sha" != "$local_sha" ]; then
        echo "opencore verification failed"
        rm -f "$zip_path"
        exit 1
    fi

    rm -rf "$OC_DIR"
    mkdir -p "$OC_DIR"
    unzip -q -o "$zip_path" -d "$OC_DIR"

    echo "copying efi to esp"
    mkdir -p "esp"
    if [ ! -d "$OC_DIR/X64" ]; then
        echo "x64 folder not found in archive"
        exit 1
    fi
    mkdir -p "esp/EFI"
    cp -r "$OC_DIR/X64/EFI/." esp/EFI/

    if [ ! -f "config.plist" ]; then
        echo "config.plist not found"
        exit 1
    fi
    cp -a config.plist "$ESP_DIR/config.plist"
}

fetch_ovmf() {
    local repo="osdev0/edk2-ovmf-nightly"
    local json
    json=$(get_release_json "$repo")

    local url
    url=$(echo "$json" | grep "browser_download_url" | grep "tar.xz" | head -n 1 | cut -d'"' -f4)
    local exp_sha
    exp_sha=$(echo "$json" | grep -B 6 "tar.xz" | grep "digest" | tail -n 1 | cut -d'"' -f4 | sed 's/sha256://')

    local tar_path="$TMP_DIR/edk2-ovmf.tar.xz"

    if [ ! -f "$tar_path" ] || [ -n "$(find "$tar_path" -mmin +"$CACHE_MINUTES" 2>/dev/null)" ]; then
        echo "downloading ovmf"
        curl -L -o "$tar_path" "$url"
    else
        echo "using cached ovmf"
    fi

    echo "verifying ovmf"
    local local_sha
    local_sha=$(sha256sum "$tar_path" | awk '{print $1}')

    if [ "$exp_sha" != "$local_sha" ]; then
        echo "ovmf verification failed"
        rm -f "$tar_path"
        exit 1
    fi

    rm -rf "$OVMF_DIR"
    mkdir -p "$OVMF_DIR"
    tar -xf "$tar_path"
}

fetch_kext() {
    local repo="$1"
    shift
    local targets=("$@")
    local repo_name
    repo_name=$(basename "$repo")

    local json
    json=$(get_release_json "$repo")

    local suffix="RELEASE.zip"
    if [ "$BUILD_TYPE" = "debug" ]; then
        suffix="DEBUG.zip"
    fi

    local url
    url=$(echo "$json" | grep "browser_download_url" | grep "$suffix" | head -n 1 | cut -d'"' -f4)

    if [ -z "$url" ] && [ "$BUILD_TYPE" = "debug" ]; then
        echo "debug build for $repo_name not found, falling back to RELEASE"
        suffix="RELEASE.zip"
        url=$(echo "$json" | grep "browser_download_url" | grep "$suffix" | head -n 1 | cut -d'"' -f4)
    fi

    if [ -z "$url" ]; then
        echo "could not find release download URL for $repo"
        return 1
    fi

    local zip_path="$TMP_DIR/${repo_name}_${BUILD_TYPE}.zip"
    local extracted_dir="$TMP_DIR/${repo_name}_${BUILD_TYPE}"

    if [ ! -f "$zip_path" ] || [ -n "$(find "$zip_path" -mmin +"$CACHE_MINUTES" 2>/dev/null)" ]; then
        echo "downloading $repo_name ($suffix)..."
        curl -L -o "$zip_path" "$url"
    else
        echo "using cached $repo_name ($suffix)"
    fi

    mkdir -p "$extracted_dir"
    unzip -q -o "$zip_path" -d "$extracted_dir"

    for target in "${targets[@]}"; do
        local found_path=""

        if [ -d "$extracted_dir/$target" ]; then
            found_path="$extracted_dir/$target"
        else
            found_path=$(find "$extracted_dir" -name "$(basename "$target")" -print -quit)
        fi

        if [ -n "$found_path" ] && [ -e "$found_path" ]; then
            echo "installing $(basename "$target") to $KEXTS_DIR/"
            rm -rf "$KEXTS_DIR/$(basename "$target")"
            cp -r "$found_path" "$KEXTS_DIR/"
        else
            echo "target '$target' not found in $repo archive"
        fi
    done
}

fetch_acpi_patches() {
    local patches=(
        "https://github.com/dortania/Getting-Started-With-ACPI/raw/refs/heads/master/extra-files/compiled/SSDT-EC-DESKTOP.aml"
        "https://github.com/dortania/Getting-Started-With-ACPI/raw/refs/heads/master/extra-files/compiled/SSDT-EC-USBX-DESKTOP.aml"
    )

    mkdir -p "$ACPI_DIR"

    for url in "${patches[@]}"; do
        local filename
        filename=$(basename "$url")
        local dest="$ACPI_DIR/$filename"

        if [ ! -f "$dest" ] || [ -n "$(find "$dest" -mmin +"$CACHE_MINUTES" 2>/dev/null)" ]; then
            echo "downloading acpi patch: $filename"
            curl -L -o "$dest" "$url"
        else
            echo "using cached acpi patch: $filename"
        fi
    done
}

generate_smbios() {
    local model="iMacPro1,1"
    local macserial_bin="$OC_DIR/Utilities/macserial/macserial.linux"

    if [ ! -f "$macserial_bin" ]; then
        echo "macserial not found"
        exit 1
    fi

    echo "generating smbios"
    local output
    output=$("$macserial_bin" -m "$model" -n 1)

    local mlb serial
    read -r mlb serial < <(echo "$output" | awk -F'\\s+\\|\\s+' '{print $1, $2}')

    local uuid
    if command -v uuidgen &>/dev/null; then
        uuid=$(uuidgen)
    else
        uuid=$(python3 -c 'import uuid; print(str(uuid.uuid4()).upper())')
    fi

    local target_config="$ESP_DIR/config.plist"
    if [ ! -f "$target_config" ]; then
        target_config="config.plist"
    fi

    sed -i "s|SERIAL_HERE|$serial|g" "$target_config"
    sed -i "s|MLB_HERE|$mlb|g" "$target_config"
    sed -i "s|UUID_HERE|$uuid|g" "$target_config"
}

cleanup_efi() {
    local keep_drivers=(
        "OpenRuntime.efi"
        "OpenCanopy.efi"
        "OpenHfsPlus.efi"
        "ResetNvramEntry.efi"
        "ToggleSipEntry.efi"
    )

    local keep_tools=(
        "OpenShell.efi"
        "CleanNvram.efi"
    )

    if [ -d "$DRIVERS_DIR" ]; then
        for file in "$DRIVERS_DIR"/*; do
            local filename
            filename=$(basename "$file")
            local keep=0

            for allowed in "${keep_drivers[@]}"; do
                if [ "$filename" = "$allowed" ]; then
                    keep=1
                    break
                fi
            done

            if [ "$keep" -eq 0 ]; then
                rm -f "$file"
            fi
        done
    fi

    if [ -d "$TOOLS_DIR" ]; then
        for file in "$TOOLS_DIR"/*; do
            local filename
            filename=$(basename "$file")
            local keep=0

            for allowed in "${keep_tools[@]}"; do
                if [ "$filename" = "$allowed" ]; then
                    keep=1
                    break
                fi
            done

            if [ "$keep" -eq 0 ]; then
                rm -f "$file"
            fi
        done
    fi
}

fetch_oc
fetch_ovmf
fetch_acpi_patches
fetch_kext "acidanthera/Lilu" "Lilu.kext"
fetch_kext "acidanthera/VirtualSMC" "VirtualSMC.kext"
fetch_kext "acidanthera/WhateverGreen" "WhateverGreen.kext"
fetch_kext "acidanthera/VoodooPS2" "VoodooPS2Controller.kext" "VoodooPS2Keyboard.kext"
generate_smbios
cleanup_efi

echo "finished"
