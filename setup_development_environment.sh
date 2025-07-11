#!/bin/bash

# Development Environment Setup Script
# Configures comprehensive development tools, languages, and optimizations
# Run this script after OS installation and desktop configuration

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

# Install development packages
install_development_packages() {
    log "Installing development packages..."
    
    if command -v pacman &> /dev/null; then
        # Core development tools
        pacman -Sy --noconfirm \
            base-devel git vim neovim tmux zsh fish btop htop curl wget \
            podman podman-compose buildah skopeo \
            nodejs npm python python-pip rust go \
            code pyenv python-poetry dotnet-sdk aspnet-runtime \
            kitty alacritty jdk-openjdk zig \
            docker-compose
        
        # Additional development tools
        pacman -S --noconfirm \
            gcc clang cmake make ninja \
            postgresql redis mariadb \
            nginx apache \
            graphviz imagemagick \
            firefox thunderbird libreoffice-fresh
            
    elif command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y \
            build-essential git vim neovim tmux zsh fish btop htop curl wget \
            podman podman-compose buildah skopeo \
            nodejs npm python3 python3-pip rustc cargo golang-go \
            kitty alacritty openjdk-17-jdk \
            docker-compose
            
    elif command -v dnf &> /dev/null; then
        dnf groupinstall -y "Development Tools"
        dnf install -y \
            git vim neovim tmux zsh fish btop htop curl wget \
            podman podman-compose buildah skopeo \
            nodejs npm python3 python3-pip rust cargo golang \
            kitty alacritty java-17-openjdk-devel \
            docker-compose
    else
        error "Could not determine package manager"
    fi
    
    # Enable Podman services
    systemctl enable podman-auto-update.timer
}

# Create development cache setup script
create_dev_cache_setup() {
    log "Creating development cache optimization script..."
    
    cat > /usr/local/bin/setup-dev-caches.sh << 'EOF'
#!/bin/bash

# Development Cache Setup Script with DDR5-6000 Memory Optimization and Podman aliases
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

# Setup Podman aliases for Docker compatibility
setup_podman_aliases() {
    echo "Setting up Podman aliases for Docker compatibility..."
    
    # Create alias configuration
    cat > "$USER_HOME/.podman-aliases" << 'ALIASES'
# Podman aliases for Docker compatibility
# Source this file: source ~/.podman-aliases

# Core container commands
alias docker='podman'
alias docker-compose='podman-compose'

# Container management
alias docker-build='podman build'
alias docker-run='podman run'
alias docker-exec='podman exec'
alias docker-logs='podman logs'
alias docker-ps='podman ps'
alias docker-stop='podman stop'
alias docker-start='podman start'
alias docker-restart='podman restart'
alias docker-rm='podman rm'
alias docker-rmi='podman rmi'

# Image management
alias docker-pull='podman pull'
alias docker-push='podman push'
alias docker-images='podman images'
alias docker-tag='podman tag'
alias docker-save='podman save'
alias docker-load='podman load'
alias docker-import='podman import'
alias docker-export='podman export'

# Network management
alias docker-network='podman network'

# Volume management  
alias docker-volume='podman volume'

# System commands
alias docker-info='podman info'
alias docker-version='podman version'
alias docker-system='podman system'

# Development shortcuts
alias dps='podman ps'
alias dimages='podman images'
alias dlog='podman logs'
alias dexec='podman exec -it'
alias dbuild='podman build'
alias drun='podman run --rm -it'
alias dstop='podman stop $(podman ps -q)'
alias dclean='podman system prune -f'
alias dcleanall='podman system prune -af'

# Docker Compose equivalents
alias dc='podman-compose'
alias dcup='podman-compose up'
alias dcdown='podman-compose down'
alias dcbuild='podman-compose build'
alias dclogs='podman-compose logs'
alias dcps='podman-compose ps'

# Development environment helpers
alias dev-container='podman run --rm -it -v $(pwd):/workspace -w /workspace'
alias dev-node='podman run --rm -it -v $(pwd):/workspace -w /workspace node:latest'
alias dev-python='podman run --rm -it -v $(pwd):/workspace -w /workspace python:latest'
alias dev-golang='podman run --rm -it -v $(pwd):/workspace -w /workspace golang:latest'
alias dev-rust='podman run --rm -it -v $(pwd):/workspace -w /workspace rust:latest'

echo "✓ Podman aliases loaded (Docker compatibility enabled)"
ALIASES

    # Add to shell configurations
    for shell_config in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"; do
        if [[ -f "$shell_config" ]] && ! grep -q ".podman-aliases" "$shell_config"; then
            echo "" >> "$shell_config"
            echo "# Podman aliases for Docker compatibility" >> "$shell_config"
            echo "source ~/.podman-aliases" >> "$shell_config"
        fi
    done
    
    echo "✓ Podman aliases configured for Docker compatibility"
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

# Python development optimizations
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &> /dev/null; then
    eval "$(pyenv init -)"
fi

# Poetry configuration for development
export POETRY_CACHE_DIR="/var/cache/poetry/$(whoami)"
export POETRY_VENV_IN_PROJECT=true

# uv configuration for ultra-fast Python packages
export UV_CACHE_DIR="/var/cache/uv/$(whoami)"

# .NET development optimizations
export DOTNET_ROOT="/var/cache/dotnet/$(whoami)/dotnet"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export NUGET_PACKAGES="/var/cache/dotnet/$(whoami)/packages"
export DOTNET_NUGET_SIGNATURE_VERIFICATION=false
export DOTNET_CLI_HOME="/var/cache/dotnet/$(whoami)/cli"

# .NET performance optimizations for large memory systems
export DOTNET_GCHeapCount=4
export DOTNET_GCConcurrent=1
export DOTNET_GCServer=1

# Haskell development optimizations
export STACK_ROOT="/var/cache/haskell/$(whoami)/stack"
export CABAL_DIR="/var/cache/haskell/$(whoami)/cabal"
export GHCUP_INSTALL_BASE_PREFIX="/var/cache/haskell/$(whoami)"

# Clojure development optimizations
export LEIN_HOME="/var/cache/clojure/$(whoami)/lein"
export CLJ_CONFIG="/var/cache/clojure/$(whoami)/clojure"

# Zig development optimizations
export ZIG_GLOBAL_CACHE_DIR="/var/cache/zig/$(whoami)"
export ZIG_LOCAL_CACHE_DIR="/var/cache/zig/$(whoami)/local"

# Container development with Podman
export CONTAINER_RUNTIME="podman"
export BUILDAH_FORMAT="docker"

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
echo "  - Python tools: pyenv, poetry, uv (optimized caches)"
echo "  - .NET tools: dotnet, nuget (optimized caches)"
echo "  - Haskell tools: ghc, stack, cabal (optimized caches)"
echo "  - Clojure tools: lein, clj (optimized caches)"
echo "  - Zig compiler: zig (optimized cache)"
echo "  - Container runtime: ${CONTAINER_RUNTIME}"
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

# Python development caches
setup_cache_links "pyenv" "$USER_HOME/.pyenv/cache"
setup_cache_links "poetry" "$USER_HOME/.cache/pypoetry"  
setup_cache_links "uv" "$USER_HOME/.cache/uv"

# .NET development caches
setup_cache_links "dotnet" "$USER_HOME/.dotnet"
setup_cache_links "dotnet" "$USER_HOME/.nuget/packages"

# Haskell development caches
setup_cache_links "haskell" "$USER_HOME/.stack"
setup_cache_links "haskell" "$USER_HOME/.cabal"
setup_cache_links "haskell" "$USER_HOME/.ghcup"

# Clojure development caches
setup_cache_links "clojure" "$USER_HOME/.m2/repository"
setup_cache_links "clojure" "$USER_HOME/.lein"
setup_cache_links "clojure" "$USER_HOME/.clojure"

# Zig development caches
setup_cache_links "zig" "$USER_HOME/.cache/zig"
setup_cache_links "zig" "$USER_HOME/zig-cache"

# Setup Podman aliases
setup_podman_aliases

# Setup memory-optimized build environment
setup_memory_build_env

echo ""
echo "Development cache setup complete!"
echo "Caches are now using optimized storage locations."
echo "Podman aliases configured for Docker compatibility."
echo "Memory-optimized build environment configured."
echo "Restart your shell or run 'source ~/.podman-aliases && source ~/.build-env' to activate optimizations."
EOF

    chmod +x /usr/local/bin/setup-dev-caches.sh
}

# Create Git integration hooks
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
}

# Create Git snapshot utility
create_git_snapshot_utility() {
    log "Creating Git snapshot utility..."
    
    cat > /usr/local/bin/git-snapshot << 'EOF'
#!/bin/bash

# Git Snapshot Utility
# Manual snapshot management for Git repositories

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

# Create manual Git snapshot
create_snapshot() {
    local description="$1"
    local repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "unknown")
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local snapshot_msg="git-manual-${repo_name}-${branch}-${description}-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating Git snapshot: $description"
    
    # Create snapshot for home filesystem
    snapper -c home create --description "$snapshot_msg" --userdata "git=true,repo=$repo_name,branch=$branch,manual=true"
    
    log "Git snapshot created"
}

# List Git-related snapshots
list_git_snapshots() {
    echo "=== Git-related Snapshots ==="
    snapper -c home list | grep -E "(git-|Description)" || echo "No Git snapshots found"
}

# Show differences for a snapshot
show_snapshot_diff() {
    local snapshot_id="$1"
    
    echo "=== Git Snapshot Differences (ID: $snapshot_id) ==="
    snapper -c home status "$snapshot_id"..0
}

# Restore files from Git snapshot
restore_from_snapshot() {
    local snapshot_id="$1"
    shift
    local files=("$@")
    
    log "Restoring files from Git snapshot $snapshot_id..."
    
    # Create pre-restore snapshot
    snapper -c home create --description "pre-git-restore-$(date +%Y%m%d-%H%M%S)" --userdata "prerestore=true"
    
    for file in "${files[@]}"; do
        if snapper -c home undochange "$snapshot_id"..0 "$file"; then
            log "✓ Restored: $file"
        else
            warn "✗ Failed to restore: $file"
        fi
    done
}

# Main function
main() {
    case "${1:-}" in
        "create")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 create \"description\""
                exit 1
            fi
            create_snapshot "$2"
            ;;
        "list")
            list_git_snapshots
            ;;
        "diff")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 diff snapshot_id"
                exit 1
            fi
            show_snapshot_diff "$2"
            ;;
        "restore")
            if [[ -z "${2:-}" || -z "${3:-}" ]]; then
                echo "Usage: $0 restore snapshot_id file1 [file2 ...]"
                exit 1
            fi
            snapshot_id="$2"
            shift 2
            restore_from_snapshot "$snapshot_id" "$@"
            ;;
        *)
            echo "Git Snapshot Utility"
            echo "Usage: $0 {create|list|diff|restore}"
            echo ""
            echo "Commands:"
            echo "  create \"description\"           - Create manual Git snapshot"
            echo "  list                            - List Git-related snapshots"
            echo "  diff snapshot_id                - Show snapshot differences"
            echo "  restore snapshot_id file1 [file2 ...] - Restore files from snapshot"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x /usr/local/bin/git-snapshot
    log "Git snapshot utility created at /usr/local/bin/git-snapshot"
}

# Create VS Code development optimizations
create_vscode_optimizations() {
    log "Creating VS Code development optimizations..."
    
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
  },
  "terminal.integrated.defaultProfile.linux": "zsh",
  "terminal.integrated.fontFamily": "MonoLisa Nerd Font, JetBrainsMono Nerd Font",
  "editor.fontFamily": "MonoLisa, JetBrains Mono",
  "editor.fontSize": 14,
  "editor.fontLigatures": true,
  "workbench.colorTheme": "Dark+ (default dark)",
  "git.enableSmartCommit": true,
  "git.confirmSync": false,
  "extensions.autoUpdate": true
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

    log "VS Code and Git optimizations created"
}

# Create Python development setup
create_python_setup() {
    log "Creating Python development setup..."
    
    cat > /usr/local/bin/setup-python-dev.sh << 'EOF'
#!/bin/bash

# Python Development Environment Setup
# Installs and configures Python development tools

set -euo pipefail

log() {
    echo -e "\033[0;32m[$(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"
}

# Install pyenv if not present
install_pyenv() {
    if ! command -v pyenv &> /dev/null; then
        log "Installing pyenv..."
        curl https://pyenv.run | bash
        
        # Add to shell configs
        for config in ~/.bashrc ~/.zshrc; do
            if [[ -f "$config" ]] && ! grep -q "pyenv" "$config"; then
                cat >> "$config" << 'PYENV'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi
PYENV
            fi
        done
    fi
}

# Install modern Python versions
install_python_versions() {
    log "Installing Python versions..."
    
    # Install latest stable versions
    pyenv install 3.12.0
    pyenv install 3.11.7
    pyenv install 3.10.13
    
    # Set global version
    pyenv global 3.12.0
}

# Install uv for fast package management
install_uv() {
    log "Installing uv for ultra-fast Python package management..."
    pip install --user uv
}

# Setup poetry configuration
setup_poetry() {
    log "Configuring Poetry..."
    
    # Install poetry via package manager (already installed)
    # Configure poetry settings
    poetry config virtualenvs.in-project true
    poetry config cache-dir "/var/cache/poetry/$(whoami)"
}

main() {
    install_pyenv
    source ~/.bashrc 2>/dev/null || true
    install_python_versions
    install_uv
    setup_poetry
    
    log "Python development environment setup complete!"
    log "Available commands:"
    log "  - pyenv: Python version management"
    log "  - poetry: Dependency management"
    log "  - uv: Ultra-fast package installer"
}

main "$@"
EOF

    chmod +x /usr/local/bin/setup-python-dev.sh
    log "Python development setup script created"
}

# Create development workspace setup
create_workspace_setup() {
    log "Creating development workspace setup..."
    
    cat > /usr/local/bin/setup-dev-workspace.sh << 'EOF'
#!/bin/bash

# Development Workspace Setup
# Creates organized development directory structure

set -euo pipefail

USER_HOME="${HOME:-/home/$(whoami)}"

log() {
    echo -e "\033[0;32m[$(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"
}

# Create development directory structure
create_directories() {
    log "Creating development workspace directories..."
    
    # Main project directories
    mkdir -p "$USER_HOME/Projects"/{personal,work,learning,experiments,archive}
    
    # Configuration directories
    mkdir -p "$USER_HOME/.config"/{git,zsh,vim,tmux}
    
    # Local binaries and scripts
    mkdir -p "$USER_HOME/.local"/{bin,share,lib}
    
    # Documentation and notes
    mkdir -p "$USER_HOME/Documents"/{notes,docs,references,cheatsheets}
    
    # Scripts and automation
    mkdir -p "$USER_HOME/Scripts"/{automation,backup,deployment,monitoring}
    
    log "Development workspace directories created"
}

# Create useful aliases and functions
create_dev_aliases() {
    log "Creating development aliases..."
    
    cat > "$USER_HOME/.dev-aliases" << 'ALIASES'
# Development aliases and functions

# Quick navigation
alias cdp='cd ~/Projects'
alias cdw='cd ~/Projects/work'
alias cdpersonal='cd ~/Projects/personal'
alias cdlearn='cd ~/Projects/learning'
alias cdexp='cd ~/Projects/experiments'

# Development shortcuts
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias gm='git merge'

# Development tools
alias py='python'
alias py3='python3'
alias pip='python -m pip'
alias venv='python -m venv'
alias serve='python -m http.server'

# System monitoring
alias ports='netstat -tuln'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# Development functions
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

function backup_project() {
    local project_dir="$1"
    local backup_name="$(basename "$project_dir")-backup-$(date +%Y%m%d-%H%M%S)"
    tar -czf "$HOME/Projects/archive/$backup_name.tar.gz" -C "$(dirname "$project_dir")" "$(basename "$project_dir")"
    echo "Project backed up to: ~/Projects/archive/$backup_name.tar.gz"
}

echo "✓ Development aliases loaded"
ALIASES

    # Add to shell configurations
    for shell_config in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"; do
        if [[ -f "$shell_config" ]] && ! grep -q ".dev-aliases" "$shell_config"; then
            echo "" >> "$shell_config"
            echo "# Development aliases" >> "$shell_config"
            echo "source ~/.dev-aliases" >> "$shell_config"
        fi
    done
}

# Create project templates
create_project_templates() {
    log "Creating project templates..."
    
    mkdir -p "$USER_HOME/.project-templates"
    
    # Python project template
    mkdir -p "$USER_HOME/.project-templates/python-project"
    cat > "$USER_HOME/.project-templates/python-project/pyproject.toml" << 'EOF'
[tool.poetry]
name = "project-name"
version = "0.1.0"
description = ""
authors = ["Your Name <your.email@example.com>"]

[tool.poetry.dependencies]
python = "^3.11"

[tool.poetry.group.dev.dependencies]
pytest = "^7.0"
black = "^23.0"
isort = "^5.0"
flake8 = "^6.0"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF

    cat > "$USER_HOME/.project-templates/python-project/README.md" << 'EOF'
# Project Name

## Setup

```bash
poetry install
poetry shell
```

## Development

```bash
poetry run python main.py
poetry run pytest
```
EOF

    # Node.js project template
    mkdir -p "$USER_HOME/.project-templates/node-project"
    cat > "$USER_HOME/.project-templates/node-project/package.json" << 'EOF'
{
  "name": "project-name",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0"
  }
}
EOF

    log "Project templates created in ~/.project-templates/"
}

main() {
    create_directories
    create_dev_aliases
    create_project_templates
    
    log "Development workspace setup complete!"
    log "Use 'source ~/.dev-aliases' to load development shortcuts"
}

main "$@"
EOF

    chmod +x /usr/local/bin/setup-dev-workspace.sh
    log "Development workspace setup script created"
}

# Show summary
show_summary() {
    log "Development environment setup completed successfully!"
    echo ""
    echo "=== Summary ==="
    echo "✓ Development packages installed"
    echo "✓ Development cache optimization script created: /usr/local/bin/setup-dev-caches.sh"
    echo "✓ Git integration hooks created"
    echo "✓ Git snapshot utility created: /usr/local/bin/git-snapshot"
    echo "✓ VS Code optimizations configured"
    echo "✓ Python development setup script created: /usr/local/bin/setup-python-dev.sh"
    echo "✓ Development workspace setup script created: /usr/local/bin/setup-dev-workspace.sh"
    echo ""
    echo "=== Next Steps ==="
    echo "• Run 'setup-dev-caches.sh' as your user to optimize development caches"
    echo "• Run 'setup-python-dev.sh' as your user to configure Python environment"
    echo "• Run 'setup-dev-workspace.sh' as your user to create development workspace"
    echo "• Configure Git templates: git config --global init.templatedir /usr/local/share/git-templates"
    echo ""
    echo "=== Available Commands ==="
    echo "• git-snapshot create \"description\" - Create manual Git snapshot"
    echo "• git-snapshot list - List Git-related snapshots"
    echo "• setup-dev-caches.sh - Optimize development caches"
    echo "• setup-python-dev.sh - Setup Python development environment"
    echo "• setup-dev-workspace.sh - Create organized development workspace"
}

# Main execution
main() {
    log "Starting development environment setup..."
    
    check_root
    install_development_packages
    create_dev_cache_setup
    create_git_hooks
    create_git_snapshot_utility
    create_vscode_optimizations
    create_python_setup
    create_workspace_setup
    show_summary
    
    log "✓ Development environment setup completed successfully!"
}

# Run main function
main "$@"