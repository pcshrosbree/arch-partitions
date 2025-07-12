#!/bin/bash

# Arch Linux Boot Partition Diagnostic Script
# Run this to diagnose why archinstall cannot find the boot partition

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

header "Boot Partition Diagnostic"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# 1. Check block devices
header "1. Block Devices Overview"
lsblk -f
echo ""

# 2. Check partitions specifically
header "2. Detailed Partition Information"
for device in /dev/nvme0n1 /dev/nvme1n1 /dev/sda; do
    if [[ -b "$device" ]]; then
        log "Checking partitions on $device:"
        parted -s "$device" print || warn "Could not read partition table on $device"
        echo ""
    else
        warn "Device $device not found"
    fi
done

# 3. Check EFI partition specifically
header "3. EFI Partition Check"
if [[ -b "/dev/nvme0n1p1" ]]; then
    log "EFI partition found: /dev/nvme0n1p1"
    
    # Check filesystem
    log "Filesystem information:"
    blkid /dev/nvme0n1p1 || warn "Could not get filesystem info"
    
    # Check if it's properly formatted
    log "Checking FAT32 filesystem:"
    file -s /dev/nvme0n1p1
    
    # Check if it's mounted
    log "Current mount status:"
    mount | grep nvme0n1p1 || log "EFI partition not currently mounted"
    
else
    error "EFI partition /dev/nvme0n1p1 not found!"
fi

# 4. Check current mount points
header "4. Current Mount Points"
log "All current mounts:"
mount | grep -E "(nvme|sda)" || log "No NVMe/SSD devices currently mounted"

# 5. Check if /mnt structure exists
header "5. Mount Structure Check"
if [[ -d "/mnt" ]]; then
    log "/mnt directory exists"
    log "Contents of /mnt:"
    ls -la /mnt/ || log "/mnt is empty"
    
    if [[ -d "/mnt/boot" ]]; then
        log "/mnt/boot exists"
        if [[ -d "/mnt/boot/efi" ]]; then
            log "/mnt/boot/efi exists"
            ls -la /mnt/boot/efi/ || log "/mnt/boot/efi is empty"
        else
            warn "/mnt/boot/efi does not exist"
        fi
    else
        warn "/mnt/boot does not exist"
    fi
else
    warn "/mnt directory does not exist"
fi

# 6. Check EFI variables (if system supports UEFI)
header "6. UEFI System Check"
if [[ -d "/sys/firmware/efi" ]]; then
    log "System booted in UEFI mode"
    
    # Check EFI variables
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        log "EFI variables accessible"
        log "EFI variables count: $(ls /sys/firmware/efi/efivars | wc -l)"
    else
        warn "EFI variables not accessible"
    fi
else
    error "System not booted in UEFI mode! This could be the problem."
    log "You may need to:"
    log "1. Boot from USB in UEFI mode (not Legacy/BIOS)"
    log "2. Check BIOS settings for UEFI boot"
fi

# 7. Check if partitions are properly recognized
header "7. Partition Recognition Check"
log "Checking if kernel recognizes partitions:"
cat /proc/partitions | grep -E "(nvme|sda)" || warn "No NVMe/SSD partitions found in /proc/partitions"

# 8. Test mounting the EFI partition
header "8. EFI Partition Mount Test"
if [[ -b "/dev/nvme0n1p1" ]]; then
    log "Testing EFI partition mount..."
    
    # Create temporary mount point
    mkdir -p /tmp/efi_test
    
    # Try to mount
    if mount /dev/nvme0n1p1 /tmp/efi_test 2>/dev/null; then
        log "✓ EFI partition mounts successfully"
        log "Contents:"
        ls -la /tmp/efi_test/ || log "Empty"
        umount /tmp/efi_test
    else
        error "✗ Cannot mount EFI partition"
        log "Trying to check filesystem errors..."
        fsck.fat -v /dev/nvme0n1p1 || error "Filesystem check failed"
    fi
    
    rmdir /tmp/efi_test
else
    error "EFI partition /dev/nvme0n1p1 not found for testing"
fi

# 9. archinstall compatibility check
header "9. archinstall Compatibility Check"
log "Checking archinstall requirements:"

# Check if archinstall can see the structure
if command -v archinstall &> /dev/null; then
    log "archinstall command available"
    
    # Check if /mnt has the expected structure
    if [[ -d "/mnt" ]] && [[ -d "/mnt/boot" ]] && [[ -d "/mnt/boot/efi" ]]; then
        log "✓ Mount structure looks correct for archinstall"
    else
        warn "✗ Mount structure incomplete for archinstall"
        log "Expected: /mnt, /mnt/boot, /mnt/boot/efi"
    fi
else
    warn "archinstall command not found"
fi

# 10. Suggested fixes
header "10. Suggested Fixes"
log "Based on the diagnostic, here are potential fixes:"

echo ""
log "Common issues and solutions:"
log "1. If EFI partition not found:"
log "   - Re-run the storage setup script"
log "   - Check device paths in script match your actual devices"

log "2. If not booted in UEFI mode:"
log "   - Reboot and enter BIOS/UEFI settings"
log "   - Enable UEFI boot mode"
log "   - Boot USB in UEFI mode (not Legacy)"

log "3. If EFI partition exists but won't mount:"
log "   - Run: mkfs.fat -F32 -n 'EFI_SYSTEM' /dev/nvme0n1p1"
log "   - Then re-run storage setup script"

log "4. If mount structure is wrong:"
log "   - Unmount all: umount -R /mnt"
log "   - Re-run storage setup script"

log "5. For archinstall compatibility:"
log "   - Use 'Pre-mounted configuration' option"
log "   - Set mount point to: /mnt"
log "   - Don't let archinstall manage partitions"

echo ""
log "If problems persist, run this script again after applying fixes"
