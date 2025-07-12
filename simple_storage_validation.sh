#!/bin/bash

# Simple Storage Validation
# Simplified version without complex arrays and arithmetic

# Device paths
PRIMARY_NVME="/dev/nvme0n1"
SECONDARY_NVME="/dev/nvme1n1"
BULK_SATA="/dev/sda"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Simple counters
TOTAL=0
PASS=0
FAIL=0
WARN=0

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

pass() {
    echo -e "${GREEN}[PASS] $1${NC}"
    PASS=$((PASS + 1))
    TOTAL=$((TOTAL + 1))
}

fail() {
    echo -e "${RED}[FAIL] $1${NC}"
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
    WARN=$((WARN + 1))
    TOTAL=$((TOTAL + 1))
}

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

echo "=== STORAGE VALIDATION ==="
echo ""

# Test 1: Hardware Detection
header "Hardware Detection"

echo "Testing block devices..."

if [[ -b "$PRIMARY_NVME" ]]; then
    pass "Primary NVMe detected: $PRIMARY_NVME"
else
    fail "Primary NVMe not found: $PRIMARY_NVME"
fi

if [[ -b "$SECONDARY_NVME" ]]; then
    pass "Secondary NVMe detected: $SECONDARY_NVME"
else
    warn "Secondary NVMe not found: $SECONDARY_NVME"
fi

if [[ -b "$BULK_SATA" ]]; then
    pass "Bulk SATA detected: $BULK_SATA"
else
    warn "Bulk SATA not found: $BULK_SATA"
fi

echo "Testing partitions..."

if [[ -b "${PRIMARY_NVME}p1" ]]; then
    pass "EFI partition detected: ${PRIMARY_NVME}p1"
else
    fail "EFI partition not found: ${PRIMARY_NVME}p1"
fi

if [[ -b "${PRIMARY_NVME}p2" ]]; then
    pass "Root partition detected: ${PRIMARY_NVME}p2"
else
    fail "Root partition not found: ${PRIMARY_NVME}p2"
fi

if [[ -b "${SECONDARY_NVME}p1" ]]; then
    pass "Home partition detected: ${SECONDARY_NVME}p1"
else
    warn "Home partition not found: ${SECONDARY_NVME}p1"
fi

if [[ -b "${BULK_SATA}1" ]]; then
    pass "Bulk partition detected: ${BULK_SATA}1"
else
    warn "Bulk partition not found: ${BULK_SATA}1"
fi

# Test 2: Filesystem Types
header "Filesystem Types"

if [[ -b "${PRIMARY_NVME}p1" ]]; then
    EFI_FS=$(blkid -s TYPE -o value "${PRIMARY_NVME}p1" 2>/dev/null || echo "unknown")
    if [[ "$EFI_FS" == "vfat" ]]; then
        pass "EFI partition filesystem: $EFI_FS"
    else
        fail "EFI partition wrong filesystem: $EFI_FS (expected vfat)"
    fi
fi

if [[ -b "${PRIMARY_NVME}p2" ]]; then
    ROOT_FS=$(blkid -s TYPE -o value "${PRIMARY_NVME}p2" 2>/dev/null || echo "unknown")
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        pass "Root partition filesystem: $ROOT_FS"
    else
        fail "Root partition wrong filesystem: $ROOT_FS (expected btrfs)"
    fi
fi

if [[ -b "${SECONDARY_NVME}p1" ]]; then
    HOME_FS=$(blkid -s TYPE -o value "${SECONDARY_NVME}p1" 2>/dev/null || echo "unknown")
    if [[ "$HOME_FS" == "btrfs" ]]; then
        pass "Home partition filesystem: $HOME_FS"
    else
        warn "Home partition filesystem: $HOME_FS (expected btrfs)"
    fi
fi

# Test 3: Mount Points
header "Critical Mount Points"

if mountpoint -q / 2>/dev/null; then
    ROOT_MOUNT_FS=$(findmnt -n -o FSTYPE /)
    ROOT_MOUNT_SRC=$(findmnt -n -o SOURCE /)
    pass "Root mounted: $ROOT_MOUNT_SRC ($ROOT_MOUNT_FS)"
else
    fail "Root filesystem not mounted"
fi

if mountpoint -q /boot/efi 2>/dev/null; then
    EFI_MOUNT_SRC=$(findmnt -n -o SOURCE /boot/efi)
    pass "EFI mounted: $EFI_MOUNT_SRC"
elif mountpoint -q /efi 2>/dev/null; then
    EFI_MOUNT_SRC=$(findmnt -n -o SOURCE /efi)
    pass "EFI mounted: $EFI_MOUNT_SRC"
else
    fail "EFI partition not mounted"
fi

if mountpoint -q /home 2>/dev/null; then
    HOME_MOUNT_FS=$(findmnt -n -o FSTYPE /home)
    HOME_MOUNT_SRC=$(findmnt -n -o SOURCE /home)
    pass "Home mounted: $HOME_MOUNT_SRC ($HOME_MOUNT_FS)"
else
    warn "Home not mounted on separate partition"
fi

# Test 4: Btrfs Subvolumes
header "Btrfs Subvolumes"

if [[ "$(findmnt -n -o FSTYPE /)" == "btrfs" ]]; then
    ROOT_SUBVOLS=$(btrfs subvolume list / 2>/dev/null | wc -l)
    if [[ "$ROOT_SUBVOLS" -gt 0 ]]; then
        pass "Root btrfs has $ROOT_SUBVOLS subvolumes"
        
        # Check for key subvolumes
        if btrfs subvolume list / 2>/dev/null | grep -q "@"; then
            pass "Root subvolume @ exists"
        else
            warn "Root subvolume @ missing"
        fi
        
        if btrfs subvolume list / 2>/dev/null | grep -q "@snapshots"; then
            pass "Snapshots subvolume exists"
        else
            warn "Snapshots subvolume missing"
        fi
    else
        warn "No subvolumes found on root filesystem"
    fi
else
    warn "Root filesystem is not btrfs"
fi

if mountpoint -q /home && [[ "$(findmnt -n -o FSTYPE /home)" == "btrfs" ]]; then
    HOME_SUBVOLS=$(btrfs subvolume list /home 2>/dev/null | wc -l)
    if [[ "$HOME_SUBVOLS" -gt 0 ]]; then
        pass "Home btrfs has $HOME_SUBVOLS subvolumes"
    else
        warn "No subvolumes found on home filesystem"
    fi
fi

# Test 5: Development Cache Directories
header "Development Cache Directories"

DEV_CACHE_DIRS="/var/cache/cargo /var/cache/go /var/cache/node_modules /var/cache/pyenv /var/cache/poetry"

for dir in $DEV_CACHE_DIRS; do
    if [[ -d "$dir" ]]; then
        if mountpoint -q "$dir" 2>/dev/null; then
            CACHE_SRC=$(findmnt -n -o SOURCE "$dir")
            pass "Cache directory mounted: $dir ($CACHE_SRC)"
        else
            warn "Cache directory exists but not mounted: $dir"
        fi
    else
        warn "Cache directory missing: $dir"
    fi
done

# Test 6: Environment Configuration
header "Environment Configuration"

if [[ -f "/etc/profile.d/dev-paths.sh" ]]; then
    pass "Development environment file exists"
    
    if grep -q "CARGO_HOME" "/etc/profile.d/dev-paths.sh"; then
        pass "CARGO_HOME configured"
    else
        warn "CARGO_HOME not configured"
    fi
    
    if grep -q "GOCACHE" "/etc/profile.d/dev-paths.sh"; then
        pass "GOCACHE configured"
    else
        warn "GOCACHE not configured"
    fi
else
    warn "Development environment file missing"
fi

if [[ -f "/etc/tmpfiles.d/dev-caches.conf" ]]; then
    pass "Systemd tmpfiles configuration exists"
else
    warn "Systemd tmpfiles configuration missing"
fi

# Test 7: Management Scripts
header "Management Scripts"

if [[ -x "/usr/local/bin/storage-info" ]]; then
    pass "Storage info script exists and executable"
else
    warn "Storage info script missing"
fi

if [[ -x "/usr/local/bin/snapshot-manager" ]]; then
    pass "Snapshot manager script exists and executable"
else
    warn "Snapshot manager script missing"
fi

# Test 8: fstab
header "fstab Configuration"

if mount -a --fake 2>/dev/null; then
    pass "fstab syntax is valid"
else
    fail "fstab has syntax errors"
fi

FSTAB_ENTRIES=$(grep -c "^UUID=" /etc/fstab || echo "0")
if [[ "$FSTAB_ENTRIES" -ge 2 ]]; then
    pass "fstab has $FSTAB_ENTRIES UUID entries"
else
    warn "fstab has only $FSTAB_ENTRIES UUID entries"
fi

if grep -q "btrfs" /etc/fstab; then
    pass "fstab contains btrfs entries"
else
    warn "fstab missing btrfs entries"
fi

# Test 9: Current Storage Layout
header "Current Storage Layout"

echo ""
log "Block devices:"
lsblk -f | grep -E "(nvme|sda)" || echo "No NVMe/SATA devices found"

echo ""
log "Current mounts:"
findmnt -t btrfs,vfat,ext4 | head -10

echo ""
log "Storage usage:"
df -h / /home 2>/dev/null | grep -v "Filesystem" || df -h /

# Summary
header "Validation Summary"

echo ""
echo "Tests completed: $TOTAL"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo -e "Warnings: ${YELLOW}$WARN${NC}"

if [[ "$FAIL" -eq 0 ]]; then
    if [[ "$WARN" -eq 0 ]]; then
        echo -e "\n${GREEN}✓ EXCELLENT: Storage fully configured!${NC}"
    else
        echo -e "\n${YELLOW}✓ GOOD: Storage mostly configured with minor issues.${NC}"
    fi
else
    echo -e "\n${YELLOW}⚠ ISSUES: Storage has some problems that need attention.${NC}"
fi

echo ""
log "Validation completed successfully!"
