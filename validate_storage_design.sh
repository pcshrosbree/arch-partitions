#!/bin/bash

# Validate Development Storage Design
# Comprehensive validation script to ensure storage is configured as designed

set -euo pipefail

# Expected device configuration
PRIMARY_NVME="/dev/nvme0n1"      # PCIe 5 NVMe - Root + EFI
SECONDARY_NVME="/dev/nvme1n1"    # PCIe 4 NVMe - Home + Dev caches
BULK_SATA="/dev/sda"             # SATA SSD - Bulk storage

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Logging functions
log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    ((WARNING_TESTS++))
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    ((FAILED_TESTS++))
}

pass() {
    echo -e "${GREEN}[PASS] $1${NC}"
    ((PASSED_TESTS++))
}

fail() {
    echo -e "${RED}[FAIL] $1${NC}"
    ((FAILED_TESTS++))
}

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

subheader() {
    echo -e "\n${CYAN}--- $1 ---${NC}"
}

test_start() {
    ((TOTAL_TESTS++))
}

# Expected subvolumes for each filesystem
declare -a EXPECTED_ROOT_SUBVOLS=(
    "@"
    "@snapshots"
    "@tmp"
    "@var_log"
    "@var_cache"
    "@opt"
    "@usr_local"
    "@home"
    "@log"
    "@pkg"
)

declare -a EXPECTED_DEV_SUBVOLS=(
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

declare -a EXPECTED_BULK_SUBVOLS=(
    "@archives"
    "@builds"
    "@containers"
    "@backup"
    "@media"
    "@projects"
)

# Expected mount points with their properties
declare -A EXPECTED_MOUNTS=(
    ["/"]="btrfs,@,nvme0n1p2"
    ["/.snapshots"]="btrfs,@snapshots,nvme0n1p2"
    ["/tmp"]="btrfs,@tmp,nvme0n1p2"
    ["/var/log"]="btrfs,@var_log,nvme0n1p2"
    ["/var/cache"]="btrfs,@var_cache,nvme0n1p2"
    ["/opt"]="btrfs,@opt,nvme0n1p2"
    ["/usr/local"]="btrfs,@usr_local,nvme0n1p2"
    ["/boot/efi"]="vfat,,nvme0n1p1"
    ["/home"]="btrfs,@home,nvme1n1p1"
    ["/var/lib/containers"]="btrfs,@containers,nvme1n1p1"
    ["/var/lib/libvirt"]="btrfs,@vms,nvme1n1p1"
    ["/var/cache/builds"]="btrfs,@tmp_builds,nvme1n1p1"
    ["/var/cache/node_modules"]="btrfs,@node_modules,nvme1n1p1"
    ["/var/cache/cargo"]="btrfs,@cargo_cache,nvme1n1p1"
    ["/var/cache/go"]="btrfs,@go_cache,nvme1n1p1"
    ["/var/cache/maven"]="btrfs,@maven_cache,nvme1n1p1"
    ["/var/cache/pyenv"]="btrfs,@pyenv_cache,nvme1n1p1"
    ["/var/cache/poetry"]="btrfs,@poetry_cache,nvme1n1p1"
    ["/var/cache/uv"]="btrfs,@uv_cache,nvme1n1p1"
    ["/var/cache/dotnet"]="btrfs,@dotnet_cache,nvme1n1p1"
    ["/var/cache/haskell"]="btrfs,@haskell_cache,nvme1n1p1"
    ["/var/cache/clojure"]="btrfs,@clojure_cache,nvme1n1p1"
    ["/var/cache/zig"]="btrfs,@zig_cache,nvme1n1p1"
    ["/mnt/bulk"]="btrfs,,sda1"
)

# Expected mount options
declare -A EXPECTED_MOUNT_OPTIONS=(
    ["btrfs_root"]="noatime,compress=zstd:1,space_cache=v2,ssd,ssd_spread,discard=async,commit=120"
    ["btrfs_home"]="noatime,compress=zstd:3,space_cache=v2,ssd,ssd_spread,discard=async,commit=120"
    ["btrfs_bulk"]="noatime,compress=zstd:6,space_cache=v2,ssd,discard=async"
    ["btrfs_nodatacow"]="nodatacow"
)

# Test 1: Hardware Detection
test_hardware_detection() {
    header "Hardware Detection Tests"
    
    subheader "Block Device Detection"
    
    test_start
    if [[ -b "$PRIMARY_NVME" ]]; then
        pass "Primary NVMe detected: $PRIMARY_NVME"
    else
        fail "Primary NVMe not found: $PRIMARY_NVME"
    fi
    
    test_start
    if [[ -b "$SECONDARY_NVME" ]]; then
        pass "Secondary NVMe detected: $SECONDARY_NVME"
    else
        fail "Secondary NVMe not found: $SECONDARY_NVME"
    fi
    
    test_start
    if [[ -b "$BULK_SATA" ]]; then
        pass "Bulk SATA detected: $BULK_SATA"
    else
        fail "Bulk SATA not found: $BULK_SATA"
    fi
    
    subheader "Partition Detection"
    
    test_start
    if [[ -b "${PRIMARY_NVME}p1" ]]; then
        pass "EFI partition detected: ${PRIMARY_NVME}p1"
    else
        fail "EFI partition not found: ${PRIMARY_NVME}p1"
    fi
    
    test_start
    if [[ -b "${PRIMARY_NVME}p2" ]]; then
        pass "Root partition detected: ${PRIMARY_NVME}p2"
    else
        fail "Root partition not found: ${PRIMARY_NVME}p2"
    fi
    
    test_start
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        pass "Home partition detected: ${SECONDARY_NVME}p1"
    else
        warn "Home partition not found: ${SECONDARY_NVME}p1 (optional)"
    fi
    
    test_start
    if [[ -b "${BULK_SATA}1" ]]; then
        pass "Bulk partition detected: ${BULK_SATA}1"
    else
        warn "Bulk partition not found: ${BULK_SATA}1 (optional)"
    fi
}

# Test 2: Filesystem Types
test_filesystem_types() {
    header "Filesystem Type Tests"
    
    test_start
    local efi_fs=$(blkid -s TYPE -o value "${PRIMARY_NVME}p1" 2>/dev/null || echo "unknown")
    if [[ "$efi_fs" == "vfat" ]]; then
        pass "EFI partition filesystem: $efi_fs"
    else
        fail "EFI partition wrong filesystem: $efi_fs (expected: vfat)"
    fi
    
    test_start
    local root_fs=$(blkid -s TYPE -o value "${PRIMARY_NVME}p2" 2>/dev/null || echo "unknown")
    if [[ "$root_fs" == "btrfs" ]]; then
        pass "Root partition filesystem: $root_fs"
    else
        fail "Root partition wrong filesystem: $root_fs (expected: btrfs)"
    fi
    
    if [[ -b "${SECONDARY_NVME}p1" ]]; then
        test_start
        local home_fs=$(blkid -s TYPE -o value "${SECONDARY_NVME}p1" 2>/dev/null || echo "unknown")
        if [[ "$home_fs" == "btrfs" ]]; then
            pass "Home partition filesystem: $home_fs"
        else
            fail "Home partition wrong filesystem: $home_fs (expected: btrfs)"
        fi
    fi
    
    if [[ -b "${BULK_SATA}1" ]]; then
        test_start
        local bulk_fs=$(blkid -s TYPE -o value "${BULK_SATA}1" 2>/dev/null || echo "unknown")
        if [[ "$bulk_fs" == "btrfs" ]]; then
            pass "Bulk partition filesystem: $bulk_fs"
        else
            fail "Bulk partition wrong filesystem: $bulk_fs (expected: btrfs)"
        fi
    fi
}

# Test 3: Btrfs Subvolumes
test_btrfs_subvolumes() {
    header "Btrfs Subvolume Tests"
    
    subheader "Root Filesystem Subvolumes"
    
    if mountpoint -q / && [[ "$(findmnt -n -o FSTYPE /)" == "btrfs" ]]; then
        local root_subvols=$(btrfs subvolume list / 2>/dev/null | awk '{print $9}' | sort)
        
        for expected_subvol in "${EXPECTED_ROOT_SUBVOLS[@]}"; do
            test_start
            if echo "$root_subvols" | grep -q "^$expected_subvol$"; then
                pass "Root subvolume exists: $expected_subvol"
            else
                warn "Root subvolume missing: $expected_subvol"
            fi
        done
    else
        error "Root filesystem is not btrfs or not mounted"
    fi
    
    subheader "Home Filesystem Subvolumes"
    
    if [[ -b "${SECONDARY_NVME}p1" ]] && mountpoint -q /home && [[ "$(findmnt -n -o FSTYPE /home)" == "btrfs" ]]; then
        local home_subvols=$(btrfs subvolume list /home 2>/dev/null | awk '{print $9}' | sort)
        
        for expected_subvol in "${EXPECTED_DEV_SUBVOLS[@]}"; do
            test_start
            if echo "$home_subvols" | grep -q "^$expected_subvol$"; then
                pass "Home subvolume exists: $expected_subvol"
            else
                warn "Home subvolume missing: $expected_subvol"
            fi
        done
    else
        warn "Home filesystem not available or not btrfs"
    fi
    
    subheader "Bulk Storage Subvolumes"
    
    if [[ -b "${BULK_SATA}1" ]] && mountpoint -q /mnt/bulk && [[ "$(findmnt -n -o FSTYPE /mnt/bulk)" == "btrfs" ]]; then
        local bulk_subvols=$(btrfs subvolume list /mnt/bulk 2>/dev/null | awk '{print $9}' | sort)
        
        for expected_subvol in "${EXPECTED_BULK_SUBVOLS[@]}"; do
            test_start
            if echo "$bulk_subvols" | grep -q "^$expected_subvol$"; then
                pass "Bulk subvolume exists: $expected_subvol"
            else
                warn "Bulk subvolume missing: $expected_subvol"
            fi
        done
    else
        warn "Bulk storage not available or not btrfs"
    fi
}

# Test 4: Mount Points
test_mount_points() {
    header "Mount Point Tests"
    
    subheader "Critical Mount Points"
    
    for mount_point in "${!EXPECTED_MOUNTS[@]}"; do
        test_start
        if mountpoint -q "$mount_point" 2>/dev/null; then
            local mount_info="${EXPECTED_MOUNTS[$mount_point]}"
            local expected_fs=$(echo "$mount_info" | cut -d',' -f1)
            local expected_subvol=$(echo "$mount_info" | cut -d',' -f2)
            local expected_device=$(echo "$mount_info" | cut -d',' -f3)
            
            local actual_fs=$(findmnt -n -o FSTYPE "$mount_point")
            local actual_source=$(findmnt -n -o SOURCE "$mount_point")
            
            if [[ "$actual_fs" == "$expected_fs" ]]; then
                if [[ "$expected_fs" == "btrfs" ]] && [[ -n "$expected_subvol" ]]; then
                    if [[ "$actual_source" =~ \[@$expected_subvol\] ]]; then
                        pass "Mount point correct: $mount_point ($expected_fs, @$expected_subvol)"
                    else
                        fail "Mount point wrong subvolume: $mount_point (expected: @$expected_subvol, got: $actual_source)"
                    fi
                else
                    pass "Mount point correct: $mount_point ($expected_fs)"
                fi
            else
                fail "Mount point wrong filesystem: $mount_point (expected: $expected_fs, got: $actual_fs)"
            fi
        else
            # Check if it's an optional mount
            if [[ "$mount_point" =~ ^/var/cache/(cargo|go|node_modules) ]] || [[ "$mount_point" == "/mnt/bulk" ]] || [[ "$mount_point" == "/home" ]]; then
                warn "Optional mount point not mounted: $mount_point"
            else
                fail "Critical mount point not mounted: $mount_point"
            fi
        fi
    done
}

# Test 5: Mount Options
test_mount_options() {
    header "Mount Option Tests"
    
    subheader "Performance Optimization Options"
    
    # Test root filesystem options
    test_start
    local root_options=$(findmnt -n -o OPTIONS /)
    local expected_root_opts="${EXPECTED_MOUNT_OPTIONS[btrfs_root]}"
    
    local missing_opts=""
    IFS=',' read -ra opts <<< "$expected_root_opts"
    for opt in "${opts[@]}"; do
        if [[ ! "$root_options" =~ $opt ]]; then
            missing_opts="$missing_opts $opt"
        fi
    done
    
    if [[ -z "$missing_opts" ]]; then
        pass "Root filesystem mount options correct"
    else
        warn "Root filesystem missing options:$missing_opts"
    fi
    
    # Test nodatacow for specific mount points
    local nodatacow_mounts=("/tmp" "/var/log" "/var/cache" "/var/lib/containers" "/var/lib/libvirt" "/var/cache/builds" "/var/cache/node_modules")
    
    for mount_point in "${nodatacow_mounts[@]}"; do
        if mountpoint -q "$mount_point" 2>/dev/null; then
            test_start
            local mount_options=$(findmnt -n -o OPTIONS "$mount_point")
            if [[ "$mount_options" =~ nodatacow ]]; then
                pass "Mount point has nodatacow: $mount_point"
            else
                warn "Mount point missing nodatacow: $mount_point"
            fi
        fi
    done
}

# Test 6: Directory Structure
test_directory_structure() {
    header "Directory Structure Tests"
    
    subheader "Development Cache Directories"
    
    local dev_cache_dirs=(
        "/var/cache/builds"
        "/var/cache/node_modules" 
        "/var/cache/cargo"
        "/var/cache/go"
        "/var/cache/maven"
        "/var/cache/pyenv"
        "/var/cache/poetry"
        "/var/cache/uv"
        "/var/cache/dotnet"
        "/var/cache/haskell"
        "/var/cache/clojure"
        "/var/cache/zig"
    )
    
    for dir in "${dev_cache_dirs[@]}"; do
        test_start
        if [[ -d "$dir" ]]; then
            pass "Cache directory exists: $dir"
        else
            warn "Cache directory missing: $dir"
        fi
    done
    
    subheader "System Directories"
    
    local system_dirs=(
        "/.snapshots"
        "/var/lib/containers"
        "/var/lib/libvirt"
    )
    
    for dir in "${system_dirs[@]}"; do
        test_start
        if [[ -d "$dir" ]]; then
            pass "System directory exists: $dir"
        else
            warn "System directory missing: $dir"
        fi
    done
    
    subheader "User Home Directory"
    
    test_start
    local actual_user=$(who | head -1 | awk '{print $1}' 2>/dev/null || echo "unknown")
    if [[ "$actual_user" != "unknown" ]] && [[ "$actual_user" != "root" ]]; then
        if [[ -d "/home/$actual_user" ]]; then
            pass "User home directory exists: /home/$actual_user"
        else
            fail "User home directory missing: /home/$actual_user"
        fi
    else
        warn "Cannot detect non-root user to test home directory"
    fi
}

# Test 7: Environment Configuration
test_environment_configuration() {
    header "Environment Configuration Tests"
    
    subheader "Development Environment Variables"
    
    test_start
    if [[ -f "/etc/profile.d/dev-paths.sh" ]]; then
        pass "Development environment file exists: /etc/profile.d/dev-paths.sh"
        
        local env_vars=(
            "CARGO_HOME"
            "GOCACHE"
            "GOMODCACHE"
            "PYENV_ROOT"
            "POETRY_CACHE_DIR"
            "UV_CACHE_DIR"
            "DOTNET_CLI_HOME"
            "ZIG_GLOBAL_CACHE_DIR"
        )
        
        for var in "${env_vars[@]}"; do
            test_start
            if grep -q "export $var=" "/etc/profile.d/dev-paths.sh"; then
                pass "Environment variable configured: $var"
            else
                warn "Environment variable missing: $var"
            fi
        done
    else
        fail "Development environment file missing: /etc/profile.d/dev-paths.sh"
    fi
    
    subheader "Systemd Configuration"
    
    test_start
    if [[ -f "/etc/tmpfiles.d/dev-caches.conf" ]]; then
        pass "Systemd tmpfiles configuration exists"
    else
        warn "Systemd tmpfiles configuration missing"
    fi
}

# Test 8: Management Scripts
test_management_scripts() {
    header "Management Script Tests"
    
    test_start
    if [[ -x "/usr/local/bin/storage-info" ]]; then
        pass "Storage info script exists and is executable"
    else
        warn "Storage info script missing or not executable"
    fi
    
    test_start
    if [[ -x "/usr/local/bin/snapshot-manager" ]]; then
        pass "Snapshot manager script exists and is executable"
    else
        warn "Snapshot manager script missing or not executable"
    fi
    
    # Test script functionality
    if [[ -x "/usr/local/bin/storage-info" ]]; then
        test_start
        if /usr/local/bin/storage-info >/dev/null 2>&1; then
            pass "Storage info script runs successfully"
        else
            warn "Storage info script has runtime errors"
        fi
    fi
}

# Test 9: Performance Features
test_performance_features() {
    header "Performance Feature Tests"
    
    subheader "Compression Settings"
    
    # Check compression on different mount points
    local compression_tests=(
        "/|zstd:1"
        "/home|zstd:3"
        "/mnt/bulk|zstd:6"
    )
    
    for test_case in "${compression_tests[@]}"; do
        local mount_point=$(echo "$test_case" | cut -d'|' -f1)
        local expected_compression=$(echo "$test_case" | cut -d'|' -f2)
        
        if mountpoint -q "$mount_point" 2>/dev/null; then
            test_start
            local mount_options=$(findmnt -n -o OPTIONS "$mount_point")
            if [[ "$mount_options" =~ compress=$expected_compression ]]; then
                pass "Compression configured correctly: $mount_point ($expected_compression)"
            else
                warn "Compression not optimal: $mount_point (expected: $expected_compression)"
            fi
        fi
    done
    
    subheader "SSD Optimizations"
    
    local ssd_opts=("ssd" "ssd_spread" "discard=async" "space_cache=v2")
    
    for mount_point in "/" "/home"; do
        if mountpoint -q "$mount_point" 2>/dev/null; then
            local mount_options=$(findmnt -n -o OPTIONS "$mount_point")
            for opt in "${ssd_opts[@]}"; do
                test_start
                if [[ "$mount_options" =~ $opt ]]; then
                    pass "SSD optimization enabled: $mount_point ($opt)"
                else
                    warn "SSD optimization missing: $mount_point ($opt)"
                fi
            done
        fi
    done
}

# Test 10: Fstab Validation
test_fstab_validation() {
    header "Fstab Validation Tests"
    
    test_start
    if mount -a --fake 2>/dev/null; then
        pass "fstab syntax is valid"
    else
        fail "fstab has syntax errors"
    fi
    
    test_start
    local fstab_entries=$(grep -c "^UUID=" /etc/fstab || echo "0")
    if [[ "$fstab_entries" -ge 3 ]]; then
        pass "fstab has sufficient UUID entries ($fstab_entries)"
    else
        warn "fstab has few UUID entries ($fstab_entries), may be incomplete"
    fi
    
    test_start
    if grep -q "btrfs" /etc/fstab; then
        pass "fstab contains btrfs entries"
    else
        fail "fstab missing btrfs entries"
    fi
    
    test_start
    if grep -q "subvol=" /etc/fstab; then
        pass "fstab contains subvolume specifications"
    else
        warn "fstab missing subvolume specifications"
    fi
}

# Test 11: Storage Capacity and Usage
test_storage_capacity() {
    header "Storage Capacity Tests"
    
    subheader "Filesystem Usage"
    
    test_start
    local root_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ "$root_usage" -lt 90 ]]; then
        pass "Root filesystem usage reasonable: ${root_usage}%"
    else
        warn "Root filesystem usage high: ${root_usage}%"
    fi
    
    if mountpoint -q /home; then
        test_start
        local home_usage=$(df /home | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ "$home_usage" -lt 90 ]]; then
            pass "Home filesystem usage reasonable: ${home_usage}%"
        else
            warn "Home filesystem usage high: ${home_usage}%"
        fi
    fi
    
    subheader "Btrfs Specific Metrics"
    
    if [[ "$(findmnt -n -o FSTYPE /)" == "btrfs" ]]; then
        test_start
        if btrfs filesystem usage / >/dev/null 2>&1; then
            pass "Btrfs root filesystem readable"
        else
            fail "Cannot read btrfs root filesystem info"
        fi
    fi
}

# Generate detailed report
generate_report() {
    header "Storage Validation Report"
    
    echo ""
    log "=== VALIDATION SUMMARY ==="
    echo "Total tests run: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNING_TESTS${NC}"
    echo ""
    
    local success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    
    if [[ "$FAILED_TESTS" -eq 0 ]]; then
        if [[ "$WARNING_TESTS" -eq 0 ]]; then
            echo -e "${GREEN}✓ EXCELLENT: Storage design fully implemented and optimized!${NC}"
        else
            echo -e "${YELLOW}✓ GOOD: Storage design mostly implemented with minor optimizations needed.${NC}"
        fi
    elif [[ "$FAILED_TESTS" -lt 5 ]]; then
        echo -e "${YELLOW}⚠ PARTIAL: Storage design partially implemented. Some critical components missing.${NC}"
    else
        echo -e "${RED}✗ INCOMPLETE: Storage design not properly implemented. Significant issues found.${NC}"
    fi
    
    echo ""
    echo "Success rate: ${success_rate}%"
    
    if [[ "$FAILED_TESTS" -gt 0 ]]; then
        echo ""
        warn "RECOMMENDATIONS:"
        echo "• Review failed tests above"
        echo "• Run the storage setup/fix script again"
        echo "• Check hardware connections and device paths"
        echo "• Verify fstab entries and mount points"
    fi
    
    if [[ "$WARNING_TESTS" -gt 0 ]]; then
        echo ""
        log "OPTIMIZATIONS:"
        echo "• Address warnings for optimal performance"
        echo "• Consider running post-install optimization script"
        echo "• Check mount options for development workloads"
    fi
    
    echo ""
    log "=== CURRENT STORAGE LAYOUT ==="
    echo ""
    echo "Block devices:"
    lsblk -f | grep -E "(nvme|sda)" || echo "No NVMe/SATA devices found"
    
    echo ""
    echo "Current mounts:"
    findmnt -t btrfs,vfat,ext4 | head -15
    
    echo ""
    log "Validation completed at $(date)"
}

# Main execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       Development Storage Validation          ║${NC}"
    echo -e "${BLUE}║     Comprehensive Design Verification         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "Starting comprehensive storage validation..."
    
    test_hardware_detection
    test_filesystem_types
    test_btrfs_subvolumes
    test_mount_points
    test_mount_options
    test_directory_structure
    test_environment_configuration
    test_management_scripts
    test_performance_features
    test_fstab_validation
    test_storage_capacity
    
    generate_report
    
    echo ""
    log "Storage validation completed!"
    
    # Return appropriate exit code
    if [[ "$FAILED_TESTS" -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"