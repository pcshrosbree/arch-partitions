#!/bin/bash

# Encrypted Arch Linux Installation Script for High-Performance Workstation
# ASUS ROG CrossHair X870E Hero with AMD Ryzen 9 9950X
# Optimized for Samsung SSD 9100 PRO with selective LUKS encryption

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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
log "Starting Encrypted Arch Linux installation for high-performance workstation"
log "Target system: ASUS ROG CrossHair X870E Hero, AMD Ryzen 9 9950X, 192GB RAM"
log "Encryption: Samsung SSD 9100 PRO (workspace + home), Root system unencrypted"

# Verify we're running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Verify UEFI boot mode
if [ ! -d /sys/firmware/efi/efivars ]; then
    error "System must be booted in UEFI mode"
fi

# Define drive variables based on your hardware configuration
# High performance NVMe Gen5 drive - Root filesystem (unencrypted)
NVME_HIGH_PERF="/dev/nvme0n1"  # TEAMGROUP T-Force Z540 4TB
# Ultra-high performance NVMe Gen5 drive - Encrypted workspaces
NVME_ULTRA_PERF="/dev/nvme1n1"  # Samsung SSD 9100 PRO 4TB (2x faster than 990 PRO)
# SATA SSD - Swap and cache (unencrypted)
SATA_SSD="/dev/sda"  # 8GB+ SATA SSD

# Verify drives exist
for drive in "$NVME_HIGH_PERF" "$NVME_ULTRA_PERF" "$SATA_SSD"; do
    if [ ! -b "$drive" ]; then
        error "Drive $drive not found!"
    fi
done

# Display drive information
log "Drive configuration:"
lsblk -d -o NAME,SIZE,MODEL "$NVME_HIGH_PERF" "$NVME_ULTRA_PERF" "$SATA_SSD"

# Verify drive models to prevent mistakes
log "Verifying drive models..."
HIGH_PERF_MODEL=$(smartctl -i "$NVME_HIGH_PERF" | grep "Model Number" | awk '{print $3, $4, $5}' || echo "Unknown")
ULTRA_PERF_MODEL=$(smartctl -i "$NVME_ULTRA_PERF" | grep "Model Number" | awk '{print $3, $4, $5}' || echo "Unknown")

log "Detected drives:"
log "  $NVME_HIGH_PERF: $HIGH_PERF_MODEL (Root system - unencrypted)"
log "  $NVME_ULTRA_PERF: $ULTRA_PERF_MODEL (Workspace + Home - encrypted)"
log "  $SATA_SSD: SATA SSD (Cache + Swap - unencrypted)"

# Confirmation prompt
echo
echo -e "${RED}⚠️  CRITICAL WARNING ⚠️${NC}"
echo -e "${RED}This will COMPLETELY ERASE all data on:${NC}"
echo -e "${RED}  - $NVME_HIGH_PERF ($HIGH_PERF_MODEL)${NC}"
echo -e "${RED}  - $NVME_ULTRA_PERF ($ULTRA_PERF_MODEL) - WILL BE ENCRYPTED${NC}"
echo -e "${RED}  - $SATA_SSD (SATA SSD)${NC}"
echo
echo -e "${YELLOW}Encryption will be applied to Samsung SSD partitions only.${NC}"
echo -e "${YELLOW}Root system will remain unencrypted for fast boot times.${NC}"
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
pacman -Sy --noconfirm archlinux-keyring cryptsetup
pacman -S --noconfirm reflector
reflector --country 'United States' --latest 20 --sort rate --save /etc/pacman.d/mirrorlist

# Wipe drives completely
log "Wiping drives (this may take several minutes)"
wipefs -af "$NVME_HIGH_PERF"
wipefs -af "$NVME_ULTRA_PERF"
wipefs -af "$SATA_SSD"

# Create partition tables
log "Creating GPT partition tables"
parted -s "$NVME_HIGH_PERF" mklabel gpt
parted -s "$NVME_ULTRA_PERF" mklabel gpt
parted -s "$SATA_SSD" mklabel gpt

# Partition High Performance NVMe (Root system - unencrypted)
log "Partitioning high performance NVMe drive ($NVME_HIGH_PERF)"
# EFI System Partition (1GB)
parted -s "$NVME_HIGH_PERF" mkpart "EFI" fat32 1MiB 1025MiB
parted -s "$NVME_HIGH_PERF" set 1 esp on
# Root partition (remaining space)
parted -s "$NVME_HIGH_PERF" mkpart "ROOT" btrfs 1025MiB 100%

# Partition Ultra Performance NVMe (Development workloads - encrypted)
log "Partitioning ultra performance NVMe drive ($NVME_ULTRA_PERF) for encryption"
# Development workspace (1TB - will be encrypted)
parted -s "$NVME_ULTRA_PERF" mkpart "DEV_WORKSPACE_CRYPT" btrfs 1MiB 1025GiB
# Home directory (remaining space - will be encrypted)
parted -s "$NVME_ULTRA_PERF" mkpart "HOME_CRYPT" btrfs 1025GiB 100%

# Partition SATA SSD (Swap and cache - unencrypted)
log "Partitioning SATA SSD ($SATA_SSD)"
# Swap partition (32GB)
parted -s "$SATA_SSD" mkpart "SWAP" linux-swap 1MiB 32GiB
# Cache partition (remaining space)
parted -s "$SATA_SSD" mkpart "CACHE" btrfs 32GiB 100%

# Wait for partition devices to be available
sleep 3

# Format unencrypted partitions
log "Formatting unencrypted partitions"

# EFI partition
mkfs.fat -F32 "${NVME_HIGH_PERF}p1"

# Root filesystem (unencrypted)
mkfs.btrfs -f -L "arch-root" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    "${NVME_HIGH_PERF}p2"

# Swap partition
mkswap "${SATA_SSD}p1"

# Cache filesystem (unencrypted)
mkfs.btrfs -f -L "arch-cache" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    "${SATA_SSD}p2"

# Setup LUKS encryption for Samsung SSD 9100 PRO
log "Setting up LUKS encryption for Samsung SSD 9100 PRO"

# Encrypt development workspace
log "Creating encrypted container for development workspace"
cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --use-random \
    --verify-passphrase \
    "${NVME_ULTRA_PERF}p1"

log "Opening encrypted development workspace"
cryptsetup open "${NVME_ULTRA_PERF}p1" dev_workspace

# Encrypt home directory
log "Creating encrypted container for home directory"
cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --use-random \
    --verify-passphrase \
    "${NVME_ULTRA_PERF}p2"

log "Opening encrypted home directory"
cryptsetup open "${NVME_ULTRA_PERF}p2" home_encrypted

# Format encrypted filesystems with Samsung SSD 9100 PRO optimizations
log "Creating optimized btrfs filesystems on encrypted devices"

# Development workspace (Samsung SSD 9100 PRO optimized)
mkfs.btrfs -f -L "workspace-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/dev_workspace

# Home directory (Samsung SSD 9100 PRO optimized)
mkfs.btrfs -f -L "home-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/home_encrypted

# Mount root filesystem and create subvolumes
log "Mounting root filesystem and creating btrfs subvolumes"
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async "${NVME_HIGH_PERF}p2" /mnt

# Create btrfs subvolumes for optimal management
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@.snapshots

# Unmount and remount with proper subvolume structure
umount /mnt
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@ "${NVME_HIGH_PERF}p2" /mnt

# Create mount points
log "Creating mount points and mounting all filesystems"
mkdir -p /mnt/{boot,home,workspace,var,tmp,.snapshots,.cache}
mkdir -p /mnt/var/{log,cache}

# Mount EFI partition
mount "${NVME_HIGH_PERF}p1" /mnt/boot

# Mount root subvolumes
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var "${NVME_HIGH_PERF}p2" /mnt/var
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_log "${NVME_HIGH_PERF}p2" /mnt/var/log
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_cache "${NVME_HIGH_PERF}p2" /mnt/var/cache
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@tmp "${NVME_HIGH_PERF}p2" /mnt/tmp
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@.snapshots "${NVME_HIGH_PERF}p2" /mnt/.snapshots

# Mount encrypted filesystems (Samsung SSD 9100 PRO with ultra-performance options)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/mapper/dev_workspace /mnt/workspace
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/mapper/home_encrypted /mnt/home

# Mount cache filesystem (unencrypted)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async "${SATA_SSD}p2" /mnt/.cache

# Enable swap
swapon "${SATA_SSD}p1"

# Verify all mounts
log "Verifying mount configuration"
lsblk
echo
log "Encrypted devices:"
ls -la /dev/mapper/

# Install base system with encryption support
log "Installing base system with encryption support"
pacstrap /mnt base base-devel linux linux-firmware \
    cryptsetup btrfs-progs \
    intel-ucode amd-ucode \
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
log "Generating fstab with encrypted device support"
genfstab -U /mnt >> /mnt/etc/fstab

# Configure the system for encryption
log "Configuring system for encrypted boot"
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

# Get UUIDs for encrypted partitions
WORKSPACE_UUID=\$(blkid -s UUID -o value ${NVME_ULTRA_PERF}p1)
HOME_UUID=\$(blkid -s UUID -o value ${NVME_ULTRA_PERF}p2)

# Create crypttab for automatic decryption at boot
cat > /etc/crypttab <<EOL
# Development workspace on Samsung SSD 9100 PRO
dev_workspace UUID=\$WORKSPACE_UUID none luks,discard

# Home directory on Samsung SSD 9100 PRO
home_encrypted UUID=\$HOME_UUID none luks,discard
EOL

# Configure mkinitcpio for encryption
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio -P

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

# Install and configure GRUB with encryption support
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Configure kernel parameters for encryption and optimal performance
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& cryptdevice=UUID=\$WORKSPACE_UUID:dev_workspace cryptdevice=UUID=\$HOME_UUID:home_encrypted elevator=none mitigations=off amd_iommu=on iommu=pt/" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# Create development directories on encrypted workspace
mkdir -p /workspace/{docker,vms,containers,build,cache,tmp,projects}
mkdir -p /home/peter/{src,projects}
chown -R peter:peter /workspace
chown -R peter:peter /home/peter

# Configure Docker for encrypted workspace
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOL
{
  "data-root": "/workspace/docker",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "tmp-dir": "/workspace/tmp"
}
EOL

# Optimize dm-crypt for performance
echo 'options dm_crypt same_cpu_crypt=1' > /etc/modprobe.d/dm_crypt.conf
echo 'options dm_crypt force_inline=1' >> /etc/modprobe.d/dm_crypt.conf

# Set up automatic snapshots for encrypted drives
cat > /etc/systemd/system/btrfs-snapshot.service <<EOL
[Unit]
Description=Btrfs snapshot for encrypted drives

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs subvolume snapshot /workspace /workspace/.snapshots/workspace-\$(date +%%Y-%%m-%%d-%%H-%%M-%%S)
ExecStart=/usr/bin/btrfs subvolume snapshot /home /home/.snapshots/home-\$(date +%%Y-%%m-%%d-%%H-%%M-%%S)
ExecStart=/usr/bin/find /workspace/.snapshots -name 'workspace-*' -mtime +7 -exec btrfs subvolume delete {} \\;
ExecStart=/usr/bin/find /home/.snapshots -name 'home-*' -mtime +7 -exec btrfs subvolume delete {} \\;
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

# Create snapshot directories
mkdir -p /workspace/.snapshots /home/.snapshots

# Enable snapshot service
systemctl enable btrfs-snapshot.timer

# Set up btrfs scrub for encrypted drives
systemctl enable btrfs-scrub@-.timer

# Create LUKS header backups (CRITICAL for recovery)
mkdir -p /root/luks-backups
chmod 700 /root/luks-backups
cryptsetup luksHeaderBackup ${NVME_ULTRA_PERF}p1 --header-backup-file /root/luks-backups/workspace_header.backup
cryptsetup luksHeaderBackup ${NVME_ULTRA_PERF}p2 --header-backup-file /root/luks-backups/home_header.backup

EOF

log "Installation completed successfully!"
echo
log "🔒 ENCRYPTED ARCH LINUX INSTALLATION SUMMARY 🔒"
log "================================================================"
log "Root filesystem: btrfs on ${NVME_HIGH_PERF}p2 (UNENCRYPTED - fast boot)"
log "Development workspace: encrypted btrfs on ${NVME_ULTRA_PERF}p1 (Samsung SSD 9100 PRO)"
log "Home directory: encrypted btrfs on ${NVME_ULTRA_PERF}p2 (Samsung SSD 9100 PRO)"
log "Cache filesystem: btrfs on ${SATA_SSD}p2 (UNENCRYPTED)"
log "Swap: ${SATA_SSD}p1 (32GB, UNENCRYPTED)"
log "EFI partition: ${NVME_HIGH_PERF}p1 (UNENCRYPTED)"
echo
log "🚀 PERFORMANCE OPTIMIZATIONS:"
log "- Samsung SSD 9100 PRO: Ultra-performance mount options (commit=30)"
log "- AES-256-XTS encryption with hardware acceleration"
log "- Btrfs compression and SSD optimizations"
log "- Docker configured on encrypted workspace"
log "- Automatic snapshots enabled (daily, kept for 7 days)"
log "- LUKS header backups stored in /root/luks-backups/"
echo
log "🔐 ENCRYPTION DETAILS:"
log "- LUKS2 containers with AES-256-XTS cipher"
log "- Development workspace and home directory encrypted"
log "- Root system unencrypted for fast boot times"
log "- Hardware AES acceleration enabled"
echo
warning "⚠️  IMPORTANT POST-INSTALLATION STEPS:"
warning "1. Reboot and test encrypted drive decryption"
warning "2. Verify all 192GB RAM is detected"
warning "3. Test Samsung SSD 9100 PRO performance"
warning "4. Configure desktop environment if desired"
warning "5. BACKUP the LUKS headers from /root/luks-backups/ to external storage"
warning "6. Test snapshot and recovery procedures"
echo
log "Installation completed. You can now reboot and enjoy your encrypted high-performance workstation!"

# Cleanup function for script interruption
cleanup() {
    log "Cleaning up..."
    umount -R /mnt 2>/dev/null || true
    cryptsetup close dev_workspace 2>/dev/null || true
    cryptsetup close home_encrypted 2>/dev/null || true
    swapoff "${SATA_SSD}p1" 2>/dev/null || true
}

# Set trap for cleanup on script exit
trap cleanup EXIT