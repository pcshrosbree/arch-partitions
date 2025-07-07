# Arch Linux Installation Using archinstall Script
## Optimized Configuration for High-Performance Workstation

### System Specifications
- **Motherboard**: ASUS ROG CrossHair X870E Hero
- **CPU**: AMD Ryzen 9 9950X
- **RAM**: 192GB DDR5-6400 CL32 (2x 96GB CORSAIR VENGEANCE)
- **Storage**:
  - **Ultra-Performance**: Samsung SSD 9100 PRO 4TB (M.2_2 slot)
  - **High-Performance**: TEAMGROUP T-Force Z540 4TB (M.2_1 slot)
  - **Cache/Swap**: 8GB+ SATA SSD
- **GPU**: ASUS Dual GeForce RTX 4060 Ti OC 8GB
- **Network**: Intel X520-DA2 10Gb dual SFP+

## Pre-Installation Setup

### 1. BIOS Configuration
Follow the BIOS configuration guide in `BIOS_Configuration.md` to ensure optimal performance settings.

### 2. Boot from Arch Linux USB
1. Download latest Arch Linux ISO from https://archlinux.org/download/
2. Create bootable USB drive
3. Boot from USB drive
4. Connect to internet if needed: `iwctl` or ethernet

### 3. Launch archinstall
```bash
# Update system clock
timedatectl set-ntp true

# Launch archinstall
archinstall
```

## archinstall Configuration Steps

### Step 1: Language and Locale
- **Language**: English (US)
- **Locale**: en_US.UTF-8

### Step 2: Mirrors
- **Mirror region**: United States (or your preferred region)
- Allow archinstall to select fastest mirrors

### Step 3: Disk Configuration (Critical Section)

#### 3.1 Select Disk Layout
- Choose **"Manual partitioning"** for full control
- **Do NOT** use automatic partitioning

#### 3.2 Identify Your Drives
```bash
# In another terminal (Ctrl+Alt+F2), identify drives:
lsblk -d -o NAME,SIZE,MODEL

# Expected output:
# NAME  SIZE   MODEL
# nvme0n1 3.7T  TEAMGROUP T-Force Z540 4TB
# nvme1n1 3.7T  Samsung SSD 9100 PRO 4TB  
# sda     X GB  [Your SATA SSD]
```

#### 3.3 Configure Drive 1: TEAMGROUP T-Force Z540 (nvme0n1)
**Purpose**: Root filesystem and EFI boot

1. **Select nvme0n1** (TEAMGROUP T-Force Z540)
2. **Wipe drive**: Yes
3. **Create partitions**:
   
   **Partition 1 - EFI System**:
   - **Size**: 1024 MiB
   - **Type**: EFI System
   - **Filesystem**: FAT32
   - **Mount point**: /boot
   - **Flags**: boot, esp
   
   **Partition 2 - Root Filesystem**:
   - **Size**: Remaining space (~3.7TB)
   - **Type**: Linux filesystem
   - **Filesystem**: Btrfs
   - **Mount point**: /
   - **Mount options**: `noatime,compress=zstd:1,space_cache=v2,discard=async`

#### 3.4 Configure Drive 2: Samsung SSD 9100 PRO (nvme1n1)
**Purpose**: Ultra-performance development workspace and home

1. **Select nvme1n1** (Samsung SSD 9100 PRO)
2. **Wipe drive**: Yes
3. **Create partitions**:
   
   **Partition 1 - Development Workspace**:
   - **Size**: 1000 GiB (1TB)
   - **Type**: Linux filesystem
   - **Filesystem**: Btrfs
   - **Mount point**: /dev
   - **Mount options**: `noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30`
   
   **Partition 2 - Home Directory**:
   - **Size**: Remaining space (~3TB)
   - **Type**: Linux filesystem
   - **Filesystem**: Btrfs
   - **Mount point**: /home
   - **Mount options**: `noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30`

#### 3.5 Configure Drive 3: SATA SSD (sda)
**Purpose**: Swap and cache

1. **Select sda** (SATA SSD)
2. **Wipe drive**: Yes
3. **Create partitions**:
   
   **Partition 1 - Swap**:
   - **Size**: 32 GiB
   - **Type**: Linux swap
   - **Filesystem**: swap
   - **Mount point**: [swap]
   
   **Partition 2 - Cache**:
   - **Size**: Remaining space
   - **Type**: Linux filesystem
   - **Filesystem**: Btrfs
   - **Mount point**: /.cache
   - **Mount options**: `noatime,compress=zstd:1,space_cache=v2,discard=async`

### Step 4: Btrfs Subvolume Configuration

**IMPORTANT**: archinstall may not support advanced btrfs subvolume configuration directly. You'll need to configure subvolumes post-installation.

For now, accept the basic btrfs setup and plan to configure subvolumes after installation.

### Step 5: Encryption (Optional)
- **Disk encryption**: None (for maximum performance)
- If security is required, consider encrypting only the home partition

### Step 6: Bootloader
- **Bootloader**: GRUB
- **UEFI**: Yes (ensure this is selected)

### Step 7: Hostname
- **Hostname**: arch-workstation (or your preference)

### Step 8: Root Password
- Set a strong root password

### Step 9: User Account
- **Username**: peter (or your preference)
- **Password**: Set strong password
- **Sudo privileges**: Yes

### Step 10: Profile Selection
- **Profile**: Minimal (we'll install desktop environment later)
- **Graphics driver**: nvidia (for RTX 4060 Ti)

### Step 11: Audio
- **Audio**: PipeWire (recommended for modern systems)

### Step 12: Kernels
- **Kernel**: linux (stable)
- **Additional**: linux-lts (optional, for fallback)

### Step 13: Network Configuration
- **Network**: NetworkManager (recommended)

### Step 14: Timezone
- **Timezone**: Your local timezone (e.g., America/New_York)

### Step 15: Additional Packages
Add these essential packages:
```
base-devel git vim docker docker-compose qemu-full libvirt virt-manager htop iotop reflector btrfs-progs
```

### Step 16: Kernel Parameters
In the advanced section, add these kernel parameters for optimal performance:
```
elevator=none mitigations=off amd_iommu=on iommu=pt
```

### Step 17: Review and Install
- Review all settings carefully
- **Proceed with installation**
- Installation will take 15-30 minutes depending on internet speed

## Post-Installation Configuration

### Step 1: Boot into New System
1. Remove installation media
2. Reboot
3. Log in as your user

### Step 2: Configure Btrfs Subvolumes
```bash
# Create btrfs subvolumes for better management
sudo btrfs subvolume create /snapshots
sudo btrfs subvolume create /var/log
sudo btrfs subvolume create /var/cache
sudo btrfs subvolume create /tmp

# You'll need to reconfigure fstab to use these subvolumes
# This is an advanced step - consider using the custom script instead
```

### Step 3: Configure Development Environment
```bash
# Update system
sudo pacman -Syu

# Enable and start services
sudo systemctl enable --now docker
sudo systemctl enable --now libvirtd
sudo systemctl enable --now NetworkManager

# Add user to groups
sudo usermod -aG docker,libvirt peter

# Create development directories on ultra-performance drive
sudo mkdir -p /dev/{docker,vms,containers,build,cache}
sudo chown -R peter:peter /dev

# Configure Docker to use ultra-performance drive
sudo systemctl stop docker
sudo mkdir -p /etc/docker
echo '{"data-root": "/dev/docker"}' | sudo tee /etc/docker/daemon.json
sudo systemctl start docker
```

### Step 4: Configure Automatic Snapshots
```bash
# Create snapshot service
sudo tee /etc/systemd/system/btrfs-snapshot.service > /dev/null << 'EOF'
[Unit]
Description=Btrfs snapshot

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs subvolume snapshot / /snapshots/@-$(date +%%Y-%%m-%%d-%%H-%%M-%%S)
ExecStart=/usr/bin/find /snapshots -name '@-*' -mtime +7 -exec btrfs subvolume delete {} \;
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

# Enable snapshot service
sudo systemctl enable --now btrfs-snapshot.timer
```

### Step 5: Configure Automatic Maintenance
```bash
# Enable periodic TRIM
sudo systemctl enable --now fstrim.timer

# Configure btrfs scrub
sudo systemctl enable --now btrfs-scrub@-.timer
sudo systemctl enable --now btrfs-scrub@home.timer
sudo systemctl enable --now btrfs-scrub@dev.timer
```

### Step 6: Install Desktop Environment (Optional)
```bash
# For GNOME
sudo pacman -S gnome gdm
sudo systemctl enable gdm

# For KDE Plasma
sudo pacman -S plasma sddm
sudo systemctl enable sddm

# For XFCE (lightweight)
sudo pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
sudo systemctl enable lightdm
```

### Step 7: Configure NVIDIA Drivers
```bash
# Install additional NVIDIA packages
sudo pacman -S nvidia-settings nvidia-utils

# Configure for multiple monitors
nvidia-settings
```

### Step 8: Install Development Tools
```bash
# Programming languages and tools
sudo pacman -S nodejs npm python python-pip rust go

# IDEs and editors
sudo pacman -S code firefox chromium

# Virtualization tools
sudo pacman -S virt-viewer qemu-guest-agent
```

## Performance Verification

### Check Drive Performance
```bash
# Test Samsung SSD 9100 PRO performance
sudo hdparm -Tt /dev/nvme1n1

# Check mount options
mount | grep btrfs
```

### Monitor System Performance
```bash
# Check memory configuration
sudo dmidecode --type memory | grep -i speed

# Monitor CPU performance
htop

# Check drive temperatures
sudo smartctl -A /dev/nvme0n1
sudo smartctl -A /dev/nvme1n1
```

## Troubleshooting

### archinstall Limitations
- **Limited btrfs subvolume support**: You may need to configure advanced subvolumes manually
- **Custom mount options**: Some advanced mount options may need manual configuration
- **Development workspace**: The `/dev` mount point may need to be configured manually

### Alternative Approach
If archinstall doesn't provide sufficient flexibility for your advanced configuration, consider:
1. Using the custom `install_arch.sh` script provided
2. Manual installation following the Arch Wiki
3. Using archinstall for basic setup, then manually configuring advanced features

### Common Issues
- **Drive not detected**: Check BIOS settings for NVMe and SATA configuration
- **Performance issues**: Verify EXPO profile is enabled and drives are running at full speed
- **Mount failures**: Check partition alignment and filesystem creation

## Advantages of Custom Script vs archinstall

### Custom Script Advantages
- **Full control**: Complete control over partition layout and subvolumes
- **Optimized configuration**: Samsung SSD 9100 PRO specific optimizations
- **Automated post-config**: Automatic setup of development environment
- **Advanced features**: Sophisticated btrfs subvolume structure

### archinstall Advantages
- **User-friendly**: Interactive GUI-like interface
- **Guided process**: Step-by-step guidance reduces errors
- **Official support**: Maintained by Arch Linux team
- **Safety checks**: Built-in validation and error checking

## Recommendation

For your specific high-performance workstation with Samsung SSD 9100 PRO, I recommend:

1. **Try archinstall first** if you prefer a guided approach
2. **Use the custom script** if you want maximum performance optimization
3. **Hybrid approach**: Use archinstall for basic setup, then run post-installation optimizations

The custom script provides better optimization for your specific hardware configuration, especially the Samsung SSD 9100 PRO performance optimizations.