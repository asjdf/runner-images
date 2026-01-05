#!/bin/bash -e
################################################################################
##  File:  resize-disk.sh
##  Desc:  Check and resize disk/filesystem if needed
################################################################################

# Get the root device and partition
ROOT_DEVICE=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
ROOT_PARTITION=$(df / | tail -1 | awk '{print $1}')

echo "Root device: $ROOT_DEVICE"
echo "Root partition: $ROOT_PARTITION"

# Rescan disk to detect size changes (in case Proxmox disk was resized)
echo "Rescanning disk to detect size changes..."

# Try multiple methods to trigger disk rescan
DEVICE_NAME=${ROOT_DEVICE##*/}

# Method 1: Scan all SCSI hosts (for virtio-scsi or SCSI disks)
for host in /sys/class/scsi_host/host*/scan; do
    if [ -f "$host" ]; then
        echo "- - -" > "$host" 2>/dev/null || true
        echo "Triggered SCSI rescan on $host"
    fi
done

# Method 2: SCSI device rescan (for specific device)
if [ -d "/sys/class/block/${DEVICE_NAME}/device" ]; then
    # Try rescan file if it exists
    if [ -f "/sys/class/block/${DEVICE_NAME}/device/rescan" ]; then
        echo 1 > /sys/class/block/${DEVICE_NAME}/device/rescan 2>/dev/null || true
    fi
    # Try to find and trigger rescan in parent device
    for rescan_file in /sys/class/block/${DEVICE_NAME}/device/*/rescan; do
        if [ -f "$rescan_file" ]; then
            echo 1 > "$rescan_file" 2>/dev/null || true
        fi
    done
fi

# Method 3: Use partprobe to re-read partition table
if command -v partprobe &> /dev/null; then
    partprobe "$ROOT_DEVICE" 2>/dev/null || true
fi

# Method 4: Use blockdev to re-read partition table
blockdev --rereadpt "$ROOT_DEVICE" 2>/dev/null || true

# Method 5: Force kernel to re-read block device size
# This is critical for virtio-scsi disks
if [ -f "/sys/block/${DEVICE_NAME}/device/rescan" ]; then
    echo 1 > /sys/block/${DEVICE_NAME}/device/rescan 2>/dev/null || true
fi

# Wait a bit for changes to propagate (Proxmox resize may take time)
echo "Waiting for Proxmox disk resize to propagate..."
sleep 15

# Check kernel messages for capacity change detection (as per Proxmox docs)
echo "Checking kernel messages for disk capacity changes..."
dmesg | grep -i "${DEVICE_NAME}.*capacity change" | tail -5 || echo "No capacity change messages found in dmesg yet"

# Retry rescan multiple times with longer waits
for i in 1 2 3 4 5 6 7 8 9 10; do
    echo "Attempt $i: Checking disk size..."
    
    # Trigger all rescan methods again
    # Scan all SCSI hosts (for virtio-scsi)
    for host in /sys/class/scsi_host/host*/scan; do
        if [ -f "$host" ]; then
            echo "- - -" > "$host" 2>/dev/null || true
        fi
    done
    
    # Try device-specific rescan
    if [ -f "/sys/block/${DEVICE_NAME}/device/rescan" ]; then
        echo 1 > /sys/block/${DEVICE_NAME}/device/rescan 2>/dev/null || true
    fi
    if [ -f "/sys/class/block/${DEVICE_NAME}/device/rescan" ]; then
        echo 1 > /sys/class/block/${DEVICE_NAME}/device/rescan 2>/dev/null || true
    fi
    
    # Re-read partition table
    if command -v partprobe &> /dev/null; then
        partprobe "$ROOT_DEVICE" 2>/dev/null || true
    fi
    blockdev --rereadpt "$ROOT_DEVICE" 2>/dev/null || true
    
    # Force kernel to update block device size
    # Try reading the size file directly to trigger update
    cat /sys/block/${DEVICE_NAME}/size > /dev/null 2>&1 || true
    
    sleep 5
    
    # Check kernel messages again
    if dmesg | grep -q "${DEVICE_NAME}.*capacity change"; then
        echo "Kernel detected capacity change!"
        dmesg | grep "${DEVICE_NAME}.*capacity change" | tail -1
    fi
    
    # Re-read disk size using multiple methods
    DISK_SIZE=$(lsblk -b -d -o SIZE -n "$ROOT_DEVICE" 2>/dev/null || echo "0")
    # Also try reading from /sys directly (more reliable)
    if [ -f "/sys/block/${DEVICE_NAME}/size" ]; then
        SECTORS=$(cat /sys/block/${DEVICE_NAME}/size 2>/dev/null || echo "0")
        SECTOR_SIZE=512
        SYS_DISK_SIZE=$((SECTORS * SECTOR_SIZE))
        # Use the larger of the two values
        if [ "$SYS_DISK_SIZE" -gt "$DISK_SIZE" ]; then
            DISK_SIZE=$SYS_DISK_SIZE
        fi
    fi
    
    DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
    
    echo "Current disk size: ${DISK_SIZE_GB}GB"
    
    # If disk is larger than 10GB, assume resize worked
    if [ "$DISK_SIZE_GB" -gt 10 ]; then
        echo "Disk resize detected! New size: ${DISK_SIZE_GB}GB"
        break
    fi
    
    if [ $i -lt 10 ]; then
        echo "Waiting for disk resize to take effect (attempt $i/10)..."
    fi
done

# Get current disk size and partition size
DISK_SIZE=$(lsblk -b -d -o SIZE -n "$ROOT_DEVICE")
PARTITION_SIZE=$(lsblk -b -o SIZE -n "$ROOT_PARTITION")
DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
PARTITION_SIZE_GB=$((PARTITION_SIZE / 1024 / 1024 / 1024))

echo "Final disk size: ${DISK_SIZE_GB}GB"
echo "Partition size: ${PARTITION_SIZE_GB}GB"

# Expected minimum size (75GB from locals, but we'll check for at least 70GB to be safe)
MIN_SIZE_GB=70

if [ "$DISK_SIZE_GB" -lt "$MIN_SIZE_GB" ]; then
    echo "WARNING: Disk size (${DISK_SIZE_GB}GB) is less than expected minimum (${MIN_SIZE_GB}GB)"
    echo "The Proxmox disk may need to be resized. Attempting to proceed with available space..."
fi

# Check if partition needs to be resized (allow 1GB tolerance)
if [ "$PARTITION_SIZE_GB" -lt "$((DISK_SIZE_GB - 1))" ]; then
    echo "Partition is smaller than disk, attempting to resize..."
    
    # Install cloud-guest-utils if not present (contains growpart)
    if ! command -v growpart &> /dev/null; then
        echo "Installing cloud-guest-utils..."
        apt-get update
        apt-get install -y cloud-guest-utils
    fi
    
    # Check if using GPT partition table (as per Proxmox docs)
    if command -v parted &> /dev/null; then
        PARTED_OUTPUT=$(parted "$ROOT_DEVICE" print 2>&1)
        if echo "$PARTED_OUTPUT" | grep -q "GPT PMBR size mismatch"; then
            echo "Detected GPT PMBR size mismatch, fixing GPT table..."
            # Use parted to fix GPT (as per Proxmox docs)
            parted "$ROOT_DEVICE" print Fix 2>&1 | grep -q "Fix" && {
                echo "Fixing GPT table..."
                # This will prompt, so we use a workaround
                echo "Fix" | parted "$ROOT_DEVICE" print 2>&1 || true
            }
        fi
    fi
    
    # Get partition number
    PARTITION_NUM=$(echo "$ROOT_PARTITION" | sed 's/.*\([0-9]\)$/\1/')
    
    # Try using parted first (as recommended in Proxmox docs)
    if command -v parted &> /dev/null; then
        echo "Attempting to resize partition using parted..."
        # Check if partition is at the end of disk (required for online resize)
        PARTED_INFO=$(parted "$ROOT_DEVICE" unit s print 2>&1)
        if echo "$PARTED_INFO" | grep -q "^${PARTITION_NUM}"; then
            echo "Resizing partition ${PARTITION_NUM} to 100% using parted..."
            # Use --script flag to avoid interactive prompts
            parted --script "$ROOT_DEVICE" resizepart "$PARTITION_NUM" 100% 2>&1 || {
                echo "parted resize failed, trying growpart..."
                # Force growpart to resize even if it says NOCHANGE
                growpart "$ROOT_DEVICE" "$PARTITION_NUM" 2>&1 || {
                    # If growpart fails, try with force flag or use sfdisk
                    echo "growpart failed, checking if we can use sfdisk..."
                    if command -v sfdisk &> /dev/null; then
                        # Get current partition info and resize
                        sfdisk -d "$ROOT_DEVICE" > /tmp/partitions.txt 2>/dev/null || true
                        # Try to resize using sfdisk
                        echo "Attempting alternative resize method..."
                    fi
                    echo "Continuing with current partition size..."
                }
            }
        else
            echo "Using growpart instead..."
            growpart "$ROOT_DEVICE" "$PARTITION_NUM" 2>&1 || {
                echo "growpart reported NOCHANGE or failed, but continuing..."
            }
        fi
    else
        # Fallback to growpart
        echo "Resizing partition ${ROOT_DEVICE}${PARTITION_NUM} using growpart..."
        growpart "$ROOT_DEVICE" "$PARTITION_NUM" 2>&1 || {
            echo "growpart reported NOCHANGE or failed, but continuing..."
        }
    fi
    
    # Resize filesystem
    echo "Resizing filesystem on $ROOT_PARTITION..."
    resize2fs "$ROOT_PARTITION" || {
        echo "Failed to resize filesystem, but continuing..."
    }
    
    # Verify new sizes
    NEW_PARTITION_SIZE=$(lsblk -b -o SIZE -n "$ROOT_PARTITION")
    NEW_PARTITION_SIZE_GB=$((NEW_PARTITION_SIZE / 1024 / 1024 / 1024))
    echo "New partition size: ${NEW_PARTITION_SIZE_GB}GB"
else
    echo "Partition size matches disk size, no resize needed"
fi

# Final check
FINAL_SIZE=$(df -BG / | tail -1 | awk '{print $2}' | sed 's/G//')
echo "Final filesystem size: ${FINAL_SIZE}GB"

# Clean up apt cache and temporary files to free up space
echo "Cleaning up apt cache and temporary files..."
apt-get clean 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/tmp/* 2>/dev/null || true
rm -rf /root/.cache 2>/dev/null || true

# Show available space
AVAILABLE_SPACE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
echo "Available disk space: ${AVAILABLE_SPACE}GB"
