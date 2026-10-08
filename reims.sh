#!/usr/bin/env bash
set -euo pipefail

TOOLS=(cargo git ninja llvm-as spirv-as)
for t in "${TOOLS[@]}"; do command -v "$t" &>/dev/null || { echo "$t not found"; exit 1; }; done

OUTPUT=reims/vendor/qemu/build/qemu-system-x86_64

if [ -d reims ]; then
    git -C reims pull --ff-only
else
    echo "reims not found, cloning"
    git clone --depth 1 https://github.com/steelbrain/reims-vgpu.git reims
fi

echo "patching reims"
sed -i 's/submodule update --init/submodule update --init --verbose --depth 1/' reims/scripts/qemu-build/qemu-build.sh

echo "building reims"
reims/scripts/qemu-build/qemu-build.sh --target x86_64 --backend vulkan
reims/crates/reims-vgpu-efi/scripts/reims-vgpu-efi-rom/reims-vgpu-efi-rom.sh
