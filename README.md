# Development Workstation Storage Architecture

A comprehensive btrfs-based storage solution optimized for software development with automatic snapshots, performance optimization, and organized data management.

**Repository**: https://github.com/pcshrosbree/arch-partitions  
**Author**: pcshrosbree

## Table of Contents

- [Overview](#overview)
- [Hardware Specifications](#hardware-specifications)
- [Storage Architecture](#storage-architecture)
- [Performance Optimizations](#performance-optimizations)
- [Installation Guide](#installation-guide)
- [Post-Installation Setup](#post-installation-setup)
- [Desktop Environment Setup](#desktop-environment-setup)
- [Development Environment](#development-environment)
- [File System Organization](#file-system-organization)
- [Snapshot Management](#snapshot-management)
- [Git Integration](#git-integration)
- [Usage Patterns](#usage-patterns)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Script Documentation](#script-documentation)

## Overview

This storage architecture provides a three-tier system optimized for development workflows:

- **High-performance storage** for active development (4TB NVMe PCIe 5.0)
- **Fast storage** for home directories and development data (4TB NVMe PCIe 4.0)
- **Bulk storage** for archives, builds, and media (8TB SATA SSD)

All filesystems use btrfs with automatic snapshots, compression, and development-optimized subvolume layouts.

## Hardware Specifications

- **CPU**: AMD Ryzen 9950X
- **RAM**: 256GB G.SKILL Flare X5 DDR5-6000 (CL34-44-44-96 @ 1.35V)
- **Motherboard**: ASUS ROG Crosshair X870E Hero (AMD X870E AM5 ATX)
- **Graphics**: AMD Radeon RX 9070 XT (PCIe 5.0 x16)
- **Displays**: 3x Dell U4320Q UltraSharp 43" 4K UHD (11,520 x 2,160 total resolution)
- **Input**: Logitech MX Master 3S with Logi Bolt USB Receiver
- **Storage**: 
  - **Primary**: Samsung SSD 9100 PRO - 4TB NVMe (PCIe 5.0) - 14,800/13,400 MB/s, 2.2M/2.6M IOPS
  - **Secondary**: TEAMGROUP T-Force Z540 - 4TB NVMe (PCIe 4.0) - 12,400/11,800 MB/s, 1.4M/1.5M IOPS
  - **Bulk**: 8TB SATA SSD
- **Network**: Intel X520-DA2 10Gb NIC (PCIe 5.0 x8)

## Storage Architecture

### Physical Layout

```
┌─────────────────────┬─────────────────────┬─────────────────────┐
│   PRIMARY NVMe      │   SECONDARY NVMe    │    BULK SATA       │
│   (PCIe 5.0)        │   (PCIe 4.0)        │   (SATA SSD)        │
│ Samsung 9100 PRO    │ TEAMGROUP Z540      │   ~500 MB/s         │
│ 14,800/13,400 MB/s  │ 12,400/11,800 MB/s  │   8TB               │
│ 2.2M/2.6M IOPS      │ 1.4M/1.5M IOPS      │                     │
│   4TB               │   4TB               │                     │
└─────────────────────┴─────────────────────┴─────────────────────┘
```

### Logical Layout

```
/ (ROOT filesystem on Samsung 9100 PRO)
├── /boot/efi (EFI_SYSTEM - FAT32)
├── /tmp (@tmp subvolume, nodatacow)
├── /var/log (@var_log subvolume, nodatacow)
├── /var/cache (@var_cache subvolume, nodatacow)
├── /opt (@opt subvolume)
├── /usr/local (@usr_local subvolume)
├── /home (HOME filesystem on TEAMGROUP Z540)
│   ├── @home (user directories)
│   ├── @containers (Container storage, nodatacow)
│   ├── @vms (VM storage, nodatacow)
│   ├── @tmp_builds (build cache, nodatacow)
│   ├── @node_modules (Node.js cache, nodatacow)
│   ├── @cargo_cache (Rust cache)
│   ├── @go_cache (Go module cache)
│   └── @maven_cache (Maven/Gradle cache)
└── /mnt/bulk (BULK filesystem on SATA SSD)
    ├── @archives (Long-term storage)
    ├── @builds (Build artifacts)
    ├── @containers (Container images)
    └── @backup (Backup storage)
```

## Performance Optimizations

### System-Level Optimizations

| Component | Optimization | Benefit |
|-----------|--------------|---------|
| **Mount Options** | ssd_spread, commit=120 | Better wear leveling, reduced write frequency |
| **NVMe Power** | default_ps_max_latency_us=0 | Maximum performance mode |
| **CPU Governor** | performance | Consistent high performance |
| **Memory** | vm.dirty_ratio=20, vm.swappiness=1, huge pages | Optimized for DDR5-6000 and large datasets |
| **Development Tools** | Increased memory limits, parallel builds | Utilizes 256GB for faster compilation |
| **Graphics** | amdgpu performance mode, memory/core OC | Optimized for triple 4K displays |
| **Network** | 10Gb NIC optimizations | Enhanced network performance |
| **Btrfs** | Enhanced compression, metadata optimization | Better performance and space efficiency |

### Hardware-Specific Optimizations

#### CPU and Memory
```bash
# CPU governor set to 'performance' for consistent high performance
# Memory settings optimized for 256GB RAM and high-speed storage
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 1
```

#### NVMe Storage Optimizations
```bash
# Maximum performance NVMe settings
nvme_core.default_ps_max_latency_us=0  # Disable power saving
ssd_spread                             # Enhanced wear leveling
commit=120                             # Extended commit intervals
```

#### Memory and Development Optimizations
```bash
# DDR5-6000 specific optimizations
vm.dirty_ratio = 20                    # Higher ratio for large memory
vm.dirty_background_ratio = 10         # Increased background ratio
vm.vfs_cache_pressure = 50             # Optimize VFS cache for development
vm.min_free_kbytes = 1048576           # 1GB minimum free memory
vm.nr_hugepages = 1024                 # 2GB huge pages for performance

# Development tool memory limits optimized for 256GB
export NODE_OPTIONS="--max-old-space-size=16384"    # 16GB for Node.js
export JAVA_OPTS="-Xmx32g -Xms8g"                   # 32GB for JVM
export MAVEN_OPTS="-Xmx32g -Xms8g -XX:+UseG1GC"    # Optimized Maven
export GOMEMLIMIT="32GiB"                           # Go memory limit
```

#### Input Device Optimizations
```bash
# Logitech MX Master 3S optimization for triple 4K displays
# Automatic configuration when Logi Bolt receiver is connected

# Mouse acceleration optimized for large display area (11,520 x 2,160)
libinput Accel Speed 0.3                  # Balanced speed for precision and traversal
libinput Natural Scrolling Enabled 1      # Natural scrolling (development preference)
libinput Middle Emulation Enabled 0       # Disable accidental middle-click paste

# Display-aware cursor movement
xset m 2/1 4                              # Mouse acceleration: 2/1 multiplier, 4px threshold

# Development gesture configuration
# Thumb wheel: Workspace/window switching
# Gesture button: Context-specific actions
```

#### Automated Health Checks
- **NVMe health monitoring**: Hourly temperature and wear level checks
- **Memory performance monitoring**: DDR5-6000 speed and stability verification
- **GPU monitoring**: Temperature, VRAM usage, and performance tracking
- **Display optimization**: Automatic GPU performance settings on boot
- **Btrfs maintenance**: Weekly defragmentation and balancing
- **Snapshot cleanup**: Daily automated cleanup
- **Performance monitoring**: Real-time I/O, memory usage, and temperature tracking

#### Manual Optimization Commands
```bash
# Check display configuration and GPU status
display-optimizer.sh status

# Check memory performance
memory-optimizer.sh benchmark

# RAMdisk for ultra-fast builds
memory-optimizer.sh ramdisk 16G

# Use RAMdisk for builds (automatically configured)
export TMPDIR=/tmp/ramdisk
cd ~/Projects/large-project && make -j$(nproc)  # Uses RAMdisk
```

## Installation Guide

### Prerequisites

- AMD Ryzen 9950X system with specified storage devices
- AMD Radeon RX 9070 XT graphics card
- Root access for initial setup
- Arch Linux installation media

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

**Language**: Select your preferred language (e.g., "English")

**Mirrors**: Choose "Automatic" or select your region for faster downloads

**Locales**: Select your locale (e.g., "en_US.UTF-8")

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

**Disk encryption**: Select "No encryption" (we're using btrfs without encryption)

**Bootloader**: Select "Grub" (recommended for btrfs)

**Swap**: Select "No swap" (we have 256GB RAM)

**Hostname**: Enter your desired hostname (e.g., "dev-workstation")

**Root password**: Set a strong root password

**User account**: Create your user account and add user to groups: wheel, audio, video, optical, storage

**Profile**: Select "Desktop" → "None" (we'll configure desktop later)

**Audio**: Select "Pipewire" (modern audio system)

**Kernel**: Select "linux" (stable kernel)

**Additional packages**:
```
git vim neovim tmux zsh fish btop htop curl wget firefox
base-devel btrfs-progs snapper grub-btrfs
```

**Network configuration**: Select "NetworkManager" (easiest for desktop)

**Timezone**: Select your timezone

**NTP**: Select "Yes" (automatic time sync)

3. **Start installation**: Review all settings, confirm installation, and wait for completion

4. **Post-installation**: When prompted, choose "No" to chroot and "Yes" to reboot

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

## Post-Installation Setup

### Automated Setup with Scripts

After successfully installing Arch Linux, use the provided scripts in sequence:

#### 1. Snapshot Management Setup
```bash
# Download and run the snapshot setup script
curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/setup-snapshotting.sh
chmod +x setup-snapshotting.sh

# Run as root
sudo ./setup-snapshotting.sh
```

**What it does:**
- Configures snapper for root and home filesystems
- Creates automatic timeline snapshots (hourly/daily/weekly/monthly)
- Sets up development snapshot timer (every 30 minutes during work hours)
- Creates backup, monitoring, and restore utility scripts
- Enables automatic cleanup services

#### 2. System Performance Optimizations
```bash
# Download and run the system optimization script
curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/setup-system-optimizations.sh
chmod +x setup-system-optimizations.sh

# Run as root
sudo ./setup-system-optimizations.sh
```

**What it does:**
- Configures CPU performance governor and optimizations
- Applies DDR5-6000 memory optimizations (256GB tuning)
- Optimizes NVMe drives for maximum performance
- Enables NVMe health monitoring (hourly checks)
- Configures network optimizations for 10Gb NIC
- Sets up btrfs maintenance services
- Creates system monitoring utilities

#### 3. Development Environment Setup
```bash
# Download and run the development environment script
curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/setup-development-environment.sh
chmod +x setup-development-environment.sh

# Run as root
sudo ./setup-development-environment.sh
```

**What it does:**
- Installs comprehensive development packages
- Creates development cache optimization scripts
- Configures Git hooks for automatic snapshots
- Optimizes VS Code settings for btrfs
- Creates Python development setup utilities
- Configures development workspace structure
- Sets up Podman with Docker compatibility aliases

#### 4. Git Integration (Optional)
```bash
# Download and run the Git integration script
curl -O https://raw.githubusercontent.com/pcshrosbree/arch-partitions/main/enable-git-integration.sh
chmod +x enable-git-integration.sh

# Run as your user (not root)
./enable-git-integration.sh
```

**What it does:**
- Enables global Git template directory
- Applies hooks to existing repositories
- Creates `git-snapshot` utility commands
- Configures Git performance optimizations
- Tests the integration with a sample repository

#### 5. Verify the Setup
```bash
# Check btrfs filesystems
sudo btrfs filesystem show

# Check snapper configurations
sudo snapper list-configs

# Check snapshots
sudo snapper -c root list
sudo snapper -c home list

# Check system optimizations
system-monitor.sh all

# Check development cache setup (run as user)
setup-dev-caches.sh

# Test Git integration (run as user)
git-snapshot status
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
    follow_mouse = 1
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

# Key bindings
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun

# Switch workspaces
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
# ... (additional bindings)

# Autostart
exec-once = waybar
exec-once = dunst
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

## Development Environment

### Install Development Tools
```bash
# Install core development packages
sudo pacman -S podman podman-compose buildah skopeo
sudo pacman -S nodejs npm python python-pip rust go
sudo pacman -S code pyenv python-poetry dotnet-sdk aspnet-runtime
sudo pacman -S kitty alacritty  # Additional terminal options
sudo pacman -S jdk-openjdk zig  # Java for Clojure, Zig compiler

# Install Python development tools
# pyenv for Python version management
curl https://pyenv.run | bash

# poetry for Python dependency management (already installed via pacman)
# uv for ultra-fast Python package installer
pip install --user uv

# Install .NET development tools
# dotnet-sdk already installed via pacman
# Install additional .NET tools
dotnet tool install --global dotnet-ef
dotnet tool install --global dotnet-aspnet-codegenerator
dotnet tool install --global dotnet-dump
dotnet tool install --global dotnet-trace

# Install additional programming languages
install-additional-languages.sh all    # Haskell, Clojure, Zig

# Install modern terminal emulators
install-ghostty.sh install        # Install Ghostty terminal
install-warp.sh install           # Install Warp terminal

# Install AUR development tools
yay -S visual-studio-code-bin
yay -S jetbrains-toolbox           # Use toolbox to install IntelliJ IDEA Ultimate and Rider
yay -S nvm

# Enable and start Podman services
sudo systemctl enable podman-auto-update.timer
sudo usermod -aG wheel $USER

# Setup development environment with Podman aliases
setup-dev-caches.sh  # This now includes Docker→Podman aliases
```

### Configure Development Environment
```bash
# Setup development directories
mkdir -p ~/Projects/{personal,work,learning,experiments}
mkdir -p ~/.config/{git,zsh,vim}
mkdir -p ~/.local/bin

# Configure Git with performance optimizations
git config --global user.name "Peter Shrosbree"
git config --global user.email "49728166-pcshrosbree@users.noreply.github.com"
git config --global init.defaultBranch main
git config --global init.templatedir /usr/local/share/git-templates
git config --global --add include.path ~/.gitconfig-performance

# Clone the arch-partitions repository for reference
git clone https://github.com/pcshrosbree/arch-partitions.git ~/Projects/personal/arch-partitions

# Setup optimized development caches and Podman aliases
setup-dev-caches.sh

# Activate development environment
source ~/.podman-aliases  # Docker compatibility aliases
source ~/.build-env       # Memory-optimized build environment

# Setup shell (if using zsh)
sudo pacman -S zsh oh-my-zsh-git
chsh -s /bin/zsh
```

### Python Development Workflows
```bash
# Modern Python development with optimized tools
# All caches use high-speed NVMe storage for maximum performance

# pyenv for Python version management
pyenv install 3.12.0 3.11.7 3.10.13      # Install multiple Python versions
pyenv local 3.12.0                        # Set project-specific version

# poetry for dependency management (optimized cache)
poetry new my-python-project
cd my-python-project
poetry add fastapi uvicorn                # Fast package installation via cache
poetry install                            # Install dependencies with cache optimization

# uv for ultra-fast package operations
uv pip install requests                   # Lightning-fast package installation
uv pip sync requirements.txt              # Sync packages at high speed

# Combined workflow with containers
docker run --rm -it \
  -v ~/.pyenv:/root/.pyenv \
  -v ~/.cache/pypoetry:/root/.cache/pypoetry \
  -v ~/.cache/uv:/root/.cache/uv \
  -v $(pwd):/workspace -w /workspace \
  python:3.12
```

### Additional Programming Languages
```bash
# Comprehensive multi-language development environment
# All languages optimized with dedicated high-speed cache storage

# Haskell functional programming
install-additional-languages.sh haskell

# Haskell development workflow:
ghc --version                              # Glasgow Haskell Compiler
cabal update                               # Update package index
stack new my-haskell-project               # Create new Stack project
stack build                               # Build with cached dependencies

# Clojure functional programming
install-additional-languages.sh clojure

# Clojure development workflow:
clj -version                               # Clojure CLI
lein new app my-clojure-app               # Create new Leiningen project
lein repl                                 # Start REPL with cached dependencies

# Zig systems programming
install-additional-languages.sh zig

# Zig development workflow:
zig version                               # Zig compiler version
zig init-exe                             # Create new executable project
zig build                                 # Build with optimized cache

# Install all languages at once
install-additional-languages.sh all       # Haskell + Clojure + Zig
```

### Multi-Language Development Containers
```bash
# Container development with all language environments
# All containers include optimized caches for fast package operations

# Development containers with cache persistence:
dev-python     # Python with pyenv, poetry, uv
dev-dotnet     # .NET SDK with NuGet and tools
dev-node       # Node.js with npm optimization
dev-rust       # Rust with Cargo optimization
dev-golang     # Go with module cache
dev-haskell    # Haskell with GHC and Stack
dev-clojure    # Clojure with JVM and Leiningen
dev-zig        # Zig with compiler cache

# Multi-language container with all tools
podman run --rm -it \
  -v ~/.local/share/fonts:/root/.local/share/fonts \
  -v ~/.pyenv:/root/.pyenv \
  -v ~/.ghcup:/root/.ghcup \
  -v ~/.cache/zig:/root/.cache/zig \
  -v ~/.m2:/root/.m2 \
  -v $(pwd):/workspace -w /workspace \
  ubuntu:latest
```

## File System Organization

### Root Filesystem (/) - Samsung SSD 9100 PRO

**Purpose**: Operating system, development tools, and system operations  
**Performance**: Exceptional (14,800/13,400 MB/s, 2.6M write IOPS)  
**Compression**: zstd:1 (fastest)  
**Optimizations**: Enhanced wear leveling, maximum performance mode

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
- Frequently accessed system operations

### Home Filesystem (/home) - TEAMGROUP T-Force Z540

**Purpose**: User data, active development projects, and development services  
**Performance**: Excellent (12,400/11,800 MB/s, 1.5M write IOPS)  
**Compression**: zstd:3 (balanced)  
**Optimizations**: Development cache optimization, container storage

```
/home/
├── user/                   # User directories
│   ├── .config/            # Application configurations
│   ├── .local/             # User-specific applications
│   ├── Documents/          # Documentation and notes
│   ├── Projects/           # Active development projects
│   └── Scripts/            # Personal automation scripts
├── /var/lib/containers/    # Container storage (nodatacow)
├── /var/lib/libvirt/       # Virtual machines (nodatacow)
├── /var/cache/builds/      # Build cache (nodatacow)
├── /var/cache/node_modules/# Node.js dependencies (nodatacow)
├── /var/cache/cargo/       # Rust build cache
├── /var/cache/go/          # Go module cache
├── /var/cache/maven/       # Maven/Gradle cache
├── /var/cache/pyenv/       # Python version management cache
├── /var/cache/poetry/      # Python dependency management cache
├── /var/cache/uv/          # Ultra-fast Python package cache
├── /var/cache/dotnet/      # .NET SDK, packages, and build cache
├── /var/cache/haskell/     # Haskell GHC, Stack, and Cabal cache
├── /var/cache/clojure/     # Clojure dependencies and REPL cache
└── /var/cache/zig/         # Zig compiler and build cache
```

**Ideal for**:
- Active development projects
- IDE configurations and workspaces
- Development databases and services
- Build systems and caches
- Container and VM storage

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

### Repository Management

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

#### Container Storage
```bash
# Container root is at /var/lib/containers (nodatacow for performance)
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

#### Display-Specific Issues
```bash
# Check for display connectivity issues
xrandr --listmonitors
dmesg | grep -E "(amdgpu|drm|display)"

# Verify all three displays are detected
xrandr | grep " connected" | wc -l  # Should return 3

# Check GPU memory allocation for triple 4K
cat /sys/class/drm/card0/device/mem_info_vram_used
cat /sys/class/drm/card0/device/mem_info_vram_total

# Monitor GPU utilization during development work
radeontop  # Real-time GPU monitoring

# Check for display-related kernel messages
journalctl -k | grep -E "(amdgpu|drm|display)"

# Reset display configuration if needed
display-optimizer.sh layout horizontal

# Verify GPU is in high performance mode
cat /sys/class/drm/card0/device/power_dpm_force_performance_level  # Should be 'high'

# Check VRAM usage for triple 4K displays
radeontop -d - -l 1 | grep VRAM

# Monitor GPU temperature under load
watch -n 5 'sensors | grep -E "(amdgpu|radeon)" -A 5'

# Check display refresh rates and configuration
xrandr | grep -E "\*|connected"
```

#### NVMe-Specific Issues
```bash
# Check NVMe drive health
sudo nvme smart-log /dev/nvme0n1  # Samsung 9100 PRO
sudo nvme smart-log /dev/nvme1n1  # TEAMGROUP Z540

# Monitor drive temperatures under load
watch -n 5 'nvme smart-log /dev/nvme0n1 | grep temperature; nvme smart-log /dev/nvme1n1 | grep temperature'

# Check for power management issues
cat /sys/block/nvme0n1/queue/scheduler  # Should show available schedulers
cat /sys/class/nvme/nvme*/power/control  # Should be 'on' for max performance

# Check NVMe health and performance
nvme-health-monitor.sh

# Monitor real-time performance
watch -n 1 'iostat -x 1 1 | grep nvme'

# Check for thermal throttling
sensors | grep -E "(nvme|CPU|amdgpu)"

# Verify system optimizations are active
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # Should be 'performance'
sysctl vm.dirty_ratio vm.swappiness  # Should be 20 and 1

# Check btrfs compression efficiency
sudo btrfs filesystem show | grep -A 5 "uuid:"
sudo compsize /home /  # Shows compression ratios
```

#### Enhanced Performance Issues
```bash
# Check display and GPU performance
display-optimizer.sh status
display-optimizer.sh monitor

# Check mouse performance and configuration
mouse-optimizer.sh status
mouse-optimizer.sh monitor

# Check memory performance
memory-optimizer.sh benchmark
```

#### Development Cache Issues
```bash
# Verify cache optimizations are working
ls -la ~/.npm ~/.cargo ~/go ~/.m2  # Should be symlinks to /var/cache/*

# Reset cache optimizations if needed
setup-dev-caches.sh

# Check cache space usage
df -h /var/cache
du -sh /var/cache/{builds,node_modules,cargo,go,maven}

# Clean cache if needed
npm cache clean --force
cargo clean
go clean -cache
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

#### System Logs and Monitoring
```bash
# Display and GPU logs
journalctl -u display-optimizer.service
dmesg | grep -E "(amdgpu|drm|display)"

# NVMe health monitoring logs
journalctl -u nvme-health-monitor.timer
tail -f /var/log/nvme-health.log

# Memory optimization logs
journalctl -u memory-optimizer.service

# Snapshot monitoring logs
tail -f /var/log/snapshot-monitor.log

# Btrfs maintenance logs
journalctl -u btrfs-maintenance.timer

# System performance logs
journalctl -k | grep btrfs
journalctl -k | grep nvme
journalctl -k | grep amdgpu
dmesg | grep -E "(nvme|btrfs|amdgpu)"
```

#### Performance Benchmarking
```bash
# Display and GPU performance testing
# GPU memory bandwidth test
clpeak  # OpenCL performance test (install with: pacman -S clpeak)

# GPU compute performance
glmark2  # OpenGL benchmark

# Display performance test
xrandr --output DP-1 --mode 3840x2160 --rate 60
xrandr --output DP-2 --mode 3840x2160 --rate 60  
xrandr --output DP-3 --mode 3840x2160 --rate 60

# Memory performance validation
memory-optimizer.sh benchmark

# Storage performance test
fio --name=random-write --ioengine=libaio --rw=randwrite --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting --filename=/tmp/perf-test

# Development workload simulation
time git clone https://github.com/torvalds/linux.git /tmp/linux-test
cd /tmp/linux-test && time make defconfig && time make -j$(nproc) modules_prepare

# Triple monitor desktop performance
# Test window management and switching between displays
for i in {1..3}; do
    gnome-terminal &
    sleep 1
done

# Compression efficiency test
echo "test data" | btrfs-compress zstd:1
echo "test data" | btrfs-compress zstd:3
echo "test data" | btrfs-compress zstd:6
```

## Script Documentation

### Core Setup Scripts

#### setup-storage.sh

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

#### setup-snapshotting.sh

Configures comprehensive btrfs snapshot management with snapper.

```bash
# Run after OS installation
sudo ./setup-snapshotting.sh
```

**What it creates**:
- Snapper configurations for root and home filesystems
- Timeline snapshots (hourly/daily/weekly/monthly)
- Development snapshot timer (every 30 minutes during work hours)
- Utility scripts: `dev-backup.sh`, `snapshot-monitor.sh`, `snapshot-restore.sh`
- Automatic cleanup services
- GRUB integration for snapshot booting (if available)

#### setup-system-optimizations.sh

Configures hardware-specific performance optimizations.

```bash
# Run after OS installation and desktop configuration
sudo ./setup-system-optimizations.sh
```

**What it creates**:
- CPU performance optimizations (performance governor)
- DDR5-6000 memory optimizations (256GB tuning)
- NVMe performance optimizations
- NVMe health monitoring (hourly checks)
- Network optimizations for 10Gb NIC
- Btrfs maintenance services
- Utility scripts: `memory-optimizer.sh`, `nvme-optimizer.sh`, `system-monitor.sh`

#### setup-development-environment.sh

Installs and configures comprehensive development tools and environments.

```bash
# Run after system optimizations
sudo ./setup-development-environment.sh
```

**What it creates**:
- Development package installation
- Development cache optimization (`setup-dev-caches.sh`)
- Git integration hooks
- VS Code optimizations for btrfs
- Python development setup (`setup-python-dev.sh`)
- Development workspace setup (`setup-dev-workspace.sh`)
- Git snapshot utility (`git-snapshot`)

#### enable-git-integration.sh

Enables automatic snapshots for Git operations.

```bash
# Run as normal user (not root)
./enable-git-integration.sh
```

**What it does**:
- Enables global Git template directory
- Applies hooks to existing repositories
- Creates user `git-snapshot` utility
- Configures Git performance optimizations
- Tests the integration

### Utility Scripts Created

#### Snapshot Management
- **`dev-backup.sh`** - Create milestone and pre-deployment snapshots
- **`snapshot-monitor.sh`** - Monitor snapshot usage and health
- **`snapshot-restore.sh`** - Interactive snapshot restoration
- **`git-snapshot`** - Git-specific snapshot management

#### System Optimization
- **`memory-optimizer.sh`** - DDR5-6000 memory optimization and RAMdisk
- **`nvme-optimizer.sh`** - NVMe performance optimization and monitoring
- **`nvme-health-monitor.sh`** - Automated NVMe health checking
- **`system-monitor.sh`** - Comprehensive system monitoring

#### Development Tools
- **`setup-dev-caches.sh`** - Optimize development caches with Podman aliases
- **`setup-python-dev.sh`** - Python development environment setup
- **`setup-dev-workspace.sh`** - Create organized development workspace
- **`git-snapshot-hook.sh`** - Git hooks for automatic snapshots

## Summary

This storage architecture provides a robust, high-performance foundation for software development with automatic data protection, organized storage tiers, and development-optimized workflows. The three-tier approach ensures that frequently accessed data gets maximum performance while providing cost-effective bulk storage for archives and backups.

### Key Performance Features

- **Samsung SSD 9100 PRO**: 14,800/13,400 MB/s with 2.6M write IOPS for system operations
- **TEAMGROUP T-Force Z540**: 12,400/11,800 MB/s with 1.5M write IOPS for development work
- **Comprehensive optimization**: CPU, memory, NVMe, and filesystem tuning
- **Intelligent caching**: Development tools use optimized storage locations
- **Health monitoring**: Automated NVMe and system health tracking

### Performance Benefits

- **Exceptional storage performance**: Samsung 9100 PRO with 2.6M write IOPS for system operations
- **High-speed development storage**: TEAMGROUP Z540 with 1.5M write IOPS for active development
- **DDR5-6000 memory optimization**: Full utilization of 256GB high-speed memory for builds and caches
- **Triple 4K display productivity**: 11,520 x 2,160 total workspace optimized for development workflows
- **AMD RX 9070 XT optimization**: GPU performance tuning for demanding multi-monitor setups
- **Precision input control**: Logitech MX Master 3S optimized for large display area navigation
- **RAMdisk support**: Ultra-fast temporary operations using DDR5-6000 speeds
- **Intelligent caching**: Development tools use optimized storage locations with memory awareness
- **Automated health monitoring**: Prevents performance degradation of storage, memory, and graphics
- **Memory-aware build systems**: Development tools configured for large memory workloads
- **Multi-monitor workspace automation**: Automatic application positioning across displays
- **Input device automation**: Mouse optimization applied automatically when connected
- **Parallel processing optimization**: Full utilization of 24-core CPU with large memory buffers

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