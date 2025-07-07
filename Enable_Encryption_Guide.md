# Enable Disk Encryption for Existing Arch Linux System
## LUKS Encryption Setup for High-Performance Workstation

### ⚠️ CRITICAL WARNING
**This process involves reformatting drives and will DESTROY ALL EXISTING DATA.** Ensure you have complete backups before proceeding.

### Overview
This guide will enable selective LUKS encryption on your Samsung SSD 9100 PRO while keeping the root system unencrypted for optimal boot performance.

### Recommended Encryption Strategy

#### What to Encrypt:
- **Samsung SSD 9100 PRO partitions** (workspace + home)
- **Sensitive development data and personal files**

#### What to Keep Unencrypted:
- **Root filesystem** (fast boot times)
- **EFI partition** (required for boot)
- **Cache and swap** (performance optimization)

### Pre-Encryption Preparation

#### Step 1: Backup Critical Data
```bash
# Backup home directory
sudo rsync -avH /home/ /backup/home/

# Backup workspace (if it exists and contains data)
sudo rsync -avH /workspace/ /backup/workspace/

# Backup system configuration
sudo rsync -avH /etc/ /backup/etc/

# List installed packages for reinstallation
pacman -Qqe > /backup/package_list.txt
```

#### Step 2: Create Bootable Arch USB
- Download latest Arch Linux ISO
- Create bootable USB drive
- Test booting from USB

### Phase 1: Boot from Arch USB and Prepare

#### Step 3: Boot from USB and Setup Environment
```bash
# Boot from Arch USB
# Set console font (optional)
setfont ter-132

# Set system clock
timedatectl set-ntp true

# Install required tools
pacman -Sy cryptsetup

# Verify LUKS support
cryptsetup --version
```

#### Step 4: Identify Current Drive Layout
```bash
# Check current drive configuration
lsblk -f

# Identify your drives
# nvme0n1: TEAMGROUP T-Force Z540 4TB (will remain unencrypted)
# nvme1n1: Samsung SSD 9100 PRO 4TB (will be encrypted)
# sda: SATA SSD (will remain unencrypted)

# Verify drive models
smartctl -i /dev/nvme0n1 | grep "Model Number"
smartctl -i /dev/nvme1n1 | grep "Model Number"
```

### Phase 2: Backup and Unmount

#### Step 5: Mount Existing System (if needed for final backup)
```bash
# Mount existing root to access data
mount /dev/nvme0n1p2 /mnt

# Mount other filesystems if needed
mount /dev/nvme1n1p2 /mnt/home
mount /dev/nvme1n1p1 /mnt/workspace

# Create additional backups if needed
cp -r /mnt/home/peter/important_data /backup/

# Unmount everything
umount -R /mnt
```

### Phase 3: Setup Encrypted Samsung SSD 9100 PRO

#### Step 6: Partition Samsung SSD 9100 PRO
```bash
# Wipe the Samsung SSD completely
wipefs -af /dev/nvme1n1

# Create new partition table
parted -s /dev/nvme1n1 mklabel gpt

# Create development workspace partition (1TB)
parted -s /dev/nvme1n1 mkpart "DEV_WORKSPACE_CRYPT" btrfs 1MiB 1025GiB

# Create home partition (remaining ~3TB)
parted -s /dev/nvme1n1 mkpart "HOME_CRYPT" btrfs 1025GiB 100%

# Verify partitions
lsblk /dev/nvme1n1
```

#### Step 7: Create LUKS Encrypted Containers

##### Encrypt Development Workspace
```bash
# Create LUKS2 encrypted container for workspace
cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --use-random \
    --verify-passphrase \
    /dev/nvme1n1p1

# Enter a strong passphrase when prompted
# Confirm the passphrase

# Open the encrypted container
cryptsetup open /dev/nvme1n1p1 workspace_crypt

# Verify the encrypted device is available
ls -la /dev/mapper/workspace_crypt
```

##### Encrypt Home Directory
```bash
# Create LUKS2 encrypted container for home
cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --use-random \
    --verify-passphrase \
    /dev/nvme1n1p2

# Enter passphrase (can be same or different from workspace)
# Confirm the passphrase

# Open the encrypted container
cryptsetup open /dev/nvme1n1p2 home_crypt

# Verify the encrypted device is available
ls -la /dev/mapper/home_crypt
```

#### Step 8: Create Filesystems on Encrypted Devices
```bash
# Format development workspace (Samsung SSD 9100 PRO optimized)
mkfs.btrfs -f -L "workspace-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/workspace_crypt

# Format home directory (Samsung SSD 9100 PRO optimized)
mkfs.btrfs -f -L "home-encrypted" \
    --csum xxhash \
    --features skinny-metadata,no-holes \
    --nodesize 16384 \
    /dev/mapper/home_crypt
```

### Phase 4: Reinstall System with Encryption

#### Step 9: Mount Filesystems for Installation
```bash
# Mount existing root filesystem (unencrypted)
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async /dev/nvme0n1p2 /mnt

# Create mount points
mkdir -p /mnt/{boot,home,workspace,var,tmp,.snapshots,.cache}

# Mount EFI partition
mount /dev/nvme0n1p1 /mnt/boot

# Mount encrypted filesystems with ultra-performance options
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/mapper/workspace_crypt /mnt/workspace
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,commit=30 /dev/mapper/home_crypt /mnt/home

# Mount cache and enable swap
mount -o noatime,compress=zstd:1,space_cache=v2,discard=async /dev/sda2 /mnt/.cache
swapon /dev/sda1
```

#### Step 10: Reinstall Base System
```bash
# Install base system with encryption support
pacstrap /mnt base base-devel linux linux-firmware \
    cryptsetup btrfs-progs \
    networkmanager openssh \
    git vim nano \
    grub efibootmgr \
    intel-ucode amd-ucode

# Generate fstab with encrypted devices
genfstab -U /mnt >> /mnt/etc/fstab

# Verify fstab looks correct
cat /mnt/etc/fstab
```

### Phase 5: Configure System for Encryption

#### Step 11: Configure Basic System Settings
```bash
# Chroot into new system
arch-chroot /mnt

# Set timezone
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

# Configure locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "arch-workstation" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch-workstation.localdomain arch-workstation
EOF
```

#### Step 12: Configure Encryption for Boot

##### Create crypttab
```bash
# Get UUIDs of encrypted partitions
WORKSPACE_UUID=$(blkid -s UUID -o value /dev/nvme1n1p1)
HOME_UUID=$(blkid -s UUID -o value /dev/nvme1n1p2)

# Create crypttab for automatic decryption
cat > /etc/crypttab << EOF
# Development workspace on Samsung SSD 9100 PRO
workspace_crypt UUID=$WORKSPACE_UUID none luks,discard

# Home directory on Samsung SSD 9100 PRO
home_crypt UUID=$HOME_UUID none luks,discard
EOF

# Verify crypttab
cat /etc/crypttab
```

##### Configure mkinitcpio
```bash
# Edit mkinitcpio configuration
nano /etc/mkinitcpio.conf

# Add 'encrypt' hook before 'filesystems'
# HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)

# Regenerate initramfs
mkinitcpio -P
```

##### Configure GRUB
```bash
# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Add kernel parameters for encryption and performance
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& cryptdevice=UUID='$WORKSPACE_UUID':workspace_crypt cryptdevice=UUID='$HOME_UUID':home_crypt elevator=none mitigations=off amd_iommu=on iommu=pt/' /etc/default/grub

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg
```

#### Step 13: Create Users and Set Passwords
```bash
# Create user
useradd -m -G wheel,storage,power -s /bin/bash peter

# Set passwords
passwd peter
passwd root

# Configure sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
```

#### Step 14: Restore Data from Backup
```bash
# Exit chroot temporarily
exit

# Copy backed up data to encrypted home
cp -r /backup/home/peter/* /mnt/home/peter/
chown -R 1000:1000 /mnt/home/peter/

# Copy workspace data if any
cp -r /backup/workspace/* /mnt/workspace/ 2>/dev/null || true
chown -R 1000:1000 /mnt/workspace/

# Re-enter chroot
arch-chroot /mnt
```

### Phase 6: Configure Encryption Optimizations

#### Step 15: Optimize for Samsung SSD 9100 PRO
```bash
# Configure dm-crypt for performance
echo 'options dm_crypt same_cpu_crypt=1' >> /etc/modprobe.d/dm_crypt.conf
echo 'options dm_crypt force_inline=1' >> /etc/modprobe.d/dm_crypt.conf

# Enable services
systemctl enable NetworkManager
systemctl enable fstrim.timer

# Install additional packages if needed
pacman -S docker docker-compose qemu-full libvirt virt-manager
```

#### Step 16: Configure Development Environment
```bash
# Create development directories on encrypted workspace
mkdir -p /workspace/{docker,vms,containers,build,cache,tmp,projects}
chown -R peter:peter /workspace

# Configure Docker to use encrypted workspace
mkdir -p /etc/docker
echo '{"data-root": "/workspace/docker"}' > /etc/docker/daemon.json

# Enable Docker service
systemctl enable docker
usermod -aG docker peter
```

### Phase 7: Final Configuration and Testing

#### Step 17: Configure Automatic Maintenance
```bash
# Set up automatic snapshots
mkdir -p /etc/systemd/system

cat > /etc/systemd/system/btrfs-snapshot.service << 'EOF'
[Unit]
Description=Btrfs snapshot

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs subvolume snapshot /workspace /workspace/.snapshots/workspace-$(date +%%Y-%%m-%%d-%%H-%%M-%%S)
ExecStart=/usr/bin/btrfs subvolume snapshot /home /home/.snapshots/home-$(date +%%Y-%%m-%%d-%%H-%%M-%%S)
ExecStart=/usr/bin/find /workspace/.snapshots -name 'workspace-*' -mtime +7 -exec btrfs subvolume delete {} \;
ExecStart=/usr/bin/find /home/.snapshots -name 'home-*' -mtime +7 -exec btrfs subvolume delete {} \;
EOF

cat > /etc/systemd/system/btrfs-snapshot.timer << 'EOF'
[Unit]
Description=Daily Btrfs snapshot

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable snapshot service
systemctl enable btrfs-snapshot.timer

# Create snapshot directories
mkdir -p /workspace/.snapshots /home/.snapshots
```

#### Step 18: Backup Encryption Keys
```bash
# Create secure directory for key backups
mkdir -p /root/luks-backups
chmod 700 /root/luks-backups

# Backup LUKS headers (CRITICAL for recovery)
cryptsetup luksHeaderBackup /dev/nvme1n1p1 --header-backup-file /root/luks-backups/workspace_header.backup
cryptsetup luksHeaderBackup /dev/nvme1n1p2 --header-backup-file /root/luks-backups/home_header.backup

# Exit chroot
exit
```

### Phase 8: First Boot and Verification

#### Step 19: Reboot and Test Encryption
```bash
# Unmount all filesystems
umount -R /mnt

# Close encrypted containers
cryptsetup close workspace_crypt
cryptsetup close home_crypt

# Disable swap
swapoff -a

# Reboot
reboot
```

#### Step 20: Verify Encryption is Working
After reboot, you should be prompted for passphrases:

```bash
# Check encryption status
sudo cryptsetup status workspace_crypt
sudo cryptsetup status home_crypt

# Verify mounts
mount | grep mapper

# Check performance
sudo hdparm -Tt /dev/mapper/workspace_crypt
sudo hdparm -Tt /dev/mapper/home_crypt

# Test file creation on encrypted drives
echo "test" > /workspace/test.txt
echo "test" > /home/peter/test.txt
```

### Post-Encryption Configuration

#### Step 21: Configure Cache Redirection
```bash
# Update cache configuration to use encrypted workspace
sudo mkdir -p /workspace/{cache,tmp}

# Update Docker configuration
sudo systemctl stop docker
sudo mkdir -p /etc/docker
echo '{"data-root": "/workspace/docker", "tmp-dir": "/workspace/tmp"}' | sudo tee /etc/docker/daemon.json
sudo systemctl start docker
```

#### Step 22: Performance Verification
```bash
# Test encryption performance
fio --name=encrypted-test --ioengine=libaio --iodepth=4 --rw=randrw --bs=4k --direct=1 --size=1G --runtime=60 --filename=/workspace/fio-test

# Compare with unencrypted performance
fio --name=unencrypted-test --ioengine=libaio --iodepth=4 --rw=randrw --bs=4k --direct=1 --size=1G --runtime=60 --filename=/tmp/fio-test

# Check CPU usage during encryption
iostat -x 1
```

### Security and Maintenance

#### Step 23: Additional Security Measures
```bash
# Add additional passphrase for recovery
sudo cryptsetup luksAddKey /dev/nvme1n1p1
sudo cryptsetup luksAddKey /dev/nvme1n1p2

# Verify key slots
sudo cryptsetup luksDump /dev/nvme1n1p1 | grep "Key Slot"
sudo cryptsetup luksDump /dev/nvme1n1p2 | grep "Key Slot"

# Test TRIM functionality
sudo fstrim -v /workspace
sudo fstrim -v /home
```

#### Step 24: Backup Strategy for Encrypted System
```bash
# Create backup script for encrypted data
cat > /usr/local/bin/backup-encrypted << 'EOF'
#!/bin/bash
BACKUP_DATE=$(date +%Y-%m-%d)
BACKUP_DIR="/backup/encrypted-$BACKUP_DATE"

mkdir -p "$BACKUP_DIR"

# Backup encrypted home directory
rsync -avH --exclude='.cache' /home/ "$BACKUP_DIR/home/"

# Backup workspace (excluding temporary files)
rsync -avH --exclude='docker/tmp' --exclude='tmp' /workspace/ "$BACKUP_DIR/workspace/"

# Backup LUKS headers
cp /root/luks-backups/* "$BACKUP_DIR/"

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x /usr/local/bin/backup-encrypted
```

### Troubleshooting

#### Common Issues and Solutions:

1. **System won't boot after encryption**:
   - Boot from Arch USB
   - Open encrypted containers manually
   - Check GRUB configuration

2. **Performance degradation**:
   - Verify AES-NI is enabled
   - Check mount options include `discard`
   - Monitor CPU usage

3. **Forgot passphrase**:
   - Use backup LUKS headers
   - Try alternative key slots
   - Restore from backups

### Summary

After completing this process, you'll have:
- **Encrypted Samsung SSD 9100 PRO** for sensitive data
- **Unencrypted root system** for fast boot times
- **Optimized performance** with minimal encryption overhead
- **Comprehensive backup** and recovery strategy
- **Automatic maintenance** with snapshots and TRIM

Your development workspace and personal files will be fully encrypted while maintaining the high-performance characteristics of your Samsung SSD 9100 PRO.