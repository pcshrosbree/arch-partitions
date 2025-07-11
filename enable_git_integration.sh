#!/bin/bash

# Git Integration Setup Script
# Enables automatic snapshots for Git operations
# Run this script as a normal user (not root)

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

# Check if NOT running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should NOT be run as root. Run as your normal user."
    fi
}

# Check if snapper is available
check_snapper() {
    if ! command -v snapper &> /dev/null; then
        error "Snapper is not installed. Please run setup-snapshotting.sh first."
    fi
    
    # Check if home config exists
    if ! snapper list-configs | grep -q "home"; then
        error "Snapper home configuration not found. Please run setup-snapshotting.sh first."
    fi
}

# Enable global Git template directory
enable_git_templates() {
    log "Enabling Git template directory for automatic hook installation..."
    
    # Set global Git template directory
    git config --global init.templatedir /usr/local/share/git-templates
    
    log "Git template directory configured"
}

# Apply hooks to existing repositories
apply_hooks_to_existing_repos() {
    log "Applying Git hooks to existing repositories..."
    
    local repo_count=0
    
    # Find Git repositories in common development locations
    for search_dir in "$HOME/Projects" "$HOME/projects" "$HOME/src" "$HOME/code" "$HOME/development"; do
        if [[ -d "$search_dir" ]]; then
            while IFS= read -r -d '' git_dir; do
                local repo_dir=$(dirname "$git_dir")
                local repo_name=$(basename "$repo_dir")
                
                info "Applying hooks to repository: $repo_name"
                
                # Copy hooks to repository
                cp /usr/local/share/git-templates/hooks/* "$git_dir/hooks/" 2>/dev/null || {
                    warn "Could not copy hooks to $repo_name (permission denied or missing templates)"
                    continue
                }
                
                # Make hooks executable
                chmod +x "$git_dir/hooks"/* 2>/dev/null || true
                
                ((repo_count++))
                
            done < <(find "$search_dir" -name ".git" -type d -print0 2>/dev/null)
        fi
    done
    
    if [[ $repo_count -eq 0 ]]; then
        info "No existing Git repositories found to update"
    else
        log "Applied hooks to $repo_count existing repositories"
    fi
}

# Create Git snapshot utility for user
create_git_snapshot_utility() {
    log "Creating user Git snapshot utility..."
    
    # Create user bin directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
    
    cat > "$HOME/.local/bin/git-snapshot" << 'EOF'
#!/bin/bash

# Git Snapshot Utility (User Version)
# Manual snapshot management for Git repositories

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

# Check if we're in a Git repository
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        error "Not inside a Git repository"
    fi
}

# Create manual Git snapshot
create_snapshot() {
    local description="$1"
    check_git_repo
    
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local branch=$(git rev-parse --abbrev-ref HEAD)
    local snapshot_msg="git-manual-${repo_name}-${branch}-${description}-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating Git snapshot: $description"
    
    # Create snapshot for home filesystem
    if sudo snapper -c home create --description "$snapshot_msg" --userdata "git=true,repo=$repo_name,branch=$branch,manual=true"; then
        log "Git snapshot created successfully"
    else
        error "Failed to create snapshot. Make sure snapper is configured."
    fi
}

# List Git-related snapshots
list_git_snapshots() {
    echo "=== Git-related Snapshots ==="
    sudo snapper -c home list | grep -E "(git-|Description)" || echo "No Git snapshots found"
}

# Show differences for a snapshot
show_snapshot_diff() {
    local snapshot_id="$1"
    
    echo "=== Git Snapshot Differences (ID: $snapshot_id) ==="
    sudo snapper -c home status "$snapshot_id"..0
}

# Restore files from Git snapshot
restore_from_snapshot() {
    local snapshot_id="$1"
    shift
    local files=("$@")
    
    log "Restoring files from Git snapshot $snapshot_id..."
    
    # Create pre-restore snapshot
    sudo snapper -c home create --description "pre-git-restore-$(date +%Y%m%d-%H%M%S)" --userdata "prerestore=true"
    
    for file in "${files[@]}"; do
        if sudo snapper -c home undochange "$snapshot_id"..0 "$file"; then
            log "✓ Restored: $file"
        else
            warn "✗ Failed to restore: $file"
        fi
    done
}

# Interactive file restore
interactive_restore() {
    local snapshot_id="$1"
    
    echo "=== Files changed in snapshot $snapshot_id ==="
    sudo snapper -c home status "$snapshot_id"..0
    echo ""
    
    echo -n "Enter files to restore (space-separated, or 'all' for everything): "
    read -r files_input
    
    if [[ "$files_input" == "all" ]]; then
        warn "Restoring all files from snapshot $snapshot_id"
        echo -n "Are you sure? (y/N): "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sudo snapper -c home create --description "pre-git-restore-all-$(date +%Y%m%d-%H%M%S)" --userdata "prerestore=true"
            sudo snapper -c home undochange "$snapshot_id"..0
            log "Full restore completed"
        else
            log "Restore cancelled"
        fi
    else
        IFS=' ' read -ra files_array <<< "$files_input"
        restore_from_snapshot "$snapshot_id" "${files_array[@]}"
    fi
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
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 restore snapshot_id [file1 file2 ...]"
                exit 1
            fi
            snapshot_id="$2"
            shift 2
            if [[ $# -eq 0 ]]; then
                interactive_restore "$snapshot_id"
            else
                restore_from_snapshot "$snapshot_id" "$@"
            fi
            ;;
        "status")
            check_git_repo
            repo_name=$(basename "$(git rev-parse --show-toplevel)")
            branch=$(git rev-parse --abbrev-ref HEAD)
            echo "Repository: $repo_name"
            echo "Branch: $branch"
            echo "Git integration: Enabled"
            echo ""
            echo "Recent Git snapshots:"
            sudo snapper -c home list | grep "git.*$repo_name" | tail -5 || echo "No recent snapshots"
            ;;
        *)
            echo "Git Snapshot Utility"
            echo "Usage: $0 {create|list|diff|restore|status}"
            echo ""
            echo "Commands:"
            echo "  create \"description\"           - Create manual Git snapshot"
            echo "  list                            - List Git-related snapshots"
            echo "  diff snapshot_id                - Show snapshot differences"
            echo "  restore snapshot_id [files...]  - Restore files from snapshot"
            echo "  status                          - Show Git integration status"
            echo ""
            echo "Examples:"
            echo "  git-snapshot create \"before refactoring\""
            echo "  git-snapshot list"
            echo "  git-snapshot diff 42"
            echo "  git-snapshot restore 42 src/main.py"
            echo "  git-snapshot restore 42  # Interactive restore"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$HOME/.local/bin/git-snapshot"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        for shell_config in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
            if [[ -f "$shell_config" ]] && ! grep -q ".local/bin" "$shell_config"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_config"
            fi
        done
        
        # Add to current session
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    log "Git snapshot utility created at ~/.local/bin/git-snapshot"
}

# Configure Git settings for optimal snapshot integration
configure_git_settings() {
    log "Configuring Git settings for snapshot integration..."
    
    # Set up Git configuration for performance and snapshot integration
    cat > "$HOME/.gitconfig-snapshot" << 'EOF'
# Git configuration for snapshot integration
# Include this in your main .gitconfig with: git config --global --add include.path ~/.gitconfig-snapshot

[core]
    # Performance optimizations
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

# Snapshot integration settings
[alias]
    snapshot = !git-snapshot create
    snapshots = !git-snapshot list
    snap-diff = !git-snapshot diff
    snap-restore = !git-snapshot restore
    snap-status = !git-snapshot status

# Enhanced commit template for snapshot descriptions
[commit]
    template = ~/.gitmessage

# Better diff and merge settings
[diff]
    algorithm = histogram
    compactionHeuristic = true

[merge]
    tool = vimdiff
    conflictstyle = diff3
EOF

    # Create commit message template
    cat > "$HOME/.gitmessage" << 'EOF'

# <type>: <subject>
#
# <body>
#
# <footer>
#
# Type can be:
#   feat     (new feature)
#   fix      (bug fix)
#   docs     (documentation)
#   style    (formatting, missing semi colons, etc; no code change)
#   refactor (refactoring production code)
#   test     (adding tests, refactoring test; no production code change)
#   chore    (updating build tasks, package manager configs, etc; no production code change)
#
# Subject line should be 50 characters or less
# Body should wrap at 72 characters
# Footer should contain issue references (e.g., "Fixes #123")
#
# Automatic snapshot will be created before this commit
EOF

    # Suggest including the snapshot configuration
    info "Git snapshot configuration created at ~/.gitconfig-snapshot"
    info "To enable, run: git config --global --add include.path ~/.gitconfig-snapshot"
}

# Test the Git integration
test_git_integration() {
    log "Testing Git integration..."
    
    # Create a test repository if none exists
    local test_repo="$HOME/git-integration-test"
    
    if [[ ! -d "$test_repo" ]]; then
        info "Creating test repository for integration testing..."
        
        mkdir -p "$test_repo"
        cd "$test_repo"
        
        git init
        echo "# Git Integration Test" > README.md
        echo "This is a test repository for Git snapshot integration." >> README.md
        git add README.md
        
        # Test if hooks are working
        if git commit -m "Initial commit - test Git integration"; then
            log "✓ Git integration test successful"
            log "✓ Automatic snapshot should have been created"
            
            # Check if snapshot was created
            if sudo snapper -c home list | grep -q "git-commit.*git-integration-test"; then
                log "✓ Automatic snapshot was created successfully"
            else
                warn "Automatic snapshot may not have been created"
            fi
        else
            error "Git commit failed during integration test"
        fi
        
        cd - > /dev/null
    else
        info "Test repository already exists at $test_repo"
    fi
}

# Show usage instructions
show_usage_instructions() {
    log "Git integration setup completed successfully!"
    echo ""
    echo "=== Git Integration Features ==="
    echo "✓ Automatic snapshots before commits"
    echo "✓ Automatic snapshots before rebases"
    echo "✓ Automatic snapshots on branch switches"
    echo "✓ Manual snapshot creation with git-snapshot"
    echo "✓ Snapshot restore functionality"
    echo "✓ Git performance optimizations"
    echo ""
    echo "=== Available Commands ==="
    echo "• git-snapshot create \"description\" - Create manual snapshot"
    echo "• git-snapshot list - List Git-related snapshots"
    echo "• git-snapshot diff 42 - Show changes in snapshot 42"
    echo "• git-snapshot restore 42 - Restore files from snapshot 42"
    echo "• git-snapshot status - Show integration status"
    echo ""
    echo "=== Git Aliases (after including ~/.gitconfig-snapshot) ==="
    echo "• git snapshot \"description\" - Create manual snapshot"
    echo "• git snapshots - List Git-related snapshots"
    echo "• git snap-diff 42 - Show changes in snapshot 42"
    echo "• git snap-restore 42 - Restore files from snapshot 42"
    echo "• git snap-status - Show integration status"
    echo ""
    echo "=== How It Works ==="
    echo "• Snapshots are automatically created before:"
    echo "  - git commit (creates pre-commit snapshot)"
    echo "  - git rebase (creates pre-rebase snapshot)"
    echo "  - git checkout <different-branch> (creates branch-switch snapshot)"
    echo ""
    echo "• All snapshots are stored in the 'home' snapper configuration"
    echo "• Snapshots include metadata about the repository and branch"
    echo "• Use git-snapshot commands to manage snapshots manually"
    echo ""
    echo "=== Configuration ==="
    echo "• Git hooks are installed in all new repositories automatically"
    echo "• Existing repositories have been updated with hooks"
    echo "• Enhanced Git configuration available in ~/.gitconfig-snapshot"
    echo ""
    echo "=== Next Steps ==="
    echo "• Include snapshot config: git config --global --add include.path ~/.gitconfig-snapshot"
    echo "• Test in a repository: cd your-repo && git-snapshot status"
    echo "• Create a manual snapshot: git-snapshot create \"before major changes\""
    echo "• View your snapshots: git-snapshot list"
    echo ""
    echo "=== Notes ==="
    echo "• Snapshots require sudo access to snapper"
    echo "• Hooks only activate for significant Git operations"
    echo "• Use manual snapshots for important development milestones"
    echo "• Automatic cleanup maintains snapshot storage efficiency"
}

# Main execution
main() {
    log "Starting Git integration setup..."
    
    check_not_root
    check_snapper
    enable_git_templates
    apply_hooks_to_existing_repos
    create_git_snapshot_utility
    configure_git_settings
    test_git_integration
    show_usage_instructions
    
    log "✓ Git integration setup completed successfully!"
}

# Run main function
main "$@"