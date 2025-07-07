#!/bin/bash

# Disk Preparation Script for Default archinstall
# Prepares encrypted drives that archinstall can detect and use
# ASUS ROG CrossHair X870E Hero with Samsung SSD 9100 PRO optimization

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

# Verify we're running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Verify UEFI boot mode
if [ ! -d /sys/firmware/efi/efivars ]; then
    error "System must be booted in UEFI mode"
fi

log "Disk Preparation Script for Default archinstall"
log "Target: ASUS ROG CrossHair X870E Hero, AMD Ryzen 9 9950X, 192GB RAM"
log "Strategy: Encrypted Samsung SSD 9100 PRO + Unencrypted root system"

# Define drive variables
NVME_HIGH_PERF="/dev/nvme0n1"  # TEAMGROUP T-Force Z540 4TB (Root - unencrypted)
NVME_ULTRA_PERF="/dev/nvme1n1"  # Samsung SSD 9100 PRO 4TB (Encrypted)
SATA_SSD="/dev/sda"  # SATA SSD (Swap/Cache - unencrypted)

# Verify drives exist
for drive in "$NVME_HIGH_PERF" "$NVME_ULTRA_PERF" "$SATA_SSD"; do
    if [ ! -b "$drive" ]; then
        error "Drive $drive not found!"
    fi
done

# Display drive information
log "Drive configuration:"
lsblk -d -o NAME,SIZE,MODEL "$NVME_HIGH_PERF" "$NVME_ULTRA_PERF" "$SATA_SSD"

# Verify drive models
log "Verifying drive models..."
HIGH_PERF_MODEL=$(smartctl -i "$NVME_HIGH_PERF" 2>/dev/null | grep "Model Number" | awk '{print $3, $4, $5}' || echo "Unknown")
ULTRA_PERF_MODEL=$(smartctl -i "$NVME_ULTRA_PERF" 2>/dev/null | grep "Model Number" | awk '{print $3, $4, $5}' || echo "Unknown")

log "Detected drives:"
log "  $NVME_HIGH_PERF: $HIGH_PERF_MODEL (Root system - unencrypted)"
log "  $NVME_ULTRA_PERF: $ULTRA_PERF_MODEL (Workspace + Home - encrypted)"
log "  $SATA_SSD: SATA SSD (Swap + Cache - unencrypted)"

# Confirmation prompt
echo
echo -e "${RED}⚠️  CRITICAL WARNING ⚠️${NC}"
echo -e "${RED}This will COMPLETELY ERASE all data on:${NC}"
echo -e "${RED}  - $NVME_HIGH_PERF ($HIGH_PERF_MODEL)${NC}"
echo -e "${RED}  - $NVME_ULTRA_PERF ($ULTRA_PERF_MODEL) - WILL BE ENCRYPTED${NC}"
echo -e "${RED}  - $SATA_SSD (SATA SSD)${NC}"
echo
echo -e "${YELLOW}This script prepares drives for the DEFAULT archinstall to detect.${NC}"
echo -e "${YELLOW}Samsung SSD 9100 PRO will be encrypted for security.${NC}"
echo
read -p "Are you absolutely sure you want to continue? (type 'YES' to confirm): " confirm
if [ "$confirm" != "YES" ]; then
    log "Disk preparation cancelled by user"
    exit 0
fi

# Install required tools
log "Installing required tools"
pacman -Sy --noconfirm cryptsetup parted dosfstools btrfs-progs

# Enable NTP for accurate time
log "Synchronizing system clock"
timedatectl set-ntp true

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
log "Partitioning root drive ($NVME_HIGH_PERF) for archinstall"
# EFI System Partition (1GB)
parted -s "$NVME_HIGH_PERF" mkpart "ESP" fat32 1MiB 1025MiB
parted -s "$NVME_HIGH_PERF" set 1 esp on
# Root partition (remaining space)
parted -s "$NVME_HIGH_PERF" mkpart "arch-root" btrfs 1025MiB 100%

# Partition Samsung SSD 9100 PRO (Workspace + Home - encrypted)
log "Partitioning Samsung SSD 9100 PRO ($NVME_ULTRA_PERF) for encryption"
# Development workspace (1TB - will be encrypted)
parted -s "$NVME_ULTRA_PERF" mkpart "arch-workspace-crypt" btrfs 1MiB 1025GiB
# Home directory (remaining ~3TB - will be encrypted)
parted -s "$NVME_ULTRA_PERF" mkpart "arch-home-crypt" btrfs 1025GiB 100%

# Partition SATA SSD (Swap and cache - unencrypted)
log "Partitioning SATA SSD ($SATA_SSD)"
# Swap partition (32GB)
parted -s "$SATA_SSD" mkpart "arch-swap" linux-swap 1MiB 32GiB
# Cache partition (remaining space)
parted -s "$SATA_SSD" mkpart "arch-cache" btrfs 32GiB 100%

# Wait for partition devices to be available
sleep 3

# Format EFI partition
log "Formatting EFI partition"
mkfs.fat -F32 -n "ESP" "${NVME_HIGH_PERF}p1"

# Create and mount root filesystem temporarily for subvolumes
log "Creating root filesystem with btrfs subvolumes"
mkfs.btrfs -f -L "arch-root" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    "${NVME_HIGH_PERF}p2"

# Mount root temporarily to create subvolumes
log "Creating btrfs subvolumes for optimal management"
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async "${NVME_HIGH_PERF}p2" /mnt

# Create btrfs subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@.snapshots

# Unmount root (archinstall will handle proper mounting)
log "Unmounting root filesystem (archinstall will remount with subvolumes)"
umount /mnt

# Format swap and cache partitions
log "Setting up swap"
mkswap -L "arch-swap" "${SATA_SSD}p1"

log "Formatting cache filesystem"
mkfs.btrfs -f -L "arch-cache" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    "${SATA_SSD}p2"

# Setup LUKS encryption for Samsung SSD 9100 PRO
log "Setting up LUKS encryption for Samsung SSD 9100 PRO partitions"

# Encrypt development workspace
log "Creating encrypted container for development workspace"
echo
echo -e "${BLUE}You will be prompted to enter a passphrase for the encrypted workspace.${NC}"
echo -e "${BLUE}Choose a strong passphrase and remember it - you'll need it every boot.${NC}"
echo
cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --use-random \
    --verify-passphrase \
    "${NVME_ULTRA_PERF}p1"

log "Opening encrypted workspace"
cryptsetup open "${NVME_ULTRA_PERF}p1" workspace_encrypted

# Format encrypted workspace filesystem with Samsung SSD 9100 PRO optimizations
log "Creating btrfs filesystem on encrypted workspace partition"
mkfs.btrfs -f -L "arch-workspace-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/workspace_encrypted

# Close workspace device
log "Closing encrypted workspace device"
cryptsetup close workspace_encrypted

# Encrypt home directory
log "Creating encrypted container for home directory"
echo
echo -e "${BLUE}You will be prompted to enter a passphrase for the encrypted home directory.${NC}"
echo -e "${BLUE}This can be the same or different from the workspace passphrase.${NC}"
echo
cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --use-random \
    --verify-passphrase \
    "${NVME_ULTRA_PERF}p2"

log "Opening encrypted home directory"
cryptsetup open "${NVME_ULTRA_PERF}p2" home_encrypted

# Format encrypted home filesystem with Samsung SSD 9100 PRO optimizations
log "Creating btrfs filesystem on encrypted home partition"
mkfs.btrfs -f -L "arch-home-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/home_encrypted

# Close encrypted device for now (archinstall will handle opening)
log "Closing encrypted devices (archinstall will reopen them)"
cryptsetup close home_encrypted

# Display final configuration
log "Disk preparation completed successfully!"
echo
log "🎯 ARCHINSTALL-READY CONFIGURATION:"
log "=================================================="
log "EFI partition: ${NVME_HIGH_PERF}p1 (FAT32, ESP label, 1GB)"
log "Root partition: ${NVME_HIGH_PERF}p2 (btrfs, arch-root label, unencrypted)"
log "Workspace partition: ${NVME_ULTRA_PERF}p1 (LUKS encrypted btrfs, arch-workspace-encrypted label, 1TB)"
log "Home partition: ${NVME_ULTRA_PERF}p2 (LUKS encrypted btrfs, arch-home-encrypted label, ~3TB)"
log "Swap partition: ${SATA_SSD}p1 (swap, arch-swap label, 32GB)"
log "Cache partition: ${SATA_SSD}p2 (btrfs, arch-cache label, unencrypted)"
echo
log "🔐 ENCRYPTION DETAILS:"
log "- Home directory encrypted with LUKS2 AES-256-XTS"
log "- Root system unencrypted btrfs for fast boot and snapshots"
log "- Samsung SSD 9100 PRO optimized btrfs (nodesize=16384)"
log "- archinstall will detect and configure encrypted home"
echo
log "📋 NEXT STEPS:"
log "1. Run: archinstall"
log "2. Select 'Use existing partitions'"
log "3. Configure partitions:"
log "   - ${NVME_HIGH_PERF}p1 → /boot (EFI)"
log "   - ${NVME_HIGH_PERF}p2 → / (root)"
log "   - ${NVME_ULTRA_PERF}p1 → /workspace (encrypted)"
log "   - ${NVME_ULTRA_PERF}p2 → /home (encrypted)"
log "   - ${SATA_SSD}p1 → swap"
log "   - ${SATA_SSD}p2 → /.cache (cache directory)"
log "4. archinstall will prompt for encryption passphrases"
log "5. Complete installation normally"
echo
warning "⚠️  IMPORTANT NOTES:"
warning "- Remember your encryption passphrase!"
warning "- archinstall will automatically configure encrypted home"
warning "- Samsung SSD 9100 PRO uses optimized btrfs settings"
warning "- Root btrfs enables snapshots and compression"
warning "- All partitions have descriptive labels for easy identification"

# Verify setup
log "Verifying disk setup..."
echo
log "Partition layout:"
lsblk

echo
log "LUKS devices:"
log "Workspace encryption:"
cryptsetup luksDump "${NVME_ULTRA_PERF}p1" | head -5
log "Home encryption:"
cryptsetup luksDump "${NVME_ULTRA_PERF}p2" | head -5

echo
log "Disk preparation complete! Ready for archinstall."