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
log "  $NVME_ULTRA_PERF: $ULTRA_PERF_MODEL (Home - encrypted)"
log "  $SATA_SSD: SATA SSD (Swap - unencrypted)"

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
pacman -Sy --noconfirm cryptsetup parted dosfstools

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
parted -s "$NVME_HIGH_PERF" mkpart "EFI" fat32 1MiB 1025MiB
parted -s "$NVME_HIGH_PERF" set 1 esp on
# Root partition (remaining space)
parted -s "$NVME_HIGH_PERF" mkpart "ROOT" ext4 1025MiB 100%

# Partition Samsung SSD 9100 PRO (Home - encrypted)
log "Partitioning Samsung SSD 9100 PRO ($NVME_ULTRA_PERF) for encryption"
# Home directory (full drive - will be encrypted)
parted -s "$NVME_ULTRA_PERF" mkpart "HOME_CRYPT" ext4 1MiB 100%

# Partition SATA SSD (Swap - unencrypted)
log "Partitioning SATA SSD ($SATA_SSD)"
# Swap partition (full drive)
parted -s "$SATA_SSD" mkpart "SWAP" linux-swap 1MiB 100%

# Wait for partition devices to be available
sleep 3

# Format EFI partition
log "Formatting EFI partition"
mkfs.fat -F32 "${NVME_HIGH_PERF}p1"

# Format root filesystem (unencrypted)
log "Formatting root filesystem (unencrypted)"
mkfs.ext4 -F "${NVME_HIGH_PERF}p2"

# Format and enable swap
log "Setting up swap"
mkswap "${SATA_SSD}p1"

# Setup LUKS encryption for Samsung SSD 9100 PRO
log "Setting up LUKS encryption for Samsung SSD 9100 PRO home partition"

# Encrypt home directory
log "Creating encrypted container for home directory"
echo
echo -e "${BLUE}You will be prompted to enter a passphrase for the encrypted home directory.${NC}"
echo -e "${BLUE}Choose a strong passphrase and remember it - you'll need it every boot.${NC}"
echo
cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --use-random \
    --verify-passphrase \
    "${NVME_ULTRA_PERF}p1"

log "Opening encrypted home directory"
cryptsetup open "${NVME_ULTRA_PERF}p1" home_encrypted

# Format encrypted home filesystem
log "Creating filesystem on encrypted home partition"
mkfs.ext4 -F /dev/mapper/home_encrypted

# Close encrypted device for now (archinstall will handle opening)
log "Closing encrypted device (archinstall will reopen it)"
cryptsetup close home_encrypted

# Display final configuration
log "Disk preparation completed successfully!"
echo
log "🎯 ARCHINSTALL-READY CONFIGURATION:"
log "=================================================="
log "EFI partition: ${NVME_HIGH_PERF}p1 (FAT32, 1GB)"
log "Root partition: ${NVME_HIGH_PERF}p2 (ext4, unencrypted)"
log "Home partition: ${NVME_ULTRA_PERF}p1 (LUKS encrypted ext4)"
log "Swap partition: ${SATA_SSD}p1 (swap)"
echo
log "🔐 ENCRYPTION DETAILS:"
log "- Home directory encrypted with LUKS2 AES-256-XTS"
log "- Root system unencrypted for fast boot"
log "- archinstall will detect and configure encrypted home"
echo
log "📋 NEXT STEPS:"
log "1. Run: archinstall"
log "2. Select 'Use existing partitions'"
log "3. Configure partitions:"
log "   - ${NVME_HIGH_PERF}p1 → /boot (EFI)"
log "   - ${NVME_HIGH_PERF}p2 → / (root)"
log "   - ${NVME_ULTRA_PERF}p1 → /home (encrypted)"
log "   - ${SATA_SSD}p1 → swap"
log "4. archinstall will prompt for encryption passphrase"
log "5. Complete installation normally"
echo
warning "⚠️  IMPORTANT NOTES:"
warning "- Remember your encryption passphrase!"
warning "- archinstall will automatically configure encrypted home"
warning "- The Samsung SSD 9100 PRO is optimized for performance"
warning "- You can customize filesystem options in archinstall if desired"

# Verify setup
log "Verifying disk setup..."
echo
log "Partition layout:"
lsblk

echo
log "LUKS devices:"
cryptsetup luksDump "${NVME_ULTRA_PERF}p1" | head -10

echo
log "Disk preparation complete! Ready for archinstall."