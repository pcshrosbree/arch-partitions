# BIOS Configuration Guide for Arch Linux Installation

## ASUS ROG CrossHair X870E Hero - BIOS Version 1512

### **IMPORTANT NOTE**: BIOS 1512 Update is Irreversible

**WARNING**: BIOS version 1512 cannot be rolled back to older versions. This update includes AGESA ComboAM5 PI 1.2.0.3e for upcoming CPU compatibility and enhanced system performance.

### Critical Settings for Optimal Performance

#### Boot Settings (Boot Tab)

- **Boot Mode**: UEFI only
  - **Setting Location**: Boot → Boot Mode Select → UEFI
  - **Alternative Names**: Boot Mode Select, UEFI/Legacy Boot
- **CSM (Compatibility Support Module)**: Disabled
  - **Setting Location**: Boot → CSM Support → Disabled
  - **Alternative Names**: Launch CSM, CSM Configuration, Legacy Support
- **Secure Boot**: Disabled (for initial installation)
  - **Setting Location**: Security → Secure Boot → Disabled
  - **Alternative Names**: Secure Boot Control, UEFI Secure Boot
- **Boot Device Priority**: USB first, then NVMe drives
  - **Setting Location**: Boot → Boot Option Priorities

#### CPU Configuration (Advanced → CPU Configuration)

- **CPU Frequency**: Auto or Manual overclock if desired
  - **Setting Location**: Extreme Tweaker → CPU Core Clock
- **Core Performance Boost**: Enabled
  - **Setting Location**: Advanced → CPU Configuration → Core Performance Boost
  - **Alternative Names**: CPB, Precision Boost
- **Precision Boost Overdrive (PBO)**: Enabled (for maximum performance)
  - **Setting Location**: Extreme Tweaker → Precision Boost Overdrive
  - **Alternative Names**: PBO, AMD PBO

#### Memory Settings (Extreme Tweaker)

##### For EXPO-Compatible Memory Kits

- **Memory Profile**: EXPO Profile I or II (for DDR5-6400 CL32)
  - **Setting Location**: Extreme Tweaker → Memory → EXPO
  - **Available Options**: EXPO I, EXPO II, EXPO Tweaked, EXPO on the fly
  - **Alternative Names**: AMD EXPO, Extended Profiles for Overclocking
- **Memory Timing**: Auto (let EXPO handle timing)
- **Memory Voltage**: Auto (typically 1.4V for DDR5-6400)
- **⚠️ Known Issue**: Some users report NVMe SSD recognition issues when EXPO is enabled in recent BIOS versions. If SSDs are not detected after enabling EXPO, temporarily disable EXPO to verify drives, then re-enable.

##### For Intel XMP-Only Memory Kits (CORSAIR VENGEANCE CMK96GX5M2B6400C32)

Since your CORSAIR VENGEANCE DDR5 96GB (2x48GB) 6400MHz CL32 kit is designed for Intel XMP and does not have AMD EXPO support, manual configuration is required:

**⚠️ Important**: Intel XMP profiles will not automatically work on AMD X870E motherboards. Manual configuration is essential for optimal performance and stability.

- **Memory Profile**: Disabled (do not enable EXPO for XMP-only kits)
  - **Setting Location**: Extreme Tweaker → Memory → EXPO → Disabled
- **Manual Memory Configuration**: Required
  - **Setting Location**: Extreme Tweaker → Memory → Memory Frequency
  
**Recommended Manual Settings for CMK96GX5M2B6400C32:**

**Conservative Starting Configuration (Recommended):**

- **Memory Frequency**: 6000 MT/s (safer than rated 6400 MT/s)
  - **Setting Location**: Extreme Tweaker → Memory → Memory Frequency → DDR5-6000
- **Primary Timings**: 32-39-39-77
  - **CAS Latency (tCL)**: 32
  - **tRCDRD**: 39  
  - **tRCDWR**: 39
  - **tRP**: 32
  - **tRAS**: 77
- **DRAM Voltage**: 1.35V
  - **Setting Location**: Extreme Tweaker → Memory → DRAM Voltage
- **FCLK (Fabric Clock)**: 2000 MHz (maintains 1:3 ratio with 6000 MT/s)
  - **Setting Location**: Extreme Tweaker → Memory → FCLK Frequency

**Advanced Configuration (After Stability Testing):**
Once the conservative settings are stable, you can attempt the kit's rated specifications:

- **Memory Frequency**: 6400 MT/s
- **Primary Timings**: 32-39-39-84 (from XMP profile)
- **DRAM Voltage**: 1.40V
- **FCLK**: 2133 MHz (maintains 1:3 ratio with 6400 MT/s)

**Additional Manual Settings:**

- **Memory Training**: Extended (allows more time for high-speed training)
  - **Setting Location**: Extreme Tweaker → Memory → Memory Training
- **Gear Mode**: Auto (let BIOS determine optimal gear for speed)
- **Command Rate**: Auto
- **Refresh Interval**: Auto (important for stability)

#### PCIe Configuration (Advanced → PCIe Configuration)

- **PCIe Speed**: Gen 5 for M.2_1, M.2_2, and M.2_3 slots
- **PCIEX16(G5)_1**: Gen 5 x16 (RTX 4060 Ti)
- **PCIEX16(G5)_2**: Gen 5 x8 (Intel X520-DA2)
- **M.2_1**: PCIe 5.0 x4 (TEAMGROUP T-Force Z540 4TB)
- **M.2_2**: PCIe 5.0 x4 (Samsung SSD 9100 PRO 4TB - Ultra-High Performance)
- **M.2_3**: PCIe 5.0 x4 (if used)
- **⚠️ Lane Sharing Note**:
  - When M.2_3 is enabled: PCIEX16_1 runs x8, PCIEX16_2 runs x4
  - When M.2_2 and M.2_3 are both enabled: PCIEX16_2 is disabled

#### Storage Configuration (Advanced → Storage Configuration)

- **SATA Mode**: AHCI
  - **Setting Location**: Advanced → Storage Configuration → SATA Mode
  - **Alternative Names**: SATA Controller Mode, SATA Operation
- **NVMe Support**: Enabled (usually enabled by default)
- **Hot Plug**: Enabled for all SATA ports
  - **Setting Location**: Advanced → Storage Configuration → SATA Hot Plug

#### Power Management (Advanced → APM Configuration)

- **CPU Power Management**: Enabled
  - **Alternative Names**: APM Configuration, Power Management
- **PCIe Power Management**: Disabled (for stability)
  - **Setting Location**: Advanced → PCIe Configuration → PCIe Power Management
  - **Alternative Names**: ASPM, Active State Power Management
- **USB Power Management**: Disabled (for development tools)
  - **Setting Location**: Advanced → USB Configuration → USB Power Management

#### Virtualization Settings (Advanced)

- **SVM Mode (AMD Virtualization)**: Enabled
  - **Setting Location**: Advanced → CPU Configuration → SVM Mode
  - **Alternative Names**: AMD-V, Secure Virtual Machine, AMD Virtualization Technology
- **IOMMU**: Enabled (for PCI passthrough and virtualization)
  - **Setting Location**: Advanced → North Bridge → IOMMU
  - **Alternative Names**: AMD-Vi, I/O Memory Management Unit
  - **Additional Setting**: May also find "IOMMU Mode" option
- **SR-IOV**: Enabled (for advanced networking)
  - **Setting Location**: Advanced → PCIe Configuration → SR-IOV Support
  - **Alternative Names**: Single Root I/O Virtualization

#### Advanced Memory Settings (Advanced → North Bridge)

- **Above 4GB Memory**: Enabled (usually enabled by default on 64-bit systems)
  - **Setting Location**: Advanced → North Bridge → Memory Configuration
  - **Alternative Names**: Memory Remap, Above 4G Decoding
- **Memory Hole**: Disabled
  - **Setting Location**: Advanced → North Bridge → Memory Hole Remapping
  - **Alternative Names**: Memory Hole at 15MB-16MB

### BIOS Navigation Tips

#### Primary BIOS Tabs

- **Main**: System information and basic settings
- **Extreme Tweaker**: Overclocking and performance settings (main tab for advanced tuning)
- **Advanced**: Advanced chipset and hardware configuration
- **Monitor**: Hardware monitoring and fan control
- **Boot**: Boot configuration and priorities
- **Security**: Security settings including Secure Boot
- **Tool**: BIOS utilities and tools

#### Advanced Sub-menus

- **CPU Configuration**: CPU-specific settings
- **North Bridge**: Memory and PCIe configuration
- **South Bridge**: SATA, USB, and other I/O settings
- **PCIe Configuration**: PCIe slots and lanes
- **Storage Configuration**: Storage controller settings
- **USB Configuration**: USB port and power settings

### Troubleshooting BIOS Settings

#### If Setting Not Found

1. **Check Alternative Names**: Use the alternative names provided above
2. **Search Function**: Use F7 or search function in BIOS to find settings
3. **Update BIOS**: Ensure you have BIOS 1512 (some settings may not exist in older versions)
4. **Reset to Defaults**: Load optimized defaults and reconfigure if settings are missing

#### Common Issues

- **IOMMU Not Visible**: Ensure CSM is disabled
- **EXPO Issues**: Try different EXPO profiles if one causes problems
- **PCIe Speed Not Available**: Check if all drives are properly connected
- **Virtualization Options Missing**: Update to latest BIOS version

### DDR5 Memory Configuration Deep Dive

#### Understanding XMP vs EXPO

- **XMP (Extreme Memory Profile)**: Intel technology for DDR5 memory overclocking
- **EXPO (Extended Profiles for Overclocking)**: AMD equivalent to XMP
- **Compatibility**: XMP kits can work on AMD motherboards but require manual configuration
- **Performance**: EXPO kits are optimized for AMD memory controllers

#### Memory Training and Boot Times

**⚠️ Expected Behavior**: AM5 systems with DDR5 take significantly longer to boot initially:

- **First Boot**: 5-10 minutes for memory training
- **Subsequent Boots**: 30-60 seconds normal boot time
- **Training Process**: CPU learns optimal timings for your specific memory modules
- **Patience Required**: Do not power cycle during training - wait at least 10 minutes

#### Memory Configuration Priority (Choose One Method)

**Method 1: EXPO-Compatible Kits**

1. Enable EXPO Profile I or II
2. Boot and verify stability
3. Fine-tune if needed

**Method 2: XMP-Only Kits (Like CMK96GX5M2B6400C32)**

1. Disable all memory profiles
2. Manually configure frequency and timings
3. Test stability at conservative settings first
4. Gradually increase performance

#### CORSAIR VENGEANCE CMK96GX5M2B6400C32 Specific Notes

**Kit Specifications:**

- **Capacity**: 96GB (2x48GB) - Massive capacity for development workloads
- **Speed**: DDR5-6400 MT/s rated
- **Timings**: 32-39-39-84 (XMP profile)
- **Voltage**: 1.40V rated
- **Memory Chips**: SK Hynix or Micron (varies by production batch)
- **Optimization**: Designed for Intel platforms, requires manual tuning on AMD

**Known Compatibility Issues:**

- Some X870E motherboards may refuse to boot above 4800 MT/s with high-capacity kits
- Memory training may take longer with 48GB modules
- Conservative settings recommended for initial configuration

**Troubleshooting High-Capacity Kits:**

1. **If System Won't Boot**: Start with JEDEC default (4800 MT/s)
2. **If Training Fails**: Increase DRAM voltage to 1.35V minimum
3. **If Instability Occurs**: Use looser timings (34-40-40-80)
4. **Memory Slot Configuration**: Use slots A2 and B2 (furthest from CPU)

#### Memory Timing Explanation

**Primary Timings (Most Important):**

- **tCL (CAS Latency)**: Time between command and data availability
- **tRCDRD**: Row to Column Delay (Read)
- **tRCDWR**: Row to Column Delay (Write)
- **tRP**: Row Precharge Time
- **tRAS**: Row Active Time

**For CMK96GX5M2B6400C32 Manual Configuration:**

```
Conservative: 32-39-39-32-77
Rated XMP:    32-39-39-32-84
Aggressive:   30-36-36-30-72 (requires testing)
```

#### Advanced Memory Settings

**FCLK (Fabric Clock) Optimization:**

- **DDR5-6000**: FCLK 2000 MHz (1:3 ratio) - Optimal
- **DDR5-6400**: FCLK 2133 MHz (1:3 ratio) - Good
- **Higher Speeds**: May require FCLK/2 mode (performance penalty)

**Memory Training Options:**

- **Normal**: Standard training time
- **Extended**: Longer training for better stability with difficult kits
- **Fast**: Shorter training (not recommended for manual overclocks)

#### Stability Testing Memory Configuration

**Basic Stability Test:**

1. Boot to BIOS successfully 3 times
2. Boot to OS and check memory detection
3. Run `free -h` to verify full 192GB detected

**Intermediate Testing:**

```bash
# Install memory testing tools
sudo pacman -S memtest86+

# Run memory test
sudo memtest86+
```

**Advanced Testing:**

```bash
# Stress test with multiple tools
sudo pacman -S stress-ng

# Memory stress test
stress-ng --vm 4 --vm-bytes 80G --timeout 300s
```

#### Memory Performance Optimization

**Memory Interleaving:**

- **Bank Interleaving**: Auto (improves performance)
- **Rank Interleaving**: Auto
- **Channel Interleaving**: Enabled

**Memory Refresh:**

- **Refresh Rate**: Auto (let BIOS optimize)
- **Refresh Interval**: Auto (critical for stability)

**Power Management:**

- **Memory Power Down**: Disabled (for maximum performance)
- **Gear Mode**: Auto (BIOS determines optimal gear)

### Pre-Installation Checklist

1. **Update BIOS**: Ensure you have version 1512 (irreversible update)
2. **Configure Memory**:
   - **EXPO Kits**: Enable appropriate EXPO profile
   - **XMP Kits**: Configure manually starting with conservative settings
3. **Verify Memory Detection**: Full 192GB should be detected in BIOS
4. **Test Memory Stability**: Boot successfully multiple times
5. **Configure Boot Priority**: USB first, then NVMe drives
6. **Disable Secure Boot**: Temporarily for installation
7. **Enable Virtualization**: SVM Mode and IOMMU for containers/VMs
8. **Verify Drive Detection**: All three drives should be visible
9. **Check Temperatures**: CPU and memory temperatures stable
10. **Verify PCIe Speeds**: Samsung SSD 9100 PRO at full Gen5 speed
11. **Document Settings**: Note any custom configurations for future reference

### Performance Verification

After configuring BIOS settings:

- **Memory Speed**: Should show DDR5-6400 in BIOS
- **PCIe Speeds**: M.2 slots should show Gen5 x4
- **Drive Detection**: All storage devices visible
- **Temperature Monitoring**: Verify thermal readings are normal
- **Boot Times**: Should achieve ~30 second boot to OS

### BIOS Features Specific to Version 1512

- **High-Resolution Display**: Supports 1920×1200 16:10 aspect ratio
- **Enhanced Memory Training**: Improved DDR5 compatibility and stability
- **Updated AGESA**: ComboAM5 PI 1.2.0.3e for future CPU support
- **Performance Improvements**: Enhanced system stability and performance
