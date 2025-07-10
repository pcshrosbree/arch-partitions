#!/bin/bash

# Development Workstation Storage Setup Script
# Creates partitions, filesystems, and btrfs subvolumes for optimal development workflow
# WARNING: This script will destroy existing data on specified drives!

set -euo pipefail

# Configuration - MODIFY THESE TO MATCH YOUR ACTUAL DEVICE PATHS
PRIMARY_NVME="/dev/nvme0n1"      # 14,000 MB/s PCIe 5 NVMe (4TB)
SECONDARY_NVME="/dev/nvme1n1"    # 7,450 MB/s PCIe 4 NVMe (4TB)
BULK_SATA="/dev/sda"             # 8TB SATA SSD

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
    echo "  - $PRIMARY_NVME (Primary NVMe)"
    echo "  - $SECONDARY_NVME (Secondary NVMe)"
    echo "  - $BULK_SATA (Bulk SATA SSD)"
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
    
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y btrfs-progs parted util-linux
    elif command -v dnf &> /dev/null; then
        dnf install -y btrfs-progs parted util-linux
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm btrfs-progs parted util-linux
    else
        warn "Could not determine package manager. Please install btrfs-progs, parted, and util-linux manually."
    fi
}

# Create partitions
create_partitions() {
    log "Creating partitions..."
    
    # Primary NVMe - Root filesystem
    log "Partitioning $PRIMARY_NVME..."
    parted -s "$PRIMARY_NVME" mklabel gpt
    parted -s "$PRIMARY_NVME" mkpart EFI_SYSTEM fat32 1MiB 1025MiB
    parted -s "$PRIMARY_NVME" set 1 esp on
    parted -s "$PRIMARY_NVME" mkpart ROOT btrfs 1025MiB 100%
    
    # Secondary NVMe - Home filesystem
    log "Partitioning $SECONDARY_NVME..."
    parted -s "$SECONDARY_NVME" mklabel gpt
    parted -s "$SECONDARY_NVME" mkpart HOME btrfs 1MiB 100%
    
    # Bulk SATA - Bulk storage
    log "Partitioning $BULK_SATA..."
    parted -s "$BULK_SATA" mklabel gpt
    parted -s "$BULK_SATA" mkpart BULK btrfs 1MiB 100%
    
    # Wait for kernel to recognize partitions
    sleep 3
    partprobe
}

# Format filesystems
format_filesystems() {
    log "Formatting filesystems..."
    
    # EFI System Partition
    log "Creating EFI System Partition..."
    mkfs.fat -F32 -n "EFI_SYSTEM" "${PRIMARY_NVME}p1"
    
    # Primary NVMe - Root btrfs
    log "Creating root btrfs filesystem..."
    mkfs.btrfs -f -L "ROOT" "${PRIMARY_NVME}p2"
    
    # Secondary NVMe - Home btrfs
    log "Creating home btrfs filesystem..."
    mkfs.btrfs -f -L "HOME" "${SECONDARY_NVME}p1"
    
    # Bulk SATA - Bulk btrfs
    log "Creating bulk btrfs filesystem..."
    mkfs.btrfs -f -L "BULK" "${BULK_SATA}p1"
}

# Create btrfs subvolumes
create_subvolumes() {
    log "Creating btrfs subvolumes..."
    
    # Mount root filesystem temporarily
    mkdir -p /mnt/root
    mount "${PRIMARY_NVME}p2" /mnt/root
    
    # Create root subvolumes
    log "Creating root filesystem subvolumes..."
    btrfs subvolume create /mnt/root/@
    btrfs subvolume create /mnt/root/@snapshots
    btrfs subvolume create /mnt/root/@tmp
    btrfs subvolume create /mnt/root/@var_log
    btrfs subvolume create /mnt/root/@var_cache
    btrfs subvolume create /mnt/root/@opt
    btrfs subvolume create /mnt/root/@usr_local
    
    umount /mnt/root
    
    # Mount home filesystem temporarily
    mkdir -p /mnt/home
    mount "${SECONDARY_NVME}p1" /mnt/home
    
    # Create home subvolumes
    log "Creating home filesystem subvolumes..."
    btrfs subvolume create /mnt/home/@home
    btrfs subvolume create /mnt/home/@home_snapshots
    btrfs subvolume create /mnt/home/@docker
    btrfs subvolume create /mnt/home/@vms
    
    umount /mnt/home
    
    # Mount bulk filesystem temporarily  
    mkdir -p /mnt/bulk
    mount "${BULK_SATA}p1" /mnt/bulk
    
    # Create bulk subvolumes
    log "Creating bulk storage subvolumes..."
    btrfs subvolume create /mnt/bulk/@archives
    btrfs subvolume create /mnt/bulk/@builds
    btrfs subvolume create /mnt/bulk/@containers
    btrfs subvolume create /mnt/bulk/@backup
    
    umount /mnt/bulk
}

# Setup mount points and fstab
setup_mounts() {
    log "Setting up mount points..."
    
    # Create mount directories
    mkdir -p /mnt/target
    mkdir -p /mnt/target/boot/efi
    mkdir -p /mnt/target/home
    mkdir -p /mnt/target/tmp
    mkdir -p /mnt/target/var/log
    mkdir -p /mnt/target/var/cache
    mkdir -p /mnt/target/opt
    mkdir -p /mnt/target/usr/local
    mkdir -p /mnt/target/mnt/bulk
    mkdir -p /mnt/target/var/lib/docker
    mkdir -p /mnt/target/var/lib/libvirt
    
    # Get UUIDs
    ROOT_UUID=$(blkid -s UUID -o value "${PRIMARY_NVME}p2")
    HOME_UUID=$(blkid -s UUID -o value "${SECONDARY_NVME}p1")
    BULK_UUID=$(blkid -s UUID -o value "${BULK_SATA}p1")
    EFI_UUID=$(blkid -s UUID -o value "${PRIMARY_NVME}p1")
    
    # Mount filesystems
    log "Mounting filesystems..."
    
    # Root
    mount -o defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@ \
        "${PRIMARY_NVME}p2" /mnt/target
    
    # EFI
    mount "${PRIMARY_NVME}p1" /mnt/target/boot/efi
    
    # Other root subvolumes
    mount -o defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@tmp \
        "${PRIMARY_NVME}p2" /mnt/target/tmp
    mount -o defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@var_log,nodatacow \
        "${PRIMARY_NVME}p2" /mnt/target/var/log
    mount -o defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@var_cache,nodatacow \
        "${PRIMARY_NVME}p2" /mnt/target/var/cache
    mount -o defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@opt \
        "${PRIMARY_NVME}p2" /mnt/target/opt
    mount -o defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@usr_local \
        "${PRIMARY_NVME}p2" /mnt/target/usr/local
    
    # Home filesystem
    mount -o defaults,noatime,compress=zstd:3,space_cache=v2,ssd,discard=async,subvol=@home \
        "${SECONDARY_NVME}p1" /mnt/target/home
    mount -o defaults,noatime,compress=zstd:3,space_cache=v2,ssd,discard=async,subvol=@docker,nodatacow \
        "${SECONDARY_NVME}p1" /mnt/target/var/lib/docker
    mount -o defaults,noatime,compress=zstd:3,space_cache=v2,ssd,discard=async,subvol=@vms,nodatacow \
        "${SECONDARY_NVME}p1" /mnt/target/var/lib/libvirt
    
    # Bulk storage
    mount -o defaults,noatime,compress=zstd:6,space_cache=v2,ssd,discard=async \
        "${BULK_SATA}p1" /mnt/target/mnt/bulk
    
    # Generate fstab
    log "Generating fstab..."
    cat > /mnt/target/etc/fstab << EOF
# /etc/fstab: static file system information.
# <file system> <mount point> <type> <options> <dump> <pass>

# Root filesystem (ROOT)
UUID=$ROOT_UUID / btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@ 0 1

# EFI System Partition (EFI_SYSTEM)
UUID=$EFI_UUID /boot/efi vfat defaults,noatime 0 2

# Root subvolumes (ROOT)
UUID=$ROOT_UUID /tmp btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@tmp,nodatacow 0 0
UUID=$ROOT_UUID /var/log btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@var_log,nodatacow 0 0
UUID=$ROOT_UUID /var/cache btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@var_cache,nodatacow 0 0
UUID=$ROOT_UUID /opt btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@opt 0 0
UUID=$ROOT_UUID /usr/local btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,discard=async,subvol=@usr_local 0 0

# Home filesystem (HOME)
UUID=$HOME_UUID /home btrfs defaults,noatime,compress=zstd:3,space_cache=v2,ssd,discard=async,subvol=@home 0 2
UUID=$HOME_UUID /var/lib/docker btrfs defaults,noatime,compress=zstd:3,space_cache=v2,ssd,discard=async,subvol=@docker,nodatacow 0 0
UUID=$HOME_UUID /var/lib/libvirt btrfs defaults,noatime,compress=zstd:3,space_cache=v2,ssd,discard=async,subvol=@vms,nodatacow 0 0

# Bulk storage (BULK)
UUID=$BULK_UUID /mnt/bulk btrfs defaults,noatime,compress=zstd:6,space_cache=v2,ssd,discard=async 0 2

EOF
    
    log "Storage setup complete!"
    log "Your filesystems are mounted at /mnt/target"
    log "fstab has been generated at /mnt/target/etc/fstab"
}

# Main execution
main() {
    log "Starting development workstation storage setup..."
    
    check_root
    verify_devices
    confirm_action
    install_packages
    create_partitions
    format_filesystems
    create_subvolumes
    setup_mounts
    
    log "✓ Storage setup completed successfully!"
    log "Next steps:"
    log "1. Install your OS to /mnt/target"
    log "2. Copy the generated fstab to your installed system"
    log "3. Run the snapshot setup script after OS installation"
}

# Run main function
main "$@"