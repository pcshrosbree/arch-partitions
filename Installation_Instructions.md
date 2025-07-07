# Arch Linux Installation Instructions

## Pre-Installation Setup

### 1. BIOS Configuration

Follow the detailed BIOS configuration guide in `BIOS_Configuration.md` before proceeding.

### 2. Create Arch Linux Installation Media

- Download the latest Arch Linux ISO from <https://archlinux.org/download/>
- Create a bootable USB drive using `dd` or your preferred tool
- Boot from the USB drive

### 3. Copy Installation Script

Once booted from the USB, copy the installation script to the live environment:

```bash
# If you have network access, you can curl the script:
curl -O https://raw.githubusercontent.com/yourusername/arch-part/main/install_arch.sh

# Or copy it from another USB drive if you prepared one
# Mount the USB drive containing the script
mkdir /mnt/usb
mount /dev/sdX1 /mnt/usb  # Replace X with your USB drive letter
cp /mnt/usb/install_arch.sh /root/
chmod +x /root/install_arch.sh
```

## Installation Process

### 1. Verify System Requirements

```bash
# Check UEFI boot mode
ls /sys/firmware/efi/efivars

# Check available drives
lsblk

# Verify network connectivity (if needed)
ping -c 3 archlinux.org
```

### 2. Run the Installation Script

```bash
cd /root
./install_arch.sh
```

### 3. Follow the Prompts

The script will:

- Display drive information and ask for confirmation
- Completely wipe all three drives (TEAMGROUP NVMe, Samsung SSD 9100 PRO, SATA SSD)
- Create optimized partition layouts
- Install base system with development tools
- Configure btrfs with optimal settings
- Set up automatic snapshots and maintenance

### 4. Post-Installation Configuration

After the script completes, you'll be prompted to:

- Set passwords for root and user 'peter'
- Review the installation

## Drive Layout Created by Script

### High-Performance NVMe (TEAMGROUP T-Force Z540 4TB) - `/dev/nvme0n1`

- `nvme0n1p1`: EFI System Partition (1GB, FAT32)
- `nvme0n1p2`: Root filesystem (remaining space, btrfs)
  - `@`: Root subvolume (/)
  - `@var`: /var subvolume
  - `@var_log`: /var/log subvolume
  - `@var_cache`: /var/cache subvolume
  - `@tmp`: /tmp subvolume
  - `@snapshots`: Snapshot storage

### Ultra-Performance NVMe (Samsung SSD 9100 PRO 4TB) - `/dev/nvme1n1`

- `nvme1n1p1`: Development workspace (1TB, btrfs, mounted at /dev)
  - Optimized for containers, VMs, build processes, and active development
  - 2x faster than Samsung 990 PRO for maximum I/O performance
- `nvme1n1p2`: Home filesystem (remaining 3TB, btrfs, mounted at /home)

### SATA SSD (8GB+) - `/dev/sda`

- `sda1`: Swap partition (32GB)
- `sda2`: Cache filesystem (remaining space, btrfs, mounted at /.cache)

## Optimizations Applied

### Btrfs Mount Options

- `noatime`: Improves performance by not updating access times
- `compress=zstd:1`: Fast compression for space savings
- `space_cache=v2`: Improved free space tracking
- `discard=async`: Asynchronous TRIM for SSD longevity
- `commit=30`: Optimized commit interval for Samsung SSD 9100 PRO performance
- `nodesize=16384`: Optimized node size for ultra-high performance drives

### Kernel Parameters

- `elevator=none`: Optimal for NVMe SSDs
- `mitigations=off`: Maximum performance (consider security implications)
- `amd_iommu=on iommu=pt`: Optimized IOMMU for virtualization

### Automatic Maintenance

- Daily snapshots (kept for 7 days)
- Monthly btrfs scrub for data integrity
- Automatic TRIM via fstrim.timer

## Post-Installation Steps

### 1. First Boot

```bash
# Reboot into new system
reboot

# Log in as user 'peter'
# Update system
sudo pacman -Syu

# Install additional packages as needed
sudo pacman -S firefox code nodejs npm python python-pip
```

### 2. Desktop Environment (Optional)

```bash
# Install GNOME
sudo pacman -S gnome gdm
sudo systemctl enable gdm

# Or install KDE Plasma
sudo pacman -S plasma sddm
sudo systemctl enable sddm
```

### 3. Development Environment Setup

```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Configure Docker to use ultra-performance drive
sudo systemctl stop docker
sudo mkdir -p /etc/docker
echo '{"data-root": "/dev/docker"}' | sudo tee /etc/docker/daemon.json
sudo systemctl start docker

# Verify Docker works
docker run hello-world
```

### 4. Graphics Driver Configuration

The script installs NVIDIA drivers. After reboot:

```bash
# Check NVIDIA driver status
nvidia-smi

# Configure displays if needed
nvidia-settings
```

## Troubleshooting

### Drive Not Detected

- Verify drives are properly connected
- Check BIOS settings for SATA/NVMe detection
- Ensure drives are not in RAID mode

### Boot Issues

- Verify UEFI boot mode in BIOS
- Check EFI partition is properly mounted
- Ensure GRUB installation completed successfully

### Performance Issues

- Verify EXPO memory profile is active
- Check CPU temperatures under load
- Monitor drive temperatures and throttling

## Backup and Recovery

### Creating Manual Snapshots

```bash
# Create snapshot of root
sudo btrfs subvolume snapshot / /snapshots/@-manual-$(date +%Y-%m-%d)

# List snapshots
sudo btrfs subvolume list /snapshots
```

### Restoring from Snapshot

```bash
# Boot from Arch Linux USB
# Mount drives and restore snapshot
mount /dev/nvme0n1p2 /mnt
btrfs subvolume snapshot /mnt/snapshots/@-YYYY-MM-DD /mnt/@-restored
# Update fstab to use restored snapshot
```

## Hardware-Specific Notes

### Samsung SSD 9100 PRO Performance

- Ultra-high performance drive with 2x speed advantage over Samsung 990 PRO
- Optimized for development workloads (containers, VMs, build processes)
- `/dev` mount point provides maximum I/O performance for critical operations
- Reduced commit interval (30s) for optimal write performance

### Memory Configuration

- 192GB DDR5-6400 CL32 requires EXPO profile activation
- Monitor memory training times during boot
- Consider enabling ECC if supported

### Network Configuration

- Intel X520-DA2 requires additional firmware
- Configure 10Gb networking as needed
- Set up bonding for redundancy if using both ports

### Display Configuration

- Three Dell U4320Q monitors at 4K
- Configure extended desktop or specific layouts
- Adjust scaling for optimal development workspace

### Development Workspace Layout

- `/dev/docker`: Docker containers and images on ultra-performance drive
- `/dev/vms`: Virtual machines on ultra-performance drive
- `/dev/build`: Build artifacts and temporary files
- `/dev/cache`: Development tool caches
- `/home/peter/src`: Source code repositories
- `/home/peter/projects`: Project directories
