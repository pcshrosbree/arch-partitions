    chmod +x /usr/local/bin/snapshot-monitor.sh
    
    log "Monitoring script created at /usr/local/bin/snapshot-monitor.sh"
}

# Create enhanced monitoring script with NVMe health checking
create_enhanced_monitoring() {
    log "Creating enhanced monitoring script with NVMe health checking..."
    
    cat > /usr/local/bin/nvme-health-monitor.sh << 'EOF'
#!/bin/bash

# NVMe Health and Temperature Monitoring Script

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check NVMe drive health
check_nvme_health() {
    local device="$1"
    local device_name="$2"
    
    if [[ ! -e "$device" ]]; then
        warn "$device_name not found at $device"
        return 1
    fi
    
    echo "=== $device_name Health Status ==="
    
    # Get temperature
    local temp=$(nvme smart-log "$device" 2>/dev/null | grep temperature | awk '{print $3}' || echo "N/A")
    
    # Get percentage used
    local usage=$(nvme smart-log "$device" 2>/dev/null | grep percentage_used | awk '{print $3}' | sed 's/%//' || echo "N/A")
    
    # Get available spare
    local spare=$(nvme smart-log "$device" 2>/dev/null | grep available_spare | awk '{print $3}' | sed 's/%//' || echo "N/A")
    
    echo "Temperature: ${temp}°C"
    echo "Percentage Used: ${usage}%"
    echo "Available Spare: ${spare}%"
    
    # Alert conditions
    if [[ "$temp" != "N/A" && "$temp" -gt 70 ]]; then
        error "High temperature detected: ${temp}°C"
    fi
    
    if [[ "$usage" != "N/A" && "$usage" -gt 80 ]]; then
        warn "High wear level: ${usage}%"
    fi
    
    if [[ "$spare" != "N/A" && "$spare" -lt 10 ]]; then
        error "Low available spare: ${spare}%"
    fi
    
    echo ""
}

# Check btrfs allocation and performance
check_btrfs_performance() {
    echo "=== Btrfs Performance Status ==="
    
    for fs in / /home /mnt/bulk; do
        if mountpoint -q "$fs"; then
            echo "Filesystem: $fs"
            btrfs filesystem usage "$fs" 2>/dev/null | grep "Free (estimated)" || echo "  Status: OK"
            echo ""
        fi
    done
}

# Main monitoring function
main() {
    log "NVMe Health and Performance Monitor"
    echo ""
    
    # Check NVMe drives
    check_nvme_health "/dev/nvme0n1" "Samsung SSD 9100 PRO (Primary)"
    check_nvme_health "/dev/nvme1n1" "TEAMGROUP T-Force Z540 (Secondary)"
    
    # Check btrfs performance
    check_btrfs_performance
    
    # Check I/O statistics
    echo "=== I/O Statistics ==="
    iostat -x 1 1 2>/dev/null | grep nvme || echo "iostat not available"
    echo ""
}

main "$@"
EOF

    chmod +x /usr/local/bin/nvme-health-monitor.sh
    
    # Create systemd service for regular health monitoring
    cat > /etc/systemd/system/nvme-health-monitor.service << 'EOF'
[Unit]
Description=NVMe Health Monitoring
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvme-health-monitor.sh
User=root
EOF

    cat > /etc/systemd/system/nvme-health-monitor.timer << 'EOF'
[Unit]
Description=NVMe Health Monitoring Timer
Requires=nvme-health-monitor.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now nvme-health-monitor.timer
    
# Create development environment optimizations
create_dev_optimizations() {
    log "Creating development environment optimizations..."
    
    # Create VS Code settings for btrfs optimization
    mkdir -p /etc/skel/.config/Code/User
    cat > /etc/skel/.config/Code/User/settings.json << 'EOF'
{
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/tmp/**": true,
    "**/.snapshots/**": true,
    "**/target/**": true,
    "**/build/**": true
  },
  "search.exclude": {
    "**/.snapshots": true,
    "**/node_modules": true,
    "**/target": true,
    "**/build": true,
    "**/.git": true
  },
  "files.exclude": {
    "**/.snapshots": true
  }
}
EOF

    # Create Git performance configuration template
    cat > /etc/skel/.gitconfig-performance << 'EOF'
# Git performance optimizations for high-speed storage
# Add these to your ~/.gitconfig with: git config --global --add include.path ~/.gitconfig-performance

[core]
    preloadindex = true
    fscache = true

[gc]
    auto = 256

[pack]
    threads = 0
    windowMemory = 100M
    packSizeLimit = 100M

[feature]
    manyFiles = true

[index]
    threads = true
EOF

    # Create development environment optimizations with memory awareness
    cat > /usr/local/bin/setup-dev-caches.sh << 'EOF'
#!/bin/bash

# Development Cache Setup Script with DDR5-6000 Memory Optimization
# Links common development caches to optimized storage locations

set -euo pipefail

USER_HOME="${HOME:-/home/$(whoami)}"

# Create symlinks for development caches
setup_cache_links() {
    local cache_name="$1"
    local user_cache_dir="$2"
    local system_cache_dir="/var/cache/$cache_name"
    
    if [[ -d "$system_cache_dir" ]]; then
        # Create user-specific cache directory
        local user_cache_path="$system_cache_dir/$(whoami)"
        sudo mkdir -p "$user_cache_path"
        sudo chown "$(whoami):$(id -gn)" "$user_cache_path"
        
        # Remove existing cache and create symlink
        if [[ -e "$user_cache_dir" && ! -L "$user_cache_dir" ]]; then
            mv "$user_cache_dir" "$user_cache_dir.backup-$(date +%Y%m%d)"
        fi
        
        rm -f "$user_cache_dir"
        ln -sf "$user_cache_path" "$user_cache_dir"
        
        echo "✓ Linked $cache_name cache to optimized storage"
    fi
}

# Setup memory-optimized build environment
setup_memory_build_env() {
    echo "Setting up memory-optimized build environment..."
    
    # Create build environment script
    cat > "$USER_HOME/.build-env" << 'BUILDEOF'
# Memory-optimized build environment for DDR5-6000 system
# Source this file: source ~/.build-env

# Use more parallel jobs with large memory
export MAKEFLAGS="-j$(nproc)"
export CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"

# Increase memory limits for development tools
export NODE_OPTIONS="--max-old-space-size=16384"
export JAVA_OPTS="-Xmx32g -Xms8g"
export MAVEN_OPTS="-Xmx32g -Xms8g -XX:+UseG1GC"
export GRADLE_OPTS="-Xmx32g -Xms8g -XX:+UseG1GC"

# Rust optimizations for large memory
export CARGO_BUILD_JOBS="$(nproc)"
export RUSTC_WRAPPER=""

# Go optimizations
export GOMAXPROCS="$(nproc)"
export GOMEMLIMIT="32GiB"

# Use RAMdisk for temporary files if available
if [[ -d /tmp/ramdisk ]]; then
    export TMPDIR=/tmp/ramdisk
    export TMP=/tmp/ramdisk
    export TEMP=/tmp/ramdisk
fi

echo "✓ Memory-optimized build environment loaded"
echo "  - Parallel jobs: $(nproc)"
echo "  - Node.js memory: 16GB"
echo "  - JVM memory: 32GB"
echo "  - Temp directory: ${TMPDIR:-/tmp}"
BUILDEOF

    # Add to shell configuration
    if [[ -f "$USER_HOME/.bashrc" ]] && ! grep -q ".build-env" "$USER_HOME/.bashrc"; then
        echo "source ~/.build-env" >> "$USER_HOME/.bashrc"
    fi
    
    if [[ -f "$USER_HOME/.zshrc" ]] && ! grep -q ".build-env" "$USER_HOME/.zshrc"; then
        echo "source ~/.build-env" >> "$USER_HOME/.zshrc"
    fi
    
    echo "✓ Memory-optimized build environment configured"
}

# Setup common development caches
echo "Setting up development cache optimizations for DDR5-6000 system..."

# Node.js cache
setup_cache_links "node_modules" "$USER_HOME/.npm"

# Cargo (Rust) cache
setup_cache_links "cargo" "$USER_HOME/.cargo"

# Go module cache
setup_cache_links "go" "$USER_HOME/go"

# Maven cache
setup_cache_links "maven" "$USER_HOME/.m2"

# Setup memory-optimized build environment
setup_memory_build_env

echo ""
echo "Development cache setup complete!"
echo "Caches are now using optimized storage locations."
echo "Memory-optimized build environment configured."
echo "Restart your shell or run 'source ~/.build-env' to activate optimizations."
EOF

    chmod +x /usr/local/bin/setup-dev-caches.sh
    
    log "✓ Development environment optimizations created"
}#!/bin/bash

# Development Workstation Snapshot Setup Script
# Configures snapper for automatic btrfs snapshots with development-optimized settings
# Run this script after OS installation and first boot

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SNAPPER_CONFIGS_DIR="/etc/snapper/configs"
SYSTEMD_TIMERS_DIR="/etc/systemd/system"

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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Install required packages
install_packages() {
    log "Installing snapshot management and optimization packages..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y snapper btrfs-progs cpupower lm-sensors nvme-cli
    elif command -v dnf &> /dev/null; then
        dnf install -y snapper btrfs-progs cpupower lm_sensors nvme-cli
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm snapper btrfs-progs cpupower lm_sensors nvme-cli
    else
        warn "Could not determine package manager. Please install snapper, btrfs-progs, cpupower, lm_sensors, and nvme-cli manually."
        exit 1
    fi
    
    # Enable snapper service
    systemctl enable --now snapper-timeline.timer
    systemctl enable --now snapper-cleanup.timer
    
    # Enable CPU performance governor
    systemctl enable cpupower
    echo 'governor="performance"' > /etc/default/cpupower
}

# Create snapper configuration for root
create_root_config() {
    log "Creating snapper configuration for root filesystem..."
    
    # Create snapper config for root
    snapper -c root create-config /
    
    # Customize root config for development workstation
    cat > /etc/snapper/configs/root << 'EOF'
# snapper configuration for root filesystem
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"

# Development-optimized timeline settings
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"

# Frequent snapshots for active development
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="48"
TIMELINE_LIMIT_DAILY="14"
TIMELINE_LIMIT_WEEKLY="8"
TIMELINE_LIMIT_MONTHLY="6"
TIMELINE_LIMIT_YEARLY="2"

# Cleanup settings
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"

# Background comparison
BACKGROUND_COMPARISON="yes"

# Number cleanup
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"

# Sync ACL for proper permissions
SYNC_ACL="yes"
EOF
}

# Create snapper configuration for home
create_home_config() {
    log "Creating snapper configuration for home filesystem..."
    
    # Create snapper config for home
    snapper -c home create-config /home
    
    # Customize home config for development files
    cat > /etc/snapper/configs/home << 'EOF'
# snapper configuration for home filesystem
SUBVOLUME="/home"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.3"
FREE_LIMIT="0.15"

# Development-optimized timeline settings
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"

# More frequent snapshots for active development work
TIMELINE_MIN_AGE="900"
TIMELINE_LIMIT_HOURLY="72"
TIMELINE_LIMIT_DAILY="21"
TIMELINE_LIMIT_WEEKLY="12"
TIMELINE_LIMIT_MONTHLY="12"
TIMELINE_LIMIT_YEARLY="3"

# Cleanup settings
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="900"

# Background comparison
BACKGROUND_COMPARISON="yes"

# Number cleanup
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="900"
NUMBER_LIMIT="100"
NUMBER_LIMIT_IMPORTANT="20"

# Sync ACL for proper permissions
SYNC_ACL="yes"
EOF
}

# Create custom systemd timer for development snapshots
create_dev_snapshot_timer() {
    log "Creating development-specific snapshot timer..."
    
    # Create service file for development snapshots
    cat > /etc/systemd/system/snapper-dev-snapshot.service << 'EOF'
[Unit]
Description=Development Snapshot Service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/snapper -c root create --description "dev-auto"
ExecStart=/usr/bin/snapper -c home create --description "dev-auto"
User=root
EOF

    # Create timer file for every 30 minutes during work hours
    cat > /etc/systemd/system/snapper-dev-snapshot.timer << 'EOF'
[Unit]
Description=Development Snapshot Timer
Requires=snapper-dev-snapshot.service

[Timer]
# Run every 30 minutes during typical work hours (8 AM - 8 PM)
OnCalendar=Mon-Fri 08:00:00/30min
OnCalendar=Mon-Fri 08:30:00/30min
OnCalendar=Mon-Fri 09:00:00/30min
OnCalendar=Mon-Fri 09:30:00/30min
OnCalendar=Mon-Fri 10:00:00/30min
OnCalendar=Mon-Fri 10:30:00/30min
OnCalendar=Mon-Fri 11:00:00/30min
OnCalendar=Mon-Fri 11:30:00/30min
OnCalendar=Mon-Fri 12:00:00/30min
OnCalendar=Mon-Fri 12:30:00/30min
OnCalendar=Mon-Fri 13:00:00/30min
OnCalendar=Mon-Fri 13:30:00/30min
OnCalendar=Mon-Fri 14:00:00/30min
OnCalendar=Mon-Fri 14:30:00/30min
OnCalendar=Mon-Fri 15:00:00/30min
OnCalendar=Mon-Fri 15:30:00/30min
OnCalendar=Mon-Fri 16:00:00/30min
OnCalendar=Mon-Fri 16:30:00/30min
OnCalendar=Mon-Fri 17:00:00/30min
OnCalendar=Mon-Fri 17:30:00/30min
OnCalendar=Mon-Fri 18:00:00/30min
OnCalendar=Mon-Fri 18:30:00/30min
OnCalendar=Mon-Fri 19:00:00/30min
OnCalendar=Mon-Fri 19:30:00/30min
OnCalendar=Mon-Fri 20:00:00/30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable the timer
    systemctl daemon-reload
    systemctl enable --now snapper-dev-snapshot.timer
}

# Create backup script for critical development work
create_backup_script() {
    log "Creating backup script for critical development work..."
    
    cat > /usr/local/bin/dev-backup.sh << 'EOF'
#!/bin/bash

# Development Backup Script
# Creates tagged snapshots before major development milestones

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Function to create milestone snapshot
create_milestone_snapshot() {
    local description="$1"
    local tag="milestone-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating milestone snapshot: $description"
    
    # Create snapshots for both root and home
    snapper -c root create --description "$description" --userdata "milestone=true,tag=$tag"
    snapper -c home create --description "$description" --userdata "milestone=true,tag=$tag"
    
    log "Milestone snapshot created with tag: $tag"
}

# Function to create pre-deploy snapshot
create_predeploy_snapshot() {
    local project="$1"
    local version="$2"
    local description="pre-deploy-${project}-${version}"
    
    log "Creating pre-deployment snapshot for $project v$version"
    
    snapper -c root create --description "$description" --userdata "predeploy=true,project=$project,version=$version"
    snapper -c home create --description "$description" --userdata "predeploy=true,project=$project,version=$version"
    
    log "Pre-deployment snapshot created"
}

# Function to list development snapshots
list_dev_snapshots() {
    echo "=== Root Filesystem Snapshots ==="
    snapper -c root list
    echo ""
    echo "=== Home Filesystem Snapshots ==="
    snapper -c home list
}

# Function to clean old development snapshots
clean_old_snapshots() {
    local days_old="${1:-7}"
    
    log "Cleaning snapshots older than $days_old days..."
    
    # Clean root snapshots
    snapper -c root cleanup number
    
    # Clean home snapshots  
    snapper -c home cleanup number
    
    log "Cleanup completed"
}

# Main function
main() {
    case "${1:-}" in
        "milestone")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 milestone \"description\""
                exit 1
            fi
            create_milestone_snapshot "$2"
            ;;
        "predeploy")
            if [[ -z "${2:-}" || -z "${3:-}" ]]; then
                echo "Usage: $0 predeploy project_name version"
                exit 1
            fi
            create_predeploy_snapshot "$2" "$3"
            ;;
        "list")
            list_dev_snapshots
            ;;
        "clean")
            clean_old_snapshots "${2:-7}"
            ;;
        *)
            echo "Development Backup Script"
            echo "Usage: $0 {milestone|predeploy|list|clean}"
            echo ""
            echo "Commands:"
            echo "  milestone \"description\"    - Create milestone snapshot"
            echo "  predeploy project version   - Create pre-deployment snapshot"
            echo "  list                        - List all snapshots"
            echo "  clean [days]                - Clean old snapshots (default: 7 days)"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x /usr/local/bin/snapshot-monitor.sh
    
    log "Monitoring script created at /usr/local/bin/snapshot-monitor.sh"
}

# Create cron job for regular monitoring
setup_monitoring_cron() {
    log "Setting up monitoring cron job..."
    
    # Create cron job to check snapshot usage daily
    cat > /etc/cron.d/snapshot-monitor << 'EOF'
# Snapshot monitoring cron job
# Check snapshot usage daily at 9 AM
0 9 * * * root /usr/local/bin/snapshot-monitor.sh status >> /var/log/snapshot-monitor.log 2>&1
EOF

    log "Monitoring cron job created"
}

# Create systemd service for automatic cleanup
create_cleanup_service() {
    log "Creating automatic cleanup service..."
    
    cat > /etc/systemd/system/snapshot-cleanup.service << 'EOF'
[Unit]
Description=Snapshot Cleanup Service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/snapper -c root cleanup timeline
ExecStart=/usr/bin/snapper -c home cleanup timeline
ExecStart=/usr/bin/snapper -c root cleanup number
ExecStart=/usr/bin/snapper -c home cleanup number
User=root
EOF

    cat > /etc/systemd/system/snapshot-cleanup.timer << 'EOF'
[Unit]
Description=Snapshot Cleanup Timer
Requires=snapshot-cleanup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now snapshot-cleanup.timer
    
# Create enhanced btrfs maintenance service
create_btrfs_maintenance() {
    log "Creating enhanced btrfs maintenance service..."
    
    cat > /etc/systemd/system/btrfs-maintenance.service << 'EOF'
[Unit]
Description=Btrfs maintenance tasks
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for fs in / /home /mnt/bulk; do btrfs filesystem defragment -r -czstd "$fs" 2>/dev/null || true; done'
ExecStart=/bin/bash -c 'for fs in / /home /mnt/bulk; do btrfs balance start -dusage=50 "$fs" 2>/dev/null || true; done'
ExecStart=/bin/bash -c 'for fs in / /home; do btrfs property set "$fs" compression zstd 2>/dev/null || true; done'
User=root
IOSchedulingClass=3
IOSchedulingPriority=7
EOF

    cat > /etc/systemd/system/btrfs-maintenance.timer << 'EOF'
[Unit]
Description=Weekly Btrfs maintenance
Requires=btrfs-maintenance.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now btrfs-maintenance.timer
    
    log "✓ Btrfs maintenance service enabled"
}

# Create snapshot restore helper script
create_restore_helper() {
    log "Creating snapshot restore helper script..."
    
    cat > /usr/local/bin/snapshot-restore.sh << 'EOF'
#!/bin/bash

# Snapshot Restore Helper Script
# Safely restore from snapshots with verification

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to list snapshots for selection
list_snapshots() {
    local config="$1"
    
    echo "=== Available Snapshots for $config ==="
    snapper -c "$config" list
    echo ""
}

# Function to show snapshot differences
show_differences() {
    local config="$1"
    local snapshot_id="$2"
    
    echo "=== Changes in snapshot $snapshot_id ==="
    snapper -c "$config" status "$snapshot_id"..0
    echo ""
}

# Function to restore files from snapshot
restore_files() {
    local config="$1"
    local snapshot_id="$2"
    local files=("${@:3}")
    
    log "Restoring files from snapshot $snapshot_id..."
    
    for file in "${files[@]}"; do
        if snapper -c "$config" undochange "$snapshot_id"..0 "$file"; then
            log "✓ Restored: $file"
        else
            error "✗ Failed to restore: $file"
        fi
    done
}

# Function to create pre-restore snapshot
create_prerestore_snapshot() {
    local config="$1"
    local description="pre-restore-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating pre-restore snapshot..."
    snapper -c "$config" create --description "$description" --userdata "prerestore=true"
    log "Pre-restore snapshot created"
}

# Interactive restore function
interactive_restore() {
    local config="$1"
    
    list_snapshots "$config"
    
    echo -n "Enter snapshot ID to restore from: "
    read -r snapshot_id
    
    if ! snapper -c "$config" list | grep -q "^$snapshot_id"; then
        error "Invalid snapshot ID: $snapshot_id"
        return 1
    fi
    
    show_differences "$config" "$snapshot_id"
    
    echo -n "Show detailed file differences? (y/n): "
    read -r show_diff
    
    if [[ "$show_diff" =~ ^[Yy]$ ]]; then
        snapper -c "$config" diff "$snapshot_id"..0 | less
    fi
    
    echo -n "Proceed with restore? (y/n): "
    read -r proceed
    
    if [[ "$proceed" =~ ^[Yy]$ ]]; then
        create_prerestore_snapshot "$config"
        
        echo -n "Enter files to restore (space-separated, or 'ALL' for everything): "
        read -r files_input
        
        if [[ "$files_input" == "ALL" ]]; then
            warn "Full system restore is dangerous and should be done from a live system"
            echo -n "Are you sure you want to proceed? (type 'YES' to confirm): "
            read -r confirm
            
            if [[ "$confirm" == "YES" ]]; then
                snapper -c "$config" undochange "$snapshot_id"..0
                log "Full restore completed"
            else
                log "Restore cancelled"
            fi
        else
            IFS=' ' read -ra files_array <<< "$files_input"
            restore_files "$config" "$snapshot_id" "${files_array[@]}"
        fi
    else
        log "Restore cancelled"
    fi
}

# Main function
main() {
    case "${1:-}" in
        "list")
            config="${2:-root}"
            list_snapshots "$config"
            ;;
        "diff")
            config="${2:-root}"
            snapshot_id="${3:-}"
            if [[ -z "$snapshot_id" ]]; then
                echo "Usage: $0 diff [config] snapshot_id"
                exit 1
            fi
            show_differences "$config" "$snapshot_id"
            ;;
        "restore")
            config="${2:-root}"
            interactive_restore "$config"
            ;;
        "quick-restore")
            config="${2:-root}"
            snapshot_id="${3:-}"
            shift 3
            files=("$@")
            if [[ -z "$snapshot_id" || ${#files[@]} -eq 0 ]]; then
                echo "Usage: $0 quick-restore [config] snapshot_id file1 [file2 ...]"
                exit 1
            fi
            create_prerestore_snapshot "$config"
            restore_files "$config" "$snapshot_id" "${files[@]}"
            ;;
        *)
            echo "Snapshot Restore Helper"
            echo "Usage: $0 {list|diff|restore|quick-restore}"
            echo ""
            echo "Commands:"
            echo "  list [config]                      - List available snapshots"
            echo "  diff [config] snapshot_id          - Show differences in snapshot"
            echo "  restore [config]                   - Interactive restore"
            echo "  quick-restore [config] snapshot_id file1 [file2 ...] - Quick file restore"
            echo ""
            echo "Default config is 'root'. Use 'home' for home filesystem."
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x /usr/local/bin/snapshot-restore.sh
    
    log "Restore helper script created at /usr/local/bin/snapshot-restore.sh"
}

# Create Git pre-commit hook for automatic snapshots
create_git_hooks() {
    log "Creating Git integration for automatic snapshots..."
    
    cat > /usr/local/bin/git-snapshot-hook.sh << 'EOF'
#!/bin/bash

# Git Snapshot Hook
# Creates snapshots before major Git operations

set -euo pipefail

# Function to create commit snapshot
create_commit_snapshot() {
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local branch=$(git rev-parse --abbrev-ref HEAD)
    local commit_msg="git-commit-${repo_name}-${branch}-$(date +%Y%m%d-%H%M%S)"
    
    # Create snapshot for home (where most development happens)
    snapper -c home create --description "$commit_msg" --userdata "git=true,repo=$repo_name,branch=$branch" 2>/dev/null || true
}

# Function to create branch snapshot
create_branch_snapshot() {
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local old_branch="$1"
    local new_branch="$2"
    local branch_msg="git-branch-${repo_name}-${old_branch}-to-${new_branch}-$(date +%Y%m%d-%H%M%S)"
    
    # Create snapshot for home
    snapper -c home create --description "$branch_msg" --userdata "git=true,repo=$repo_name,branch_change=true" 2>/dev/null || true
}

# Main hook logic
case "${1:-}" in
    "pre-commit")
        # Only create snapshot for significant commits (not during rebases, etc.)
        if [[ -z "${GIT_REFLOG_ACTION:-}" ]]; then
            create_commit_snapshot
        fi
        ;;
    "pre-rebase")
        create_commit_snapshot
        ;;
    "checkout")
        if [[ "${2:-}" != "${3:-}" ]]; then
            create_branch_snapshot "$2" "$3"
        fi
        ;;
    *)
        echo "Git Snapshot Hook"
        echo "Usage: Called automatically by Git hooks"
        ;;
esac
EOF

    chmod +x /usr/local/bin/git-snapshot-hook.sh
    
    # Create template Git hooks
    mkdir -p /usr/local/share/git-templates/hooks
    
    cat > /usr/local/share/git-templates/hooks/pre-commit << 'EOF'
#!/bin/bash
# Auto-snapshot before commits
/usr/local/bin/git-snapshot-hook.sh pre-commit
EOF

    cat > /usr/local/share/git-templates/hooks/pre-rebase << 'EOF'
#!/bin/bash
# Auto-snapshot before rebases
/usr/local/bin/git-snapshot-hook.sh pre-rebase
EOF

    cat > /usr/local/share/git-templates/hooks/post-checkout << 'EOF'
#!/bin/bash
# Auto-snapshot on branch changes
/usr/local/bin/git-snapshot-hook.sh checkout "$1" "$2"
EOF

    chmod +x /usr/local/share/git-templates/hooks/*
    
    log "Git hooks created at /usr/local/share/git-templates/hooks/"
    info "To enable for new repositories, run: git config --global init.templatedir /usr/local/share/git-templates"
}

# Show final summary and usage instructions
show_summary() {
    log "Snapshot setup completed successfully!"
    echo ""
    echo "=== Summary ==="
    echo "✓ Snapper configurations created for root and home filesystems"
    echo "✓ Automatic timeline snapshots enabled"
    echo "✓ Development snapshot timer created (every 30 minutes during work hours)"
    echo "✓ System performance optimizations applied"
    echo "✓ DDR5-6000 memory optimizations configured"
    echo "✓ Triple Dell U4320Q 4K display optimizations configured"
    echo "✓ NVMe health monitoring enabled (hourly checks)"
    echo "✓ Docker optimization configuration created"
    echo "✓ Btrfs maintenance service enabled (weekly)"
    echo "✓ Development environment optimizations created"
    echo "✓ Backup script created: /usr/local/bin/dev-backup.sh"
    echo "✓ Monitoring script created: /usr/local/bin/snapshot-monitor.sh"
    echo "✓ NVMe health monitor: /usr/local/bin/nvme-health-monitor.sh"
    echo "✓ Display optimization script: /usr/local/bin/display-optimizer.sh"
    echo "✓ Memory optimization script: /usr/local/bin/memory-optimizer.sh"
    echo "✓ Restore helper script created: /usr/local/bin/snapshot-restore.sh"
    echo "✓ Development cache setup: /usr/local/bin/setup-dev-caches.sh"
    echo "✓ Git integration hooks created"
    echo "✓ Automatic cleanup services enabled"
    echo ""
    echo "=== Usage Examples ==="
    echo "• Create milestone snapshot: dev-backup.sh milestone \"Project Alpha Complete\""
    echo "• Create pre-deploy snapshot: dev-backup.sh predeploy myapp v1.2.3"
    echo "• List all snapshots: dev-backup.sh list"
    echo "• Monitor snapshot usage: snapshot-monitor.sh status"
    echo "• Check display configuration: display-optimizer.sh status"
    echo "• Optimize GPU performance: display-optimizer.sh optimize"
    echo "• Configure display layout: display-optimizer.sh layout horizontal"
    echo "• Monitor GPU performance: display-optimizer.sh monitor"
    echo "• Setup dev workspace: display-optimizer.sh workspace"
    echo "• Create RAMdisk for builds: memory-optimizer.sh ramdisk 16G"
    echo "• Benchmark memory: memory-optimizer.sh benchmark"
    echo "• Setup development caches: setup-dev-caches.sh"
    echo "• Restore files interactively: snapshot-restore.sh restore"
    echo "• Quick file restore: snapshot-restore.sh quick-restore home 42 /home/user/important.txt"
    echo ""
    echo "=== Performance Optimizations ==="
    echo "• CPU governor set to 'performance'"
    echo "• NVMe power management optimized for maximum performance"
    echo "• Memory settings tuned for DDR5-6000 CL34 (256GB)"
    echo "• Transparent Huge Pages enabled for large memory workloads"
    echo "• Development tools configured for high-memory builds"
    echo "• Network settings optimized for 10Gb NIC"
    echo "• Docker configured for btrfs and memory optimization"
    echo "• VS Code and Git configurations optimized"
    echo ""
    echo "=== Memory-Specific Features ==="
    echo "• Large memory buffers enabled (vm.dirty_ratio=20)"
    echo "• VFS cache pressure optimized for development workloads"
    echo "• Huge pages configured for performance (1024 x 2MB)"
    echo "• Development tools configured with increased memory limits"
    echo "=== Display-Specific Features ==="
    echo "• Triple 4K display support (11,520 x 2,160 total resolution)"
    echo "• GPU performance optimization for AMD RX 9070 XT"
    echo "• Display layout management (horizontal, vertical, mixed)"
    echo "• Development workspace automation across all monitors"
    echo "• GPU temperature and VRAM monitoring"
    echo "• High refresh rate optimization for development workflows"
    echo ""
    echo "=== Post-Installation Tasks ==="
    echo "• Run 'grub-mkconfig -o /boot/grub/grub.cfg' to apply GRUB optimizations"
    echo "• Run 'setup-dev-caches.sh' as your user to optimize development caches"
    echo "• Run 'display-optimizer.sh optimize' to apply GPU performance settings"
    echo "• Configure display layout with 'display-optimizer.sh layout horizontal'"
    echo "• Setup development workspace with 'display-optimizer.sh workspace'"
    echo "• Consider creating a RAMdisk with 'memory-optimizer.sh ramdisk 16G' for builds"
    echo "• Source ~/.build-env in your shell for memory-optimized build environment"
    echo "• Restart system to apply all kernel parameter optimizations"
    echo ""
    echo "=== Git Integration ==="
    echo "To enable Git snapshot hooks for new repositories:"
    echo "git config --global init.templatedir /usr/local/share/git-templates"
    echo ""
    echo "=== Monitoring ==="
    echo "• Snapshot usage is checked daily at 9 AM"
    echo "• Automatic cleanup runs daily"
    echo "• Logs are available in /var/log/snapshot-monitor.log"
    echo ""
    echo "=== Current Status ==="
    snapper list-configs
    echo ""
    systemctl --no-pager status snapper-timeline.timer snapper-cleanup.timer snapper-dev-snapshot.timer
}

# Main execution
main() {
    log "Starting snapshot setup for development workstation..."
    
    check_root
    install_packages
    create_root_config
    create_home_config
    create_dev_snapshot_timer
    create_backup_script
    setup_grub_btrfs
    create_monitoring_script
    setup_monitoring_cron
    create_cleanup_service
    create_restore_helper
    create_git_hooks
    create_system_optimizations
    create_memory_optimizations
    create_display_optimizations
    create_docker_optimization
    create_btrfs_maintenance
    create_enhanced_monitoring
    create_dev_optimizations
    show_summary
    
    log "✓ Snapshot setup completed successfully!"
}

# Run main function
main "$@"

    chmod +x /usr/local/bin/dev-backup.sh
    
    log "Backup script created at /usr/local/bin/dev-backup.sh"
}

# Create grub-btrfs configuration for boot-time snapshot access
setup_grub_btrfs() {
    log "Setting up GRUB integration for snapshot booting..."
    
    # Install grub-btrfs if available
    if command -v apt-get &> /dev/null; then
        apt-get install -y grub-btrfs 2>/dev/null || warn "grub-btrfs not available in repositories"
    elif command -v dnf &> /dev/null; then
        dnf install -y grub-btrfs 2>/dev/null || warn "grub-btrfs not available in repositories"
    elif command -v pacman &> /dev/null; then
        pacman -S --noconfirm grub-btrfs 2>/dev/null || warn "grub-btrfs not available in repositories"
    fi
    
    # Enable grub-btrfs if installed
    if command -v grub-btrfs &> /dev/null; then
        systemctl enable --now grub-btrfs.path
        log "GRUB-BTRFS enabled for snapshot booting"
    else
        warn "grub-btrfs not available - snapshot booting from GRUB will not be available"
    fi
}

# Create monitoring script
create_monitoring_script() {
    log "Creating snapshot monitoring script..."
    
    cat > /usr/local/bin/snapshot-monitor.sh << 'EOF'
#!/bin/bash

# Snapshot Monitoring Script
# Monitors snapshot usage and provides alerts

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check snapshot disk usage
check_snapshot_usage() {
    local config="$1"
    local mount_point="$2"
    
    echo "=== Snapshot Usage for $config ==="
    
    # Get filesystem usage
    local fs_usage=$(df -h "$mount_point" | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # Get snapshot count
    local snapshot_count=$(snapper -c "$config" list | grep -c "^[0-9]" || echo "0")
    
    # Get oldest snapshot age
    local oldest_snapshot=$(snapper -c "$config" list | grep -E "^[0-9]" | head -1 | awk '{print $3}' || echo "N/A")
    
    echo "Filesystem usage: ${fs_usage}%"
    echo "Snapshot count: $snapshot_count"
    echo "Oldest snapshot: $oldest_snapshot"
    
    # Alert if usage is high
    if [[ "$fs_usage" -gt 80 ]]; then
        error "High disk usage detected: ${fs_usage}%"
        return 1
    elif [[ "$fs_usage" -gt 70 ]]; then
        warn "Moderate disk usage: ${fs_usage}%"
    fi
    
    # Alert if too many snapshots
    if [[ "$snapshot_count" -gt 200 ]]; then
        warn "High snapshot count: $snapshot_count"
    fi
    
    echo ""
}

# Show snapshot timeline
show_timeline() {
    echo "=== Recent Snapshot Timeline ==="
    echo "Root filesystem (last 10):"
    snapper -c root list | tail -10
    echo ""
    echo "Home filesystem (last 10):"
    snapper -c home list | tail -10
    echo ""
}

# Main monitoring function
main() {
    case "${1:-status}" in
        "status")
            log "Checking snapshot status..."
            check_snapshot_usage "root" "/"
            check_snapshot_usage "home" "/home"
            ;;
        "timeline")
            show_timeline
            ;;
        "summary")
            log "Snapshot Summary"
            echo "Root snapshots: $(snapper -c root list | grep -c "^[0-9]" || echo "0")"
            echo "Home snapshots: $(snapper -c home list | grep -c "^[0-9]" || echo "0")"
            echo "Total snapshots: $(( $(snapper -c root list | grep -c "^[0-9]" || echo "0") + $(snapper -c home list | grep -c "^[0-9]" || echo "0") ))"
            ;;
        *)
            echo "Snapshot Monitoring Script"
            echo "Usage: $0 {status|timeline|summary}"
            ;;
    esac
}

main "$@"
EOF