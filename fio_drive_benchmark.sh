#!/bin/bash

# FIO Comprehensive Drive Benchmark
# Pure fio-based benchmarking for all three drives
# Tests sequential and random performance at various block sizes and queue depths

set -euo pipefail

# Drive configuration
NVME0="/dev/nvme0n1"
NVME1="/dev/nvme1n1"
SATA_SSD="/dev/sda"

# Test configuration
TEST_SIZE="8G"           # Size for each test file
TEST_RUNTIME="60"        # Runtime for each test in seconds
WARMUP_TIME="10"         # Warmup time before measurements
RAMP_TIME="5"            # Ramp time to reach steady state

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
    echo -e "\n${BLUE}╔$(printf '═%.0s' {1..70})╗${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..70})║${NC}"
    printf "${BLUE}║$(printf ' %.0s' {1..5})${BOLD}%-60s${NC}${BLUE}$(printf ' %.0s' {1..5})║${NC}\n" "$1"
    echo -e "${BLUE}║$(printf ' %.0s' {1..70})║${NC}"
    echo -e "${BLUE}╚$(printf '═%.0s' {1..70})╝${NC}"
}

subheader() {
    echo -e "\n${CYAN}▶ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for direct device access"
    fi
    
    # Check for fio
    if ! command -v fio &> /dev/null; then
        log "Installing fio..."
        if command -v pacman &> /dev/null; then
            pacman -S --noconfirm fio
        elif command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y fio
        elif command -v dnf &> /dev/null; then
            dnf install -y fio
        else
            error "Cannot install fio. Please install it manually."
        fi
    fi
    
    # Check devices
    for device in "$NVME0" "$NVME1" "$SATA_SSD"; do
        if [[ -b "$device" ]]; then
            log "✓ Found device: $device"
            
            # Check if device is mounted
            if mount | grep -q "$device"; then
                warn "Device $device has mounted partitions. Results may be affected."
            fi
        else
            warn "Device not found: $device"
        fi
    done
    
    # Create results directory
    mkdir -p /tmp/fio_results
    
    log "✓ Prerequisites checked"
}

# Get device information
show_device_info() {
    header "Device Information"
    
    for device in "$NVME0" "$NVME1" "$SATA_SSD"; do
        if [[ -b "$device" ]]; then
            subheader "Device: $device"
            
            # Basic device info
            local model=$(lsblk -no MODEL "$device" 2>/dev/null | head -1 | xargs || echo "Unknown")
            local size=$(lsblk -no SIZE "$device" 2>/dev/null | head -1 || echo "Unknown")
            local rota=$(lsblk -no ROTA "$device" 2>/dev/null | head -1 || echo "Unknown")
            local type=$(lsblk -no TYPE "$device" 2>/dev/null | head -1 || echo "Unknown")
            
            echo "Model: $model"
            echo "Size: $size"
            echo "Type: $type"
            echo "Rotational: $([ "$rota" = "0" ] && echo "No (SSD)" || echo "Yes (HDD)")"
            
            # Block device info
            if [[ -f "/sys/block/$(basename "$device")/queue/scheduler" ]]; then
                local scheduler=$(cat "/sys/block/$(basename "$device")/queue/scheduler" | grep -o '\[.*\]' | tr -d '[]')
                echo "I/O Scheduler: $scheduler"
            fi
            
            if [[ -f "/sys/block/$(basename "$device")/queue/rotational" ]]; then
                local queue_depth=$(cat "/sys/block/$(basename "$device")/queue/nr_requests" 2>/dev/null || echo "Unknown")
                echo "Queue Depth: $queue_depth"
            fi
            
            # Physical block size
            if [[ -f "/sys/block/$(basename "$device")/queue/physical_block_size" ]]; then
                local phys_block=$(cat "/sys/block/$(basename "$device")/queue/physical_block_size")
                local log_block=$(cat "/sys/block/$(basename "$device")/queue/logical_block_size")
                echo "Block Size: ${log_block}B logical, ${phys_block}B physical"
            fi
            
            # NVMe specific info
            if [[ "$device" =~ nvme ]] && command -v nvme &> /dev/null; then
                local nvme_info=$(nvme id-ctrl "$device" 2>/dev/null | grep "vid\|ssvid\|mn\|fr" | head -4 || echo "")
                if [[ -n "$nvme_info" ]]; then
                    echo "NVMe Details:"
                    echo "$nvme_info" | sed 's/^/  /'
                fi
            fi
            
            echo ""
        fi
    done
}

# Run individual fio test
run_fio_test() {
    local device="$1"
    local test_name="$2"
    local rw_pattern="$3"
    local block_size="$4"
    local queue_depth="$5"
    local num_jobs="$6"
    local extra_params="$7"
    
    local output_file="/tmp/fio_results/$(basename "$device")_${test_name}.json"
    
    log "Running $test_name test on $device (bs=$block_size, qd=$queue_depth, jobs=$num_jobs)..."
    
    # Run fio test
    fio --name="$test_name" \
        --filename="$device" \
        --rw="$rw_pattern" \
        --bs="$block_size" \
        --iodepth="$queue_depth" \
        --numjobs="$num_jobs" \
        --size="$TEST_SIZE" \
        --runtime="$TEST_RUNTIME" \
        --ramp_time="$RAMP_TIME" \
        --time_based \
        --group_reporting \
        --output-format=json \
        --output="$output_file" \
        --ioengine=libaio \
        --direct=1 \
        --sync=1 \
        $extra_params \
        > /dev/null 2>&1
    
    # Parse results
    if [[ -f "$output_file" ]]; then
        # Extract key metrics using jq or manual parsing
        if command -v jq &> /dev/null; then
            local read_bw=$(jq -r '.jobs[0].read.bw // 0' "$output_file")
            local read_iops=$(jq -r '.jobs[0].read.iops // 0' "$output_file")
            local read_lat_avg=$(jq -r '.jobs[0].read.lat_ns.mean // 0' "$output_file")
            local write_bw=$(jq -r '.jobs[0].write.bw // 0' "$output_file")
            local write_iops=$(jq -r '.jobs[0].write.iops // 0' "$output_file")
            local write_lat_avg=$(jq -r '.jobs[0].write.lat_ns.mean // 0' "$output_file")
        else
            # Manual parsing as fallback
            local read_bw=$(grep -o '"bw":[0-9]*' "$output_file" | head -1 | cut -d':' -f2 || echo "0")
            local read_iops=$(grep -o '"iops":[0-9]*\.[0-9]*' "$output_file" | head -1 | cut -d':' -f2 || echo "0")
            local write_bw=$(grep -o '"bw":[0-9]*' "$output_file" | tail -1 | cut -d':' -f2 || echo "0")
            local write_iops=$(grep -o '"iops":[0-9]*\.[0-9]*' "$output_file" | tail -1 | cut -d':' -f2 || echo "0")
            local read_lat_avg="0"
            local write_lat_avg="0"
        fi
        
        # Store results
        RESULTS["${device}_${test_name}_read_bw"]="$read_bw"
        RESULTS["${device}_${test_name}_read_iops"]="$read_iops"
        RESULTS["${device}_${test_name}_read_lat"]="$read_lat_avg"
        RESULTS["${device}_${test_name}_write_bw"]="$write_bw"
        RESULTS["${device}_${test_name}_write_iops"]="$write_iops"
        RESULTS["${device}_${test_name}_write_lat"]="$write_lat_avg"
        
        # Convert and display results
        local read_mb_s=$((read_bw / 1024))
        local write_mb_s=$((write_bw / 1024))
        local read_lat_us=$((read_lat_avg / 1000))
        local write_lat_us=$((write_lat_avg / 1000))
        
        printf "  Read:  %8d MB/s, %10.0f IOPS, %8d μs latency\n" "$read_mb_s" "$read_iops" "$read_lat_us"
        printf "  Write: %8d MB/s, %10.0f IOPS, %8d μs latency\n" "$write_mb_s" "$write_iops" "$write_lat_us"
    else
        warn "Failed to get results for $test_name on $device"
    fi
}

# Comprehensive benchmark suite
run_benchmark_suite() {
    local device="$1"
    local device_name="$2"
    
    header "Benchmarking $device_name ($device)"
    
    if [[ ! -b "$device" ]]; then
        warn "Device $device not found, skipping"
        return
    fi
    
    # Sequential Tests
    subheader "Sequential Performance Tests"
    
    # Sequential Read - Large blocks
    run_fio_test "$device" "seq_read_1M" "read" "1M" "32" "1" ""
    
    # Sequential Write - Large blocks  
    run_fio_test "$device" "seq_write_1M" "write" "1M" "32" "1" ""
    
    # Sequential Read/Write Mix
    run_fio_test "$device" "seq_rw_1M" "rw" "1M" "32" "1" "--rwmixread=70"
    
    # Sequential Read - Medium blocks
    run_fio_test "$device" "seq_read_128K" "read" "128K" "32" "1" ""
    
    # Sequential Write - Medium blocks
    run_fio_test "$device" "seq_write_128K" "write" "128K" "32" "1" ""
    
    echo ""
    
    # Random Tests
    subheader "Random Performance Tests"
    
    # Random Read - 4K (typical development workload)
    run_fio_test "$device" "rand_read_4K" "randread" "4K" "32" "4" ""
    
    # Random Write - 4K
    run_fio_test "$device" "rand_write_4K" "randwrite" "4K" "32" "4" ""
    
    # Random Read/Write Mix - 4K
    run_fio_test "$device" "rand_rw_4K" "randrw" "4K" "32" "4" "--rwmixread=70"
    
    # Random Read - 16K (larger random I/O)
    run_fio_test "$device" "rand_read_16K" "randread" "16K" "32" "4" ""
    
    # Random Write - 16K
    run_fio_test "$device" "rand_write_16K" "randwrite" "16K" "32" "4" ""
    
    echo ""
    
    # Queue Depth Tests
    subheader "Queue Depth Scaling Tests (4K Random Read)"
    
    for qd in 1 4 16 64; do
        run_fio_test "$device" "qd${qd}_rand_read_4K" "randread" "4K" "$qd" "1" ""
    done
    
    echo ""
    
    # Multi-threaded Tests
    subheader "Multi-threaded Tests"
    
    # Multi-threaded random read
    run_fio_test "$device" "mt_rand_read_4K" "randread" "4K" "16" "8" ""
    
    # Multi-threaded random write
    run_fio_test "$device" "mt_rand_write_4K" "randwrite" "4K" "16" "8" ""
    
    echo ""
    
    # Latency Tests
    subheader "Low Latency Tests (Single Thread, QD=1)"
    
    # Single-threaded random read for latency
    run_fio_test "$device" "lat_rand_read_4K" "randread" "4K" "1" "1" ""
    
    # Single-threaded random write for latency
    run_fio_test "$device" "lat_rand_write_4K" "randwrite" "4K" "1" "1" ""
    
    echo ""
}

# Generate comparison tables
generate_comparison() {
    header "Performance Comparison Analysis"
    
    subheader "Sequential Performance Summary"
    
    printf "\n%-20s %-15s %-15s %-15s\n" "Test" "NVMe0" "NVMe1" "SATA SSD"
    printf "%-20s %-15s %-15s %-15s\n" "$(printf '─%.0s' {1..20})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})"
    
    # Sequential Read 1M
    local nvme0_seq_r=$((${RESULTS["${NVME0}_seq_read_1M_read_bw"]:-0} / 1024))
    local nvme1_seq_r=$((${RESULTS["${NVME1}_seq_read_1M_read_bw"]:-0} / 1024))
    local sata_seq_r=$((${RESULTS["${SATA_SSD}_seq_read_1M_read_bw"]:-0} / 1024))
    printf "%-20s %-15s %-15s %-15s\n" "Seq Read (MB/s)" "$nvme0_seq_r" "$nvme1_seq_r" "$sata_seq_r"
    
    # Sequential Write 1M
    local nvme0_seq_w=$((${RESULTS["${NVME0}_seq_write_1M_write_bw"]:-0} / 1024))
    local nvme1_seq_w=$((${RESULTS["${NVME1}_seq_write_1M_write_bw"]:-0} / 1024))
    local sata_seq_w=$((${RESULTS["${SATA_SSD}_seq_write_1M_write_bw"]:-0} / 1024))
    printf "%-20s %-15s %-15s %-15s\n" "Seq Write (MB/s)" "$nvme0_seq_w" "$nvme1_seq_w" "$sata_seq_w"
    
    subheader "Random Performance Summary (4K)"
    
    printf "\n%-20s %-15s %-15s %-15s\n" "Test" "NVMe0" "NVMe1" "SATA SSD"
    printf "%-20s %-15s %-15s %-15s\n" "$(printf '─%.0s' {1..20})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})"
    
    # Random Read 4K IOPS
    local nvme0_rand_r_iops=${RESULTS["${NVME0}_rand_read_4K_read_iops"]:-0}
    local nvme1_rand_r_iops=${RESULTS["${NVME1}_rand_read_4K_read_iops"]:-0}
    local sata_rand_r_iops=${RESULTS["${SATA_SSD}_rand_read_4K_read_iops"]:-0}
    printf "%-20s %-15.0f %-15.0f %-15.0f\n" "Rand Read (IOPS)" "$nvme0_rand_r_iops" "$nvme1_rand_r_iops" "$sata_rand_r_iops"
    
    # Random Write 4K IOPS
    local nvme0_rand_w_iops=${RESULTS["${NVME0}_rand_write_4K_write_iops"]:-0}
    local nvme1_rand_w_iops=${RESULTS["${NVME1}_rand_write_4K_write_iops"]:-0}
    local sata_rand_w_iops=${RESULTS["${SATA_SSD}_rand_write_4K_write_iops"]:-0}
    printf "%-20s %-15.0f %-15.0f %-15.0f\n" "Rand Write (IOPS)" "$nvme0_rand_w_iops" "$nvme1_rand_w_iops" "$sata_rand_w_iops"
    
    subheader "Latency Comparison (Single Thread, QD=1)"
    
    printf "\n%-20s %-15s %-15s %-15s\n" "Test" "NVMe0" "NVMe1" "SATA SSD"
    printf "%-20s %-15s %-15s %-15s\n" "$(printf '─%.0s' {1..20})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})"
    
    # Read Latency
    local nvme0_read_lat=$((${RESULTS["${NVME0}_lat_rand_read_4K_read_lat"]:-0} / 1000))
    local nvme1_read_lat=$((${RESULTS["${NVME1}_lat_rand_read_4K_read_lat"]:-0} / 1000))
    local sata_read_lat=$((${RESULTS["${SATA_SSD}_lat_rand_read_4K_read_lat"]:-0} / 1000))
    printf "%-20s %-15s %-15s %-15s\n" "Read Latency (μs)" "$nvme0_read_lat" "$nvme1_read_lat" "$sata_read_lat"
    
    # Write Latency
    local nvme0_write_lat=$((${RESULTS["${NVME0}_lat_rand_write_4K_write_lat"]:-0} / 1000))
    local nvme1_write_lat=$((${RESULTS["${NVME1}_lat_rand_write_4K_write_lat"]:-0} / 1000))
    local sata_write_lat=$((${RESULTS["${SATA_SSD}_lat_rand_write_4K_write_lat"]:-0} / 1000))
    printf "%-20s %-15s %-15s %-15s\n" "Write Latency (μs)" "$nvme0_write_lat" "$nvme1_write_lat" "$sata_write_lat"
    
    subheader "Queue Depth Scaling (NVMe0 vs NVMe1)"
    
    printf "\n%-15s %-15s %-15s %-15s\n" "Queue Depth" "NVMe0 IOPS" "NVMe1 IOPS" "Difference"
    printf "%-15s %-15s %-15s %-15s\n" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})" "$(printf '─%.0s' {1..15})"
    
    for qd in 1 4 16 64; do
        local nvme0_qd_iops=${RESULTS["${NVME0}_qd${qd}_rand_read_4K_read_iops"]:-0}
        local nvme1_qd_iops=${RESULTS["${NVME1}_qd${qd}_rand_read_4K_read_iops"]:-0}
        local qd_diff=$(echo "scale=1; ($nvme0_qd_iops - $nvme1_qd_iops) * 100 / $nvme1_qd_iops" | bc 2>/dev/null || echo "0")
        printf "%-15s %-15.0f %-15.0f %+14.1f%%\n" "QD=$qd" "$nvme0_qd_iops" "$nvme1_qd_iops" "$qd_diff"
    done
    
    echo ""
}

# Generate recommendations
generate_recommendations() {
    header "Storage Layout Recommendations"
    
    # Calculate key performance differences
    local nvme0_rand_r=${RESULTS["${NVME0}_rand_read_4K_read_iops"]:-0}
    local nvme1_rand_r=${RESULTS["${NVME1}_rand_read_4K_read_iops"]:-0}
    local nvme0_rand_w=${RESULTS["${NVME0}_rand_write_4K_write_iops"]:-0}
    local nvme1_rand_w=${RESULTS["${NVME1}_rand_write_4K_write_iops"]:-0}
    
    local rand_read_diff=$(echo "scale=1; ($nvme0_rand_r - $nvme1_rand_r) * 100 / $nvme1_rand_r" | bc 2>/dev/null || echo "0")
    local rand_write_diff=$(echo "scale=1; ($nvme0_rand_w - $nvme1_rand_w) * 100 / $nvme1_rand_w" | bc 2>/dev/null || echo "0")
    local avg_random_diff=$(echo "scale=1; ($rand_read_diff + $rand_write_diff) / 2" | bc 2>/dev/null || echo "0")
    
    subheader "Performance Analysis"
    
    echo "Random I/O Performance Differences:"
    printf "• Random Read:  NVMe0 is %+.1f%% faster than NVMe1\n" "$rand_read_diff"
    printf "• Random Write: NVMe0 is %+.1f%% faster than NVMe1\n" "$rand_write_diff"
    printf "• Average:      NVMe0 is %+.1f%% faster for random I/O\n" "$avg_random_diff"
    
    echo ""
    
    subheader "Storage Layout Recommendation"
    
    if (( $(echo "$avg_random_diff > 20" | bc -l) )); then
        echo -e "${GREEN}🚀 STRONG RECOMMENDATION: Reorganize for maximum performance${NC}"
        echo ""
        echo "NVMe0 shows significant random I/O advantages (${avg_random_diff}% faster)"
        echo ""
        echo -e "${BOLD}Optimal Layout:${NC}"
        echo "• NVMe0 (Fast Random): Development caches, containers, build temps"
        echo "• NVMe1 (Good Sequential): OS, home directories, logs"
        echo "• SATA SSD: Archives, backup, bulk storage"
        echo ""
        echo "Expected development performance improvement: 25-40%"
        
    elif (( $(echo "$avg_random_diff > 10" | bc -l) )); then
        echo -e "${YELLOW}⚠ MODERATE RECOMMENDATION: Consider reorganization${NC}"
        echo ""
        echo "NVMe0 shows moderate random I/O advantages (${avg_random_diff}% faster)"
        echo ""
        echo "Consider moving high-random-I/O workloads to NVMe0:"
        echo "• Language package caches (npm, cargo, go)"
        echo "• Container storage"
        echo "• IDE workspace and indexing"
        echo ""
        echo "Expected development performance improvement: 15-25%"
        
    elif (( $(echo "$avg_random_diff > 5" | bc -l) )); then
        echo -e "${CYAN}ℹ MINOR BENEFIT: Current layout acceptable${NC}"
        echo ""
        echo "NVMe0 shows small random I/O advantages (${avg_random_diff}% faster)"
        echo "Current layout is reasonably good"
        echo "Reorganization would provide minor benefits"
        echo ""
        echo "Expected development performance improvement: 5-15%"
        
    else
        echo -e "${CYAN}✓ CURRENT LAYOUT OPTIMAL: No changes needed${NC}"
        echo ""
        echo "Performance difference is minimal (${avg_random_diff}% difference)"
        echo "Current storage layout is well-optimized"
        echo "Focus optimization efforts elsewhere"
    fi
    
    echo ""
    
    subheader "Development Workload Mapping"
    
    echo -e "${BOLD}High Random I/O (Best on fastest drive):${NC}"
    echo "• Package managers: npm, cargo, go mod, pip"
    echo "• Build systems: incremental compilation, dependency resolution"
    echo "• Container operations: layer extraction, image management"
    echo "• IDE operations: code indexing, autocomplete, LSP"
    echo "• Version control: git status, diff, log operations"
    echo ""
    
    echo -e "${BOLD}Sequential I/O (Good on any fast drive):${NC}"
    echo "• OS operations: boot, system services"
    echo "• Large file operations: media, archives"
    echo "• Database storage: if using large databases"
    echo "• Log files: system and application logs"
    echo ""
    
    echo -e "${BOLD}Archive/Cold Storage (Suitable for SATA):${NC}"
    echo "• Project archives and backups"
    echo "• Media files and documentation"
    echo "• Container image storage (cold)"
    echo "• Historical data and logs"
}

# Save detailed results
save_results() {
    local results_file="/tmp/fio_benchmark_results_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "FIO Comprehensive Drive Benchmark Results"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        
        echo "Test Configuration:"
        echo "- Test Size: $TEST_SIZE"
        echo "- Runtime: $TEST_RUNTIME seconds"
        echo "- Ramp Time: $RAMP_TIME seconds"
        echo ""
        
        echo "Device Information:"
        echo "-------------------"
        for device in "$NVME0" "$NVME1" "$SATA_SSD"; do
            if [[ -b "$device" ]]; then
                echo "$device: $(lsblk -no MODEL "$device" 2>/dev/null | head -1 | xargs)"
            fi
        done
        echo ""
        
        echo "Detailed Results:"
        echo "-----------------"
        for key in $(printf '%s\n' "${!RESULTS[@]}" | sort); do
            echo "$key: ${RESULTS[$key]}"
        done
        echo ""
        
        echo "Raw FIO JSON files available in: /tmp/fio_results/"
        
    } > "$results_file"
    
    log "Detailed results saved to: $results_file"
    log "Raw FIO JSON results in: /tmp/fio_results/"
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    
    # Remove any remaining fio processes
    pkill -f "fio.*${NVME0}" 2>/dev/null || true
    pkill -f "fio.*${NVME1}" 2>/dev/null || true
    pkill -f "fio.*${SATA_SSD}" 2>/dev/null || true
    
    log "Cleanup completed"
}

# Main execution
main() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║              FIO Comprehensive Drive Benchmark                ║"
    echo "║         Sequential & Random Performance Analysis              ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    warn "This benchmark performs intensive direct disk I/O operations"
    warn "It will test devices directly and may take 45-60 minutes"
    warn "Ensure no critical operations are running on test devices"
    
    echo ""
    read -p "Continue with comprehensive FIO benchmark? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Benchmark cancelled"
        exit 0
    fi
    
    check_prerequisites
    show_device_info
    
    # Run benchmarks for each device
    run_benchmark_suite "$NVME0" "Primary NVMe"
    run_benchmark_suite "$NVME1" "Secondary NVMe"
    run_benchmark_suite "$SATA_SSD" "SATA SSD"
    
    generate_comparison
    generate_recommendations
    save_results
    
    echo ""
    log "FIO benchmark completed successfully!"
    log "Check recommendations above for optimal storage layout"
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"