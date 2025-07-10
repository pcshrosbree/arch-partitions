# Development Workstation Storage Architecture

A comprehensive btrfs-based storage solution optimized for software development with automatic snapshots, performance optimization, and organized data management.

**Repository**: https://github.com/pcshrosbree/arch-partitions  
**Author**: pcshrosbree

## Table of Contents

- [Overview](#overview)
- [Storage Architecture](#storage-architecture)
- [Quick Start](#quick-start)
- [File System Organization](#file-system-organization)
- [Script Documentation](#script-documentation)
- [Usage Patterns](#usage-patterns)
- [Snapshot Management](#snapshot-management)
- [Git Integration](#git-integration)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

This storage architecture provides a three-tier system optimized for development workflows:

- **High-performance storage** for active development (4TB NVMe PCIe 5.0)
- **Fast storage** for home directories and development data (4TB NVMe PCIe 4.0)
- **Bulk storage** for archives, builds, and media (8TB SATA SSD)

All filesystems use btrfs with automatic snapshots, compression, and development-optimized subvolume layouts.

## Hardware Specifications

- **CPU**: AMD Ryzen 9950X
- **RAM**: 256GB DDR5
- **Motherboard**: ASUS ROG Crosshair X870E Hero (AMD X870E AM5 ATX)
- **Graphics**: AMD Radeon RX 9070 XT (PCIe 5.0 x16)
- **Storage**: 
  - 14,000 MB/s 4TB NVMe SSD (PCIe 5.0 x4)
  - 7,450 MB/s 4TB NVMe SSD (PCIe 4.0 x4)
  - 8TB SATA SSD
- **Network**: Intel X520-DA2 10Gb NIC (PCIe 5.0 x8)

## Storage Architecture

### Physical Layout

```
┌─────────────────────┬─────────────────────┬─────────────────────┐
│   PRIMARY NVMe      │   SECONDARY NVMe    │    BULK SATA       │
│   (PCIe 5.0)        │   (PCIe 4.0)        │   (SATA SSD)        │
│   14,000 MB/s       │   7,450 MB/s        │   ~500 MB/s         │
│   4TB               │   4TB               │   8TB               │
└─────────────────────┴─────────────────────┴─────────────────────┘
```

### Logical Layout

```
/ (ROOT filesystem on Primary NVMe)
├── /boot/efi (EFI_SYSTEM - FAT32)
├── /tmp (@tmp subvolume, nodatacow)
├── /var/log (@var_log subvolume, nodatacow)
├── /var/cache (@var_cache subvolume, nodatacow)
├── /opt (@opt subvolume)
├── /usr/local (@usr_local subvolume)
├── /home (HOME filesystem on Secondary NVMe)
│   ├── @home (user directories)
│   ├── @docker (Docker storage, nodatacow)
│   └── @vms (VM storage, nodatacow)
└── /mnt/bulk (BULK filesystem on SATA SSD)
    ├── @archives (Long-term storage)
    ├── @builds (Build artifacts)
    ├── @containers (Container images)
    └── @backup (Backup storage)
```

### Compression Strategy

| Filesystem | Compression | Use Case |
|------------|-------------|----------|
| ROOT | zstd:1 | Fast access for OS and tools |
| HOME | zstd:3 | Balanced for development files |
| BULK | zstd:6 | Maximum compression for archives |

## Quick Start

### Prerequisites

- AMD Ryzen 9950X system with specified storage devices
- AMD Radeon RX 9070 XT graphics card
- Root access for initial setup
- Arch Linux installation media

### Installation Overview

1. **Setup Storage Architecture** (⚠️ **DESTROYS ALL DATA** ⚠️)
2. **Install Arch Linux** using archinstall
3. **Configure Desktop Environment** (GNOME or Hyprland)
4. **Setup Snapshots** for automatic backups
5. **Enable Git Integration** (optional)

## Post-Installation Setup

### Complete Storage and Snapshot Configuration

After successfully installing Arch Linux and configuring your desktop environment:

1. **Download and run the snapshot setup script**:
   ```bash
   # Download the script from GitHub
   curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/setup-snapshots.sh
   chmod +x setup-snapshots.sh
   
   # Run as root
   sudo ./setup-snapshots.sh
   ```

2. **Enable Git integration** (optional):
   ```bash
   # Download the script from GitHub
   curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/enable-git-integration.sh
   chmod +x enable-git-integration.sh
   
   # Run as your user (not root)
   ./enable-git-integration.sh
   ```

3. **Verify the setup**:
   ```bash
   # Check btrfs filesystems
   sudo btrfs filesystem show
   
   # Check snapper configurations
   sudo snapper list-configs
   
   # Check snapshots
   sudo snapper -c root list
   sudo snapper -c home list
   ```

### Development Environment Setup

#### Install Development Tools
```bash
# Install development packages
sudo pacman -S docker docker-compose podman
sudo pacman -S nodejs npm python python-pip rust go
sudo pacman -S code intellij-idea-community-edition

# Install AUR development tools
yay -S visual-studio-code-bin
yay -S jetbrains-toolbox
yay -S nvm

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

#### Configure Git
```bash
# Setup development directories
mkdir -p ~/Projects/{personal,work,learning,experiments}
mkdir -p ~/.config/{git,zsh,vim}
mkdir -p ~/.local/bin

# Configure Git with your information
git config --global user.name "pcshrosbree"
git config --global user.email "your.email@example.com"
git config --global init.defaultBranch main
git config --global init.templatedir /usr/local/share/git-templates

# Clone the arch-partitions repository for reference
git clone https://github.com/pcshrosbree/arch-partitions.git ~/Projects/personal/arch-partitions

# Setup shell (if using zsh)
sudo pacman -S zsh oh-my-zsh-git
chsh -s /bin/zsh
```

## Arch Linux Installation

### Step 1: Boot Arch Linux Installation Media

1. Download the latest Arch Linux ISO from https://archlinux.org/download/
2. Create bootable USB drive:
   ```bash
   dd if=archlinux.iso of=/dev/sdX bs=4M status=progress
   ```
3. Boot from USB drive
4. Verify UEFI boot mode:
   ```bash
   ls /sys/firmware/efi/efivars
   ```

### Step 2: Setup Storage Architecture

**⚠️ CRITICAL: This will destroy all data on your drives!**

1. **Identify your storage devices**:
   ```bash
   lsblk
   ```
   
2. **Download and modify the storage setup script**:
   ```bash
   # Download the script from GitHub
   curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/setup-storage.sh
   
   # Edit device paths to match your hardware
   nano setup-storage.sh
   
   # Modify these lines:
   PRIMARY_NVME="/dev/nvme0n1"      # Your fastest NVMe (PCIe 5.0)
   SECONDARY_NVME="/dev/nvme1n1"    # Your second NVMe (PCIe 4.0)
   BULK_SATA="/dev/sda"             # Your SATA SSD
   ```

3. **Run the storage setup**:
   ```bash
   chmod +x setup-storage.sh
   ./setup-storage.sh
   ```

4. **Verify the setup**:
   ```bash
   lsblk
   mount | grep /mnt/target
   ```

### Step 3: Install Arch Linux with archinstall

1. **Launch archinstall**:
   ```bash
   archinstall
   ```

2. **Complete the archinstall prompts**:

#### archinstall Configuration Guide

**Language**:
- Select your preferred language (e.g., "English")

**Mirrors**:
- Choose "Automatic" or select your region for faster downloads

**Locales**:
- Select your locale (e.g., "en_US.UTF-8")

**Disk configuration**:
- Choose "Manual partitioning"
- **DO NOT** let archinstall format disks
- Select your **primary NVMe device** (e.g., `/dev/nvme0n1`)
- Choose "Use existing partition layout"
- Map partitions:
  - `/dev/nvme0n1p1` → `/boot/efi` (FAT32, existing)
  - `/dev/nvme0n1p2` → `/` (btrfs, existing)
  - `/dev/nvme1n1p1` → `/home` (btrfs, existing)
  - `/dev/sda1` → `/mnt/bulk` (btrfs, existing)

**Disk encryption**:
- Select "No encryption" (we're using btrfs without encryption)

**Bootloader**:
- Select "Grub" (recommended for btrfs)

**Swap**:
- Select "No swap" (we have 256GB RAM)

**Hostname**:
- Enter your desired hostname (e.g., "dev-workstation")

**Root password**:
- Set a strong root password

**User account**:
- Create your user account
- Add user to groups: wheel, audio, video, optical, storage

**Profile**:
- Select "Desktop" → "None" (we'll configure desktop later)

**Audio**:
- Select "Pipewire" (modern audio system)

**Kernel**:
- Select "linux" (stable kernel)

**Additional packages**:
- Add essential packages:
  ```
  git vim neovim tmux zsh fish btop htop curl wget firefox
  base-devel btrfs-progs snapper grub-btrfs
  ```

**Network configuration**:
- Select "NetworkManager" (easiest for desktop)

**Timezone**:
- Select your timezone

**NTP**:
- Select "Yes" (automatic time sync)

3. **Start installation**:
   - Review all settings
   - Confirm installation
   - Wait for installation to complete

4. **Post-installation**:
   - When prompted, choose "No" to chroot
   - Choose "Yes" to reboot

### Step 4: First Boot Configuration

1. **Boot into your new system**
2. **Login as your user**
3. **Update system**:
   ```bash
   sudo pacman -Syu
   ```

4. **Install AMD graphics drivers**:
   ```bash
   # Install Mesa drivers for AMD RX 9070 XT
   sudo pacman -S mesa vulkan-radeon libva-mesa-driver mesa-vdpau
   
   # Install additional AMD tools
   sudo pacman -S radeontop
   ```

5. **Install AUR helper** (yay):
   ```bash
   cd /tmp
   git clone https://aur.archlinux.org/yay.git
   cd yay
   makepkg -si
   ```

## Desktop Environment Setup

### Option 1: GNOME Desktop

#### Install GNOME
```bash
# Install GNOME desktop
sudo pacman -S gnome gnome-extra

# Install additional applications
sudo pacman -S firefox thunderbird libreoffice-fresh

# Enable GDM (login manager)
sudo systemctl enable gdm

# Enable NetworkManager
sudo systemctl enable NetworkManager

# Reboot to start GNOME
sudo reboot
```

#### Configure GNOME
```bash
# Install GNOME extensions
sudo pacman -S gnome-shell-extensions

# Install additional extensions via AUR
yay -S gnome-shell-extension-dash-to-dock
yay -S gnome-shell-extension-gsconnect

# Configure GNOME settings
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
```

### Option 2: Hyprland (Wayland Compositor)

#### Install Hyprland
```bash
# Install Hyprland and dependencies
sudo pacman -S hyprland xdg-desktop-portal-hyprland

# Install additional components
sudo pacman -S waybar wofi kitty thunar

# Install notification daemon
sudo pacman -S dunst

# Install screen capture tools
sudo pacman -S grim slurp

# Install display manager
sudo pacman -S sddm
sudo systemctl enable sddm
```

#### Configure Hyprland
```bash
# Create config directory
mkdir -p ~/.config/hypr

# Basic Hyprland configuration
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Hyprland configuration for AMD RX 9070 XT

# Monitor configuration
monitor=,preferred,auto,1

# Environment variables
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct
env = WLR_NO_HARDWARE_CURSORS,1

# Input configuration
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1
    touchpad {
        natural_scroll = no
    }
    sensitivity = 0
}

# General configuration
general {
    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
    allow_tearing = false
}

# Decoration
decoration {
    rounding = 10
    
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layout
dwindle {
    pseudotile = yes
    preserve_split = yes
}

# Key bindings
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,

# Move focus with mainMod + arrow keys
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

# Switch workspaces
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9
bind = SUPER, 0, workspace, 10

# Move windows to workspaces
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9
bind = SUPER SHIFT, 0, movetoworkspace, 10

# Mouse bindings
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow

# Autostart
exec-once = waybar
exec-once = dunst
EOF

# Configure Waybar
mkdir -p ~/.config/waybar
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["network", "memory", "cpu", "temperature", "battery", "tray"],
    
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}: {icon}",
        "format-icons": {
            "urgent": "",
            "focused": "",
            "default": ""
        }
    },
    
    "clock": {
        "format": "{:%Y-%m-%d %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "format-alt": "{:%Y-%m-%d}"
    },
    
    "cpu": {
        "format": "{usage}% ",
        "tooltip": false
    },
    
    "memory": {
        "format": "{}% "
    },
    
    "temperature": {
        "thermal-zone": 2,
        "hwmon-path": "/sys/class/hwmon/hwmon2/temp1_input",
        "critical-threshold": 80,
        "format": "{temperatureC}°C {icon}",
        "format-icons": ["", "", ""]
    },
    
    "network": {
        "format-wifi": "{essid} ({signalStrength}%) ",
        "format-ethernet": "{ipaddr}/{cidr} ",
        "tooltip-format": "{ifname} via {gwaddr} ",
        "format-linked": "{ifname} (No IP) ",
        "format-disconnected": "Disconnected ⚠",
        "format-alt": "{ifname}: {ipaddr}/{cidr}"
    },
    
    "tray": {
        "spacing": 10
    }
}
EOF

# Reboot to start Hyprland
sudo reboot
```

### Graphics Performance Optimization

#### AMD RX 9070 XT Optimization
```bash
# Install AMD performance tools
sudo pacman -S corectrl

# Enable GPU overclocking (if needed)
# Add to kernel parameters in /etc/default/grub:
sudo nano /etc/default/grub
# Add: amdgpu.ppfeaturemask=0xffffffff

# Rebuild GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Install Mesa development packages
sudo pacman -S mesa-demos vulkan-tools

# Test graphics performance
vkcube
glxgears
```

#### Gaming Performance (Optional)
```bash
# Install gaming tools
sudo pacman -S steam lutris wine

# Install additional graphics libraries
sudo pacman -S lib32-mesa lib32-vulkan-radeon

# Enable multilib repository in /etc/pacman.conf
sudo nano /etc/pacman.conf
# Uncomment [multilib] section

sudo pacman -Syu
```

## File System Organization

### Root Filesystem (/) - Primary NVMe

**Purpose**: Operating system, development tools, and active projects
**Performance**: Highest (14,000 MB/s)
**Compression**: zstd:1 (fastest)

```
/
├── /opt/                   # Third-party software
├── /usr/local/             # Custom installations
├── /tmp/                   # Temporary files (nodatacow)
├── /var/log/               # System logs (nodatacow)
└── /var/cache/             # Package cache (nodatacow)
```

**Ideal for**:
- Operating system files
- Development tools (IDEs, compilers, debuggers)
- Package managers and system utilities
- Small, frequently accessed configuration files

### Home Filesystem (/home) - Secondary NVMe

**Purpose**: User data, active development projects, and development services
**Performance**: High (7,450 MB/s)
**Compression**: zstd:3 (balanced)

```
/home/
├── user/                   # User directories
│   ├── .config/            # Application configurations
│   ├── .local/             # User-specific applications
│   ├── Documents/          # Documentation and notes
│   ├── Projects/           # Active development projects
│   └── Scripts/            # Personal automation scripts
├── /var/lib/docker/        # Docker containers/images (nodatacow)
└── /var/lib/libvirt/       # Virtual machines (nodatacow)
```

**Ideal for**:
- Active development projects
- IDE configurations and workspaces
- Development databases and services
- Personal scripts and automation
- Documentation and notes

### Bulk Storage (/mnt/bulk) - SATA SSD

**Purpose**: Long-term storage, archives, and large assets
**Performance**: Standard (500 MB/s)
**Compression**: zstd:6 (maximum)

```
/mnt/bulk/
├── archives/               # Long-term project archives
├── builds/                 # Build artifacts and releases
├── containers/             # Container registry cache
├── backup/                 # System and data backups
├── media/                  # Large media files
└── datasets/               # Development datasets
```

**Ideal for**:
- Completed project archives
- Build artifacts and release packages
- Container images and registries
- Media files and assets
- Development datasets
- Backup storage

## Script Documentation

### setup-storage.sh

Creates the complete storage layout with partitions, filesystems, and subvolumes.

**⚠️ WARNING: This script destroys all data on specified drives!**

```bash
# Configuration (modify these paths!)
PRIMARY_NVME="/dev/nvme0n1"      # Your primary NVMe device
SECONDARY_NVME="/dev/nvme1n1"    # Your secondary NVMe device
BULK_SATA="/dev/sda"             # Your SATA SSD device

# Run with root privileges
sudo ./setup-storage.sh
```

**What it does**:
- Creates GPT partition tables
- Formats filesystems with labels
- Creates btrfs subvolumes
- Generates optimized `/etc/fstab`
- Mounts everything at `/mnt/target`

### setup-snapshots.sh

Configures automatic snapshots and development tools.

```bash
# Run after OS installation and first boot
sudo ./setup-snapshots.sh
```

**What it creates**:
- Snapper configurations for root and home
- Timeline snapshots (hourly/daily/weekly)
- Development snapshot timer (every 30 minutes during work hours)
- Utility scripts: `dev-backup.sh`, `snapshot-monitor.sh`, `snapshot-restore.sh`
- Git integration hooks
- Automatic cleanup services

### enable-git-integration.sh

Enables automatic snapshots for Git operations.

```bash
# Run as normal user (not root)
./enable-git-integration.sh
```

**What it does**:
- Enables global Git template directory
- Applies hooks to existing repositories
- Creates `git-snapshot` helper command
- Tests the integration

## Usage Patterns

### Development Workflow

#### Active Development
```bash
# Work on projects in /home/user/Projects/
cd ~/Projects/my-project

# Automatic snapshots happen:
# - Every 30 minutes during work hours
# - Before each Git commit
# - Before rebases and branch switches
```

#### Project Organization
```bash
# Active projects
~/Projects/
├── client-project/         # Current client work
├── personal-project/       # Personal development
├── experiments/            # Proof of concepts
└── learning/              # Educational projects

# Configuration
~/.config/
├── vscode/                # VS Code settings
├── git/                   # Git configuration
└── zsh/                   # Shell configuration
```

#### Long-term Storage
```bash
# Archive completed projects
mv ~/Projects/completed-project /mnt/bulk/archives/2024/

# Store build artifacts
cp -r build/release/ /mnt/bulk/builds/my-project-v1.0/

# Container image cache
docker save my-image:latest | gzip > /mnt/bulk/containers/my-image-latest.tar.gz
```

### Configuration Management

#### System Configuration
```bash
# Store in /opt for system-wide tools
sudo cp my-tool /opt/my-tool/

# Store in /usr/local for custom builds
sudo make install PREFIX=/usr/local
```

#### User Configuration
```bash
# Personal configurations
~/.config/              # Application configs
~/.local/bin/          # Personal scripts
~/.local/share/        # Application data

# Development environment
~/.zshrc               # Shell configuration
~/.gitconfig           # Git settings
~/.vimrc               # Editor settings
```

### Container and VM Management

#### Docker Storage
```bash
# Docker root is at /var/lib/docker (nodatacow for performance)
# Store images in bulk storage for long-term
docker save ubuntu:latest | gzip > /mnt/bulk/containers/ubuntu-latest.tar.gz

# Load when needed
gunzip -c /mnt/bulk/containers/ubuntu-latest.tar.gz | docker load
```

#### Virtual Machines
```bash
# VM storage is at /var/lib/libvirt (nodatacow for performance)
# Archive unused VMs to bulk storage
sudo mv /var/lib/libvirt/images/old-vm.qcow2 /mnt/bulk/archives/vms/
```

### Media and Assets

#### Large Files
```bash
# Store media files in bulk storage
/mnt/bulk/media/
├── images/             # Design assets
├── videos/             # Video content
├── audio/              # Audio files
└── datasets/           # Development datasets
```

#### Backup Strategy
```bash
# System backups
/mnt/bulk/backup/
├── system/             # System configuration backups
├── databases/          # Database dumps
└── projects/           # Project backups
```

## Snapshot Management

### Automatic Snapshots

#### Timeline Snapshots
- **Hourly**: 48 snapshots (2 days)
- **Daily**: 14 snapshots (2 weeks)
- **Weekly**: 8 snapshots (2 months)
- **Monthly**: 6 snapshots (6 months)

#### Development Snapshots
- **Work hours**: Every 30 minutes (8 AM - 8 PM, Mon-Fri)
- **Git operations**: Before commits, rebases, branch switches

### Manual Snapshot Operations

#### Create Milestone Snapshots
```bash
# Before major changes
dev-backup.sh milestone "Before refactoring authentication"

# Before deployments
dev-backup.sh predeploy myapp v2.1.0
```

#### Monitor Snapshot Usage
```bash
# Check snapshot status
snapshot-monitor.sh status

# View recent snapshots
snapshot-monitor.sh timeline

# Summary information
snapshot-monitor.sh summary
```

#### Restore Operations
```bash
# Interactive restore
snapshot-restore.sh restore home

# Quick file restore
snapshot-restore.sh quick-restore home 42 /home/user/important-file.txt

# List available snapshots
snapshot-restore.sh list home
```

## Git Integration

### Automatic Snapshots

Git operations automatically create snapshots:

```bash
git commit -m "Add feature"     # Creates pre-commit snapshot
git rebase main                 # Creates pre-rebase snapshot
git checkout feature-branch    # Creates branch-switch snapshot
```

### Manual Git Snapshots

```bash
# Create manual snapshot
git-snapshot create "before-major-refactor"

# List Git-related snapshots
git-snapshot list

# Show snapshot differences
git-snapshot diff 42

# Restore specific files
git-snapshot restore 42 src/main.py config.json
```

#### Repository Management

#### Enable for New Repository
```bash
# Automatic with global template (after running enable-git-integration.sh)
git init my-project
cd my-project
# Hooks are automatically installed
```

#### Enable for Existing Repository
```bash
# Copy hooks manually
cp /usr/local/share/git-templates/hooks/* .git/hooks/

# Or use the integration script
curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/enable-git-integration.sh
chmod +x enable-git-integration.sh
./enable-git-integration.sh
```

#### Disable for Repository
```bash
# Remove hooks
rm .git/hooks/pre-commit .git/hooks/pre-rebase .git/hooks/post-checkout
```

## Maintenance

### Regular Maintenance Tasks

#### Daily (Automated)
```bash
# Automatic cleanup (via systemd timer)
# - Timeline cleanup
# - Number cleanup
# - Monitoring checks
```

#### Weekly (Manual)
```bash
# Check filesystem usage
df -h

# Check snapshot usage
snapshot-monitor.sh status

# Clean old snapshots if needed
dev-backup.sh clean 14  # Clean snapshots older than 14 days
```

#### Monthly (Manual)
```bash
# Check filesystem integrity
sudo btrfs scrub start /
sudo btrfs scrub start /home
sudo btrfs scrub start /mnt/bulk

# Check scrub status
sudo btrfs scrub status /
```

### Performance Optimization

#### Defragmentation
```bash
# Defragment if needed (rare with SSDs)
sudo btrfs filesystem defragment -r /home/user/Projects/
```

#### Balance Operations
```bash
# Balance filesystems if allocation is uneven
sudo btrfs filesystem balance /
```

### Backup Strategy

#### System Backup
```bash
# Create system backup
sudo btrfs send /path/to/snapshot | gzip > /mnt/bulk/backup/system-backup.btrfs.gz

# Restore system backup
gunzip -c /mnt/bulk/backup/system-backup.btrfs.gz | sudo btrfs receive /mnt/restore/
```

#### Configuration Backup
```bash
# Backup important configurations
tar -czf /mnt/bulk/backup/configs-$(date +%Y%m%d).tar.gz \
  ~/.config ~/.local/bin ~/.zshrc ~/.gitconfig
```

## Troubleshooting

### Common Issues

#### Snapshot Space Issues
```bash
# Check snapshot usage
snapper -c home list
snapper -c root list

# Clean old snapshots
snapper -c home cleanup number
snapper -c root cleanup number

# Manual cleanup
snapper -c home delete 10-20  # Delete snapshots 10 through 20
```

#### Performance Issues
```bash
# Check filesystem usage
df -h

# Check for fragmentation
sudo btrfs filesystem show
sudo btrfs filesystem usage /

# Monitor I/O
iotop -a
```

#### Git Integration Issues
```bash
# Check if hooks are installed
ls -la .git/hooks/

# Test hook execution
.git/hooks/pre-commit

# Check snapper configuration
snapper list-configs
```

### Recovery Procedures

#### Boot from Snapshot
```bash
# If grub-btrfs is installed, snapshots appear in GRUB menu
# Select "Snapshots" -> choose snapshot -> boot

# Manual recovery
mount -o subvol=@snapshots/42/snapshot /dev/nvme0n1p2 /mnt
# Copy files as needed
```

#### Restore Entire System
```bash
# Boot from live system
# Mount snapshot
mount -o subvol=@snapshots/42/snapshot /dev/nvme0n1p2 /mnt/source

# Mount current system
mount -o subvol=@ /dev/nvme0n1p2 /mnt/target

# Restore files
cp -a /mnt/source/* /mnt/target/
```

### Log Files

#### Snapshot Logs
```bash
# Monitoring logs
tail -f /var/log/snapshot-monitor.log

# Snapper logs
journalctl -u snapper-timeline.timer
journalctl -u snapper-cleanup.timer
```

#### System Logs
```bash
# Filesystem logs
journalctl -k | grep btrfs

# Mount logs
journalctl -u '*.mount'
```

---

## Summary

This storage architecture provides a robust, high-performance foundation for software development with automatic data protection, organized storage tiers, and development-optimized workflows. The three-tier approach ensures that frequently accessed data gets maximum performance while providing cost-effective bulk storage for archives and backups.

The automatic snapshot system provides safety nets for development work, while the Git integration seamlessly captures development milestones. The organized subvolume structure makes it easy to manage different types of data and optimize performance for specific use cases.

## Repository Information

- **GitHub Repository**: https://github.com/pcshrosbree/arch-partitions
- **Author**: pcshrosbree
- **License**: [Add your preferred license]

## Contributing

If you find issues or have improvements, please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

For support or questions:
- Open an issue on GitHub
- Refer to the troubleshooting section above
- Consult the btrfs and snapper documentation