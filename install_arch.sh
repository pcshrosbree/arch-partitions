#!/bin/bash

# Arch Linux Installation Script for High-Performance Workstation
# ASUS ROG CrossHair X870E Hero with AMD Ryzen 9 9950X
# Optimized for software development with containers and VMs

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# System information
log "Starting Arch Linux installation for high-performance workstation"
log "Target system: ASUS ROG CrossHair X870E Hero, AMD Ryzen 9 9950X, 192GB RAM"

# Verify we're running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Verify UEFI boot mode
if [ ! -d /sys/firmware/efi/efivars ]; then
    error "System must be booted in UEFI mode"
fi

# Define drive variables based on your hardware configuration
# Ultra-high performance NVMe Gen5 drive - Critical performance workloads
NVME_ULTRA_PERF="/dev/nvme1n1"  # Samsung SSD 9100 PRO 4TB (2x faster than 990 PRO)
# High performance NVMe Gen5 drive - Root filesystem and system
NVME_HIGH_PERF="/dev/nvme0n1"  # TEAMGROUP T-Force Z540 4TB
# SATA SSD - Swap and cache
SATA_SSD="/dev/sda"  # 8GB SATA SSD (assuming it's larger than 8GB)

# Verify drives exist
for drive in "$NVME_ULTRA_PERF" "$NVME_HIGH_PERF" "$SATA_SSD"; do
    if [ ! -b "$drive" ]; then
        error "Drive $drive not found!"
    fi
done

# Display drive information
log "Drive configuration:"
lsblk -d -o NAME,SIZE,MODEL "$NVME_ULTRA_PERF" "$NVME_HIGH_PERF" "$SATA_SSD"

# Confirmation prompt
echo -e "${RED}WARNING: This will COMPLETELY ERASE all data on:${NC}"
echo -e "${RED}  - $NVME_ULTRA_PERF (Samsung SSD 9100 PRO - Ultra Performance)${NC}"
echo -e "${RED}  - $NVME_HIGH_PERF (TEAMGROUP T-Force Z540 - High Performance)${NC}"
echo -e "${RED}  - $SATA_SSD (SATA SSD)${NC}"
echo
read -p "Are you absolutely sure you want to continue? (type 'YES' to confirm): " confirm
if [ "$confirm" != "YES" ]; then
    log "Installation cancelled by user"
    exit 0
fi

# Enable NTP for accurate time
log "Synchronizing system clock"
timedatectl set-ntp true

# Update keyring and mirrors
log "Updating package keyring and mirrors"
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm reflector
reflector --country 'United States' --latest 20 --sort rate --save /etc/pacman.d/mirrorlist

# Wipe drives completely
log "Wiping drives (this may take several minutes)"
wipefs -af "$NVME_ULTRA_PERF"
wipefs -af "$NVME_HIGH_PERF"
wipefs -af "$SATA_SSD"

# Create partition tables
log "Creating GPT partition tables"
parted -s "$NVME_ULTRA_PERF" mklabel gpt
parted -s "$NVME_HIGH_PERF" mklabel gpt
parted -s "$SATA_SSD" mklabel gpt

# Partition High Performance NVMe (Root system and EFI)
log "Partitioning high performance NVMe drive ($NVME_HIGH_PERF)"
# EFI System Partition (1GB)
parted -s "$NVME_HIGH_PERF" mkpart "EFI" fat32 1MiB 1025MiB
parted -s "$NVME_HIGH_PERF" set 1 esp on
# Root partition (remaining space)
parted -s "$NVME_HIGH_PERF" mkpart "ROOT" btrfs 1025MiB 100%

# Partition Ultra Performance NVMe (Development workloads and home)
log "Partitioning ultra performance NVMe drive ($NVME_ULTRA_PERF)"
# Development workspace (1TB - for containers, VMs, active projects)
parted -s "$NVME_ULTRA_PERF" mkpart "DEV_WORKSPACE" btrfs 1MiB 1025GiB
# Home directory (remaining space)
parted -s "$NVME_ULTRA_PERF" mkpart "HOME" btrfs 1025GiB 100%

# Partition SATA SSD (Swap and cache)
log "Partitioning SATA SSD ($SATA_SSD)"
# Swap partition (32GB - 2x typical swap for hibernation support)
parted -s "$SATA_SSD" mkpart "SWAP" linux-swap 1MiB 32GiB
# Cache partition (remaining space)
parted -s "$SATA_SSD" mkpart "CACHE" btrfs 32GiB 100%

# Wait for partition devices to be available
sleep 2

# Format EFI partition
log "Formatting EFI partition"
mkfs.fat -F32 "${NVME_HIGH_PERF}p1"

# Format swap partition
log "Formatting swap partition"
mkswap "${SATA_SSD}p1"

# Create btrfs filesystems with optimizations for NVMe SSDs
log "Creating btrfs filesystems"

# High Performance NVMe - Root filesystem with optimal settings for Gen5 NVMe
mkfs.btrfs -f -L "arch-root" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    "${NVME_HIGH_PERF}p2"

# Ultra Performance NVMe - Development workspace (Samsung SSD 9100 PRO optimized)
mkfs.btrfs -f -L "arch-dev" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    "${NVME_ULTRA_PERF}p1"

# Ultra Performance NVMe - Home filesystem (Samsung SSD 9100 PRO optimized)
mkfs.btrfs -f -L "arch-home" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    "${NVME_ULTRA_PERF}p2"

# SATA SSD - Cache filesystem
mkfs.btrfs -f -L "arch-cache" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    "${SATA_SSD}p2"

# Mount root filesystem
log "Mounting root filesystem"
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async "${NVME_HIGH_PERF}p2" /mnt

# Create btrfs subvolumes for optimal performance and management
log "Creating btrfs subvolumes"
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots

# Unmount and remount with proper subvolume structure
umount /mnt

# Mount root subvolume
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@ "${NVME_HIGH_PERF}p2" /mnt

# Create mount points
mkdir -p /mnt/{boot,home,dev,var,tmp,snapshots,.cache}
mkdir -p /mnt/var/{log,cache}

# Mount EFI partition
mount "${NVME_HIGH_PERF}p1" /mnt/boot

# Mount other subvolumes
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var "${NVME_HIGH_PERF}p2" /mnt/var
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_log "${NVME_HIGH_PERF}p2" /mnt/var/log
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_cache "${NVME_HIGH_PERF}p2" /mnt/var/cache
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@tmp "${NVME_HIGH_PERF}p2" /mnt/tmp
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@snapshots "${NVME_HIGH_PERF}p2" /mnt/snapshots

# Mount ultra-performance development workspace (Samsung SSD 9100 PRO)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 "${NVME_ULTRA_PERF}p1" /mnt/dev

# Mount home filesystem (Samsung SSD 9100 PRO)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 "${NVME_ULTRA_PERF}p2" /mnt/home

# Mount cache filesystem (SATA SSD)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async "${SATA_SSD}p2" /mnt/.cache

# Enable swap
swapon "${SATA_SSD}p1"

# Install base system with essential packages for development
log "Installing base system"
pacstrap /mnt base base-devel linux linux-firmware \
    btrfs-progs intel-ucode amd-ucode \
    networkmanager openssh \
    git vim nano \
    docker docker-compose \
    qemu-full libvirt virt-manager \
    nvidia nvidia-utils nvidia-settings \
    intel-media-driver \
    htop iotop \
    reflector \
    grub efibootmgr

# Generate fstab
log "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# Configure the system
log "Configuring system"
arch-chroot /mnt /bin/bash <<EOF
# Set timezone
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

# Configure locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "arch-workstation" > /etc/hostname

# Configure hosts
cat > /etc/hosts <<EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch-workstation.localdomain arch-workstation
EOL

# Create user and set passwords
useradd -m -G wheel,docker,libvirt -s /bin/bash peter
echo "Set password for user 'peter':"
passwd peter
echo "Set password for root:"
passwd

# Configure sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable essential services
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable docker
systemctl enable libvirtd
systemctl enable fstrim.timer

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Configure kernel parameters for optimal performance
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& elevator=none mitigations=off amd_iommu=on iommu=pt/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Create development directories optimized for Samsung SSD 9100 PRO performance
mkdir -p /home/peter/{src,projects}
mkdir -p /dev/{docker,vms,containers,build,cache}
chown -R peter:peter /home/peter
chown -R peter:peter /dev

# Configure Docker for development
usermod -aG docker peter

# Set up btrfs maintenance
cat > /etc/systemd/system/btrfs-scrub@.service <<EOL
[Unit]
Description=Btrfs scrub on %i
RequiresMountsFor=%i

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs scrub start -B %i
Nice=19
IOSchedulingClass=3
KillSignal=SIGTERM
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/btrfs-scrub@.timer <<EOL
[Unit]
Description=Monthly Btrfs scrub on %i
RequiresMountsFor=%i

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOL

systemctl enable btrfs-scrub@-.timer
systemctl enable btrfs-scrub@home.timer

# Configure automatic snapshots
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/btrfs-snapshot.service <<EOL
[Unit]
Description=Btrfs snapshot

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs subvolume snapshot / /snapshots/@-\$(date +%%Y-%%m-%%d-%%H-%%M-%%S)
ExecStart=/usr/bin/find /snapshots -name '@-*' -mtime +7 -exec btrfs subvolume delete {} \;
EOL

cat > /etc/systemd/system/btrfs-snapshot.timer <<EOL
[Unit]
Description=Daily Btrfs snapshot

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOL

systemctl enable btrfs-snapshot.timer

EOF

log "Installation completed successfully!"
log "System configuration summary:"
log "- Root filesystem: btrfs on ${NVME_HIGH_PERF}p2 with zstd compression"
log "- Development workspace: btrfs on ${NVME_ULTRA_PERF}p1 (Samsung SSD 9100 PRO - Ultra Performance)"
log "- Home filesystem: btrfs on ${NVME_ULTRA_PERF}p2 (Samsung SSD 9100 PRO - Ultra Performance)"
log "- Cache filesystem: btrfs on ${SATA_SSD}p2"
log "- Swap: ${SATA_SSD}p1 (32GB)"
log "- EFI partition: ${NVME_HIGH_PERF}p1"
log "- Ultra-performance mount options for Samsung SSD 9100 PRO"
log "- Automatic snapshots enabled (daily, kept for 7 days)"
log "- Btrfs scrub enabled (monthly)"
log "- Services enabled: NetworkManager, SSH, Docker, libvirt"
log "- User 'peter' created with sudo access"

warning "Next steps:"
warning "1. Review /mnt/etc/fstab to ensure all mounts are correct"
warning "2. Reboot and remove installation media"
warning "3. Configure desktop environment if desired"
warning "4. Install additional development tools"
warning "5. Configure network settings"

log "Installation script completed. You can now reboot."