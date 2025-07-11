#!/bin/bash

# System Performance Optimizations Setup Script
# Configures hardware-specific optimizations for development workstation
# Run this script after OS installation

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

# Install performance monitoring packages
install_performance_packages() {
    log "Installing performance monitoring packages..."
    
    if command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm \
            cpupower lm-sensors nvme-cli sysstat iotop \
            mesa-utils vulkan-tools radeontop \
            htop btop iftop nethogs \
            stress stress-ng benchmark
    elif command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y \
            cpufrequtils lm-sensors nvme-cli sysstat iotop \
            mesa-utils vulkan-tools radeontop \
            htop iftop nethogs \
            stress stress-ng
    elif command -v dnf &> /dev/null; then
        dnf install -y \
            cpupower lm_sensors nvme-cli sysstat iotop \
            mesa-utils vulkan-tools radeontop \
            htop iftop nethogs \
            stress stress-ng
    else
        error "Could not determine package manager"
    fi
}

# Create CPU performance optimizations
create_cpu_optimizations() {
    log "Creating CPU performance optimizations..."
    
    # Set CPU governor to performance
    systemctl enable cpupower
    cat > /etc/default/cpupower << 'EOF'
# CPU governor configuration for AMD Ryzen 9950X
governor="performance"
min_freq="3200MHz"
max_freq="5700MHz"
EOF

    # Create systemd service for CPU optimizations
    cat > /etc/systemd/system/cpu-optimizer.service << 'EOF'
[Unit]
Description=CPU Performance Optimization
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/cpupower frequency-set -g performance
ExecStart=/usr/bin/cpupower idle-set -D 0
ExecStart=/bin/bash -c 'echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now cpu-optimizer.service
    
    log "CPU optimizations configured"
}

# Create memory optimizations for DDR5-6000
create_memory_optimizations() {
    log "Creating DDR5-6000 memory optimizations..."
    
    # Memory optimization script
    cat > /usr/local/bin/memory-optimizer.sh << 'EOF'
#!/bin/bash

# Memory Optimization Script for DDR5-6000 (256GB)
# Optimizes memory settings for development workloads

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

# Apply memory optimizations
apply_memory_optimizations() {
    log "Applying DDR5-6000 memory optimizations..."
    
    # Configure sysctl parameters
    cat > /etc/sysctl.d/99-memory-optimization.conf << 'SYSCTL'
# Memory optimizations for DDR5-6000 256GB development workstation

# Virtual memory settings
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.swappiness = 1
vm.vfs_cache_pressure = 50

# Memory allocation
vm.min_free_kbytes = 1048576
vm.zone_reclaim_mode = 0
vm.page_cluster = 3

# Transparent Huge Pages
vm.nr_hugepages = 1024

# OOM killer tuning
vm.oom_kill_allocating_task = 1
vm.panic_on_oom = 0

# Network memory
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000

# File system
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
SYSCTL

    # Apply settings
    sysctl -p /etc/sysctl.d/99-memory-optimization.conf
    
    log "Memory optimizations applied"
}

# Create RAMdisk for ultra-fast builds
create_ramdisk() {
    local size="${1:-16G}"
    
    log "Creating ${size} RAMdisk for ultra-fast builds..."
    
    # Create mount point
    mkdir -p /tmp/ramdisk
    
    # Add to fstab for persistent mounting
    if ! grep -q "/tmp/ramdisk" /etc/fstab; then
        echo "tmpfs /tmp/ramdisk tmpfs defaults,size=${size},mode=1777 0 0" >> /etc/fstab
    fi
    
    # Mount immediately
    mount -t tmpfs -o size="${size}",mode=1777 tmpfs /tmp/ramdisk
    
    log "RAMdisk created at /tmp/ramdisk (${size})"
    log "Use TMPDIR=/tmp/ramdisk for ultra-fast builds"
}

# Check memory performance
check_memory_performance() {
    log "Checking memory performance..."
    
    echo "=== Memory Information ==="
    free -h
    echo ""
    
    echo "=== Memory Speed ==="
    dmidecode --type memory | grep -E "(Speed|Type:|Size)" || echo "dmidecode not available"
    echo ""
    
    echo "=== Current Memory Settings ==="
    echo "vm.dirty_ratio: $(sysctl -n vm.dirty_ratio)"
    echo "vm.dirty_background_ratio: $(sysctl -n vm.dirty_background_ratio)"
    echo "vm.swappiness: $(sysctl -n vm.swappiness)"
    echo "vm.vfs_cache_pressure: $(sysctl -n vm.vfs_cache_pressure)"
    echo "vm.nr_hugepages: $(sysctl -n vm.nr_hugepages)"
    echo ""
    
    echo "=== Huge Pages Status ==="
    cat /proc/meminfo | grep -i huge
    echo ""
}

# Benchmark memory performance
benchmark_memory() {
    log "Running memory benchmark..."
    
    if command -v sysbench &> /dev/null; then
        echo "=== Memory Throughput Test ==="
        sysbench memory --memory-total-size=10G run
    elif command -v stress-ng &> /dev/null; then
        echo "=== Memory Stress Test ==="
        stress-ng --vm 4 --vm-bytes 8G --timeout 30s --metrics-brief
    else
        warn "No benchmarking tools available. Install sysbench or stress-ng for memory testing."
    fi
}

# Main function
main() {
    case "${1:-optimize}" in
        "optimize")
            apply_memory_optimizations
            ;;
        "ramdisk")
            size="${2:-16G}"
            create_ramdisk "$size"
            ;;
        "check"|"status")
            check_memory_performance
            ;;
        "benchmark")
            benchmark_memory
            ;;
        *)
            echo "Memory Optimizer for DDR5-6000 System"
            echo "Usage: $0 {optimize|ramdisk|check|benchmark}"
            echo ""
            echo "Commands:"
            echo "  optimize           - Apply memory optimizations"
            echo "  ramdisk [size]     - Create RAMdisk (default: 16G)"
            echo "  check              - Check memory performance"
            echo "  benchmark          - Run memory benchmark"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x /usr/local/bin/memory-optimizer.sh
    
    # Apply initial optimizations
    /usr/local/bin/memory-optimizer.sh optimize
    
    log "Memory optimization script created at /usr/local/bin/memory-optimizer.sh"
}

# Create NVMe optimizations
create_nvme_optimizations() {
    log "Creating NVMe performance optimizations..."
    
    # NVMe optimization script
    cat > /usr/local/bin/nvme-optimizer.sh << 'EOF'
#!/bin/bash

# NVMe Performance Optimization Script
# Optimizes Samsung SSD 9100 PRO and TEAMGROUP T-Force Z540

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

# Apply NVMe optimizations
apply_nvme_optimizations() {
    log "Applying NVMe performance optimizations..."
    
    # Kernel boot parameters for NVMe optimization
    if ! grep -q "nvme_core.default_ps_max_latency_us=0" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&nvme_core.default_ps_max_latency_us=0 /' /etc/default/grub
        warn "GRUB configuration updated. Run 'grub-mkconfig -o /boot/grub/grub.cfg' and reboot."
    fi
    
    # I/O scheduler optimization
    cat > /etc/udev/rules.d/60-nvme-scheduler.rules << 'UDEV'
# NVMe I/O scheduler optimization
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="128"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nr_requests}="256"
UDEV

    # Apply immediate scheduler changes
    for nvme in /sys/block/nvme*; do
        if [[ -d "$nvme" ]]; then
            echo "none" > "$nvme/queue/scheduler" 2>/dev/null || true
            echo "128" > "$nvme/queue/read_ahead_kb" 2>/dev/null || true
            echo "256" > "$nvme/queue/nr_requests" 2>/dev/null || true
        fi
    done
    
    log "NVMe optimizations applied"
}

# Monitor NVMe health and performance
monitor_nvme() {
    log "Monitoring NVMe drives..."
    
    for device in /dev/nvme[0-9]*n[0-9]*; do
        if [[ -e "$device" ]]; then
            echo "=== $(basename "$device") ==="
            nvme smart-log "$device" 2>/dev/null | grep -E "(temperature|percentage_used|available_spare)" || true
            echo ""
        fi
    done
    
    echo "=== I/O Statistics ==="
    iostat -x 1 1 2>/dev/null | grep nvme || echo "iostat not available"
}

# Benchmark NVMe performance
benchmark_nvme() {
    log "Running NVMe benchmark..."
    
    if command -v fio &> /dev/null; then
        echo "=== NVMe Sequential Read/Write Test ==="
        fio --name=nvme-test --ioengine=libaio --rw=readwrite --bs=1M --size=1G --numjobs=1 --runtime=30 --group_reporting --filename=/tmp/nvme-test
        rm -f /tmp/nvme-test
        
        echo "=== NVMe Random Read/Write Test ==="
        fio --name=nvme-random --ioengine=libaio --rw=randrw --bs=4k --size=1G --numjobs=4 --runtime=30 --group_reporting --filename=/tmp/nvme-random
        rm -f /tmp/nvme-random
    else
        warn "fio not available. Install fio for detailed NVMe benchmarking."
        
        # Simple dd test
        echo "=== Simple Write Test ==="
        dd if=/dev/zero of=/tmp/nvme-test bs=1M count=1024 oflag=direct 2>&1 | grep -E "(copied|MB/s)"
        rm -f /tmp/nvme-test
    fi
}

# Main function
main() {
    case "${1:-optimize}" in
        "optimize")
            apply_nvme_optimizations
            ;;
        "monitor"|"status")
            monitor_nvme
            ;;
        "benchmark")
            benchmark_nvme
            ;;
        *)
            echo "NVMe Optimizer"
            echo "Usage: $0 {optimize|monitor|benchmark}"
            echo ""
            echo "Commands:"
            echo "  optimize    - Apply NVMe optimizations"
            echo "  monitor     - Monitor NVMe health and performance"
            echo "  benchmark   - Run NVMe performance benchmark"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x /usr/local/bin/nvme-optimizer.sh
    
    # Apply initial optimizations
    /usr/local/bin/nvme-optimizer.sh optimize
    
    log "NVMe optimization script created at /usr/local/bin/nvme-optimizer.sh"
}

# Create NVMe health monitoring
create_nvme_health_monitoring() {
    log "Creating NVMe health monitoring service..."
    
    cat > /usr/local/bin/nvme-health-monitor.sh << 'EOF'
#!/bin/bash

# NVMe Health and Temperature Monitoring Script

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

# Check NVMe drive health
check_nvme_health() {
    local device="$1"
    local device_name="$2"
    
    if [[ ! -e "$device" ]]; then
        warn "$device_name not found at $device"
        return 1
    fi
    
    echo "=== $device_name Health Status ==="
    
    # Get temperature
    local temp=$(nvme smart-log "$device" 2>/dev/null | grep temperature | awk '{print $3}' || echo "N/A")
    
    # Get percentage used
    local usage=$(nvme smart-log "$device" 2>/dev/null | grep percentage_used | awk '{print $3}' | sed 's/%//' || echo "N/A")
    
    # Get available spare
    local spare=$(nvme smart-log "$device" 2>/dev/null | grep available_spare | awk '{print $3}' | sed 's/%//' || echo "N/A")
    
    echo "Temperature: ${temp}°C"
    echo "Percentage Used: ${usage}%"
    echo "Available Spare: ${spare}%"
    
    # Alert conditions
    if [[ "$temp" != "N/A" && "$temp" -gt 70 ]]; then
        error "High temperature detected: ${temp}°C"
    fi
    
    if [[ "$usage" != "N/A" && "$usage" -gt 80 ]]; then
        warn "High wear level: ${usage}%"
    fi
    
    if [[ "$spare" != "N/A" && "$spare" -lt 10 ]]; then
        error "Low available spare: ${spare}%"
    fi
    
    echo ""
}

# Check btrfs allocation and performance
check_btrfs_performance() {
    echo "=== Btrfs Performance Status ==="
    
    for fs in / /home /mnt/bulk; do
        if mountpoint -q "$fs"; then
            echo "Filesystem: $fs"
            btrfs filesystem usage "$fs" 2>/dev/null | grep "Free (estimated)" || echo "  Status: OK"
            echo ""
        fi
    done
}

# Main monitoring function
main() {
    log "NVMe Health and Performance Monitor"
    echo ""
    
    # Check NVMe drives
    check_nvme_health "/dev/nvme0n1" "Samsung SSD 9100 PRO (Primary)"
    check_nvme_health "/dev/nvme1n1" "TEAMGROUP T-Force Z540 (Secondary)"
    
    # Check btrfs performance
    check_btrfs_performance
    
    # Check I/O statistics
    echo "=== I/O Statistics ==="
    iostat -x 1 1 2>/dev/null | grep nvme || echo "iostat not available"
    echo ""
}

main "$@"
EOF

    chmod +x /usr/local/bin/nvme-health-monitor.sh
    
    # Create systemd service for regular health monitoring
    cat > /etc/systemd/system/nvme-health-monitor.service << 'EOF'
[Unit]
Description=NVMe Health Monitoring
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvme-health-monitor.sh
User=root
EOF

    cat > /etc/systemd/system/nvme-health-monitor.timer << 'EOF'
[Unit]
Description=NVMe Health Monitoring Timer
Requires=nvme-health-monitor.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now nvme-health-monitor.timer
    
    log "NVMe health monitoring service enabled"
}

# Create btrfs maintenance service
create_btrfs_maintenance() {
    log "Creating enhanced btrfs maintenance service..."
    
    cat > /etc/systemd/system/btrfs-maintenance.service << 'EOF'
[Unit]
Description=Btrfs maintenance tasks
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for fs in / /home /mnt/bulk; do btrfs filesystem defragment -r -czstd "$fs" 2>/dev/null || true; done'
ExecStart=/bin/bash -c 'for fs in / /home /mnt/bulk; do btrfs balance start -dusage=50 "$fs" 2>/dev/null || true; done'
ExecStart=/bin/bash -c 'for fs in / /home; do btrfs property set "$fs" compression zstd 2>/dev/null || true; done'
User=root
IOSchedulingClass=3
IOSchedulingPriority=7
EOF

    cat > /etc/systemd/system/btrfs-maintenance.timer << 'EOF'
[Unit]
Description=Weekly Btrfs maintenance
Requires=btrfs-maintenance.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now btrfs-maintenance.timer
    
    log "Btrfs maintenance service enabled"
}

# Create network optimizations
create_network_optimizations() {
    log "Creating network optimizations for 10Gb NIC..."
    
    # Network optimization settings
    cat > /etc/sysctl.d/99-network-optimization.conf << 'EOF'
# Network optimizations for Intel X520-DA2 10Gb NIC

# TCP buffer sizes
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216

# TCP window scaling
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP congestion control
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# Connection tracking
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576

# Network device queue
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600
EOF

    sysctl -p /etc/sysctl.d/99-network-optimization.conf
    
    log "Network optimizations applied"
}

# Create system monitoring script
create_system_monitor() {
    log "Creating comprehensive system monitoring script..."
    
    cat > /usr/local/bin/system-monitor.sh << 'EOF'
#!/bin/bash

# Comprehensive System Monitor
# Monitors CPU, memory, storage, and network performance

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# System overview
show_system_overview() {
    echo "=== System Overview ==="
    uptime
    echo ""
    
    echo "=== CPU Information ==="
    lscpu | grep -E "(Model name|CPU\(s\)|Thread|Core|MHz|Cache)"
    echo ""
    
    echo "=== Memory Information ==="
    free -h
    echo ""
    
    echo "=== Storage Information ==="
    df -h | grep -E "(Filesystem|/dev/)"
    echo ""
}

# Performance metrics
show_performance_metrics() {
    echo "=== CPU Usage ==="
    top -bn1 | head -20
    echo ""
    
    echo "=== Memory Usage ==="
    ps aux --sort=-%mem | head -10
    echo ""
    
    echo "=== I/O Statistics ==="
    iostat -x 1 1 2>/dev/null || echo "iostat not available"
    echo ""
    
    echo "=== Network Statistics ==="
    ss -tuln | head -10
    echo ""
}

# Hardware temperatures
show_temperatures() {
    echo "=== System Temperatures ==="
    sensors 2>/dev/null || echo "lm-sensors not configured"
    echo ""
    
    echo "=== NVMe Temperatures ==="
    for device in /dev/nvme[0-9]*n[0-9]*; do
        if [[ -e "$device" ]]; then
            temp=$(nvme smart-log "$device" 2>/dev/null | grep temperature | awk '{print $3}' || echo "N/A")
            echo "$(basename "$device"): ${temp}°C"
        fi
    done
    echo ""
}

# Main function
main() {
    case "${1:-overview}" in
        "overview")
            show_system_overview
            ;;
        "performance")
            show_performance_metrics
            ;;
        "temperature"|"temp")
            show_temperatures
            ;;
        "all")
            show_system_overview
            show_performance_metrics
            show_temperatures
            ;;
        *)
            echo "System Monitor"
            echo "Usage: $0 {overview|performance|temperature|all}"
            echo ""
            echo "Commands:"
            echo "  overview      - Show system overview"
            echo "  performance   - Show performance metrics"
            echo "  temperature   - Show system temperatures"
            echo "  all          - Show all information"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x /usr/local/bin/system-monitor.sh
    
    log "System monitoring script created at /usr/local/bin/system-monitor.sh"
}

# Show summary
show_summary() {
    log "System optimizations setup completed successfully!"
    echo ""
    echo "=== Summary ==="
    echo "✓ Performance monitoring packages installed"
    echo "✓ CPU optimizations configured (performance governor)"
    echo "✓ DDR5-6000 memory optimizations applied"
    echo "✓ NVMe performance optimizations configured"
    echo "✓ NVMe health monitoring enabled (hourly checks)"
    echo "✓ Btrfs maintenance service enabled (weekly)"
    echo "✓ Network optimizations applied (10Gb NIC)"
    echo "✓ System monitoring script created"
    echo ""
    echo "=== Available Commands ==="
    echo "• memory-optimizer.sh optimize - Apply memory optimizations"
    echo "• memory-optimizer.sh ramdisk 16G - Create 16GB RAMdisk for builds"
    echo "• memory-optimizer.sh benchmark - Run memory performance tests"
    echo "• nvme-optimizer.sh optimize - Apply NVMe optimizations"
    echo "• nvme-optimizer.sh monitor - Monitor NVMe health"
    echo "• nvme-optimizer.sh benchmark - Run NVMe performance tests"
    echo "• nvme-health-monitor.sh - Check NVMe health status"
    echo "• system-monitor.sh all - Show comprehensive system status"
    echo ""
    echo "=== Performance Optimizations Applied ==="
    echo "• CPU governor set to 'performance'"
    echo "• NVMe power management optimized for maximum performance"
    echo "• Memory settings tuned for DDR5-6000 CL34 (256GB)"
    echo "• Transparent Huge Pages enabled for large memory workloads"
    echo "• Network settings optimized for 10Gb Intel X520-DA2 NIC"
    echo "• I/O scheduler optimized for NVMe SSDs"
    echo ""
    echo "=== Next Steps ==="
    echo "• Run 'grub-mkconfig -o /boot/grub/grub.cfg' to apply GRUB optimizations"
    echo "• Reboot system to apply all kernel parameter optimizations"
    echo "• Run 'memory-optimizer.sh ramdisk 16G' to create RAMdisk for builds"
    echo "• Monitor system with 'system-monitor.sh all'"
}

# Main execution
main() {
    log "Starting system performance optimizations setup..."
    
    check_root
    install_performance_packages
    create_cpu_optimizations
    create_memory_optimizations
    create_nvme_optimizations
    create_nvme_health_monitoring
    create_btrfs_maintenance
    create_network_optimizations
    create_system_monitor
    show_summary
    
    log "✓ System performance optimizations setup completed successfully!"
}

# Run main function
main "$@"