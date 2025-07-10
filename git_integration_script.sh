#!/bin/bash

# Git Integration Setup Script
# Enables automatic btrfs snapshots for Git operations across all repositories
# Run this script after the snapshot setup is complete

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GIT_TEMPLATE_DIR="/usr/local/share/git-templates"
SNAPSHOT_HOOK="/usr/local/bin/git-snapshot-hook.sh"
USER_HOME="${HOME:-/home/$(whoami)}"

# Logging function
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

# Check if snapshot system is available
check_snapshot_system() {
    log "Checking snapshot system availability..."
    
    if ! command -v snapper &> /dev/null; then
        error "Snapper is not installed. Please run setup-snapshots.sh first."
    fi
    
    if ! snapper list-configs | grep -q "home"; then
        error "Snapper 'home' configuration not found. Please run setup-snapshots.sh first."
    fi
    
    if [[ ! -f "$SNAPSHOT_HOOK" ]]; then
        error "Git snapshot hook not found at $SNAPSHOT_HOOK. Please run setup-snapshots.sh first."
    fi
    
    log "✓ Snapshot system is available"
}

# Check if Git is installed and configured
check_git_setup() {
    log "Checking Git setup..."
    
    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install Git first."
    fi
    
    # Check if user has basic Git configuration
    if ! git config --global user.name &> /dev/null; then
        warn "Git user.name not configured. Please run: git config --global user.name 'Your Name'"
    fi
    
    if ! git config --global user.email &> /dev/null; then
        warn "Git user.email not configured. Please run: git config --global user.email 'your.email@example.com'"
    fi
    
    log "✓ Git is available"
}

# Enable global Git template directory
enable_global_templates() {
    log "Enabling global Git template directory..."
    
    if [[ ! -d "$GIT_TEMPLATE_DIR" ]]; then
        error "Git template directory not found at $GIT_TEMPLATE_DIR. Please run setup-snapshots.sh first."
    fi
    
    # Set global Git template directory
    git config --global init.templatedir "$GIT_TEMPLATE_DIR"
    
    log "✓ Global Git template directory enabled"
}

# Apply hooks to existing repositories
apply_to_existing_repos() {
    log "Searching for existing Git repositories..."
    
    local repos_found=0
    local repos_updated=0
    
    # Find all Git repositories in user's home directory
    while IFS= read -r -d '' repo; do
        repos_found=$((repos_found + 1))
        local repo_dir=$(dirname "$repo")
        local repo_name=$(basename "$repo_dir")
        
        info "Found repository: $repo_name at $repo_dir"
        
        # Ask user if they want to enable snapshots for this repo
        echo -n "Enable Git snapshots for $repo_name? (y/n/a=all remaining): "
        read -r response
        
        case "$response" in
            [Yy]*)
                install_hooks_to_repo "$repo_dir"
                repos_updated=$((repos_updated + 1))
                ;;
            [Aa]*)
                log "Enabling snapshots for all remaining repositories..."
                install_hooks_to_repo "$repo_dir"
                repos_updated=$((repos_updated + 1))
                # Enable for all remaining repos
                while IFS= read -r -d '' remaining_repo; do
                    repos_found=$((repos_found + 1))
                    local remaining_repo_dir=$(dirname "$remaining_repo")
                    local remaining_repo_name=$(basename "$remaining_repo_dir")
                    info "Enabling for: $remaining_repo_name"
                    install_hooks_to_repo "$remaining_repo_dir"
                    repos_updated=$((repos_updated + 1))
                done
                break
                ;;
            *)
                info "Skipping $repo_name"
                ;;
        esac
    done < <(find "$USER_HOME" -type d -name ".git" -not -path "*/.*/*" -print0 2>/dev/null)
    
    log "Found $repos_found repositories, updated $repos_updated repositories"
}

# Install hooks to a specific repository
install_hooks_to_repo() {
    local repo_dir="$1"
    local hooks_dir="$repo_dir/.git/hooks"
    
    if [[ ! -d "$hooks_dir" ]]; then
        warn "Hooks directory not found: $hooks_dir"
        return 1
    fi
    
    # Copy hooks from template directory
    local hooks_installed=0
    
    for hook in pre-commit pre-rebase post-checkout; do
        local template_hook="$GIT_TEMPLATE_DIR/hooks/$hook"
        local repo_hook="$hooks_dir/$hook"
        
        if [[ -f "$template_hook" ]]; then
            # Backup existing hook if it exists
            if [[ -f "$repo_hook" ]]; then
                cp "$repo_hook" "$repo_hook.backup-$(date +%Y%m%d-%H%M%S)"
                info "Backed up existing $hook hook"
            fi
            
            # Copy and make executable
            cp "$template_hook" "$repo_hook"
            chmod +x "$repo_hook"
            hooks_installed=$((hooks_installed + 1))
        fi
    done
    
    if [[ $hooks_installed -gt 0 ]]; then
        info "✓ Installed $hooks_installed hooks to $(basename "$repo_dir")"
    else
        warn "No hooks were installed to $(basename "$repo_dir")"
    fi
}

# Test the integration
test_integration() {
    log "Testing Git integration..."
    
    # Create a test repository
    local test_dir="/tmp/git-snapshot-test-$$"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Initialize repository
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create test file
    echo "Test content" > test.txt
    git add test.txt
    
    # Test pre-commit hook
    log "Testing pre-commit hook..."
    if git commit -m "Test commit" 2>/dev/null; then
        log "✓ Pre-commit hook executed successfully"
    else
        warn "Pre-commit hook may have encountered an issue"
    fi
    
    # Cleanup
    cd /
    rm -rf "$test_dir"
    
    log "✓ Integration test completed"
}

# Create helper script for manual snapshot operations
create_git_snapshot_helper() {
    log "Creating Git snapshot helper script..."
    
    cat > "$USER_HOME/.local/bin/git-snapshot" << 'EOF'
#!/bin/bash

# Git Snapshot Helper Script
# Manual snapshot operations for Git repositories

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if we're in a Git repository
check_git_repo() {
    if ! git rev-parse --git-dir &> /dev/null; then
        error "Not in a Git repository"
    fi
}

# Create manual snapshot
create_snapshot() {
    local description="$1"
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local branch=$(git rev-parse --abbrev-ref HEAD)
    local snapshot_desc="manual-${repo_name}-${branch}-${description}-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating manual snapshot: $description"
    
    if snapper -c home create --description "$snapshot_desc" --userdata "git=true,manual=true,repo=$repo_name,branch=$branch" 2>/dev/null; then
        log "✓ Snapshot created successfully"
    else
        error "Failed to create snapshot"
    fi
}

# List Git-related snapshots
list_git_snapshots() {
    local repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "any")
    
    log "Git-related snapshots for repository: $repo_name"
    echo ""
    
    # List snapshots with git userdata
    snapper -c home list | grep -E "(git-|manual-|pre-commit|pre-rebase)" || echo "No Git snapshots found"
}

# Show snapshot differences for current repository
show_snapshot_diff() {
    local snapshot_id="$1"
    
    if [[ -z "$snapshot_id" ]]; then
        error "Please provide a snapshot ID"
    fi
    
    log "Showing differences for snapshot $snapshot_id"
    snapper -c home status "$snapshot_id"..0
}

# Restore from snapshot (files only, not Git history)
restore_from_snapshot() {
    local snapshot_id="$1"
    local files=("${@:2}")
    
    if [[ -z "$snapshot_id" ]]; then
        error "Please provide a snapshot ID"
    fi
    
    if [[ ${#files[@]} -eq 0 ]]; then
        error "Please provide files to restore"
    fi
    
    log "Restoring files from snapshot $snapshot_id"
    
    # Create safety snapshot first
    create_snapshot "before-restore"
    
    # Restore files
    for file in "${files[@]}"; do
        if snapper -c home undochange "$snapshot_id"..0 "$file"; then
            log "✓ Restored: $file"
        else
            warn "Failed to restore: $file"
        fi
    done
}

# Main function
main() {
    case "${1:-}" in
        "create"|"snap")
            check_git_repo
            description="${2:-manual-snapshot}"
            create_snapshot "$description"
            ;;
        "list"|"ls")
            list_git_snapshots
            ;;
        "diff"|"status")
            check_git_repo
            snapshot_id="${2:-}"
            show_snapshot_diff "$snapshot_id"
            ;;
        "restore")
            check_git_repo
            snapshot_id="${2:-}"
            shift 2 2>/dev/null || true
            files=("$@")
            restore_from_snapshot "$snapshot_id" "${files[@]}"
            ;;
        *)
            echo "Git Snapshot Helper"
            echo "Usage: git-snapshot {create|list|diff|restore}"
            echo ""
            echo "Commands:"
            echo "  create [description]     - Create manual snapshot"
            echo "  list                     - List Git-related snapshots"
            echo "  diff snapshot_id         - Show changes in snapshot"
            echo "  restore snapshot_id file1 [file2 ...] - Restore files from snapshot"
            echo ""
            echo "Examples:"
            echo "  git-snapshot create \"before-refactor\""
            echo "  git-snapshot list"
            echo "  git-snapshot diff 42"
            echo "  git-snapshot restore 42 src/main.py"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    # Create user bin directory if it doesn't exist
    mkdir -p "$USER_HOME/.local/bin"
    chmod +x "$USER_HOME/.local/bin/git-snapshot"
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$USER_HOME/.local/bin"; then
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$USER_HOME/.bashrc"
        warn "Added ~/.local/bin to PATH in .bashrc. Please restart your shell or run: source ~/.bashrc"
    fi
    
    log "✓ Git snapshot helper created at ~/.local/bin/git-snapshot"
}

# Show usage instructions
show_usage_instructions() {
    log "Git integration setup completed!"
    echo ""
    echo "=== Summary ==="
    echo "✓ Global Git template directory enabled"
    echo "✓ Hooks applied to selected existing repositories"
    echo "✓ Git snapshot helper script created"
    echo ""
    echo "=== How It Works ==="
    echo "• New repositories will automatically include snapshot hooks"
    echo "• Existing repositories can be updated manually or were updated during setup"
    echo "• Snapshots are created automatically before commits, rebases, and branch switches"
    echo ""
    echo "=== Commands ==="
    echo "• git-snapshot create \"description\" - Create manual snapshot"
    echo "• git-snapshot list - List Git-related snapshots"
    echo "• git-snapshot diff ID - Show changes in snapshot"
    echo "• git-snapshot restore ID file1 file2 - Restore specific files"
    echo ""
    echo "=== Repository Management ==="
    echo "• Enable for new repo: (automatic with global template)"
    echo "• Enable for existing repo: cp $GIT_TEMPLATE_DIR/hooks/* .git/hooks/"
    echo "• Disable for repo: rm .git/hooks/pre-commit .git/hooks/pre-rebase .git/hooks/post-checkout"
    echo ""
    echo "=== Snapshot Locations ==="
    echo "• All snapshots are stored in the 'home' snapper configuration"
    echo "• Use 'snapper -c home list' to see all snapshots"
    echo "• Use 'dev-backup.sh list' to see all development snapshots"
    echo ""
    echo "=== Configuration ==="
    echo "• Template directory: $GIT_TEMPLATE_DIR"
    echo "• Snapshot hook: $SNAPSHOT_HOOK"
    echo "• Helper script: ~/.local/bin/git-snapshot"
}

# Main execution
main() {
    log "Starting Git integration setup..."
    
    check_snapshot_system
    check_git_setup
    enable_global_templates
    apply_to_existing_repos
    test_integration
    create_git_snapshot_helper
    show_usage_instructions
    
    log "✓ Git integration setup completed successfully!"
}

# Run main function
main "$@"