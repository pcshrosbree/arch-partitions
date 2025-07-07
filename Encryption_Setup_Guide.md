# Disk Encryption Setup Guide
## LUKS Encryption for High-Performance Workstation

### Overview
This guide configures LUKS (Linux Unified Key Setup) encryption for your multi-drive setup while maintaining optimal performance on your Samsung SSD 9100 PRO. We'll implement a selective encryption strategy that balances security with performance.

### Encryption Strategy Options

#### Option 1: Selective Encryption (Recommended)
**Encrypt**: Home directory and development workspace (Samsung SSD 9100 PRO)
**Unencrypted**: Root system (TEAMGROUP drive), Cache/Swap (SATA SSD)

**Benefits**:
- Protects sensitive development data and personal files
- Maintains fast boot times (unencrypted root)
- Optimal performance for cached data
- Reduces complexity

#### Option 2: Full Encryption
**Encrypt**: All drives except EFI partition
**Benefits**: Maximum security
**Drawbacks**: Performance impact, complex key management

#### Option 3: Home-Only Encryption
**Encrypt**: Only home directory
**Benefits**: Simplest setup, minimal performance impact

## Recommended Setup: Selective Encryption

### Drive Layout with Encryption
```
TEAMGROUP T-Force Z540 (nvme0n1):
├── nvme0n1p1: EFI (unencrypted) - 1GB FAT32
└── nvme0n1p2: Root (unencrypted) - btrfs with subvolumes

Samsung SSD 9100 PRO (nvme1n1):
├── nvme1n1p1: Dev Workspace (encrypted) - 1TB btrfs
└── nvme1n1p2: Home (encrypted) - 3TB btrfs

SATA SSD (sda):
├── sda1: Swap (unencrypted) - 32GB
└── sda2: Cache (unencrypted) - btrfs
```

## Phase 1: Pre-Installation Encryption Setup

### Step 1: Install Encryption Tools
```bash
# Ensure cryptsetup is available (should be on Arch ISO)
pacman -Sy cryptsetup

# Verify LUKS support
cryptsetup --version
```

### Step 2: Partition Drives (Same as Before)
```bash
# TEAMGROUP T-Force Z540 (nvme0n1) - No changes needed
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart "EFI" fat32 1MiB 1025MiB
parted -s /dev/nvme0n1 set 1 esp on
parted -s /dev/nvme0n1 mkpart "ROOT" btrfs 1025MiB 100%

# Samsung SSD 9100 PRO (nvme1n1) - Will be encrypted
parted -s /dev/nvme1n1 mklabel gpt
parted -s /dev/nvme1n1 mkpart "DEV_WORKSPACE_CRYPT" btrfs 1MiB 1025GiB
parted -s /dev/nvme1n1 mkpart "HOME_CRYPT" btrfs 1025GiB 100%

# SATA SSD (sda) - No changes needed
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart "SWAP" linux-swap 1MiB 32GiB
parted -s /dev/sda mkpart "CACHE" btrfs 32GiB 100%
```

### Step 3: Setup LUKS Encryption for Samsung SSD 9100 PRO

#### Encrypt Development Workspace Partition
```bash
# Create LUKS container for development workspace
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha256 /dev/nvme1n1p1

# You'll be prompted to enter a passphrase - use a strong passphrase
# Confirm the passphrase

# Open the encrypted container
cryptsetup open /dev/nvme1n1p1 dev_workspace

# The decrypted device is now available as /dev/mapper/dev_workspace
```

#### Encrypt Home Partition
```bash
# Create LUKS container for home directory
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha256 /dev/nvme1n1p2

# Enter a passphrase (can be same or different from dev workspace)
# Confirm the passphrase

# Open the encrypted container
cryptsetup open /dev/nvme1n1p2 home_encrypted

# The decrypted device is now available as /dev/mapper/home_encrypted
```

### Step 4: Format Filesystems

#### Format Unencrypted Drives
```bash
# EFI partition
mkfs.fat -F32 /dev/nvme0n1p1

# Root filesystem (unencrypted)
mkfs.btrfs -f -L "arch-root" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    /dev/nvme0n1p2

# Swap and cache (unencrypted)
mkswap /dev/sda1
mkfs.btrfs -f -L "arch-cache" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    /dev/sda2
```

#### Format Encrypted Drives
```bash
# Development workspace (encrypted Samsung SSD 9100 PRO)
mkfs.btrfs -f -L "arch-dev-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/dev_workspace

# Home directory (encrypted Samsung SSD 9100 PRO)
mkfs.btrfs -f -L "arch-home-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/home_encrypted
```

## Phase 2: Mount Encrypted Filesystems

### Step 5: Mount Root and Create Subvolumes
```bash
# Mount root filesystem
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async /dev/nvme0n1p2 /mnt

# Create btrfs subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@.snapshots

# Unmount and remount with subvolume
umount /mnt
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@ /dev/nvme0n1p2 /mnt
```

### Step 6: Mount All Filesystems
```bash
# Create mount points
mkdir -p /mnt/{boot,home,workspace,var,tmp,.snapshots,.cache}
mkdir -p /mnt/var/{log,cache}

# Mount EFI partition
mount /dev/nvme0n1p1 /mnt/boot

# Mount unencrypted subvolumes
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var /dev/nvme0n1p2 /mnt/var
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_log /dev/nvme0n1p2 /mnt/var/log
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@var_cache /dev/nvme0n1p2 /mnt/var/cache
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@tmp /dev/nvme0n1p2 /mnt/tmp
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@.snapshots /dev/nvme0n1p2 /mnt/.snapshots

# Mount encrypted filesystems (Samsung SSD 9100 PRO)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/mapper/dev_workspace /mnt/workspace
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/mapper/home_encrypted /mnt/home

# Mount cache filesystem (unencrypted)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async /dev/sda2 /mnt/.cache

# Enable swap
swapon /dev/sda1
```

### Step 7: Verify Mount Configuration
```bash
# Check all mounts
lsblk
df -h

# Verify encrypted devices
ls -la /dev/mapper/
```

## Phase 3: archinstall with Encrypted Pre-Mounted Setup

### Step 8: Launch archinstall
```bash
# archinstall will detect the pre-mounted configuration including encrypted volumes
archinstall
```

### Step 9: Configure archinstall
- **Disk layout**: Pre-mounted configuration
- **Encryption**: Should detect existing LUKS setup
- **Other settings**: Configure normally as per the main guide

## Phase 4: Post-Installation Encryption Configuration

### Step 10: Configure Automatic Mounting

#### Create Crypttab
```bash
# Create crypttab for automatic decryption
sudo tee /etc/crypttab > /dev/null << 'EOF'
# Development workspace on Samsung SSD 9100 PRO
dev_workspace UUID=device-uuid-here none luks,discard

# Home directory on Samsung SSD 9100 PRO  
home_encrypted UUID=device-uuid-here none luks,discard
EOF

# Get UUIDs for crypttab
blkid /dev/nvme1n1p1 | grep -o 'UUID="[^"]*"' | cut -d'"' -f2
blkid /dev/nvme1n1p2 | grep -o 'UUID="[^"]*"' | cut -d'"' -f2

# Replace device-uuid-here with actual UUIDs
```

#### Update fstab
```bash
# Verify fstab uses /dev/mapper/ paths for encrypted filesystems
sudo cat /etc/fstab

# Should contain entries like:
# /dev/mapper/dev_workspace /dev btrfs noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 0 0
# /dev/mapper/home_encrypted /home btrfs noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 0 0
```

### Step 11: Configure Boot Process for Encrypted Drives

#### Update GRUB Configuration
```bash
# Add cryptdevice kernel parameters
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& cryptdevice=UUID=DEV_UUID:dev_workspace cryptdevice=UUID=HOME_UUID:home_encrypted/' /etc/default/grub

# Regenerate GRUB configuration
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

#### Add Hooks to mkinitcpio
```bash
# Edit mkinitcpio configuration
sudo nano /etc/mkinitcpio.conf

# Add 'encrypt' hook before 'filesystems'
# HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)

# Regenerate initramfs
sudo mkinitcpio -P
```

## Performance Considerations

### Encryption Performance Impact

#### Expected Performance:
- **Samsung SSD 9100 PRO with AES-256**: 5-10% performance reduction
- **Modern CPUs with AES-NI**: Minimal impact
- **Memory usage**: ~50MB additional RAM per encrypted volume

#### Optimization Settings:
```bash
# Check AES-NI support
grep -m1 -o aes /proc/cpuinfo

# Optimize cryptsetup for performance
echo 'options dm_crypt same_cpu_crypt=1' | sudo tee /etc/modprobe.d/dm_crypt.conf
echo 'options dm_crypt force_inline=1' | sudo tee -a /etc/modprobe.d/dm_crypt.conf
```

### SSD-Specific Optimizations for Encrypted Drives

#### Enable TRIM for Encrypted SSDs
```bash
# Add discard option to crypttab (already included above)
# Verify TRIM is working
sudo fstrim -v /dev
sudo fstrim -v /home
```

#### Performance Testing
```bash
# Test unencrypted vs encrypted performance
sudo hdparm -Tt /dev/nvme0n1p2  # Unencrypted root
sudo hdparm -Tt /dev/mapper/dev_workspace  # Encrypted dev workspace

# Benchmark with fio
fio --name=encrypted-test --ioengine=libaio --iodepth=4 --rw=randrw --bs=4k --direct=1 --size=1G --numjobs=1 --runtime=60 --filename=/dev/encrypted-test-file
```

## Key Management and Security

### Backup Encryption Keys
```bash
# Backup LUKS headers (CRITICAL for recovery)
sudo cryptsetup luksHeaderBackup /dev/nvme1n1p1 --header-backup-file dev_workspace_header.backup
sudo cryptsetup luksHeaderBackup /dev/nvme1n1p2 --header-backup-file home_encrypted_header.backup

# Store these backup files securely (external drive, cloud storage)
```

### Add Additional Key Slots
```bash
# Add a second passphrase for recovery
sudo cryptsetup luksAddKey /dev/nvme1n1p1
sudo cryptsetup luksAddKey /dev/nvme1n1p2

# Add key file for automated mounting (optional)
sudo dd if=/dev/urandom of=/etc/luks-keys/dev_workspace.key bs=1024 count=4
sudo chmod 400 /etc/luks-keys/dev_workspace.key
sudo cryptsetup luksAddKey /dev/nvme1n1p1 /etc/luks-keys/dev_workspace.key
```

## Troubleshooting Encrypted Setup

### Boot Issues
```bash
# If system fails to boot:
# 1. Boot from Arch USB
# 2. Decrypt drives manually:
cryptsetup open /dev/nvme1n1p1 dev_workspace
cryptsetup open /dev/nvme1n1p2 home_encrypted

# 3. Mount and chroot to fix configuration
mount /dev/nvme0n1p2 /mnt
mount /dev/mapper/home_encrypted /mnt/home
mount /dev/mapper/dev_workspace /mnt/dev
arch-chroot /mnt
```

### Performance Issues
```bash
# Check encryption algorithms
cryptsetup status dev_workspace
cryptsetup status home_encrypted

# Monitor encryption overhead
iostat -x 1
```

### Key Recovery
```bash
# Test key backup files
sudo cryptsetup luksHeaderRestore /dev/nvme1n1p1 --header-backup-file dev_workspace_header.backup

# Change passphrase
sudo cryptsetup luksChangeKey /dev/nvme1n1p1
```

## Summary

This encryption setup provides:
- **Security**: Sensitive development data and personal files encrypted
- **Performance**: System and cache remain unencrypted for speed
- **Convenience**: Single passphrase entry at boot
- **Flexibility**: Easy key management and recovery options

The selective encryption approach balances security with the high-performance requirements of your development workstation while taking advantage of your Samsung SSD 9100 PRO's capabilities.