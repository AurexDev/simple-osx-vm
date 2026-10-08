# Simple OSX VM
A project made for creating OS-X/macOS virtual machines on Linux in a simple way.

## Dependencies
To install dependencies use the following instructions for your distribution
### Ubuntu/Debian
```bash
sudo apt install git python3 dmg2img qemu-system-x86 coreutils findutils curl unzip tar
```

### Arch Linux
```bash
sudo pacman -S git python dmg2img qemu-desktop coreutils findutils curl unzip tar
```

### Fedora
```bash
sudo dnf install git python3 dmg2img qemu-system-x86 coreutils findutils curl unzip tar
```

## How to use
First run setup.sh to fetch tools used and prepare the EFI partition:
```bash
./setup.sh
```
> [!TIP]
> You can also use the debug build by running:
> ```bash
> ./setup.sh debug
> ```
> You can also bypass verification (altough this is not recommended):
> ```bash
> ./setup.sh release noverify
> ```

Then execute recovery.sh to pull the macOS Recovery
> [!NOTE]
> Not all macOS versions have been tested, **Ventura** is recommended.
```bash
./recovery.sh
```

Create a qcow2 disk for the installation:
```bash
qemu-img create -f qcow2 osx_disk.qcow2 80G
```

Lastly launch qemu by running the run.sh script:
> [!NOTE]
> If the log looks, stuck do not panic!
> This can happen because the log is outputted to the serial console.
```bash
./run.sh
```
## GPU acceleration
GPU acceleration have been made possible via reims-vgpu
> [!CAUTION]
> Reims is highly experimental, some issues include:
> - Not being able to boot under 12GB RAM allocated,
> - Content on screen turns black,
> - Not being able to enter fullscreen
> - Kernel panics

First install the following dependencies:
### Ubuntu/Debian
```bash
sudo apt install git cargo ninja-build llvm spirv-tools python3 python3-venv python3-pip
```
### Arch Linux
```bash
sudo pacman -S git cargo ninja llvm spirv-tools python
```

### Fedora
```bash
sudo dnf install git cargo ninja llvm spirv-tools python3 python3-pip
```

To start the build execute:
```bash
./reims.sh
```

You will be able to launch the VM with GPU acceleration using:
```bash
 ./reims-run.sh
```

## Troubleshooting

### Unable to install macOS (Recovery server could not be contacted)

Try changing the "-device virtio-net-pci" line in run.sh to "-device e1000-nic,netdev=net0,id=net0,mac=52:54:00:c9:18:27"

## AI usage
> LLMs were used to assist making scripts in this project.

## Tools used
- OpenCore (https://github.com/acidanthera/OpenCorePkg.git)
- ProperTree (https://github.com/corpnewt/ProperTree.git)
- EDK II (https://github.com/tianocore/edk2.git, prebuilt binaries: https://github.com/osdev0/edk2-ovmf-nightly.git)
- Reference config.plist (https://raw.githubusercontent.com/kholia/OSX-KVM/refs/heads/master/OpenCore/config.plist)
- Reference QEMU arguments (https://raw.githubusercontent.com/kholia/OSX-KVM/refs/heads/master/OpenCore-Boot.sh)
