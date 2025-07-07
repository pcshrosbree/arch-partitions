# System Cache Configuration Guide
## Optimizing `/.cache` Directory for High-Performance Workstation

### Overview
This guide configures the `/.cache` directory (mounted on your SATA SSD) to serve as a centralized cache location for package managers, applications, and development tools. This strategy preserves the Samsung SSD 9100 PRO for active development work while efficiently managing cache files on appropriate storage.

### Cache Directory Structure
```
/.cache/                    # SATA SSD mount point
├── pacman/                 # Pacman package cache
├── yay/                    # AUR helper cache
├── pip/                    # Python package cache
├── npm/                    # Node.js package cache
├── cargo/                  # Rust package cache
├── go/                     # Go module cache
├── docker-tmp/             # Docker temporary files overflow
├── applications/           # Application-specific caches
│   ├── firefox/
│   ├── chrome/
│   ├── vscode/
│   └── jetbrains/
├── build/                  # Build system caches
│   ├── cmake/
│   ├── gradle/
│   └── maven/
└── thumbnails/             # System thumbnails
```

## Phase 1: System-Wide Cache Configuration

### Step 1: Create Cache Directory Structure
```bash
# Create primary cache directories
sudo mkdir -p /.cache/{pacman,yay,pip,npm,cargo,go,docker-tmp}
sudo mkdir -p /.cache/applications/{firefox,chrome,vscode,jetbrains}
sudo mkdir -p /.cache/build/{cmake,gradle,maven}
sudo mkdir -p /.cache/thumbnails

# Set appropriate permissions
sudo chown -R peter:peter /.cache
sudo chmod -R 755 /.cache

# Create symlinks for common cache locations
sudo ln -sf /.cache/thumbnails /home/peter/.cache/thumbnails
```

### Step 2: Configure System Environment Variables
```bash
# Create global cache configuration
sudo tee /etc/environment.d/99-cache-config.conf > /dev/null << 'EOF'
# Global cache directory configuration
XDG_CACHE_HOME="/.cache"
TMPDIR="/.cache/tmp"

# Package manager caches
PIP_CACHE_DIR="/.cache/pip"
NPM_CONFIG_CACHE="/.cache/npm"
CARGO_HOME="/.cache/cargo"
GOCACHE="/.cache/go"
GOMODCACHE="/.cache/go/mod"

# Build tool caches
CMAKE_CACHE_DIR="/.cache/build/cmake"
GRADLE_USER_HOME="/.cache/build/gradle"
MAVEN_OPTS="-Dmaven.repo.local=/.cache/build/maven/repository"
EOF

# Create user-specific cache configuration
tee /home/peter/.profile >> /dev/null << 'EOF'
# Cache directory configuration
export XDG_CACHE_HOME="/.cache"
export TMPDIR="/.cache/tmp"

# Package manager caches
export PIP_CACHE_DIR="/.cache/pip"
export NPM_CONFIG_CACHE="/.cache/npm"
export CARGO_HOME="/.cache/cargo"
export GOCACHE="/.cache/go"
export GOMODCACHE="/.cache/go/mod"

# Build tool caches
export CMAKE_CACHE_DIR="/.cache/build/cmake"
export GRADLE_USER_HOME="/.cache/build/gradle"
export MAVEN_OPTS="-Dmaven.repo.local=/.cache/build/maven/repository"
EOF
```

## Phase 2: Package Manager Cache Configuration

### Step 3: Configure Pacman Cache
```bash
# Configure pacman to use /.cache for package downloads
sudo sed -i 's|#CacheDir.*|CacheDir = /.cache/pacman/pkg/|' /etc/pacman.conf

# Create pacman cache directory
sudo mkdir -p /.cache/pacman/pkg
sudo chown root:root /.cache/pacman/pkg
sudo chmod 755 /.cache/pacman/pkg

# Set up automatic cache cleaning
sudo tee /etc/systemd/system/pacman-cache-clean.service > /dev/null << 'EOF'
[Unit]
Description=Clean pacman cache
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/paccache -r -k 2 -c /.cache/pacman/pkg
ExecStart=/usr/bin/paccache -r -u -k 0 -c /.cache/pacman/pkg
EOF

sudo tee /etc/systemd/system/pacman-cache-clean.timer > /dev/null << 'EOF'
[Unit]
Description=Clean pacman cache weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now pacman-cache-clean.timer
```

### Step 4: Configure AUR Helper Cache (Yay)
```bash
# Configure yay to use /.cache
mkdir -p /.cache/yay
yay --save --builddir /.cache/yay/build
yay --save --cachedir /.cache/yay/cache

# Set up automatic AUR cache cleaning
tee /home/peter/.config/yay/config.json > /dev/null << 'EOF'
{
  "buildDir": "/.cache/yay/build",
  "absdir": "/.cache/yay/abs",
  "editor": "vim",
  "makepkgconf": "",
  "makepkgflags": "",
  "pacmanconf": "",
  "tar": "bsdtar",
  "requestsplitn": 150,
  "sortby": "votes",
  "searchby": "name-desc",
  "answerclean": "All",
  "answerdiff": "All",
  "answeredit": "All",
  "answerupgrade": "All",
  "gitbin": "git",
  "gpgbin": "gpg",
  "gpgflags": "",
  "mflags": "",
  "sudobin": "sudo",
  "sudoflags": "",
  "version": "12.1.3",
  "bottomup": true,
  "removemake": "ask",
  "sudobin": "",
  "sudoflags": "",
  "version": "",
  "completionrefreshtime": 7,
  "maxconcurrentdownloads": 0,
  "bottomup": true
}
EOF
```

## Phase 3: Development Tool Cache Configuration

### Step 5: Configure Programming Language Caches

#### Python (Pip) Cache
```bash
# Configure pip cache
mkdir -p /.cache/pip
tee /home/peter/.pip/pip.conf > /dev/null << 'EOF'
[global]
cache-dir = /.cache/pip
EOF

# Set up pip cache cleaning
tee /home/peter/.local/bin/clean-pip-cache > /dev/null << 'EOF'
#!/bin/bash
# Clean pip cache older than 30 days
find /.cache/pip -type f -atime +30 -delete
find /.cache/pip -type d -empty -delete
EOF

chmod +x /home/peter/.local/bin/clean-pip-cache
```

#### Node.js (NPM) Cache
```bash
# Configure npm cache
mkdir -p /.cache/npm
npm config set cache /.cache/npm

# Configure yarn cache (if using yarn)
mkdir -p /.cache/yarn
yarn config set cache-folder /.cache/yarn

# Set up npm cache verification and cleaning
tee /home/peter/.local/bin/clean-npm-cache > /dev/null << 'EOF'
#!/bin/bash
# Verify and clean npm cache
npm cache verify --cache /.cache/npm
# Clean cache older than 30 days
find /.cache/npm -type f -atime +30 -delete
EOF

chmod +x /home/peter/.local/bin/clean-npm-cache
```

#### Rust (Cargo) Cache
```bash
# Configure cargo cache
mkdir -p /.cache/cargo/{registry,git}

# Create cargo config
mkdir -p /home/peter/.cargo
tee /home/peter/.cargo/config.toml > /dev/null << 'EOF'
[build]
target-dir = "/.cache/cargo/target"

[registry]
global-credential-providers = ["cargo:token"]

[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/.cache/cargo/vendor"

[env]
CARGO_HOME = "/.cache/cargo"
EOF

# Set up cargo cache cleaning
tee /home/peter/.local/bin/clean-cargo-cache > /dev/null << 'EOF'
#!/bin/bash
# Clean cargo cache older than 30 days
cargo cache --autoclean-expensive
find /.cache/cargo/registry -name "*.crate" -atime +30 -delete
EOF

chmod +x /home/peter/.local/bin/clean-cargo-cache
```

#### Go Module Cache
```bash
# Configure Go module cache
mkdir -p /.cache/go/{mod,cache}

# Add to user's shell profile
tee -a /home/peter/.bashrc > /dev/null << 'EOF'
# Go cache configuration
export GOCACHE="/.cache/go/cache"
export GOMODCACHE="/.cache/go/mod"
export GOTMPDIR="/.cache/go/tmp"
EOF

# Set up Go cache cleaning
tee /home/peter/.local/bin/clean-go-cache > /dev/null << 'EOF'
#!/bin/bash
# Clean Go module cache
go clean -modcache
go clean -cache
# Remove old temporary files
find /.cache/go/tmp -type f -atime +7 -delete
EOF

chmod +x /home/peter/.local/bin/clean-go-cache
```

### Step 6: Configure Build System Caches

#### CMake Cache
```bash
# Configure CMake cache
mkdir -p /.cache/build/cmake

# Create CMake presets for cache configuration
tee /home/peter/.cmake/CMakeUserPresets.json > /dev/null << 'EOF'
{
  "version": 3,
  "configurePresets": [
    {
      "name": "default",
      "displayName": "Default Config with Cache",
      "cacheVariables": {
        "CMAKE_CACHEFILE_DIR": "/.cache/build/cmake",
        "CMAKE_FIND_PACKAGE_CACHE": "/.cache/build/cmake/find-package-cache"
      }
    }
  ]
}
EOF
```

#### Gradle Cache
```bash
# Configure Gradle cache
mkdir -p /.cache/build/gradle

# Create Gradle properties
tee /home/peter/.gradle/gradle.properties > /dev/null << 'EOF'
# Gradle cache configuration
org.gradle.caching=true
org.gradle.caching.debug=false
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.configureondemand=true

# Custom cache locations
gradle.user.home=/.cache/build/gradle
org.gradle.jvmargs=-Xms2g -Xmx8g -XX:MaxMetaspaceSize=1g -Dfile.encoding=UTF-8
EOF
```

#### Maven Cache
```bash
# Configure Maven cache
mkdir -p /.cache/build/maven/repository

# Create Maven settings
mkdir -p /home/peter/.m2
tee /home/peter/.m2/settings.xml > /dev/null << 'EOF'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository>/.cache/build/maven/repository</localRepository>
  
  <profiles>
    <profile>
      <id>performance</id>
      <properties>
        <maven.repo.local>/.cache/build/maven/repository</maven.repo.local>
        <maven.test.skip>false</maven.test.skip>
      </properties>
    </profile>
  </profiles>
  
  <activeProfiles>
    <activeProfile>performance</activeProfile>
  </activeProfiles>
</settings>
EOF
```

## Phase 4: Application Cache Configuration

### Step 7: Configure Application Caches

#### Web Browser Caches
```bash
# Firefox cache configuration
mkdir -p /.cache/applications/firefox
tee /home/peter/.mozilla/firefox/profiles.ini > /dev/null << 'EOF'
[Profile0]
Name=default
IsRelative=0
Path=/.cache/applications/firefox/default
Default=1
EOF

# Chrome/Chromium cache configuration
mkdir -p /.cache/applications/chrome
# Chrome cache is configured via command line or desktop file
tee /home/peter/.local/share/applications/google-chrome-cache.desktop > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Name=Google Chrome (Custom Cache)
GenericName=Web Browser
Comment=Access the Internet
Exec=google-chrome-stable --disk-cache-dir=/.cache/applications/chrome %U
StartupNotify=true
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
```

#### Development IDE Caches
```bash
# VSCode cache configuration
mkdir -p /.cache/applications/vscode/{logs,CachedData,User/workspaceStorage}

# Create VSCode settings to use cache directory
mkdir -p /home/peter/.config/Code/User
tee /home/peter/.config/Code/User/settings.json > /dev/null << 'EOF'
{
  "extensions.cacheExpiration": 86400000,
  "typescript.tsc.autoDetect": "on",
  "eslint.workingDirectories": [{"mode": "auto"}],
  "files.watcherExclude": {
    "/.cache/**": true
  }
}
EOF

# JetBrains IDEs cache configuration
mkdir -p /.cache/applications/jetbrains/{system,config,logs}

# IntelliJ IDEA cache configuration
tee /home/peter/.local/bin/idea-cache > /dev/null << 'EOF'
#!/bin/bash
export IDEA_SYSTEM_PATH="/.cache/applications/jetbrains/system"
export IDEA_CONFIG_PATH="/.cache/applications/jetbrains/config"
export IDEA_LOG_PATH="/.cache/applications/jetbrains/logs"
exec idea "$@"
EOF

chmod +x /home/peter/.local/bin/idea-cache
```

## Phase 5: Docker and Container Cache Configuration

### Step 8: Configure Docker Overflow and Cache Management
```bash
# Configure Docker to use /.cache for overflow
sudo mkdir -p /.cache/docker-tmp
sudo chown root:root /.cache/docker-tmp

# Update Docker daemon configuration for cache management
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "data-root": "/dev/docker",
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.size=900G"
  ],
  "tmp-dir": "/.cache/docker-tmp",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "builder": {
    "gc": {
      "enabled": true,
      "defaultKeepStorage": "20GB"
    }
  }
}
EOF

# Create Docker cache cleanup service
sudo tee /etc/systemd/system/docker-cache-clean.service > /dev/null << 'EOF'
[Unit]
Description=Docker cache cleanup
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker system prune -af --volumes --filter "until=24h"
ExecStart=/usr/bin/docker builder prune -af --filter "until=48h"
ExecStart=/usr/bin/find /.cache/docker-tmp -type f -atime +1 -delete
EOF

sudo tee /etc/systemd/system/docker-cache-clean.timer > /dev/null << 'EOF'
[Unit]
Description=Clean Docker cache daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now docker-cache-clean.timer

# Restart Docker with new configuration
sudo systemctl restart docker
```

### Step 9: Configure Container Build Cache
```bash
# Configure BuildKit cache
mkdir -p /.cache/buildkit
sudo chown root:root /.cache/buildkit

# Set up BuildKit configuration
sudo tee /etc/buildkit/buildkitd.toml > /dev/null << 'EOF'
debug = false
root = "/dev/docker/buildkit"
insecure-entitlements = [ "network.host", "security.insecure" ]

[worker.oci]
  enabled = true
  platforms = [ "linux/amd64" ]
  gc = true
  gckeepstorage = 20000

[worker.containerd]
  enabled = false

[grpc]
  address = [ "/run/buildkit/buildkitd.sock" ]

[[grpc.tls]]
  cert = "/etc/buildkit/tls/cert.pem"
  key = "/etc/buildkit/tls/key.pem"
  ca = "/etc/buildkit/tls/ca.pem"

[registry."docker.io"]
  mirrors = ["registry-1.docker.io"]
  
[cache]
  dir = "/.cache/buildkit"
  maxSize = "50GB"
  keepDuration = "168h"
EOF
```

## Phase 6: Automated Cache Management

### Step 10: Create Comprehensive Cache Cleanup System
```bash
# Create master cache cleanup script
sudo tee /usr/local/bin/cleanup-all-caches > /dev/null << 'EOF'
#!/bin/bash

# Global cache cleanup script
echo "Starting comprehensive cache cleanup..."

# Package manager caches
echo "Cleaning package manager caches..."
paccache -r -k 2 -c /.cache/pacman/pkg
yay -Sc --noconfirm

# Development tool caches
echo "Cleaning development tool caches..."
if command -v /home/peter/.local/bin/clean-pip-cache &> /dev/null; then
    /home/peter/.local/bin/clean-pip-cache
fi

if command -v /home/peter/.local/bin/clean-npm-cache &> /dev/null; then
    /home/peter/.local/bin/clean-npm-cache
fi

if command -v /home/peter/.local/bin/clean-cargo-cache &> /dev/null; then
    /home/peter/.local/bin/clean-cargo-cache
fi

if command -v /home/peter/.local/bin/clean-go-cache &> /dev/null; then
    /home/peter/.local/bin/clean-go-cache
fi

# Application caches
echo "Cleaning application caches..."
find /.cache/applications -name "*.log" -atime +7 -delete
find /.cache/applications -name "*.tmp" -atime +1 -delete

# Build caches
echo "Cleaning build caches..."
find /.cache/build -name "*.o" -atime +7 -delete
find /.cache/build -name "*.a" -atime +7 -delete

# Docker caches
echo "Cleaning Docker caches..."
docker system prune -af --volumes --filter "until=24h"
find /.cache/docker-tmp -type f -atime +1 -delete

# General cleanup
echo "General cache cleanup..."
find /.cache -name "*.tmp" -atime +1 -delete
find /.cache -name "*.log" -atime +7 -delete
find /.cache -type d -empty -delete

echo "Cache cleanup completed."

# Report cache usage
echo "Current cache usage:"
du -sh /.cache/*
EOF

sudo chmod +x /usr/local/bin/cleanup-all-caches

# Create comprehensive cache cleanup timer
sudo tee /etc/systemd/system/cleanup-all-caches.service > /dev/null << 'EOF'
[Unit]
Description=Comprehensive cache cleanup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cleanup-all-caches
EOF

sudo tee /etc/systemd/system/cleanup-all-caches.timer > /dev/null << 'EOF'
[Unit]
Description=Run comprehensive cache cleanup weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now cleanup-all-caches.timer
```

### Step 11: Cache Monitoring and Alerts
```bash
# Create cache monitoring script
tee /home/peter/.local/bin/monitor-cache-usage > /dev/null << 'EOF'
#!/bin/bash

# Cache usage monitoring script
CACHE_DIR="/.cache"
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90

# Get cache usage percentage
USAGE=$(df "$CACHE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

echo "Cache usage: ${USAGE}%"

if [ "$USAGE" -gt "$CRITICAL_THRESHOLD" ]; then
    echo "CRITICAL: Cache usage above ${CRITICAL_THRESHOLD}%"
    logger "Cache usage critical: ${USAGE}%"
    # Run emergency cleanup
    /usr/local/bin/cleanup-all-caches
elif [ "$USAGE" -gt "$WARNING_THRESHOLD" ]; then
    echo "WARNING: Cache usage above ${WARNING_THRESHOLD}%"
    logger "Cache usage warning: ${USAGE}%"
fi

# Display top cache consumers
echo "Top cache consumers:"
du -sh /.cache/* | sort -hr | head -10
EOF

chmod +x /home/peter/.local/bin/monitor-cache-usage

# Create cache monitoring service
sudo tee /etc/systemd/system/cache-monitor.service > /dev/null << 'EOF'
[Unit]
Description=Cache usage monitoring

[Service]
Type=oneshot
User=peter
ExecStart=/home/peter/.local/bin/monitor-cache-usage
EOF

sudo tee /etc/systemd/system/cache-monitor.timer > /dev/null << 'EOF'
[Unit]
Description=Monitor cache usage daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now cache-monitor.timer
```

## Phase 7: Performance Verification

### Step 12: Verify Cache Configuration
```bash
# Test cache configuration
echo "Testing cache configurations..."

# Test environment variables
env | grep -E "(CACHE|CARGO|PIP|NPM|GO)"

# Test package manager caches
pacman -Ss test-package 2>/dev/null | head -1
npm config get cache
pip cache dir
cargo cache

# Test Docker configuration
docker info | grep -A 5 "Docker Root Dir"

# Verify mount points
df -h | grep cache
ls -la /.cache/

echo "Cache configuration verification completed."
```

### Step 13: Performance Benchmarking
```bash
# Benchmark cache performance
tee /home/peter/.local/bin/benchmark-cache > /dev/null << 'EOF'
#!/bin/bash

echo "Benchmarking cache performance..."

# Test cache drive performance
echo "Cache drive sequential write test:"
dd if=/dev/zero of=/.cache/test-write bs=1M count=1000 conv=fdatasync 2>&1 | grep -E "(copied|MB/s)"

echo "Cache drive sequential read test:"
dd if=/.cache/test-write of=/dev/null bs=1M 2>&1 | grep -E "(copied|MB/s)"

# Clean up test file
rm -f /.cache/test-write

# Test random I/O performance
echo "Cache drive random I/O test:"
fio --name=cache-random --ioengine=libaio --iodepth=1 --rw=randrw --bs=4k --direct=1 --size=100M --numjobs=1 --runtime=10 --group_reporting --filename=/.cache/fio-test 2>/dev/null

# Clean up fio test file
rm -f /.cache/fio-test

echo "Cache performance benchmarking completed."
EOF

chmod +x /home/peter/.local/bin/benchmark-cache
```

## Summary and Benefits

### Configuration Benefits
1. **Optimized Storage Usage**: Cache files on appropriate SATA SSD storage
2. **Preserved Performance**: Samsung SSD 9100 PRO dedicated to active development
3. **Automated Management**: Comprehensive cleanup and monitoring
4. **Centralized Control**: Single location for all cache management
5. **Overflow Protection**: Docker and build tools have overflow capacity

### Expected Performance Impact
- **Development workspace**: Maximum I/O performance preserved
- **Build times**: Improved due to centralized cache management
- **System responsiveness**: Reduced wear on high-performance drives
- **Storage efficiency**: Automated cleanup prevents cache bloat

### Monitoring Commands
```bash
# Check cache usage
df -h /.cache

# Monitor cache contents
du -sh /.cache/*

# View cleanup logs
journalctl -u cleanup-all-caches.service

# Check automated services
systemctl list-timers | grep cache
```

This configuration ensures your high-performance Samsung SSD 9100 PRO remains dedicated to active development work while efficiently managing all cache operations on the appropriate SATA storage.