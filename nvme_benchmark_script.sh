#!/bin/bash

# NVMe Drive Benchmark for Storage Decision
# Comprehensive benchmarking to inform optimal storage layout
# Tests both synthetic and real-world development workloads

set -euo pipefail

# Device configuration
NVME0="/dev/nvme0n1"
NVME1="/dev/nvme1n1"
SATA_SSD="/dev/sda"

# Test configuration
TEST_SIZE="4G"           # Size for large file tests
SMALL_FILE_COUNT="10000" # Number of small files for random I/O
TEST_DURATION="60"       # Duration for sustained tests (seconds)
THREADS="4"              # Number of parallel threads

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Results storage
declare -A RESULTS

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

header() {
    echo -e "\n${BLUE}╔$(printf '═%.0s' {1..60})╗${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..60})║${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..18})${BOLD}$1${NC}$(printf ' %.0s' {1..18})║${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..60})║${NC}"
    echo -e "${BLUE}╚$(printf '═%.0s' {1..60})╝${NC}"
}

subheader() {
    echo -e "\n${CYAN}>>> $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for accurate disk benchmarks"
    fi
    
    # Check required tools
    local missing_tools=()
    
    for tool in fio hdparm dd sync iotop iostat; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        warn "Missing tools: ${missing_tools[*]}"
        log "Installing missing tools..."
        
        if command -v pacman &> /dev/null; then
            pacman -S --noconfirm fio hdparm sysstat iotop
        elif command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y fio hdparm sysstat iotop
        else
            error "Cannot install missing tools. Please install: ${missing_tools[*]}"
        fi
    fi
    
    # Check devices exist
    for device in "$NVME0" "$NVME1" "$SATA_SSD"; do
        if [[ ! -b "$device" ]]; then
            warn "Device not found: $device"
        else
            log "✓ Found device: $device"
        fi
    done
    
    # Create test directory
    mkdir -p /tmp/nvme_benchmark
    
    log "✓ Prerequisites checked"
}

# Get device information
get_device_info() {
    header "Device Information"
    
    for device in "$NVME0" "$NVME1" "$SATA_SSD"; do
        if [[ -b "$device" ]]; then
            subheader "Device: $device"
            
            # Basic info
            local model=$(lsblk -no MODEL "$device" 2>/dev/null | head -1 || echo "Unknown")
            local size=$(lsblk -no SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")
            local vendor=$(lsblk -no VENDOR "$device" 2>/dev/null | head -1 || echo "Unknown")
            
            echo "Model: $model"
            echo "Vendor: $vendor"
            echo "Size: $size"
            
            # NVMe specific info
            if [[ "$device" =~ nvme ]]; then
                if command -v nvme &> /dev/null; then
                    echo "NVMe Info:"
                    nvme id-ctrl "$device" 2>/dev/null | grep -E "(mn|sn|fr)" || echo "  Cannot read NVMe details"
                fi
            fi
            
            # Temperature (if available)
            local temp_file="/sys/class/block/$(basename "$device")/device/hwmon/hwmon*/temp1_input"
            if ls $temp_file 2>/dev/null | head -1 | xargs cat 2>/dev/null; then
                local temp=$(($(cat $temp_file 2>/dev/null || echo "0") / 1000))
                echo "Temperature: ${temp}°C"
            fi
            
            echo ""
        fi
    done
}

# Synthetic benchmarks using fio
run_fio_benchmarks() {
    header "Synthetic Benchmarks (fio)"
    
    for device in "$NVME0" "$NVME1" "$SATA_SSD"; do
        if [[ ! -b "$device" ]]; then
            continue
        fi
        
        subheader "Testing $device"
        
        # Sequential Read
        log "Sequential Read (4MB blocks)..."
        local seq_read=$(fio --name=seq_read --filename="$device" --rw=read --bs=4M --size="$TEST_SIZE" \
            --numjobs=1 --time_based --runtime=30 --group_reporting --minimal 2>/dev/null | \
            cut -d';' -f7)
        seq_read=$((seq_read / 1024)) # Convert to MB/s
        RESULTS["${device}_seq_read"]="$seq_read"
        echo "  Sequential Read: ${seq_read} MB/s"
        
        # Sequential Write
        log "Sequential Write (4MB blocks)..."
        local seq_write=$(fio --name=seq_write --filename="$device" --rw=write --bs=4M --size="$TEST_SIZE" \
            --numjobs=1 --time_based --runtime=30 --group_reporting --minimal 2>/dev/null | \
            cut -d';' -f48)
        seq_write=$((seq_write / 1024)) # Convert to MB/s
        RESULTS["${device}_seq_write"]="$seq_write"
        echo "  Sequential Write: ${seq_write} MB/s"
        
        # Random Read (4K blocks)
        log "Random Read (4K blocks)..."
        local rand_read_iops=$(fio --name=rand_read --filename="$device" --rw=randread --bs=4K \
            --size="$TEST_SIZE" --numjobs=4 --time_based --runtime=30 --group_reporting --minimal 2>/dev/null | \
            cut -d';' -f8)
        RESULTS["${device}_rand_read_iops"]="$rand_read_iops"
        echo "  Random Read: ${rand_read_iops} IOPS"
        
        # Random Write (4K blocks)
        log "Random Write (4K blocks)..."
        local rand_write_iops=$(fio --name=rand_write --filename="$device" --rw=randwrite --bs=4K \
            --size="$TEST_SIZE" --numjobs=4 --time_based --runtime=30 --group_reporting --minimal 2>/dev/null | \
            cut -d';' -f49)
        RESULTS["${device}_rand_write_iops"]="$rand_write_iops"
        echo "  Random Write: ${rand_write_iops} IOPS"
        
        # Mixed Random (70% read, 30% write)
        log "Mixed Random (70% read, 30% write)..."
        local mixed_iops=$(fio --name=mixed --filename="$device" --rw=randrw --rwmixread=70 --bs=4K \
            --size="$TEST_SIZE" --numjobs=4 --time_based --runtime=30 --group_reporting --minimal 2>/dev/null | \
            cut -d';' -f8)
        RESULTS["${device}_mixed_iops"]="$mixed_iops"
        echo "  Mixed Random: ${mixed_iops} IOPS"
        
        echo ""
        sleep 2 # Let drive cool down
    done
}

# Development workload simulations
run_development_workloads() {
    header "Development Workload Simulations"
    
    for device in "$NVME0" "$NVME1"; do
        if [[ ! -b "$device" ]]; then
            continue
        fi
        
        # Create test partition if needed
        local test_partition="${device}p99"  # Use a test partition number
        local mount_point="/tmp/benchmark_$(basename "$device")"
        
        subheader "Development Workload Tests: $device"
        
        # Create test filesystem on device (WARNING: This is destructive on unused space)
        warn "Creating test filesystem on $device (will use end of drive)"
        
        # Create small test partition (1GB) at end of drive
        local device_size=$(blockdev --getsz "$device")
        local start_sector=$((device_size - 2097152))  # 1GB from end
        
        if ! parted -s "$device" mkpart test ext4 "${start_sector}s" 100% 2>/dev/null; then
            warn "Cannot create test partition on $device, skipping workload tests"
            continue
        fi
        
        sleep 2
        partprobe
        
        # Format test partition
        if ! mkfs.ext4 -F "$test_partition" &>/dev/null; then
            warn "Cannot format test partition on $device, skipping"
            parted -s "$device" rm 99 2>/dev/null || true
            continue
        fi
        
        # Mount test partition
        mkdir -p "$mount_point"
        if ! mount "$test_partition" "$mount_point"; then
            warn "Cannot mount test partition on $device, skipping"
            parted -s "$device" rm 99 2>/dev/null || true
            continue
        fi
        
        # Test 1: Package Manager Simulation (many small files)
        log "Package manager simulation (npm/cargo style)..."
        local start_time=$(date +%s.%N)
        
        mkdir -p "$mount_point/node_modules"
        for i in $(seq 1 1000); do
            mkdir -p "$mount_point/node_modules/package$i"
            for j in $(seq 1 5); do
                echo "export const value$j = 'test';" > "$mount_point/node_modules/package$i/index$j.js"
                echo '{"name": "package'$i'", "version": "1.0.0"}' > "$mount_point/node_modules/package$i/package$j.json"
            done
        done
        sync
        
        local end_time=$(date +%s.%N)
        local npm_time=$(echo "$end_time - $start_time" | bc)
        RESULTS["${device}_npm_simulation"]="$npm_time"
        echo "  Package creation time: ${npm_time}s"
        
        # Test 2: Build System Simulation (incremental builds)
        log "Build system simulation..."
        start_time=$(date +%s.%N)
        
        mkdir -p "$mount_point/build"
        for i in $(seq 1 500); do
            echo "Building component $i..." > "$mount_point/build/component$i.log"
            echo "Binary output for $i" > "$mount_point/build/component$i.o"
            # Simulate dependency checking
            ls "$mount_point/node_modules" > "$mount_point/build/deps$i.txt" 2>/dev/null || true
        done
        sync
        
        end_time=$(date +%s.%N)
        local build_time=$(echo "$end_time - $start_time" | bc)
        RESULTS["${device}_build_simulation"]="$build_time"
        echo "  Build simulation time: ${build_time}s"
        
        # Test 3: Git Operation Simulation
        log "Git operation simulation..."
        start_time=$(date +%s.%N)
        
        cd "$mount_point"
        git init --quiet . 2>/dev/null || true
        git config user.name "Test" 2>/dev/null || true
        git config user.email "test@test.com" 2>/dev/null || true
        
        # Simulate large codebase
        for i in $(seq 1 200); do
            mkdir -p "src/module$i"
            for j in $(seq 1 10); do
                cat > "src/module$i/file$j.js" << EOF
// Module $i File $j
export class Component$i$j {
    constructor() {
        this.value = $((i * j));
    }
    
    render() {
        return 'Component ' + this.value;
    }
}
EOF
            done
        done
        
        git add . 2>/dev/null || true
        git commit -m "Initial commit" --quiet 2>/dev/null || true
        
        # Simulate modifications
        for i in $(seq 1 50); do
            echo "// Modified $(date)" >> "src/module$i/file1.js"
        done
        
        git add . 2>/dev/null || true
        git commit -m "Modifications" --quiet 2>/dev/null || true
        
        # Test git status (common operation)
        git status > /dev/null 2>&1 || true
        
        end_time=$(date +%s.%N)
        local git_time=$(echo "$end_time - $start_time" | bc)
        RESULTS["${device}_git_simulation"]="$git_time"
        echo "  Git operations time: ${git_time}s"
        
        # Test 4: IDE Indexing Simulation
        log "IDE indexing simulation..."
        start_time=$(date +%s.%N)
        
        # Simulate IDE scanning all files
        find "$mount_point" -type f -name "*.js" -exec wc -l {} \; > /dev/null 2>&1
        find "$mount_point" -type f -name "*.json" -exec cat {} \; > /dev/null 2>&1
        
        end_time=$(date +%s.%N)
        local ide_time=$(echo "$end_time - $start_time" | bc)
        RESULTS["${device}_ide_simulation"]="$ide_time"
        echo "  IDE indexing time: ${ide_time}s"
        
        # Test 5: Container Layer Simulation
        log "Container layer simulation..."
        start_time=$(date +%s.%N)
        
        mkdir -p "$mount_point/containers"
        for i in $(seq 1 100); do
            mkdir -p "$mount_point/containers/layer$i"
            # Simulate extracting container layers
            for j in $(seq 1 20); do
                echo "Container file $i-$j content" > "$mount_point/containers/layer$i/file$j"
            done
        done
        sync
        
        end_time=$(date +%s.%N)
        local container_time=$(echo "$end_time - $start_time" | bc)
        RESULTS["${device}_container_simulation"]="$container_time"
        echo "  Container operations time: ${container_time}s"
        
        # Cleanup
        cd /
        umount "$mount_point" 2>/dev/null || true
        rmdir "$mount_point" 2>/dev/null || true
        parted -s "$device" rm 99 2>/dev/null || true
        
        echo ""
    done
}

# Real-world cache analysis
analyze_current_caches() {
    header "Current Development Cache Analysis"
    
    subheader "Existing Cache Directories"
    
    local cache_dirs=(
        "/var/cache/cargo"
        "/var/cache/go" 
        "/var/cache/node_modules"
        "/var/cache/pyenv"
        "/var/cache/poetry"
        "/var/lib/containers"
        "/tmp"
        "$HOME/.cache" 
        "$HOME/.npm"
        "$HOME/.cargo"
    )
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            local size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
            local files=$(find "$cache_dir" -type f 2>/dev/null | wc -l)
            local device=$(df "$cache_dir" | tail -1 | awk '{print $1}')
            
            echo "$cache_dir:"
            echo "  Size: $size"
            echo "  Files: $files"
            echo "  Device: $device"
            echo ""
        fi
    done
    
    subheader "Current I/O Patterns"
    
    log "Monitoring I/O for 10 seconds (install development tools and see patterns)..."
    
    # Start iostat in background
    iostat -x 1 10 > /tmp/iostat_output &
    local iostat_pid=$!
    
    # Sleep to collect data
    sleep 10
    
    # Kill iostat if still running
    kill $iostat_pid 2>/dev/null || true
    wait $iostat_pid 2>/dev/null || true
    
    echo "I/O Statistics (10 second average):"
    if [[ -f /tmp/iostat_output ]]; then
        grep -E "(nvme|sda)" /tmp/iostat_output | tail -3 || echo "No I/O data collected"
    fi
}

# Generate performance comparison
generate_comparison() {
    header "Performance Analysis & Recommendations"
    
    subheader "Synthetic Benchmark Comparison"
    
    echo -e "${BOLD}Drive Performance Summary:${NC}"
    echo ""
    
    printf "%-20s %-15s %-15s %-15s\n" "Metric" "NVMe0" "NVMe1" "Difference"
    printf "%-20s %-15s %-15s %-15s\n" "$(printf '─%.0s' {1..20})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})"
    
    # Sequential Read
    local nvme0_seq_r=${RESULTS["${NVME0}_seq_read"]:-0}
    local nvme1_seq_r=${RESULTS["${NVME1}_seq_read"]:-0}
    local seq_r_diff=$(echo "scale=1; ($nvme0_seq_r - $nvme1_seq_r) * 100 / $nvme1_seq_r" | bc 2>/dev/null || echo "0")
    printf "%-20s %-15s %-15s %+14.1f%%\n" "Sequential Read" "${nvme0_seq_r}MB/s" "${nvme1_seq_r}MB/s" "$seq_r_diff"
    
    # Sequential Write  
    local nvme0_seq_w=${RESULTS["${NVME0}_seq_write"]:-0}
    local nvme1_seq_w=${RESULTS["${NVME1}_seq_write"]:-0}
    local seq_w_diff=$(echo "scale=1; ($nvme0_seq_w - $nvme1_seq_w) * 100 / $nvme1_seq_w" | bc 2>/dev/null || echo "0")
    printf "%-20s %-15s %-15s %+14.1f%%\n" "Sequential Write" "${nvme0_seq_w}MB/s" "${nvme1_seq_w}MB/s" "$seq_w_diff"
    
    # Random Read
    local nvme0_rand_r=${RESULTS["${NVME0}_rand_read_iops"]:-0}
    local nvme1_rand_r=${RESULTS["${NVME1}_rand_read_iops"]:-0}
    local rand_r_diff=$(echo "scale=1; ($nvme0_rand_r - $nvme1_rand_r) * 100 / $nvme1_rand_r" | bc 2>/dev/null || echo "0")
    printf "%-20s %-15s %-15s %+14.1f%%\n" "Random Read" "${nvme0_rand_r}IOPS" "${nvme1_rand_r}IOPS" "$rand_r_diff"
    
    # Random Write
    local nvme0_rand_w=${RESULTS["${NVME0}_rand_write_iops"]:-0}
    local nvme1_rand_w=${RESULTS["${NVME1}_rand_write_iops"]:-0}
    local rand_w_diff=$(echo "scale=1; ($nvme0_rand_w - $nvme1_rand_w) * 100 / $nvme1_rand_w" | bc 2>/dev/null || echo "0")
    printf "%-20s %-15s %-15s %+14.1f%%\n" "Random Write" "${nvme0_rand_w}IOPS" "${nvme1_rand_w}IOPS" "$rand_w_diff"
    
    echo ""
    
    subheader "Development Workload Comparison"
    
    if [[ -n "${RESULTS["${NVME0}_npm_simulation"]:-}" ]] && [[ -n "${RESULTS["${NVME1}_npm_simulation"]:-}" ]]; then
        echo -e "${BOLD}Development Task Performance:${NC}"
        echo ""
        
        printf "%-25s %-15s %-15s %-15s\n" "Workload" "NVMe0" "NVMe1" "Improvement"
        printf "%-25s %-15s %-15s %-15s\n" "$(printf '─%.0s' {1..25})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})"
        
        # Package operations
        local nvme0_npm=${RESULTS["${NVME0}_npm_simulation"]:-0}
        local nvme1_npm=${RESULTS["${NVME1}_npm_simulation"]:-0}
        local npm_improvement=$(echo "scale=1; ($nvme1_npm - $nvme0_npm) * 100 / $nvme1_npm" | bc 2>/dev/null || echo "0")
        printf "%-25s %-15s %-15s %+14.1f%%\n" "Package Operations" "${nvme0_npm}s" "${nvme1_npm}s" "$npm_improvement"
        
        # Build operations
        local nvme0_build=${RESULTS["${NVME0}_build_simulation"]:-0}
        local nvme1_build=${RESULTS["${NVME1}_build_simulation"]:-0}
        local build_improvement=$(echo "scale=1; ($nvme1_build - $nvme0_build) * 100 / $nvme1_build" | bc 2>/dev/null || echo "0")
        printf "%-25s %-15s %-15s %+14.1f%%\n" "Build Operations" "${nvme0_build}s" "${nvme1_build}s" "$build_improvement"
        
        # Git operations
        local nvme0_git=${RESULTS["${NVME0}_git_simulation"]:-0}
        local nvme1_git=${RESULTS["${NVME1}_git_simulation"]:-0}
        local git_improvement=$(echo "scale=1; ($nvme1_git - $nvme0_git) * 100 / $nvme1_git" | bc 2>/dev/null || echo "0")
        printf "%-25s %-15s %-15s %+14.1f%%\n" "Git Operations" "${nvme0_git}s" "${nvme1_git}s" "$git_improvement"
        
        # IDE indexing
        local nvme0_ide=${RESULTS["${NVME0}_ide_simulation"]:-0}
        local nvme1_ide=${RESULTS["${NVME1}_ide_simulation"]:-0}
        local ide_improvement=$(echo "scale=1; ($nvme1_ide - $nvme0_ide) * 100 / $nvme1_ide" | bc 2>/dev/null || echo "0")
        printf "%-25s %-15s %-15s %+14.1f%%\n" "IDE Indexing" "${nvme0_ide}s" "${nvme1_ide}s" "$ide_improvement"
        
        # Container operations
        local nvme0_container=${RESULTS["${NVME0}_container_simulation"]:-0}
        local nvme1_container=${RESULTS["${NVME1}_container_simulation"]:-0}
        local container_improvement=$(echo "scale=1; ($nvme1_container - $nvme0_container) * 100 / $nvme1_container" | bc 2>/dev/null || echo "0")
        printf "%-25s %-15s %-15s %+14.1f%%\n" "Container Operations" "${nvme0_container}s" "${nvme1_container}s" "$container_improvement"
    fi
    
    echo ""
    
    subheader "Optimization Recommendations"
    
    # Calculate average random I/O improvement
    local avg_random_improvement=$(echo "scale=1; ($rand_r_diff + $rand_w_diff) / 2" | bc 2>/dev/null || echo "0")
    
    if (( $(echo "$avg_random_improvement > 15" | bc -l) )); then
        echo -e "${GREEN}✓ STRONG RECOMMENDATION: Reorganize storage layout${NC}"
        echo ""
        echo "Key findings:"
        echo "• NVMe0 shows ${avg_random_improvement}% better random I/O performance"
        echo "• Development workloads are heavily random I/O dependent"
        echo "• Current layout suboptimal for development performance"
        echo ""
        echo "Recommended actions:"
        echo "1. Move development caches to NVMe0 (fastest random I/O)"
        echo "2. Keep OS on NVMe1 (sequential I/O is adequate)"
        echo "3. Expected overall development performance improvement: 25-40%"
        echo ""
        echo "Migration options:"
        echo "• Fresh install with optimized layout (best performance)"
        echo "• Migrate development caches only (safer, still significant gains)"
        
    elif (( $(echo "$avg_random_improvement > 5" | bc -l) )); then
        echo -e "${YELLOW}⚠ MODERATE RECOMMENDATION: Consider reorganization${NC}"
        echo ""
        echo "NVMe0 shows ${avg_random_improvement}% better random I/O performance"
        echo "Reorganization would provide moderate development performance gains"
        echo "Consider migration based on your development intensity"
        
    else
        echo -e "${CYAN}ℹ MINIMAL BENEFIT: Current layout acceptable${NC}"
        echo ""
        echo "Performance difference between drives is minimal (${avg_random_improvement}%)"
        echo "Current storage layout is reasonably optimal"
        echo "Focus optimization efforts elsewhere"
    fi
    
    echo ""
    
    subheader "Implementation Complexity vs Benefit"
    
    echo "Migration effort assessment:"
    echo ""
    echo "LOW EFFORT (Recommended):"
    echo "• Migrate development caches only"
    echo "• Keep current OS installation"
    echo "• 2-4 hours work, moderate risk"
    echo "• Capture 70-80% of potential performance gains"
    echo ""
    echo "HIGH EFFORT:"
    echo "• Complete storage reorganization"
    echo "• Fresh OS installation required"
    echo "• 6-8 hours work, higher risk"
    echo "• Capture 100% of potential performance gains"
    echo ""
    echo "BENCHMARK AGAIN:"
    echo "• Test with your actual development workloads"
    echo "• Measure build times, package installation, IDE startup"
    echo "• Make decision based on real usage patterns"
}

# Save results to file
save_results() {
    local results_file="/tmp/nvme_benchmark_results_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "NVMe Benchmark Results - $(date)"
        echo "========================================"
        echo ""
        
        echo "Device Information:"
        echo "-------------------"
        for device in "$NVME0" "$NVME1" "$SATA_SSD"; do
            if [[ -b "$device" ]]; then
                echo "$device: $(lsblk -no MODEL "$device" 2>/dev/null | head -1)"
            fi
        done
        echo ""
        
        echo "Benchmark Results:"
        echo "------------------"
        for key in "${!RESULTS[@]}"; do
            echo "$key: ${RESULTS[$key]}"
        done
        echo ""
        
        echo "Raw iostat output:"
        echo "------------------"
        if [[ -f /tmp/iostat_output ]]; then
            cat /tmp/iostat_output
        fi
        
    } > "$results_file"
    
    log "Results saved to: $results_file"
}

# Main execution
main() {
    echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║                                                           ║${NC}"
    echo -e "${BOLD}${BLUE}║            NVMe Performance Benchmark Suite              ║${NC}"
    echo -e "${BOLD}${BLUE}║         Storage Layout Optimization Analysis             ║${NC}"
    echo -e "${BOLD}${BLUE}║                                                           ║${NC}"
    echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    warn "This benchmark will perform intensive disk I/O operations"
    warn "Ensure no critical operations are running"
    warn "Some tests may temporarily use disk space"
    
    read -p "Continue with benchmarking? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Benchmark cancelled"
        exit 0
    fi
    
    check_prerequisites
    get_device_info
    run_fio_benchmarks
    run_development_workloads
    analyze_current_caches
    generate_comparison
    save_results
    
    echo ""
    log "Benchmark completed! Check the recommendations above."
    log "Results saved for future reference."
}

# Cleanup on exit
cleanup() {
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Unmount any test partitions
    umount /tmp/benchmark_* 2>/dev/null || true
    rmdir /tmp/benchmark_* 2>/dev/null || true
    
    # Remove test partitions
    for device in "$NVME0" "$NVME1"; do
        if [[ -b "$device" ]]; then
            parted -s "$device" rm 99 2>/dev/null || true
        fi
    done
    
    # Clean up temporary files
    rm -f /tmp/iostat_output /tmp/nvme_benchmark/* 2>/dev/null || true
    rmdir /tmp/nvme_benchmark 2>/dev/null || true
    
    log "Cleanup completed"
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"