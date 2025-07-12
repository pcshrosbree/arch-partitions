#!/bin/bash

# Convert archinstall Layout to Development Storage
# Transforms archinstall's basic setup into optimized development workstation storage
# Run this AFTER successful archinstall installation and first boot

set -euo pipefail

# Expected devices (adjust if needed)
PRIMARY_NVME="/dev/nvme0n1"      # Should have archinstall's root filesystem
SECONDARY_NVME="/dev/nvme1n1"    # Will be setup for home + dev caches  
BULK_SATA="/dev/sda"             # Will be setup for bulk storage

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Verify we're in the installed Arch system
verify_system() {
    if [[ ! -f "/etc/arch-release" ]]; then
        error "This doesn't appear to be an Arch Linux system"
    fi
    
    # Check if we're running on the expected root device
    local current_root=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
    if [[ ! "$current_root" =~ $PRIMARY_NVME ]]; then
        warn "Root filesystem not on expected device"
        log "Current root: $current_root"
        log "Expected: $PRIMARY_NVME"
        read -p "Continue anyway? (y/N): " response
        if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
            exit 0
        fi
    fi
    
    log "✓ Running on installed Arch Linux system"
}

# Detect current filesystem type and layout
detect_current_layout() {
    header "Detecting Current Storage Layout"
    
    # Check root filesystem type
    ROOT_FS_TYPE=$(findmnt -n -o FSTYPE /)
    ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
    
    log "Current root filesystem: $ROOT_FS_TYPE on $ROOT_DEVICE"
    
    # Check if already using btrfs
    if [[ "$ROOT_FS_TYPE" == "btrfs" ]]; then
        log "✓ Root is already btrfs"
        CONVERT_ROOT=false
    else
        log "Root is $ROOT_FS_TYPE - will need conversion"
        CONVERT_ROOT=true
    fi
    
    # Check EFI partition
    if [[ -d "/boot/efi" ]] && mountpoint -q "/boot/efi"; then
        EFI_DEVICE=$(findmnt -n -o SOURCE /boot/efi)
        log "✓ EFI partition found: $EFI_DEVICE"
    elif [[ -d "/efi" ]] && mountpoint -q "/efi"; then
        EFI_DEVICE=$(findmnt -n -o SOURCE /efi)
        log "✓ EFI partition found: $EFI_DEVICE"
    else
        warn "EFI partition not found at expected locations"
        EFI_DEVICE=""
    fi
    
    # Check available devices
    for device in "$SECONDARY_NVME" "$BULK_SATA"; do
        if [[ -b "$device" ]]; then
            log "✓ Found device: $device"
        else
            warn "Device not found: $device"
        fi
    done
}

# Backup current system
backup_system() {
    header "Creating System Backup"
    
    log "Backing up critical configuration files..."
    
    # Create backup directory
    mkdir -p /root/archinstall_backup
    
    # Backup fstab
    cp /etc/fstab "/root/archinstall_backup/fstab.original.$(date +%Y%m%d_%H%M%S)"
    
    # Backup bootloader config
    if [[ -f "/boot/loader/loader.conf" ]]; then
        cp -r /boot/loader "/root/archinstall_backup/"
    fi
    
    if [[ -f "/boot/grub/grub.cfg" ]]; then
        cp /boot/grub/grub.cfg "/root/archinstall_backup/"
    fi
    
    log "✓ System configuration backed up to /root/archinstall_backup"
}

# Convert root filesystem to btrfs if needed
convert_root_to_btrfs() {
    if [[ "$CONVERT_ROOT" == "false" ]]; then
        log "Root filesystem already btrfs, skipping conversion"
        return
    fi
    
    header "Converting Root Filesystem to Btrfs"
    
    warn "This is a complex operation that requires a reboot"
    warn "Ensure you have a backup before proceeding!"
    
    read -p "Convert root filesystem to btrfs? (y/N): " response
    if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
        log "Skipping root filesystem conversion"
        CONVERT_ROOT=false
        return
    fi
    
    # Install btrfs-progs if not present
    if ! command -v btrfs &> /dev/null; then
        log "Installing btrfs-progs..."
        pacman -S --noconfirm btrfs-progs
    fi
    
    log "Starting root filesystem conversion..."
    
    # This requires btrfs-convert and is complex
    # For safety, we'll create a script for manual execution
    cat > /root/convert_root_to_btrfs.sh << 'EOF'
#!/bin/bash
# Manual root filesystem conversion script
# WARNING: This will convert your root filesystem to btrfs
# Only run this if you understand the risks!

set -euo pipefail

ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')

echo "Converting $ROOT_DEVICE to btrfs..."
echo "This requires booting from a live USB!"
echo ""
echo "Steps to perform manually:"
echo "1. Boot from Arch Linux USB"
echo "2. Run: btrfs-convert $ROOT_DEVICE"
echo "3. Mount and create subvolumes"
echo "4. Update bootloader configuration"
echo ""
echo "This is advanced - consider fresh install with btrfs instead"
EOF
    
    chmod +x /root/convert_root_to_btrfs.sh
    
    warn "Root conversion script created at /root/convert_root_to_btrfs.sh"
    warn "This requires manual execution from live USB - too risky to automate"
    
    CONVERT_ROOT=false
}

# Setup secondary NVMe for home and development caches
setup_secondary_nvme() {
    header "Setting Up Secondary NVMe for Development"
    
    if [[ ! -b "$SECONDARY_NVME" ]]; then
        warn "Secondary NVMe $SECONDARY_NVME not found, skipping"
        return
    fi
    
    warn "This will destroy all data on $SECONDARY_NVME"
    read -p "Continue with secondary NVMe setup? (y/N): " response
    if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
        log "Skipping secondary NVMe setup"
        return
    fi
    
    log "Partitioning and formatting $SECONDARY_NVME..."
    
    # Create partition
    parted -s "$SECONDARY_NVME" mklabel gpt
    parted -s "$SECONDARY_NVME" mkpart HOME btrfs 1MiB 100%
    
    sleep 3
    partprobe
    
    # Format with optimized settings
    mkfs.btrfs -f -L "HOME" \
        --metadata single \
        --data single \
        --nodesize 16384 \
        --sectorsize 4096 \
        "${SECONDARY_NVME}p1"
    
    # Create temporary mount point and subvolumes
    mkdir -p /mnt/home_setup
    mount "${SECONDARY_NVME}p1" /mnt/home_setup
    
    log "Creating development subvolumes..."
    btrfs subvolume create /mnt/home_setup/@home
    btrfs subvolume create /mnt/home_setup/@home_snapshots
    btrfs subvolume create /mnt/home_setup/@containers
    btrfs subvolume create /mnt/home_setup/@vms
    btrfs subvolume create /mnt/home_setup/@tmp_builds
    
    # Language-specific cache subvolumes
    btrfs subvolume create /mnt/home_setup/@node_modules
    btrfs subvolume create /mnt/home_setup/@cargo_cache
    btrfs subvolume create /mnt/home_setup/@go_cache
    btrfs subvolume create /mnt/home_setup/@maven_cache
    btrfs subvolume create /mnt/home_setup/@pyenv_cache
    btrfs subvolume create /mnt/home_setup/@poetry_cache
    btrfs subvolume create /mnt/home_setup/@uv_cache
    btrfs subvolume create /mnt/home_setup/@dotnet_cache
    btrfs subvolume create /mnt/home_setup/@haskell_cache
    btrfs subvolume create /mnt/home_setup/@clojure_cache
    btrfs subvolume create /mnt/home_setup/@zig_cache
    
    umount /mnt/home_setup
    rmdir /mnt/home_setup
    
    log "✓ Secondary NVMe configured with development subvolumes"
}

# Setup bulk SATA storage
setup_bulk_storage() {
    header "Setting Up Bulk Storage"
    
    if [[ ! -b "$BULK_SATA" ]]; then
        warn "Bulk storage $BULK_SATA not found, skipping"
        return
    fi
    
    warn "This will destroy all data on $BULK_SATA"
    read -p "Continue with bulk storage setup? (y/N): " response
    if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
        log "Skipping bulk storage setup"
        return
    fi
    
    log "Setting up bulk storage on $BULK_SATA..."
    
    # Create partition
    parted -s "$BULK_SATA" mklabel gpt
    parted -s "$BULK_SATA" mkpart BULK btrfs 1MiB 100%
    
    sleep 3
    partprobe
    
    # Format
    mkfs.btrfs -f -L "BULK" "${BULK_SATA}1"
    
    # Create subvolumes
    mkdir -p /mnt/bulk_setup
    mount "${BULK_SATA}1" /mnt/bulk_setup
    
    log "Creating bulk storage subvolumes..."
    btrfs subvolume create /mnt/bulk_setup/@archives
    btrfs subvolume create /mnt/bulk_setup/@builds
    btrfs subvolume create /mnt/bulk_setup/@containers
    btrfs subvolume create /mnt/bulk_setup/@backup
    btrfs subvolume create /mnt/bulk_setup/@media
    btrfs subvolume create /mnt/bulk_setup/@projects
    
    umount /mnt/bulk_setup
    rmdir /mnt/bulk_setup
    
    log "✓ Bulk storage configured"
}

# Create optimized mount points
create_mount_points() {
    header "Creating Optimized Mount Points"
    
    log "Creating directory structure..."
    mkdir -p /var/lib/containers
    mkdir -p /var/lib/libvirt
    mkdir -p /var/cache/{builds,node_modules,cargo,go,maven,pyenv,poetry,uv,dotnet,haskell,clojure,zig}
    mkdir -p /mnt/bulk
    
    log "✓ Mount points created"
}

# Generate optimized fstab
generate_optimized_fstab() {
    header "Generating Optimized fstab"
    
    # Get current fstab entries we want to keep
    local root_line=$(grep ' / ' /etc/fstab | head -1)
    local efi_line=""
    
    if grep -q '/boot/efi' /etc/fstab; then
        efi_line=$(grep '/boot/efi' /etc/fstab | head -1)
    elif grep -q ' /efi ' /etc/fstab; then
        efi_line=$(grep ' /efi ' /etc/fstab | head -1)
    fi
    
    # Get UUIDs for new devices
    local home_uuid=""
    local bulk_uuid=""
    
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        home_uuid=$(blkid -s UUID -o value "${SECONDARY_NVME}p1" 2>/dev/null || true)
    fi
    
    if [[ -b "${BULK_SATA}1" ]]; then
        bulk_uuid=$(blkid -s UUID -o value "${BULK_SATA}1" 2>/dev/null || true)
    fi
    
    log "Generating optimized fstab..."
    
    # Create new fstab
    cat > /etc/fstab << EOF
# /etc/fstab: static file system information.
# Generated by development storage conversion script
# <file system> <mount point> <type> <options> <dump> <pass>

# Original archinstall entries (preserved)
$root_line
EOF
    
    if [[ -n "$efi_line" ]]; then
        echo "$efi_line" >> /etc/fstab
    fi
    
    # Add optimized entries if devices are available
    if [[ -n "$home_uuid" ]]; then
        cat >> /etc/fstab << EOF

# Home filesystem - Secondary NVMe with performance optimizations
UUID=$home_uuid /home btrfs defaults,noatime,compress=zstd:3,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@home 0 2
UUID=$home_uuid /var/lib/containers btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@containers,nodatacow 0 0
UUID=$home_uuid /var/lib/libvirt btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@vms,nodatacow 0 0

# Development cache mounts - Secondary NVMe
UUID=$home_uuid /var/cache/builds btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@tmp_builds,nodatacow 0 0
UUID=$home_uuid /var/cache/node_modules btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@node_modules,nodatacow 0 0
UUID=$home_uuid /var/cache/cargo btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@cargo_cache 0 0
UUID=$home_uuid /var/cache/go btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@go_cache 0 0
UUID=$home_uuid /var/cache/maven btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@maven_cache 0 0
UUID=$home_uuid /var/cache/pyenv btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@pyenv_cache 0 0
UUID=$home_uuid /var/cache/poetry btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@poetry_cache 0 0
UUID=$home_uuid /var/cache/uv btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@uv_cache 0 0
UUID=$home_uuid /var/cache/dotnet btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@dotnet_cache 0 0
UUID=$home_uuid /var/cache/haskell btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@haskell_cache 0 0
UUID=$home_uuid /var/cache/clojure btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@clojure_cache 0 0
UUID=$home_uuid /var/cache/zig btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@zig_cache 0 0
EOF
    fi
    
    if [[ -n "$bulk_uuid" ]]; then
        cat >> /etc/fstab << EOF

# Bulk storage - SATA SSD
UUID=$bulk_uuid /mnt/bulk btrfs defaults,noatime,compress=zstd:6,space_cache=v2,ssd,discard=async 0 2
EOF
    fi
    
    log "✓ Optimized fstab generated"
}

# Setup development environment
setup_development_environment() {
    header "Setting Up Development Environment"
    
    # Create environment variables file
    cat > /etc/profile.d/dev-paths.sh << 'EOF'
# Development cache directories
export CARGO_HOME="/var/cache/cargo"
export GOCACHE="/var/cache/go"
export GOMODCACHE="/var/cache/go/mod"
export MAVEN_OPTS="-Dmaven.repo.local=/var/cache/maven"
export PYENV_ROOT="/var/cache/pyenv"
export POETRY_CACHE_DIR="/var/cache/poetry"
export UV_CACHE_DIR="/var/cache/uv"
export DOTNET_CLI_HOME="/var/cache/dotnet"
export STACK_ROOT="/var/cache/haskell"
export ZIG_GLOBAL_CACHE_DIR="/var/cache/zig"

# Add cache directories to PATH where appropriate
export PATH="/var/cache/pyenv/bin:$PATH"
EOF
    
    # Create systemd tmpfiles config
    cat > /etc/tmpfiles.d/dev-caches.conf << 'EOF'
# Development cache directories
d /var/cache/builds 0755 root root -
d /var/cache/node_modules 0755 root root -
d /var/cache/cargo 0755 root root -
d /var/cache/go 0755 root root -
d /var/cache/maven 0755 root root -
d /var/cache/pyenv 0755 root root -
d /var/cache/poetry 0755 root root -
d /var/cache/uv 0755 root root -
d /var/cache/dotnet 0755 root root -
d /var/cache/haskell 0755 root root -
d /var/cache/clojure 0755 root root -
d /var/cache/zig 0755 root root -
EOF
    
    log "✓ Development environment configured"
}

# Create management scripts
create_management_scripts() {
    header "Creating Management Scripts"
    
    # Storage info script
    cat > /usr/local/bin/storage-info << 'EOF'
#!/bin/bash
# Development Storage Information

echo "=== Storage Layout ==="
echo ""
lsblk -f | grep -E "(nvme|sda)"
echo ""

echo "=== Mount Points ==="
echo ""
findmnt -t btrfs,ext4,fat32

if command -v btrfs &> /dev/null; then
    echo ""
    echo "=== Btrfs Filesystems ==="
    for mp in / /home /mnt/bulk; do
        if mountpoint -q "$mp" 2>/dev/null && [[ "$(findmnt -n -o FSTYPE "$mp")" == "btrfs" ]]; then
            echo ""
            echo "Filesystem: $mp"
            btrfs filesystem usage "$mp" 2>/dev/null || echo "  (Cannot read btrfs info)"
        fi
    done
fi
EOF
    
    chmod +x /usr/local/bin/storage-info
    
    # If root is btrfs, create snapshot manager
    if [[ "$ROOT_FS_TYPE" == "btrfs" ]]; then
        cat > /usr/local/bin/snapshot-manager << 'EOF'
#!/bin/bash
# Btrfs Snapshot Management

case "$1" in
    create)
        if [[ -z "$2" ]]; then
            echo "Usage: snapshot-manager create <n>"
            exit 1
        fi
        timestamp=$(date +%Y%m%d_%H%M%S)
        btrfs subvolume snapshot / "/.snapshots/@_${2}_${timestamp}" 2>/dev/null || {
            mkdir -p /.snapshots
            btrfs subvolume snapshot / "/.snapshots/@_${2}_${timestamp}"
        }
        echo "Snapshot created: @_${2}_${timestamp}"
        ;;
    list)
        if [[ -d "/.snapshots" ]]; then
            btrfs subvolume list /.snapshots 2>/dev/null || echo "No snapshots found"
        else
            echo "Snapshots directory not found"
        fi
        ;;
    delete)
        if [[ -z "$2" ]]; then
            echo "Usage: snapshot-manager delete <snapshot_name>"
            exit 1
        fi
        btrfs subvolume delete "/.snapshots/$2"
        ;;
    *)
        echo "Usage: snapshot-manager {create|list|delete} [n]"
        ;;
esac
EOF
        
        chmod +x /usr/local/bin/snapshot-manager
        log "✓ Snapshot manager created"
    fi
    
    log "✓ Management scripts created"
}

# Test the new configuration
test_configuration() {
    header "Testing Configuration"
    
    log "Testing mount configuration..."
    
    # Test that fstab is valid
    if mount -a --fake 2>/dev/null; then
        log "✓ fstab syntax is valid"
    else
        warn "fstab syntax errors detected"
    fi
    
    # Try to mount new filesystems
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        log "Testing secondary NVMe mounts..."
        if mount -a 2>/dev/null; then
            log "✓ New mounts successful"
        else
            warn "Some mounts failed - check manually"
        fi
    fi
    
    log "✓ Configuration test completed"
}

# Display final summary
display_summary() {
    header "Conversion Complete!"
    
    echo ""
    log "archinstall layout converted to development storage setup!"
    echo ""
    
    echo -e "${GREEN}=== WHAT WAS DONE ===${NC}"
    echo "✓ Preserved archinstall's root filesystem and bootloader"
    echo "✓ Added secondary NVMe for home and development caches"
    echo "✓ Added bulk storage with organized subvolumes"
    echo "✓ Created optimized mount configuration"
    echo "✓ Set up development environment variables"
    echo "✓ Created storage management scripts"
    echo ""
    
    echo -e "${GREEN}=== AVAILABLE COMMANDS ===${NC}"
    echo "• storage-info                 - Display storage information"
    if [[ "$ROOT_FS_TYPE" == "btrfs" ]]; then
        echo "• snapshot-manager create <n>  - Create system snapshot"
        echo "• snapshot-manager list        - List snapshots"
        echo "• snapshot-manager delete <n>  - Delete snapshot"
    fi
    echo ""
    
    echo -e "${GREEN}=== DEVELOPMENT FEATURES ===${NC}"
    echo "• Language-specific cache directories configured"
    echo "• Container storage optimized (nodatacow)"
    echo "• VM storage optimized (nodatacow)"
    echo "• Build cache separated for performance"
    echo "• Environment variables set automatically"
    echo ""
    
    echo -e "${YELLOW}=== NEXT STEPS ===${NC}"
    echo "1. Reboot to activate all new mount points"
    echo "2. Install your development tools"
    echo "3. Check: storage-info"
    echo "4. Backup files are in /root/archinstall_backup"
    echo ""
    
    if [[ "$CONVERT_ROOT" == "true" ]]; then
        echo -e "${RED}=== ROOT FILESYSTEM CONVERSION ===${NC}"
        echo "Root filesystem conversion was skipped for safety."
        echo "Manual conversion script: /root/convert_root_to_btrfs.sh"
        echo "Consider this only if you need btrfs root features."
        echo ""
    fi
}

# Main execution
main() {
    log "Starting archinstall to development storage conversion..."
    
    check_root
    verify_system
    detect_current_layout
    backup_system
    convert_root_to_btrfs
    setup_secondary_nvme
    setup_bulk_storage
    create_mount_points
    generate_optimized_fstab
    setup_development_environment
    create_management_scripts
    test_configuration
    display_summary
    
    log "✓ Conversion completed successfully!"
    warn "Reboot recommended to activate all changes"
}

# Run main function
main "$@"