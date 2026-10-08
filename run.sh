#!/usr/bin/env bash
set -euo pipefail

TOOLS=(qemu-system-x86_64)
for t in "${TOOLS[@]}"; do command -v "$t" &>/dev/null || { echo "$t not found"; exit 1; }; done

if [ ! -d "esp" ]; then
    echo "esp directory not found, did you run setup.sh?"
    exit 1
fi

OVMF_CODE="edk2-ovmf/ovmf-code-x86_64.fd"
OVMF_VARS="edk2-ovmf/ovmf-vars-x86_64.fd"

if [ ! -f "$OVMF_CODE" ] || [ ! -f "$OVMF_VARS" ]; then
    echo "ovmf firmware files not found in edk2-ovmf/"
    exit 1
fi

if [ ! -d "recovery" ]; then
    echo "recovery directory not found, did you run recovery.sh? (use norecovery to omit)"
    exit 1
fi

QEMU="${QEMU_BIN:-qemu-system-x86_64}"
RAM_ALLOCATED="${RAM_ALLOCATED:-12G}"
TOTAL_CPUS="${TOTAL_CPUS:-4}"
QCOW_DISK="${QCOW_DISK:-osx_disk.qcow2}"

CPU_MODEL="${CPU_MODEL:-Skylake-Client}"
CPU_OPTIONS="${CPU_OPTIONS:-+ssse3,+sse4.2,+popcnt,+avx,+avx2,+aes,+xsave,+xsaveopt,check}"

QEMU_ARGS=(
	-enable-kvm
	-m "$RAM_ALLOCATED"
	-object "memory-backend-memfd,id=reims-ram,size=$RAM_ALLOCATED,share=on"
	-cpu "${CPU_MODEL},-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,${CPU_OPTIONS}"
	-machine q35,memory-backend=reims-ram
	-smp "$TOTAL_CPUS"
	-device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"

	-usb
	-device qemu-xhci,id=xhci.0
	-device usb-tablet,bus=usb-bus.0

	-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$OVMF_VARS"

	-device ich9-ahci,id=sata
	-drive id=MacDisk,if=none,format=qcow2,file="$QCOW_DISK"
	-device ide-hd,bus=sata.2,drive=MacDisk
	
    -drive "file=fat:rw:esp,format=raw"
	-drive "file=recovery/BaseSystem.img,format=raw"

	-audiodev pipewire,id=audio0,out.buffer-length=46440
	-device usb-audio,bus=usb-bus.0,audiodev=audio0,buffer=65536

	-netdev user,id=net0,hostfwd=tcp::2222-:22
	-device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27

	-chardev "stdio,id=charserial0"
	-device "isa-serial,chardev=charserial0,id=serial0"
    -debugcon "file:qemu_debug.log" -global "isa-debugcon.iobase=0x402"
    
    -action reboot=shutdown
)

if [ "${REIMS:-0}" = "1" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export DISPLAY="${DISPLAY:-:0}"

    QEMU="${QEMU_BIN:-reims/vendor/qemu/build/qemu-system-x86_64}"

	GOP_ROM="${REIMS_VGPU_GOP_ROM:-reims/crates/reims-vgpu-efi/out/reims-vgpu-gop.rom}"
    [ -f "$GOP_ROM" ] || { echo "GOP ROM missing, run reims/crates/reims-vgpu-efi/scripts/reims-vgpu-efi-rom/reims-vgpu-efi-rom.sh"; exit 1; }
    export REIMS_VGPU_WINDOW=1
    QEMU_ARGS+=(
        -display none
#		-display sdl,full-screen=on 
        -vga none
        -device pci-bridge,chassis_nr=5,id=pci.5,bus=pcie.0,addr=1e.0
        -device "reims-vgpu-pci,id=reimsvgpu,bus=pci.5,addr=00.0,romfile=$GOP_ROM,rombar=1"
    )
else
    QEMU_ARGS+=(
        -display gtk,zoom-to-fit=on
        -device virtio-vga
    )
fi

"$QEMU" "${QEMU_ARGS[@]}" 2>&1 | tee serial_output.log
