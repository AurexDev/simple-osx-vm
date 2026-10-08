#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "reims/vendor/qemu/build/qemu-system-x86_64" ]; then
    echo "reims binary not found (did you run reims.sh?)"
    exit 1
fi

exec env QEMU_BIN="reims/vendor/qemu/build/qemu-system-x86_64" REIMS=1 ./run.sh
