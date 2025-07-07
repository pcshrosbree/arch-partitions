# Arch Linux Installation Using archinstall Pre-Mounted Configuration

## Optimized for Samsung SSD 9100 PRO High-Performance Workstation

### Overview

The pre-mounted configuration option in archinstall allows you to manually partition and mount your drives with full control over the filesystem layout, then have archinstall detect and use your custom configuration. This approach provides maximum flexibility for optimizing your Samsung SSD 9100 PRO setup.

### System Specifications

- **Motherboard**: ASUS ROG CrossHair X870E Hero
- **CPU**: AMD Ryzen 9 9950X  
- **RAM**: 192GB DDR5-6400 CL32
- **Storage**:
  - **Ultra-Performance**: Samsung SSD 9100 PRO 4TB (`/dev/nvme1n1`)
  - **High-Performance**: TEAMGROUP T-Force Z540 4TB (`/dev/nvme0n1`)
  - **Cache/Swap**: 8GB+ SATA SSD (`/dev/sda`)

## Phase 1: Pre-Installation Setup

### Step 1: Boot from Arch Linux USB

1. Boot from your Arch Linux USB drive
2. Verify UEFI mode: `ls /sys/firmware/efi/efivars`
3. Set system clock: `timedatectl set-ntp true`
4. Connect to internet if needed

### Step 2: Identify Your Drives

```bash
# List all drives and their models
lsblk -d -o NAME,SIZE,MODEL

# Expected output:
# NAME     SIZE   MODEL
# nvme0n1  3.7T   TEAMGROUP T-Force Z540 4TB
# nvme1n1  3.7T   Samsung SSD 9100 PRO 4TB
# sda      X GB   [Your SATA SSD Model]

# Verify drive identification
smartctl -i /dev/nvme0n1 | grep "Model Number"
smartctl -i /dev/nvme1n1 | grep "Model Number"
```

## Phase 2: Manual Partitioning and Formatting

### Step 3: Partition the Drives

#### Drive 1: TEAMGROUP T-Force Z540 (nvme0n1) - Root System

```bash
# Create GPT partition table
parted -s /dev/nvme0n1 mklabel gpt

# Create EFI System Partition (1GB)
parted -s /dev/nvme0n1 mkpart "EFI" fat32 1MiB 1025MiB
parted -s /dev/nvme0n1 set 1 esp on

# Create Root partition (remaining space)
parted -s /dev/nvme0n1 mkpart "ROOT" btrfs 1025MiB 100%

# Verify partitions
lsblk /dev/nvme0n1
```

#### Drive 2: Samsung SSD 9100 PRO (nvme1n1) - Ultra-Performance

```bash
# Create GPT partition table
parted -s /dev/nvme1n1 mklabel gpt

# Create Development Workspace partition (1TB)
parted -s /dev/nvme1n1 mkpart "DEV_WORKSPACE" btrfs 1MiB 1025GiB

# Create Home partition (remaining ~3TB)
parted -s /dev/nvme1n1 mkpart "HOME" btrfs 1025GiB 100%

# Verify partitions
lsblk /dev/nvme1n1
```

#### Drive 3: SATA SSD (sda) - Swap and Cache

```bash
# Create GPT partition table
parted -s /dev/sda mklabel gpt

# Create Swap partition (32GB)
parted -s /dev/sda mkpart "SWAP" linux-swap 1MiB 32GiB

# Create Cache partition (remaining space)
parted -s /dev/sda mkpart "CACHE" btrfs 32GiB 100%

# Verify partitions
lsblk /dev/sda
```

### Step 4: Format the Filesystems

#### Format EFI and Swap

```bash
# Format EFI partition
mkfs.fat -F32 /dev/nvme0n1p1

# Format and enable swap
mkswap /dev/sda1
swapon /dev/sda1
```

#### Format Btrfs Filesystems with Optimizations

```bash
# Root filesystem (TEAMGROUP T-Force Z540)
mkfs.btrfs -f -L "arch-root" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    /dev/nvme0n1p2

# Development workspace (Samsung SSD 9100 PRO - Ultra Performance)
mkfs.btrfs -f -L "arch-dev" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/nvme1n1p1

# Home filesystem (Samsung SSD 9100 PRO - Ultra Performance)
mkfs.btrfs -f -L "arch-home" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/nvme1n1p2

# Cache filesystem (SATA SSD)
mkfs.btrfs -f -L "arch-cache" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    /dev/sda2
```

## Phase 3: Mount Configuration

### Step 5: Create and Mount Root Filesystem with Subvolumes

```bash
# Mount root filesystem temporarily
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async /dev/nvme0n1p2 /mnt

# Create btrfs subvolumes for optimal management
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@.snapshots

# Unmount temporarily
umount /mnt

# Mount root subvolume
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@ /dev/nvme0n1p2 /mnt
```

### Step 6: Create Mount Points and Mount All Filesystems

```bash
# Create all mount points
mkdir -p /mnt/{boot,home,workspace,var,tmp,.snapshots,.cache}
mkdir -p /mnt/var/{log,cache}

# Mount EFI partition
mount /dev/nvme0n1p1 /mnt/boot

# Mount root subvolumes
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var /dev/nvme0n1p2 /mnt/var
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_log /dev/nvme0n1p2 /mnt/var/log
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_cache /dev/nvme0n1p2 /mnt/var/cache
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@tmp /dev/nvme0n1p2 /mnt/tmp
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@.snapshots /dev/nvme0n1p2 /mnt/.snapshots

# Mount Samsung SSD 9100 PRO partitions with ultra-performance options
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/nvme1n1p1 /mnt/workspace
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/nvme1n1p2 /mnt/home

# Mount cache filesystem
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async /dev/sda2 /mnt/.cache
```

### Step 7: Verify Mount Configuration

```bash
# Check all mounts
lsblk

# Verify mount options
mount | grep btrfs

# Check available space
df -h

# Verify subvolumes
btrfs subvolume list /mnt
```

Expected output should show:

- `/mnt` mounted from nvme0n1p2 subvolume @
- `/mnt/boot` mounted from nvme0n1p1 (FAT32)
- `/mnt/home` mounted from nvme1n1p2 (Samsung SSD 9100 PRO)
- `/mnt/workspace` mounted from nvme1n1p1 (Samsung SSD 9100 PRO)
- `/mnt/.cache` mounted from sda2
- All subvolumes properly mounted

## Phase 4: Launch archinstall with Pre-Mounted Configuration

### Step 8: Launch archinstall

```bash
# Launch archinstall - it will detect your pre-mounted configuration
archinstall
```

### Step 9: Configure archinstall with Pre-Mounted Setup

#### Disk Configuration

- **Disk layout**: Select **"Pre-mounted configuration"**
- archinstall will automatically detect your mounted filesystems
- **Verify** that all mount points are correctly identified:
  - `/mnt` → Root filesystem
  - `/mnt/boot` → EFI partition
  - `/mnt/home` → Home directory
  - `/mnt/workspace` → Development workspace
  - `/mnt/.cache` → Cache directory

#### Other Configuration Options

1. **Language**: English (US)
2. **Locale**: en_US.UTF-8
3. **Mirrors**: United States (or your region)
4. **Hostname**: arch-workstation
5. **Root password**: Set strong password
6. **User account**:
   - Username: peter
   - Password: Strong password
   - Sudo privileges: Yes
7. **Profile**: Minimal
8. **Graphics driver**: nvidia
9. **Audio**: PipeWire
10. **Kernels**: linux
11. **Network**: NetworkManager
12. **Timezone**: Your timezone
13. **Additional packages**:

    ```
    base-devel git vim docker docker-compose qemu-full libvirt virt-manager htop iotop reflector btrfs-progs intel-ucode amd-ucode
    ```

#### Bootloader Configuration

- **Bootloader**: GRUB
- **Additional kernel parameters**:

  ```
  elevator=none mitigations=off amd_iommu=on iommu=pt
  ```

### Step 10: Review and Install

- Carefully review all detected mount points
- Ensure Samsung SSD 9100 PRO partitions are properly recognized
- **Proceed with installation**

## Phase 5: Post-Installation Configuration

### Step 11: First Boot Setup

```bash
# Reboot into new system
reboot

# Log in as your user
# Update system
sudo pacman -Syu
```

### Step 12: Configure Development Environment

```bash
# Enable and start services
sudo systemctl enable --now docker
sudo systemctl enable --now libvirtd
sudo systemctl enable --now fstrim.timer

# Add user to groups
sudo usermod -aG docker,libvirt peter

# Create optimized development directories on Samsung SSD 9100 PRO
sudo mkdir -p /workspace/{docker,vms,containers,build,cache,tmp}
sudo chown -R peter:peter /workspace

# Configure Docker to use ultra-performance Samsung SSD 9100 PRO
sudo systemctl stop docker
sudo mkdir -p /etc/docker
echo '{"data-root": "/workspace/docker"}' | sudo tee /etc/docker/daemon.json
sudo systemctl start docker

# Test Docker
docker run hello-world
```

### Step 13: Configure Automatic Snapshots

```bash
# Create snapshot service
sudo tee /etc/systemd/system/btrfs-snapshot.service > /dev/null << 'EOF'
[Unit]
Description=Btrfs snapshot

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs subvolume snapshot / /.snapshots/@-$(date +%%Y-%%m-%%d-%%H-%%M-%%S)
ExecStart=/usr/bin/find /.snapshots -name '@-*' -mtime +7 -exec btrfs subvolume delete {} \;
EOF

# Create snapshot timer
sudo tee /etc/systemd/system/btrfs-snapshot.timer > /dev/null << 'EOF'
[Unit]
Description=Daily Btrfs snapshot

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable automatic snapshots
sudo systemctl enable --now btrfs-snapshot.timer
```

### Step 14: Configure Btrfs Maintenance

```bash
# Create scrub services for all btrfs filesystems
for mount in - home dev; do
    sudo systemctl enable --now btrfs-scrub@${mount}.timer
done

# Verify scrub services
systemctl list-timers | grep btrfs
```

## Phase 6: Verification and Performance Testing

### Step 15: Verify Installation

```bash
# Check all filesystems
df -h

# Verify mount options
mount | grep btrfs

# Check btrfs subvolumes
sudo btrfs subvolume list /
sudo btrfs subvolume list /home
sudo btrfs subvolume list /dev

# Test Samsung SSD 9100 PRO performance
sudo hdparm -Tt /dev/nvme1n1

# Check drive temperatures
sudo smartctl -A /dev/nvme0n1 | grep Temperature
sudo smartctl -A /dev/nvme1n1 | grep Temperature
```

### Step 16: Performance Benchmarking

```bash
# Install benchmarking tools
sudo pacman -S fio

# Test Samsung SSD 9100 PRO random read/write performance
fio --name=random-rw --ioengine=libaio --iodepth=4 --rw=randrw --bs=4k --direct=1 --size=1G --numjobs=1 --runtime=60 --group_reporting --filename=/dev/test-file

# Test development workspace performance
fio --name=dev-workspace --ioengine=libaio --iodepth=8 --rw=randwrite --bs=16k --direct=1 --size=2G --numjobs=2 --runtime=30 --group_reporting --filename=/workspace/benchmark-test
```

## Troubleshooting

### Common Issues and Solutions

#### Mount Point Not Detected

```bash
# If archinstall doesn't detect mount points:
# 1. Verify all partitions are mounted
mount | grep /mnt

# 2. Check filesystem labels
lsblk -o NAME,FSTYPE,LABEL,MOUNTPOINT

# 3. Remount if necessary
umount /mnt/workspace
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/nvme1n1p1 /mnt/workspace
```

#### Btrfs Subvolume Issues

```bash
# If subvolumes aren't working properly:
# 1. Check subvolume creation
btrfs subvolume list /mnt

# 2. Verify mount options
mount | grep subvol

# 3. Recreate if needed
btrfs subvolume delete /mnt/@var
btrfs subvolume create /mnt/@var
```

#### Samsung SSD 9100 PRO Not Optimized

```bash
# Verify ultra-performance mount options
mount | grep nvme1n1

# Should show: commit=30 for optimal performance
# If not, remount with correct options
sudo umount /home
sudo mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/nvme1n1p2 /home
```

### Performance Validation

```bash
# Check if Samsung SSD 9100 PRO is performing optimally
# Sequential read should be >12,000 MB/s
# Sequential write should be >11,000 MB/s
# Random read should be >2,000,000 IOPS
# Random write should be >1,800,000 IOPS

# Monitor real-time performance
iostat -x 1
```

## Advantages of Pre-Mounted Configuration

### Benefits

1. **Full Control**: Complete control over partition sizes and filesystem options
2. **Advanced Optimization**: Samsung SSD 9100 PRO specific optimizations
3. **Custom Subvolumes**: Advanced btrfs subvolume structure
4. **Performance Tuning**: Optimized mount options for each drive
5. **Flexibility**: Easy to modify before archinstall runs

### Considerations

1. **Complexity**: Requires manual partitioning knowledge
2. **Time**: Takes longer than automatic configuration
3. **Error Prone**: Manual commands can cause mistakes
4. **Documentation**: Need to document custom configuration

## Final Configuration Summary

After completion, your system will have:

- **Root filesystem**: High-performance TEAMGROUP drive with btrfs subvolumes
- **Development workspace**: Ultra-performance Samsung SSD 9100 PRO at `/dev`
- **Home directory**: Ultra-performance Samsung SSD 9100 PRO at `/home`
- **Optimized mount options**: Specific to each drive's performance characteristics
- **Automatic maintenance**: Snapshots, scrubs, and TRIM
- **Development environment**: Docker, VMs, and build tools on fastest storage

This configuration maximizes the performance benefits of your Samsung SSD 9100 PRO while maintaining system stability and providing comprehensive backup capabilities.
