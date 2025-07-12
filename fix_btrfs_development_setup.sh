#!/bin/bash

# Fix and Complete Btrfs Development Setup
# Completes the advanced development subvolume design and mounts

set -euo pipefail

# Device paths
PRIMARY_NVME="/dev/nvme0n1p2"    # Root btrfs filesystem
SECONDARY_NVME="/dev/nvme1n1"    # For home and dev caches
BULK_SATA="/dev/sda"             # For bulk storage

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
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

# Backup current fstab
backup_fstab() {
    log "Backing up current fstab..."
    cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    log "✓ fstab backed up"
}

# Create missing development subvolumes on root filesystem
create_missing_root_subvolumes() {
    header "Creating Missing Root Subvolumes"
    
    log "Mounting root btrfs filesystem to check/create subvolumes..."
    mkdir -p /mnt/root_btrfs
    mount "$PRIMARY_NVME" /mnt/root_btrfs
    
    # List existing subvolumes
    log "Current subvolumes:"
    btrfs subvolume list /mnt/root_btrfs | awk '{print $9}'
    echo ""
    
    # Create missing essential subvolumes
    declare -a missing_subvols=(
        "@snapshots"
        "@tmp" 
        "@var_log"
        "@var_cache"
        "@opt"
        "@usr_local"
    )
    
    for subvol in "${missing_subvols[@]}"; do
        if [[ ! -d "/mnt/root_btrfs/$subvol" ]]; then
            log "Creating subvolume: $subvol"
            btrfs subvolume create "/mnt/root_btrfs/$subvol"
        else
            log "✓ Subvolume exists: $subvol"
        fi
    done
    
    umount /mnt/root_btrfs
    rmdir /mnt/root_btrfs
    
    log "✓ Root subvolumes created"
}

# Setup secondary NVMe for development caches
setup_secondary_nvme() {
    header "Setting Up Secondary NVMe for Development"
    
    if [[ ! -b "$SECONDARY_NVME" ]]; then
        warn "Secondary NVMe $SECONDARY_NVME not found"
        return
    fi
    
    # Check if already partitioned
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        log "Secondary NVMe already partitioned"
    else
        warn "This will destroy all data on $SECONDARY_NVME"
        read -p "Continue with secondary NVMe setup? (y/N): " response
        if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
            log "Skipping secondary NVMe setup"
            return
        fi
        
        log "Partitioning $SECONDARY_NVME..."
        parted -s "$SECONDARY_NVME" mklabel gpt
        parted -s "$SECONDARY_NVME" mkpart HOME btrfs 1MiB 100%
        
        sleep 3
        partprobe
        
        log "Formatting ${SECONDARY_NVME}p1..."
        mkfs.btrfs -f -L "HOME" \
            --metadata single \
            --data single \
            --nodesize 16384 \
            --sectorsize 4096 \
            "${SECONDARY_NVME}p1"
    fi
    
    # Create development subvolumes
    log "Setting up development subvolumes on secondary NVMe..."
    mkdir -p /mnt/home_btrfs
    mount "${SECONDARY_NVME}p1" /mnt/home_btrfs
    
    # Development subvolumes
    declare -a dev_subvols=(
        "@home"
        "@home_snapshots"
        "@containers"
        "@vms"
        "@tmp_builds"
        "@node_modules"
        "@cargo_cache"
        "@go_cache"
        "@maven_cache"
        "@pyenv_cache"
        "@poetry_cache"
        "@uv_cache"
        "@dotnet_cache"
        "@haskell_cache"
        "@clojure_cache"
        "@zig_cache"
    )
    
    for subvol in "${dev_subvols[@]}"; do
        if [[ ! -d "/mnt/home_btrfs/$subvol" ]]; then
            log "Creating development subvolume: $subvol"
            btrfs subvolume create "/mnt/home_btrfs/$subvol"
        else
            log "✓ Development subvolume exists: $subvol"
        fi
    done
    
    umount /mnt/home_btrfs
    rmdir /mnt/home_btrfs
    
    log "✓ Secondary NVMe configured for development"
}

# Setup bulk storage
setup_bulk_storage() {
    header "Setting Up Bulk Storage"
    
    if [[ ! -b "$BULK_SATA" ]]; then
        warn "Bulk storage $BULK_SATA not found"
        return
    fi
    
    # Check if already partitioned
    if [[ -b "${BULK_SATA}1" ]]; then
        log "Bulk storage already partitioned"
    else
        warn "This will destroy all data on $BULK_SATA"
        read -p "Continue with bulk storage setup? (y/N): " response
        if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
            log "Skipping bulk storage setup"
            return
        fi
        
        log "Setting up bulk storage on $BULK_SATA..."
        parted -s "$BULK_SATA" mklabel gpt
        parted -s "$BULK_SATA" mkpart BULK btrfs 1MiB 100%
        
        sleep 3
        partprobe
        
        mkfs.btrfs -f -L "BULK" "${BULK_SATA}1"
    fi
    
    # Create bulk subvolumes
    mkdir -p /mnt/bulk_btrfs
    mount "${BULK_SATA}1" /mnt/bulk_btrfs
    
    declare -a bulk_subvols=(
        "@archives"
        "@builds"
        "@containers"
        "@backup"
        "@media"
        "@projects"
    )
    
    for subvol in "${bulk_subvols[@]}"; do
        if [[ ! -d "/mnt/bulk_btrfs/$subvol" ]]; then
            log "Creating bulk subvolume: $subvol"
            btrfs subvolume create "/mnt/bulk_btrfs/$subvol"
        else
            log "✓ Bulk subvolume exists: $subvol"
        fi
    done
    
    umount /mnt/bulk_btrfs
    rmdir /mnt/bulk_btrfs
    
    log "✓ Bulk storage configured"
}

# Create all required mount points
create_mount_points() {
    header "Creating Mount Point Directories"
    
    log "Creating directory structure..."
    
    # Root filesystem mount points
    mkdir -p /.snapshots
    mkdir -p /tmp
    mkdir -p /var/log
    mkdir -p /var/cache
    mkdir -p /opt
    mkdir -p /usr/local
    
    # Home and development mount points  
    mkdir -p /home
    mkdir -p /var/lib/containers
    mkdir -p /var/lib/libvirt
    
    # Development cache directories
    mkdir -p /var/cache/{builds,node_modules,cargo,go,maven,pyenv,poetry,uv,dotnet,haskell,clojure,zig}
    
    # Bulk storage
    mkdir -p /mnt/bulk
    
    log "✓ All mount point directories created"
}

# Generate complete optimized fstab
generate_complete_fstab() {
    header "Generating Complete Optimized fstab"
    
    # Get UUIDs
    ROOT_UUID=$(blkid -s UUID -o value "$PRIMARY_NVME")
    EFI_UUID=""
    HOME_UUID=""
    BULK_UUID=""
    
    # Find EFI partition
    if [[ -b "/dev/nvme0n1p1" ]]; then
        EFI_UUID=$(blkid -s UUID -o value "/dev/nvme0n1p1" 2>/dev/null || true)
    fi
    
    # Secondary NVMe UUID
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        HOME_UUID=$(blkid -s UUID -o value "${SECONDARY_NVME}p1" 2>/dev/null || true)
    fi
    
    # Bulk storage UUID
    if [[ -b "${BULK_SATA}1" ]]; then
        BULK_UUID=$(blkid -s UUID -o value "${BULK_SATA}1" 2>/dev/null || true)
    fi
    
    log "Generating optimized fstab..."
    
    cat > /etc/fstab << EOF
# /etc/fstab: static file system information.
# Generated by btrfs development setup script
# <file system> <mount point> <type> <options> <dump> <pass>

# Root filesystem (PRIMARY_NVME) - High-performance btrfs setup
UUID=$ROOT_UUID / btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@ 0 1
EOF
    
    # Add EFI if available
    if [[ -n "$EFI_UUID" ]]; then
        cat >> /etc/fstab << EOF

# EFI System Partition
UUID=$EFI_UUID /boot/efi vfat defaults,noatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 2
EOF
    fi
    
    # Add root subvolumes
    cat >> /etc/fstab << EOF

# Root filesystem subvolumes with performance optimizations
UUID=$ROOT_UUID /.snapshots btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@snapshots 0 0
UUID=$ROOT_UUID /tmp btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@tmp,nodatacow 0 0
UUID=$ROOT_UUID /var/log btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@var_log,nodatacow 0 0
UUID=$ROOT_UUID /var/cache btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@var_cache,nodatacow 0 0
UUID=$ROOT_UUID /opt btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@opt 0 0
UUID=$ROOT_UUID /usr/local btrfs defaults,noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@usr_local 0 0
EOF
    
    # Add home/development entries if secondary NVMe is available
    if [[ -n "$HOME_UUID" ]]; then
        cat >> /etc/fstab << EOF

# Home filesystem (SECONDARY_NVME) - Development optimized
UUID=$HOME_UUID /home btrfs defaults,noatime,compress=zstd:3,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@home 0 2
UUID=$HOME_UUID /var/lib/containers btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@containers,nodatacow 0 0
UUID=$HOME_UUID /var/lib/libvirt btrfs defaults,noatime,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@vms,nodatacow 0 0

# Development cache mounts - Optimized for build performance
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
EOF
    fi
    
    # Add bulk storage if available
    if [[ -n "$BULK_UUID" ]]; then
        cat >> /etc/fstab << EOF

# Bulk storage (BULK_SATA) - Archive and project storage
UUID=$BULK_UUID /mnt/bulk btrfs defaults,noatime,compress=zstd:6,space_cache=v2,ssd,discard=async 0 2
EOF
    fi
    
    log "✓ Complete optimized fstab generated"
}

# Create development environment configuration
setup_development_environment() {
    header "Setting Up Development Environment"
    
    # Environment variables
    cat > /etc/profile.d/dev-paths.sh << 'EOF'
# Development cache directories - High-performance paths
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
    
    # Systemd tmpfiles configuration
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
    
    # Storage information script
    cat > /usr/local/bin/storage-info << 'EOF'
#!/bin/bash
# Development Storage Information Script

echo "=== BTRFS Development Storage Layout ==="
echo ""

echo "Block Devices:"
lsblk -f | grep -E "(nvme|sda)"
echo ""

echo "=== Current Mounts ==="
findmnt -t btrfs | head -20
echo ""

echo "=== Btrfs Subvolumes ==="
echo "Root filesystem subvolumes:"
btrfs subvolume list / 2>/dev/null | head -10

if mountpoint -q /home && [[ "$(findmnt -n -o FSTYPE /home)" == "btrfs" ]]; then
    echo ""
    echo "Home filesystem subvolumes:"
    btrfs subvolume list /home 2>/dev/null | head -10
fi

if mountpoint -q /mnt/bulk && [[ "$(findmnt -n -o FSTYPE /mnt/bulk)" == "btrfs" ]]; then
    echo ""
    echo "Bulk storage subvolumes:"
    btrfs subvolume list /mnt/bulk 2>/dev/null
fi

echo ""
echo "=== Filesystem Usage ==="
echo "Root filesystem:"
btrfs filesystem usage / 2>/dev/null | head -10

if mountpoint -q /home && [[ "$(findmnt -n -o FSTYPE /home)" == "btrfs" ]]; then
    echo ""
    echo "Home filesystem:"
    btrfs filesystem usage /home 2>/dev/null | head -10
fi

echo ""
echo "=== Development Cache Directories ==="
du -sh /var/cache/* 2>/dev/null | sort -hr | head -10 || echo "No cache directories found"
EOF
    
    chmod +x /usr/local/bin/storage-info
    
    # Snapshot management script
    cat > /usr/local/bin/snapshot-manager << 'EOF'
#!/bin/bash
# Btrfs Snapshot Management for Development

case "$1" in
    create)
        if [[ -z "$2" ]]; then
            echo "Usage: snapshot-manager create <name>"
            echo "Example: snapshot-manager create before-update"
            exit 1
        fi
        timestamp=$(date +%Y%m%d_%H%M%S)
        snapshot_name="@_${2}_${timestamp}"
        
        if [[ ! -d "/.snapshots" ]]; then
            echo "Creating snapshots directory..."
            mkdir -p /.snapshots
        fi
        
        echo "Creating snapshot: $snapshot_name"
        btrfs subvolume snapshot / "/.snapshots/$snapshot_name"
        echo "✓ Snapshot created: /.snapshots/$snapshot_name"
        ;;
    list)
        if [[ -d "/.snapshots" ]]; then
            echo "Available snapshots:"
            btrfs subvolume list /.snapshots 2>/dev/null | awk '{print $9}' | sort
        else
            echo "No snapshots directory found"
        fi
        ;;
    delete)
        if [[ -z "$2" ]]; then
            echo "Usage: snapshot-manager delete <snapshot_name>"
            echo "Use 'snapshot-manager list' to see available snapshots"
            exit 1
        fi
        if [[ -d "/.snapshots/$2" ]]; then
            echo "Deleting snapshot: $2"
            btrfs subvolume delete "/.snapshots/$2"
            echo "✓ Snapshot deleted: $2"
        else
            echo "Snapshot not found: $2"
            exit 1
        fi
        ;;
    cleanup)
        if [[ -d "/.snapshots" ]]; then
            echo "Cleaning up snapshots older than 30 days..."
            find /.snapshots -maxdepth 1 -type d -mtime +30 -exec basename {} \; | while read snapshot; do
                if [[ "$snapshot" != ".snapshots" ]] && [[ "$snapshot" =~ ^@_ ]]; then
                    echo "Removing old snapshot: $snapshot"
                    btrfs subvolume delete "/.snapshots/$snapshot" 2>/dev/null || true
                fi
            done
            echo "✓ Cleanup complete"
        else
            echo "No snapshots directory found"
        fi
        ;;
    *)
        echo "Btrfs Snapshot Manager for Development"
        echo ""
        echo "Usage: snapshot-manager {create|list|delete|cleanup} [name]"
        echo ""
        echo "Commands:"
        echo "  create <name>    - Create a new system snapshot"
        echo "  list             - List all snapshots"
        echo "  delete <name>    - Delete a specific snapshot"
        echo "  cleanup          - Remove snapshots older than 30 days"
        echo ""
        echo "Examples:"
        echo "  snapshot-manager create before-update"
        echo "  snapshot-manager list"
        echo "  snapshot-manager delete @_before-update_20240101_120000"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/snapshot-manager
    
    log "✓ Management scripts created"
    log "  - storage-info: Display comprehensive storage information"
    log "  - snapshot-manager: Manage btrfs snapshots"
}

# Test and mount all filesystems
test_and_mount() {
    header "Testing and Mounting Filesystems"
    
    log "Testing fstab syntax..."
    if mount -a --fake 2>/dev/null; then
        log "✓ fstab syntax is valid"
    else
        error "fstab syntax errors detected!"
    fi
    
    log "Mounting all filesystems..."
    if mount -a; then
        log "✓ All filesystems mounted successfully"
    else
        warn "Some filesystems failed to mount - check manually"
    fi
    
    # Verify key mounts
    log "Verifying key mount points..."
    local key_mounts=("/" "/.snapshots" "/var/cache")
    
    for mount_point in "${key_mounts[@]}"; do
        if mountpoint -q "$mount_point"; then
            log "✓ $mount_point mounted correctly"
        else
            warn "✗ $mount_point not mounted"
        fi
    done
    
    # Check development cache directories if secondary NVMe exists
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        local dev_mounts=("/home" "/var/cache/cargo" "/var/cache/go")
        for mount_point in "${dev_mounts[@]}"; do
            if mountpoint -q "$mount_point"; then
                log "✓ $mount_point mounted correctly"
            else
                warn "✗ $mount_point not mounted"
            fi
        done
    fi
}

# Fix user home directory
fix_user_home() {
    header "Fixing User Home Directory"
    
    # Get the actual user (not root)
    ACTUAL_USER=$(who | head -1 | awk '{print $1}' 2>/dev/null || echo "peter")
    
    if [[ "$ACTUAL_USER" == "root" ]] || [[ -z "$ACTUAL_USER" ]]; then
        log "Detecting user from /home directory..."
        ACTUAL_USER=$(ls /home/ 2>/dev/null | head -1 || echo "peter")
    fi
    
    log "Setting up home directory for user: $ACTUAL_USER"
    
    # Ensure home directory exists and has correct permissions
    mkdir -p "/home/$ACTUAL_USER"
    
    # Get user ID and group ID
    if id "$ACTUAL_USER" &>/dev/null; then
        chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER"
        log "✓ Home directory created and permissions set for $ACTUAL_USER"
    else
        warn "User $ACTUAL_USER not found in system, using default permissions"
    fi
}

# Display final summary
display_final_summary() {
    header "Development Storage Setup Complete!"
    
    echo ""
    log "Advanced btrfs development storage is now configured!"
    echo ""
    
    echo -e "${GREEN}=== STORAGE LAYOUT ===${NC}"
    echo "Primary NVMe (nvme0n1p2): Root + System subvolumes"
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        echo "Secondary NVMe (nvme1n1p1): Home + Development caches"
    fi
    if [[ -b "${BULK_SATA}1" ]]; then
        echo "Bulk SATA (sda1): Archive + Project storage"
    fi
    echo ""
    
    echo -e "${GREEN}=== DEVELOPMENT FEATURES ===${NC}"
    echo "✓ Language-specific cache directories optimized"
    echo "✓ Container storage with nodatacow for performance"
    echo "✓ VM storage optimized for large files"
    echo "✓ Build caches separated for faster compilation"
    echo "✓ Snapshot management system ready"
    echo "✓ High-performance mount options applied"
    echo ""
    
    echo -e "${GREEN}=== AVAILABLE COMMANDS ===${NC}"
    echo "• storage-info                    - Display storage information"
    echo "• snapshot-manager create <name>  - Create system snapshot"
    echo "• snapshot-manager list           - List all snapshots"
    echo "• snapshot-manager delete <name>  - Delete snapshot"
    echo "• snapshot-manager cleanup        - Remove old snapshots"
    echo ""
    
    echo -e "${GREEN}=== DEVELOPMENT PATHS ===${NC}"
    echo "• Cargo cache: /var/cache/cargo"
    echo "• Go cache: /var/cache/go"
    echo "• Node modules: /var/cache/node_modules"
    echo "• Python (pyenv): /var/cache/pyenv"
    echo "• Poetry: /var/cache/poetry"
    echo "• Maven: /var/cache/maven"
    echo "• Build temp: /var/cache/builds"
    echo ""
    
    echo -e "${YELLOW}=== NEXT STEPS ===${NC}"
    echo "1. Reboot to ensure all mounts are stable"
    echo "2. Create your first snapshot: sudo snapshot-manager create initial"
    echo "3. Check storage: storage-info"
    echo "4. Install development tools - cache paths are pre-configured"
    echo ""
    
    echo -e "${GREEN}=== MOUNT STATUS ===${NC}"
    findmnt -t btrfs | head -10
    echo ""
    
    log "✓ All development storage optimizations are now active!"
}

# Main execution
main() {
    log "Starting btrfs development storage setup and fix..."
    
    check_root
    backup_fstab
    create_missing_root_subvolumes
    setup_secondary_nvme
    setup_bulk_storage
    create_mount_points
    generate_complete_fstab
    setup_development_environment
    create_management_scripts
    test_and_mount
    fix_user_home
    display_final_summary
    
    log "✓ Development storage setup completed successfully!"
    warn "Reboot recommended to ensure all changes are stable"
}

# Run main function
main "$@"