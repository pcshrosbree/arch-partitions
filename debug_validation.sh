#!/bin/bash

# Debug Storage Validation
# Simple debug version to identify the issue

echo "=== DEBUG STORAGE VALIDATION ==="
echo ""

# Test basic functionality
echo "1. Testing basic shell functionality..."
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "2. Testing counter increment..."
((TOTAL_TESTS++))
echo "Total tests: $TOTAL_TESTS"

echo "3. Testing device paths..."
PRIMARY_NVME="/dev/nvme0n1"
SECONDARY_NVME="/dev/nvme1n1"
BULK_SATA="/dev/sda"

echo "Primary NVMe: $PRIMARY_NVME"
echo "Secondary NVMe: $SECONDARY_NVME"
echo "Bulk SATA: $BULK_SATA"

echo "4. Testing block device detection..."
if [[ -b "$PRIMARY_NVME" ]]; then
    echo "✓ Primary NVMe exists"
    ((PASSED_TESTS++))
else
    echo "✗ Primary NVMe missing"
    ((FAILED_TESTS++))
fi

echo "5. Testing partitions..."
if [[ -b "${PRIMARY_NVME}p1" ]]; then
    echo "✓ EFI partition exists"
else
    echo "✗ EFI partition missing"
fi

if [[ -b "${PRIMARY_NVME}p2" ]]; then
    echo "✓ Root partition exists"
else
    echo "✗ Root partition missing"
fi

echo "6. Current block devices:"
lsblk

echo "7. Current mounts:"
mount | head -10

echo "8. Test completed successfully!"
echo "Passed: $PASSED_TESTS, Failed: $FAILED_TESTS, Total: $TOTAL_TESTS"
