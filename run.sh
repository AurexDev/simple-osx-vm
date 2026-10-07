#!/usr/bin/env bash

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

QEMU="qemu-system-x86_64"
RAM_ALLOCATED="4G"
TOTAL_CPUS="4"
QCOW_DISK="osx_disk.qcow2"

QEMU_ARGS=(
	-machine q35
	-enable-kvm
	-cpu Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on
	-m "$RAM_ALLOCATED"
	-smp "$TOTAL_CPUS"
	-device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"

	-usb
	-device qemu-xhci,id=xhci
	-device usb-tablet,bus=usb-bus.0

	-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$OVMF_VARS"

	-object iothread,id=io0
	-drive id=MacDisk,if=none,format=qcow2,file="$QCOW_DISK",cache=writeback,aio=threads
	-device virtio-blk-pci,drive=MacDisk,iothread=io0
	
    -drive "file=fat:rw:esp,format=raw"
	-drive "file=recovery/BaseSystem.img,format=raw"

	-netdev user,id=net0,hostfwd=tcp::2222-:22
	-device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27

	-display gtk,zoom-to-fit=on
	-device virtio-vga

#	-chardev "stdio,id=charserial0"
#    -device "isa-serial,chardev=charserial0,id=serial0"
#    -debugcon "file:qemu_debug.log" -global "isa-debugcon.iobase=0x402"
)

"$QEMU" "${QEMU_ARGS[@]}"
