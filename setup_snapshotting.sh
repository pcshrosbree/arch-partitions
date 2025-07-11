#!/bin/bash

# Snapshot Management Setup Script
# Configures comprehensive btrfs snapshot management with snapper
# Run this script after OS installation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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
    log "Installing snapshot management packages..."
    
    if command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm snapper btrfs-progs
    elif command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y snapper btrfs-progs
    elif command -v dnf &> /dev/null; then
        dnf install -y snapper btrfs-progs
    else
        error "Could not determine package manager. Please install snapper and btrfs-progs manually."
    fi
    
    # Enable snapper services
    systemctl enable --now snapper-timeline.timer
    systemctl enable --now snapper-cleanup.timer
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
# Run every 30 minutes during typical work hours (8 AM - 8 PM, Mon-Fri)
OnCalendar=Mon-Fri *-*-* 08:00:00/30min
OnCalendar=Mon-Fri *-*-* 08:30:00/30min
OnCalendar=Mon-Fri *-*-* 09:00:00/30min
OnCalendar=Mon-Fri *-*-* 09:30:00/30min
OnCalendar=Mon-Fri *-*-* 10:00:00/30min
OnCalendar=Mon-Fri *-*-* 10:30:00/30min
OnCalendar=Mon-Fri *-*-* 11:00:00/30min
OnCalendar=Mon-Fri *-*-* 11:30:00/30min
OnCalendar=Mon-Fri *-*-* 12:00:00/30min
OnCalendar=Mon-Fri *-*-* 12:30:00/30min
OnCalendar=Mon-Fri *-*-* 13:00:00/30min
OnCalendar=Mon-Fri *-*-* 13:30:00/30min
OnCalendar=Mon-Fri *-*-* 14:00:00/30min
OnCalendar=Mon-Fri *-*-* 14:30:00/30min
OnCalendar=Mon-Fri *-*-* 15:00:00/30min
OnCalendar=Mon-Fri *-*-* 15:30:00/30min
OnCalendar=Mon-Fri *-*-* 16:00:00/30min
OnCalendar=Mon-Fri *-*-* 16:30:00/30min
OnCalendar=Mon-Fri *-*-* 17:00:00/30min
OnCalendar=Mon-Fri *-*-* 17:30:00/30min
OnCalendar=Mon-Fri *-*-* 18:00:00/30min
OnCalendar=Mon-Fri *-*-* 18:30:00/30min
OnCalendar=Mon-Fri *-*-* 19:00:00/30min
OnCalendar=Mon-Fri *-*-* 19:30:00/30min
OnCalendar=Mon-Fri *-*-* 20:00:00/30min
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

    chmod +x /usr/local/bin/dev-backup.sh
    log "Backup script created at /usr/local/bin/dev-backup.sh"
}

# Create snapshot monitoring script
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

    chmod +x /usr/local/bin/snapshot-monitor.sh
    log "Monitoring script created at /usr/local/bin/snapshot-monitor.sh"
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

# Create automatic cleanup service
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
    log "Automatic cleanup service enabled"
}

# Setup GRUB integration for snapshot booting
setup_grub_btrfs() {
    log "Setting up GRUB integration for snapshot booting..."
    
    # Install grub-btrfs if available
    if command -v pacman &> /dev/null; then
        pacman -S --noconfirm grub-btrfs 2>/dev/null || warn "grub-btrfs not available in repositories"
    elif command -v apt-get &> /dev/null; then
        apt-get install -y grub-btrfs 2>/dev/null || warn "grub-btrfs not available in repositories"
    elif command -v dnf &> /dev/null; then
        dnf install -y grub-btrfs 2>/dev/null || warn "grub-btrfs not available in repositories"
    fi
    
    # Enable grub-btrfs if installed
    if command -v grub-btrfs &> /dev/null; then
        systemctl enable --now grub-btrfs.path
        log "GRUB-BTRFS enabled for snapshot booting"
    else
        warn "grub-btrfs not available - snapshot booting from GRUB will not be available"
    fi
}

# Setup monitoring cron job
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

# Show summary
show_summary() {
    log "Snapshot management setup completed successfully!"
    echo ""
    echo "=== Summary ==="
    echo "✓ Snapper configurations created for root and home filesystems"
    echo "✓ Automatic timeline snapshots enabled"
    echo "✓ Development snapshot timer created (every 30 minutes during work hours)"
    echo "✓ Backup script created: /usr/local/bin/dev-backup.sh"
    echo "✓ Monitoring script created: /usr/local/bin/snapshot-monitor.sh"
    echo "✓ Restore helper script created: /usr/local/bin/snapshot-restore.sh"
    echo "✓ Automatic cleanup services enabled"
    echo "✓ GRUB integration configured (if available)"
    echo ""
    echo "=== Usage Examples ==="
    echo "• Create milestone snapshot: dev-backup.sh milestone \"Project Alpha Complete\""
    echo "• Create pre-deploy snapshot: dev-backup.sh predeploy myapp v1.2.3"
    echo "• List all snapshots: dev-backup.sh list"
    echo "• Monitor snapshot usage: snapshot-monitor.sh status"
    echo "• Restore files interactively: snapshot-restore.sh restore"
    echo "• Quick file restore: snapshot-restore.sh quick-restore home 42 /home/user/important.txt"
    echo ""
    echo "=== Current Status ==="
    snapper list-configs
    echo ""
    systemctl --no-pager status snapper-timeline.timer snapper-cleanup.timer snapper-dev-snapshot.timer
}

# Main execution
main() {
    log "Starting snapshot management setup..."
    
    check_root
    install_packages
    create_root_config
    create_home_config
    create_dev_snapshot_timer
    create_backup_script
    create_monitoring_script
    create_restore_helper
    create_cleanup_service
    setup_grub_btrfs
    setup_monitoring_cron
    show_summary
    
    log "✓ Snapshot management setup completed successfully!"
}

# Run main function
main "$@"