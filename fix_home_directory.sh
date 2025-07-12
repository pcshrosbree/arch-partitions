#!/bin/bash

# Fix Home Directory Mount Issue
# Run this to diagnose and fix /home mount problems

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo bash $0"
    exit 1
fi

echo "=== HOME DIRECTORY RECOVERY ==="
echo ""

# Get the actual username (not root)
ACTUAL_USER=$(who | head -1 | awk '{print $1}' 2>/dev/null || echo "peter")
log "Detected user: $ACTUAL_USER"

# Step 1: Check current mount status
log "Checking current mount status..."
echo ""
mount | grep -E "(home|nvme1n1)" || log "No home-related mounts found"
echo ""

# Step 2: Check available devices
log "Checking available storage devices..."
lsblk -f | grep -E "(nvme1n1|sda)"
echo ""

# Step 3: Check fstab entries
log "Checking fstab entries for home..."
grep -i home /etc/fstab || log "No home entries in fstab"
echo ""

# Step 4: Try to identify the home device
HOME_DEVICE=""
if [[ -b "/dev/nvme1n1p1" ]]; then
    HOME_DEVICE="/dev/nvme1n1p1"
    log "Found secondary NVMe: $HOME_DEVICE"
elif [[ -b "/dev/nvme1n1" ]]; then
    log "Found secondary NVMe but no partition: /dev/nvme1n1"
    warn "The secondary drive may not be partitioned"
else
    warn "Secondary NVMe not found"
fi

# Step 5: Quick fix - create home directory on root filesystem
log "Creating temporary home directory on root filesystem..."
mkdir -p "/home/$ACTUAL_USER"
chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER"
log "✓ Temporary home directory created: /home/$ACTUAL_USER"

# Step 6: If we have a home device, try to set it up
if [[ -n "$HOME_DEVICE" ]] && [[ -b "$HOME_DEVICE" ]]; then
    log "Attempting to set up home filesystem on $HOME_DEVICE..."
    
    # Check if it's formatted
    if blkid "$HOME_DEVICE" | grep -q btrfs; then
        log "Device is formatted with btrfs"
        
        # Try to mount and check subvolumes
        mkdir -p /mnt/home_check
        if mount "$HOME_DEVICE" /mnt/home_check 2>/dev/null; then
            log "Mounted successfully, checking subvolumes..."
            
            # List subvolumes
            btrfs subvolume list /mnt/home_check || log "No subvolumes found"
            
            # Check if @home exists
            if [[ -d "/mnt/home_check/@home" ]]; then
                log "Found @home subvolume"
                
                # Unmount and remount with correct subvolume
                umount /mnt/home_check
                
                # Mount to actual /home with @home subvolume
                if mount "$HOME_DEVICE" /home -o subvol=@home 2>/dev/null; then
                    log "✓ Successfully mounted home with @home subvolume"
                    
                    # Create user directory if it doesn't exist
                    mkdir -p "/home/$ACTUAL_USER"
                    chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER"
                    
                    # Add to fstab if not present
                    HOME_UUID=$(blkid -s UUID -o value "$HOME_DEVICE")
                    if ! grep -q "$HOME_UUID" /etc/fstab; then
                        log "Adding home mount to fstab..."
                        echo "UUID=$HOME_UUID /home btrfs defaults,noatime,compress=zstd:3,space_cache=v2,ssd,ssd_spread,discard=async,commit=120,subvol=@home 0 2" >> /etc/fstab
                        log "✓ Added to fstab"
                    fi
                else
                    warn "Failed to mount with @home subvolume, mounting default"
                    mount "$HOME_DEVICE" /home
                    mkdir -p "/home/$ACTUAL_USER"
                    chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER"
                fi
            else
                log "No @home subvolume found, mounting default subvolume"
                umount /mnt/home_check
                
                # Mount default subvolume
                mount "$HOME_DEVICE" /home
                mkdir -p "/home/$ACTUAL_USER"
                chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER"
                
                # Create @home subvolume for future use
                log "Creating @home subvolume..."
                btrfs subvolume create /home/@home
                
                # Move user data to subvolume and remount
                if [[ -d "/home/$ACTUAL_USER" ]]; then
                    mv "/home/$ACTUAL_USER" "/home/@home/"
                fi
                
                umount /home
                mount "$HOME_DEVICE" /home -o subvol=@home
                
                log "✓ Created and mounted @home subvolume"
            fi
            
            rmdir /mnt/home_check 2>/dev/null || true
        else
            error "Cannot mount $HOME_DEVICE"
        fi
    else
        log "Device not formatted with btrfs, formatting now..."
        
        # Format as btrfs
        mkfs.btrfs -f -L "HOME" "$HOME_DEVICE"
        
        # Mount and create subvolume
        mount "$HOME_DEVICE" /home
        btrfs subvolume create /home/@home
        
        # Move any existing home data
        if [[ -d "/home/$ACTUAL_USER" ]]; then
            mv "/home/$ACTUAL_USER" "/home/@home/"
        else
            mkdir -p "/home/@home/$ACTUAL_USER"
            chown "$ACTUAL_USER:$ACTUAL_USER" "/home/@home/$ACTUAL_USER"
        fi
        
        # Remount with subvolume
        umount /home
        mount "$HOME_DEVICE" /home -o subvol=@home
        
        log "✓ Formatted and set up home filesystem"
    fi
else
    log "Using root filesystem for home directory (no secondary drive setup)"
fi

# Step 7: Final verification
log "Final verification..."
echo ""
log "Home directory status:"
ls -la /home/
echo ""
log "Mount points:"
mount | grep -E "(home|nvme)" || log "No special home mounts"
echo ""

# Step 8: Test user login
log "Testing directory access..."
if [[ -d "/home/$ACTUAL_USER" ]]; then
    log "✓ User home directory exists: /home/$ACTUAL_USER"
    log "✓ Permissions: $(ls -ld /home/$ACTUAL_USER | awk '{print $1, $3, $4}')"
else
    error "User home directory still missing!"
    mkdir -p "/home/$ACTUAL_USER"
    chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER"
    log "✓ Created user home directory"
fi

echo ""
log "=== RECOVERY COMPLETE ==="
log "You should now be able to log in normally"
log "If problems persist, reboot and try logging in again"
echo ""

# Show final mount status
log "Current mount status:"
findmnt / /home 2>/dev/null || mount | grep -E "/ |/home"
