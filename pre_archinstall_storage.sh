#!/bin/bash

# Pre-archinstall Storage Setup Script
# Creates basic partitions and filesystems for archinstall compatibility
# Run this BEFORE archinstall

set -euo pipefail

# Configuration - MODIFY THESE TO MATCH YOUR ACTUAL DEVICE PATHS
PRIMARY_NVME="/dev/nvme0n1"      # 14,000 MB/s PCIe 5 NVMe (4TB) - Root + EFI
SECONDARY_NVME="/dev/nvme1n1"    # 7,450 MB/s PCIe 4 NVMe (4TB) - Home
BULK_SATA="/dev/sda"             # 8TB SATA SSD - Bulk storage

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Safety check function
confirm_action() {
    echo -e "${RED}WARNING: This will destroy all data on:${NC}"
    echo "  - $PRIMARY_NVME (Primary NVMe - Root + EFI)"
    echo "  - $SECONDARY_NVME (Secondary NVMe - Home)"
    echo "  - $BULK_SATA (Bulk SATA SSD)"
    echo ""
    echo "This script creates basic partitions for archinstall compatibility."
    echo "Advanced subvolumes will be created by the post-install script."
    echo ""
    read -p "Are you absolutely sure you want to continue? (type 'YES' to confirm): " response
    if [[ "$response" != "YES" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Verify devices exist
verify_devices() {
    log "Verifying storage devices..."
    
    for device in "$PRIMARY_NVME" "$SECONDARY_NVME" "$BULK_SATA"; do
        if [[ ! -b "$device" ]]; then
            error "Device $device not found. Please check your device paths."
        fi
        log "✓ Found device: $device"
    done
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    
    if command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm btrfs-progs parted util-linux
    elif command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y btrfs-progs parted util-linux
    elif command -v dnf &> /dev/null; then
        dnf install -y btrfs-progs parted util-linux
    else
        warn "Could not determine package manager. Please install btrfs-progs, parted, and util-linux manually."
    fi
}

# Create partitions
create_partitions() {
    log "Creating basic partition layout..."
    
    # Primary NVMe - EFI + Root
    log "Partitioning $PRIMARY_NVME (EFI + Root)..."
    parted -s "$PRIMARY_NVME" mklabel gpt
    parted -s "$PRIMARY_NVME" mkpart EFI_SYSTEM fat32 1MiB 1025MiB
    parted -s "$PRIMARY_NVME" set 1 esp on
    parted -s "$PRIMARY_NVME" mkpart ROOT btrfs 1025MiB 100%
    
    # Secondary NVMe - Home
    log "Partitioning $SECONDARY_NVME (Home)..."
    parted -s "$SECONDARY_NVME" mklabel gpt
    parted -s "$SECONDARY_NVME" mkpart HOME btrfs 1MiB 100%
    
    # Bulk SATA - Bulk storage
    log "Partitioning $BULK_SATA (Bulk storage)..."
    parted -s "$BULK_SATA" mklabel gpt
    parted -s "$BULK_SATA" mkpart BULK btrfs 1MiB 100%
    
    # Wait for kernel to recognize partitions
    sleep 3
    partprobe
    
    log "✓ Basic partitions created"
}

# Format filesystems with basic setup
format_filesystems() {
    log "Creating filesystems..."
    
    # EFI System Partition
    log "Creating EFI System Partition..."
    mkfs.fat -F32 -n "EFI_SYSTEM" "${PRIMARY_NVME}p1"
    
    # Primary NVMe - Root btrfs (simple setup for archinstall)
    log "Creating root btrfs filesystem..."
    mkfs.btrfs -f -L "ROOT" \
        --metadata single \
        --data single \
        --nodesize 16384 \
        --sectorsize 4096 \
        "${PRIMARY_NVME}p2"
    
    # Secondary NVMe - Home btrfs (will be configured post-install)
    log "Creating home btrfs filesystem..."
    mkfs.btrfs -f -L "HOME" \
        --metadata single \
        --data single \
        --nodesize 16384 \
        --sectorsize 4096 \
        "${SECONDARY_NVME}p1"
    
    # Bulk SATA - Bulk btrfs (will be configured post-install)
    log "Creating bulk btrfs filesystem..."
    mkfs.btrfs -f -L "BULK" "${BULK_SATA}1"
    
    log "✓ Basic filesystems created"
}

# Create minimal subvolumes for archinstall
create_basic_subvolumes() {
    log "Creating minimal btrfs subvolumes for archinstall..."
    
    # Mount root filesystem temporarily
    mkdir -p /tmp/root_mount
    mount "${PRIMARY_NVME}p2" /tmp/root_mount
    
    # Create only essential subvolumes for archinstall
    log "Creating essential root subvolumes..."
    btrfs subvolume create /tmp/root_mount/@          # Root
    btrfs subvolume create /tmp/root_mount/@home      # Home (temporary)
    btrfs subvolume create /tmp/root_mount/@snapshots # Snapshots
    
    umount /tmp/root_mount
    rmdir /tmp/root_mount
    
    log "✓ Essential subvolumes created"
}

# Display configuration information
display_config() {
    log "Pre-archinstall storage setup complete!"
    echo ""
    echo -e "${GREEN}=== ARCHINSTALL CONFIGURATION ===${NC}"
    echo "Use these settings in archinstall:"
    echo ""
    echo "1. Disk configuration: Manual partitioning"
    echo "2. EFI Partition: ${PRIMARY_NVME}p1 (already formatted as FAT32)"
    echo "3. Root Partition: ${PRIMARY_NVME}p2 (btrfs with @ subvolume)"
    echo "4. Bootloader: systemd-boot or GRUB"
    echo "5. Optional: Add ${SECONDARY_NVME}p1 as /home (btrfs)"
    echo ""
    echo -e "${YELLOW}=== IMPORTANT NOTES ===${NC}"
    echo "• Let archinstall handle mounting and installation"
    echo "• The root partition uses btrfs with @ subvolume"
    echo "• Advanced subvolumes will be created post-install"
    echo "• Don't mount ${BULK_SATA}1 in archinstall (handle post-install)"
    echo ""
    echo -e "${GREEN}=== DEVICE SUMMARY ===${NC}"
    echo "Primary NVMe (${PRIMARY_NVME}):"
    echo "  ├── p1: EFI System (FAT32, 1GB)"
    echo "  └── p2: Root (btrfs with @, @home, @snapshots)"
    echo ""
    echo "Secondary NVMe (${SECONDARY_NVME}):"
    echo "  └── p1: Home (btrfs, ready for post-install setup)"
    echo ""
    echo "Bulk SATA (${BULK_SATA}):"
    echo "  └── p1: Bulk Storage (btrfs, ready for post-install setup)"
    echo ""
    echo -e "${GREEN}=== NEXT STEPS ===${NC}"
    echo "1. Run 'archinstall' now"
    echo "2. After installation, run the post-install storage script"
    echo "3. The post-install script will create advanced subvolumes"
    echo ""
}

# Verify UEFI mode
check_uefi() {
    if [[ ! -d "/sys/firmware/efi" ]]; then
        error "System not booted in UEFI mode! Please boot the USB in UEFI mode."
    fi
    log "✓ System booted in UEFI mode"
}

# Main execution
main() {
    log "Starting pre-archinstall storage setup..."
    
    check_root
    check_uefi
    verify_devices
    confirm_action
    install_packages
    create_partitions
    format_filesystems
    create_basic_subvolumes
    display_config
    
    log "✓ Pre-archinstall storage setup completed successfully!"
}

# Run main function
main "$@"