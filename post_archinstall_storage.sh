#!/bin/bash

# Post-archinstall Storage Setup Script
# Creates advanced btrfs subvolumes and optimized mount configuration
# Run this AFTER archinstall completes and you've booted into the new system

set -euo pipefail

# Configuration - These should match your pre-install script
PRIMARY_NVME="/dev/nvme0n1"      # 14,000 MB/s PCIe 5 NVMe (4TB) - Root + EFI
SECONDARY_NVME="/dev/nvme1n1"    # 7,450 MB/s PCIe 4 NVMe (4TB) - Home
BULK_SATA="/dev/sda"             # 8TB SATA SSD - Bulk storage

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Verify we're in the installed system
verify_system() {
    if [[ ! -f "/etc/arch-release" ]]; then
        error "This doesn't appear to be an Arch Linux system. Run this after archinstall completion."
    fi
    
    if [[ "$(findmnt -n -o SOURCE /)" != "${PRIMARY_NVME}p2" ]]; then
        warn "Root filesystem doesn't appear to be on expected device"
        log "Current root: $(findmnt -n -o SOURCE /)"
        log "Expected: ${PRIMARY_NVME}p2"
        read -p "Continue anyway? (y/N): " response
        if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
            exit 0
        fi
    fi
    
    log "✓ Running on installed Arch Linux system"
}

# Backup current fstab
backup_fstab() {
    log "Backing up current fstab..."
    cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    log "✓ fstab backed up"
}

# Create advanced subvolumes for development
create_advanced_subvolumes() {
    header "Creating Advanced Subvolumes"
    
    # Create temporary mount points
    mkdir -p /mnt/{root_btrfs,home_btrfs,bulk_btrfs}
    
    # Mount root filesystem
    log "Mounting root filesystem for subvolume creation..."
    mount "${PRIMARY_NVME}p2" /mnt/root_btrfs
    
    # Create additional root subvolumes
    log "Creating additional root subvolumes..."
    btrfs subvolume create /mnt/root_btrfs/@tmp
    btrfs subvolume create /mnt/root_btrfs/@var_log
    btrfs subvolume create /mnt/root_btrfs/@var_cache
    btrfs subvolume create /mnt/root_btrfs/@opt
    btrfs subvolume create /mnt/root_btrfs/@usr_local
    
    # Mount home filesystem
    log "Mounting home filesystem for subvolume creation..."
    mount "${SECONDARY_NVME}p1" /mnt/home_btrfs
    
    # Create home subvolumes for development
    log "Creating development-optimized home subvolumes..."
    btrfs subvolume create /mnt/home_btrfs/@home
    btrfs subvolume create /mnt/home_btrfs/@home_snapshots
    btrfs subvolume create /mnt/home_btrfs/@containers
    btrfs subvolume create /mnt/home_btrfs/@vms
    btrfs subvolume create /mnt/home_btrfs/@tmp_builds
    
    # Language-specific cache subvolumes
    log "Creating language-specific cache subvolumes..."
    btrfs subvolume create /mnt/home_btrfs/@node_modules
    btrfs subvolume create /mnt/home_btrfs/@cargo_cache
    btrfs subvolume create /mnt/home_btrfs/@go_cache
    btrfs subvolume create /mnt/home_btrfs/@maven_cache
    btrfs subvolume create /mnt/home_btrfs/@pyenv_cache
    btrfs subvolume create /mnt/home_btrfs/@poetry_cache
    btrfs subvolume create /mnt/home_btrfs/@uv_cache
    btrfs subvolume create /mnt/home_btrfs/@dotnet_cache
    btrfs subvolume create /mnt/home_btrfs/@haskell_cache
    btrfs subvolume create /mnt/home_btrfs/@clojure_cache
    btrfs subvolume create /mnt/home_btrfs/@zig_cache
    
    # Mount bulk filesystem
    log "Mounting bulk filesystem for subvolume creation..."
    mount "${BULK_SATA}1" /mnt/bulk_btrfs
    
    # Create bulk storage subvolumes
    log "Creating bulk storage subvolumes..."
    btrfs subvolume create /mnt/bulk_btrfs/@archives
    btrfs subvolume create /mnt/bulk_btrfs/@builds
    btrfs subvolume create /mnt/bulk_btrfs/@containers
    btrfs subvolume create /mnt/bulk_btrfs/@backup
    btrfs subvolume create /mnt/bulk_btrfs/@media
    btrfs subvolume create /mnt/bulk_btrfs/@projects
    
    # Unmount temporary mounts
    umount /mnt/root_btrfs
    umount /mnt/home_btrfs
    umount /mnt/bulk_btrfs
    rmdir /mnt/{root_btrfs,home_btrfs,bulk_btrfs}
    
    log "✓ Advanced subvolumes created"
}

# Create mount points
create_mount_points() {
    header "Creating Mount Points"
    
    log "Creating directory structure..."
    mkdir -p /home
    mkdir -p /tmp
    mkdir -p /var/log
    mkdir -p /var/cache
    mkdir -p /opt
    mkdir -p /usr/local
    mkdir -p /var/lib/containers
    mkdir -p /var/lib/libvirt
    mkdir -p /var/cache/{builds,node_modules,cargo,go,maven,pyenv,poetry,uv,dotnet,haskell,clojure,zig}
    mkdir -p /mnt/bulk
    
    log "✓ Mount points created"
}

# Generate optimized fstab
generate_fstab() {
    header "Generating Optimized fstab"
    
    # Get UUIDs
    ROOT_UUID=$(blkid -s UUID -o value "${PRIMARY_NVME}p2")
    HOME_UUID=$(blkid -s UUID -o value "${SECONDARY_NVME}p1")
    BULK_UUID=$(blkid -s UUID -o value "${BULK_SATA}1")
    EFI_UUID=$(blkid -s UUID -o value "${PRIMARY_NVME}p1")
    
    log "Generating new fstab with performance optimizations..."
    
    cat > /etc/fstab << EOF
# /etc/fstab: static file system information.
# Generated by post-archinstall storage setup script
# <file system> <mount point> <type> <options> <dump> <pass>

# Root filesystem (ROOT) - Primary NVMe with performance optimizations
UUID=$ROOT_UUID / btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@ 0 1

# EFI System Partition
UUID=$EFI_UUID /boot/efi vfat defaults,noatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2

# Root subvolumes with performance optimizations
UUID=$ROOT_UUID /tmp btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@tmp,nodatacow 0 0
UUID=$ROOT_UUID /var/log btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@var_log,nodatacow 0 0
UUID=$ROOT_UUID /var/cache btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@var_cache,nodatacow 0 0
UUID=$ROOT_UUID /opt btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@opt 0 0
UUID=$ROOT_UUID /usr/local btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@usr_local 0 0

# Home filesystem - Secondary NVMe with enhanced performance
UUID=$HOME_UUID /home btrfs defaults,noatime,compress=zstd:3,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@home 0 2
UUID=$HOME_UUID /var/lib/containers btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@containers,nodatacow 0 0
UUID=$HOME_UUID /var/lib/libvirt btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@vms,nodatacow 0 0

# Development cache mounts - Secondary NVMe
UUID=$HOME_UUID /var/cache/builds btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@tmp_builds,nodatacow 0 0
UUID=$HOME_UUID /var/cache/node_modules btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@node_modules,nodatacow 0 0
UUID=$HOME_UUID /var/cache/cargo btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@cargo_cache 0 0
UUID=$HOME_UUID /var/cache/go btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@go_cache 0 0
UUID=$HOME_UUID /var/cache/maven btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@maven_cache 0 0
UUID=$HOME_UUID /var/cache/pyenv btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@pyenv_cache 0 0
UUID=$HOME_UUID /var/cache/poetry btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@poetry_cache 0 0
UUID=$HOME_UUID /var/cache/uv btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@uv_cache 0 0
UUID=$HOME_UUID /var/cache/dotnet btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@dotnet_cache 0 0
UUID=$HOME_UUID /var/cache/haskell btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@haskell_cache 0 0
UUID=$HOME_UUID /var/cache/clojure btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@clojure_cache 0 0
UUID=$HOME_UUID /var/cache/zig btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,subvol=@zig_cache 0 0

# Bulk storage - SATA SSD
UUID=$BULK_UUID /mnt/bulk btrfs defaults,noatime,compress=zstd:6,space_cache=v2,ssd,discard=async 0 2

EOF
    
    log "✓ Optimized fstab generated"
}

# Setup development environment configurations
setup_dev_environment() {
    header "Setting Up Development Environment"
    
    log "Creating development environment configurations..."
    
    # Create systemd tmpfiles for cache directories
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
    
    # Create script to set up development environment variables
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
    
    log "✓ Development environment configured"
}

# Create helpful scripts
create_helper_scripts() {
    header "Creating Helper Scripts"
    
    # Snapshot management script
    cat > /usr/local/bin/snapshot-manager << 'EOF'
#!/bin/bash
# Btrfs Snapshot Management Script

case "$1" in
    create)
        if [[ -z "$2" ]]; then
            echo "Usage: snapshot-manager create <name>"
            exit 1
        fi
        timestamp=$(date +%Y%m%d_%H%M%S)
        btrfs subvolume snapshot / "/.snapshots/@_${2}_${timestamp}"
        echo "Snapshot created: @_${2}_${timestamp}"
        ;;
    list)
        btrfs subvolume list / | grep snapshots
        ;;
    delete)
        if [[ -z "$2" ]]; then
            echo "Usage: snapshot-manager delete <snapshot_name>"
            exit 1
        fi
        btrfs subvolume delete "/.snapshots/$2"
        echo "Snapshot deleted: $2"
        ;;
    *)
        echo "Usage: snapshot-manager {create|list|delete} [name]"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/snapshot-manager
    
    # Storage info script
    cat > /usr/local/bin/storage-info << 'EOF'
#!/bin/bash
# Storage Information Script

echo "=== BTRFS Filesystem Usage ==="
echo ""
echo "Root filesystem:"
btrfs filesystem show /
echo ""
btrfs filesystem usage /
echo ""

echo "Home filesystem:"
btrfs filesystem show /home
echo ""
btrfs filesystem usage /home
echo ""

echo "Bulk storage:"
btrfs filesystem show /mnt/bulk
echo ""
btrfs filesystem usage /mnt/bulk
echo ""

echo "=== Subvolumes ==="
echo ""
echo "Root subvolumes:"
btrfs subvolume list / | head -10
echo ""
echo "Home subvolumes:"
btrfs subvolume list /home | head -10
echo ""

echo "=== Mount Points ==="
echo ""
findmnt -t btrfs
EOF
    
    chmod +x /usr/local/bin/storage-info
    
    log "✓ Helper scripts created"
    log "  - snapshot-manager: Manage btrfs snapshots"
    log "  - storage-info: Display storage information"
}

# Test mount configuration
test_mounts() {
    header "Testing Mount Configuration"
    
    log "Testing mount configuration..."
    
    # Test mount
    if mount -a; then
        log "✓ All filesystems mounted successfully"
    else
        error "Failed to mount filesystems. Check fstab configuration."
    fi
    
    # Verify key mounts
    local key_mounts=("/" "/home" "/var/cache/cargo" "/var/cache/go" "/mnt/bulk")
    for mount_point in "${key_mounts[@]}"; do
        if mountpoint -q "$mount_point"; then
            log "✓ $mount_point mounted correctly"
        else
            warn "✗ $mount_point not mounted"
        fi
    done
}

# Display final configuration
display_final_config() {
    header "Setup Complete!"
    
    echo ""
    log "Post-archinstall storage setup completed successfully!"
    echo ""
    
    echo -e "${GREEN}=== STORAGE LAYOUT ===${NC}"
    echo "Primary NVMe (${PRIMARY_NVME}): Root + EFI"
    echo "Secondary NVMe (${SECONDARY_NVME}): Home + Dev Caches"
    echo "Bulk SATA (${BULK_SATA}): Bulk Storage"
    echo ""
    
    echo -e "${GREEN}=== DEVELOPMENT FEATURES ===${NC}"
    echo "• Language-specific cache directories configured"
    echo "• Container storage optimized (nodatacow)"
    echo "• VM storage optimized (nodatacow)" 
    echo "• Build cache directories separated"
    echo "• Performance-tuned mount options"
    echo ""
    
    echo -e "${GREEN}=== HELPER COMMANDS ===${NC}"
    echo "• snapshot-manager create <name>  - Create system snapshot"
    echo "• snapshot-manager list          - List snapshots"
    echo "• snapshot-manager delete <name> - Delete snapshot"
    echo "• storage-info                   - Display storage stats"
    echo ""
    
    echo -e "${GREEN}=== NEXT STEPS ===${NC}"
    echo "1. Reboot to activate all mount points"
    echo "2. Install development tools"
    echo "3. Environment variables are set in /etc/profile.d/dev-paths.sh"
    echo "4. Create your first snapshot: sudo snapshot-manager create initial"
    echo ""
    
    echo -e "${YELLOW}=== NOTES ===${NC}"
    echo "• fstab backup: /etc/fstab.backup.*"
    echo "• Development cache paths configured automatically"
    echo "• Bulk storage available at /mnt/bulk"
    echo "• Container storage uses nodatacow for performance"
    echo ""
}

# Main execution
main() {
    log "Starting post-archinstall storage optimization..."
    
    check_root
    verify_system
    backup_fstab
    create_advanced_subvolumes
    create_mount_points
    generate_fstab
    setup_dev_environment
    create_helper_scripts
    test_mounts
    display_final_config
    
    log "✓ Post-archinstall storage setup completed!"
    log "A reboot is recommended to ensure all mount points are active."
}

# Run main function
main "$@"