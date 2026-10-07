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
Then execute recovery.sh to pull the macOS Recovery (All versions have not been tested, Ventura is recommended!)
```bash
./recovery.sh
```
Lastly launch qemu by running the run.sh script:
```bash
./run.sh
```

## AI
- LLMs were used in this project, and its scripts.

## Tools used
- OpenCore (https://github.com/acidanthera/OpenCorePkg.git)
- ProperTree (https://github.com/corpnewt/ProperTree.git)
- EDK II (https://github.com/tianocore/edk2.git, prebuilt binaries: https://github.com/osdev0/edk2-ovmf-nightly.git)
- Reference config.plist (https://raw.githubusercontent.com/kholia/OSX-KVM/refs/heads/master/OpenCore/config.plist)
- Reference QEMU arguments (https://raw.githubusercontent.com/kholia/OSX-KVM/refs/heads/master/OpenCore-Boot.sh)
