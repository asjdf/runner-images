#!/bin/bash -e
################################################################################
##  File:  resize-proxmox-disk.sh
##  Desc:  Resize Proxmox disk via API before resizing filesystem
################################################################################

# This script should be run on the Packer host, not inside the VM
# It uses Proxmox API to resize the disk

PROXMOX_URL="${PROXMOX_URL:-}"
PROXMOX_USERNAME="${PROXMOX_USERNAME:-}"
PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-}"
PROXMOX_NODE="${PROXMOX_NODE:-}"
VM_NAME="${VM_NAME:-}"
DISK_SIZE="${DISK_SIZE:-75G}"

if [ -z "$PROXMOX_URL" ] || [ -z "$PROXMOX_USERNAME" ] || [ -z "$PROXMOX_PASSWORD" ] || [ -z "$PROXMOX_NODE" ] || [ -z "$VM_NAME" ]; then
    echo "Missing required environment variables for Proxmox disk resize"
    exit 0  # Don't fail if variables are not set
fi

echo "Resizing Proxmox disk for VM $VM_NAME to $DISK_SIZE..."

# Get ticket for authentication
AUTH_RESPONSE=$(curl -s -k -d "username=${PROXMOX_USERNAME}&password=${PROXMOX_PASSWORD}" "${PROXMOX_URL}/access/ticket")
TICKET=$(echo "$AUTH_RESPONSE" | grep -o '"ticket":"[^"]*' | cut -d'"' -f4)
CSRF_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"CSRFPreventionToken":"[^"]*' | cut -d'"' -f4)

if [ -z "$TICKET" ]; then
    echo "Failed to authenticate with Proxmox API"
    exit 0  # Don't fail the build
fi

# Find VM by name
VM_LIST=$(curl -s -k -b "PVEAuthCookie=${TICKET}" "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu")

# Try to find VM by name using jq if available, otherwise use grep
if command -v jq &> /dev/null; then
    VM_ID=$(echo "$VM_LIST" | jq -r ".data[] | select(.name==\"${VM_NAME}\") | .vmid" | head -1)
else
    # Fallback to grep if jq is not available
    VM_ID=$(echo "$VM_LIST" | grep -A10 "\"name\":\"${VM_NAME}\"" | grep -o "\"vmid\":[0-9]*" | head -1 | cut -d':' -f2)
fi

if [ -z "$VM_ID" ] || [ "$VM_ID" = "null" ]; then
    echo "Could not find VM with name $VM_NAME"
    echo "Available VMs:"
    if command -v jq &> /dev/null; then
        echo "$VM_LIST" | jq -r '.data[] | "\(.vmid): \(.name)"'
    else
        echo "$VM_LIST" | grep -E '"vmid"|"name"' | head -20
    fi
    exit 0  # Don't fail the build
fi

echo "Found VM ID: $VM_ID"

# Get VM config to find the disk
VM_CONFIG=$(curl -s -k -b "PVEAuthCookie=${TICKET}" "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/config")

# Find the first disk (usually scsi0 or virtio0)
# Skip CDROM devices (ide2, ide3, etc. with media=cdrom)
# Try using jq first, then fallback to grep
if command -v jq &> /dev/null; then
    # Get all disk entries, filter out CDROM devices, prefer scsi/virtio over ide/sata
    DISK_KEY=$(echo "$VM_CONFIG" | jq -r '.data | to_entries | map(select(.key | test("^(scsi|virtio|ide|sata)[0-9]+$"))) | map(select(.value | contains("media=cdrom") | not)) | sort_by(.key) | .[0].key' 2>/dev/null)
    CURRENT_DISK_VALUE=$(echo "$VM_CONFIG" | jq -r ".data.${DISK_KEY}" 2>/dev/null)
else
    # Fallback: find first non-CDROM disk
    DISK_KEY=$(echo "$VM_CONFIG" | grep -oE '"(scsi|virtio|ide|sata)[0-9]+":[^,}]*' | grep -v 'media=cdrom' | head -1 | cut -d'"' -f2)
    CURRENT_DISK_VALUE=$(echo "$VM_CONFIG" | grep -oE "\"${DISK_KEY}\":\"[^\"]*" | head -1 | cut -d'"' -f4)
fi

if [ -z "$DISK_KEY" ] || [ "$DISK_KEY" = "null" ]; then
    echo "Could not find disk to resize"
    echo "VM config: $VM_CONFIG"
    exit 0  # Don't fail the build
fi

echo "Found disk: $DISK_KEY"
echo "Current disk configuration: $CURRENT_DISK_VALUE"

# Extract current size (format: size=3584M or size=75G)
CURRENT_SIZE_STR=$(echo "$CURRENT_DISK_VALUE" | grep -oE 'size=[0-9]+[MG]' | cut -d'=' -f2 || echo "")
if [ -z "$CURRENT_SIZE_STR" ]; then
    echo "Could not determine current disk size from config: $CURRENT_DISK_VALUE"
    echo "Using absolute size format: $DISK_SIZE"
    RESIZE_SIZE="${DISK_SIZE}"
else
    echo "Current disk size: $CURRENT_SIZE_STR"
    CURRENT_SIZE_NUM=$(echo "$CURRENT_SIZE_STR" | grep -oE '[0-9]+')
    CURRENT_SIZE_UNIT=$(echo "$CURRENT_SIZE_STR" | grep -oE '[MG]')
    
    # Get target size
    TARGET_SIZE_NUM=$(echo "$DISK_SIZE" | grep -oE '[0-9]+')
    TARGET_SIZE_UNIT=$(echo "$DISK_SIZE" | grep -oE '[MG]')
    
    # Convert current size to GB (approximate: 1024M = 1G)
    if [ "$CURRENT_SIZE_UNIT" = "M" ]; then
        # Convert MB to GB (divide by 1024, round up)
        CURRENT_SIZE_GB=$(( (CURRENT_SIZE_NUM + 1023) / 1024 ))
    else
        CURRENT_SIZE_GB=$CURRENT_SIZE_NUM
    fi
    
    # Target size in GB
    if [ "$TARGET_SIZE_UNIT" = "M" ]; then
        TARGET_SIZE_GB=$(( (TARGET_SIZE_NUM + 1023) / 1024 ))
    else
        TARGET_SIZE_GB=$TARGET_SIZE_NUM
    fi
    
    # Calculate increment needed
    if [ "$TARGET_SIZE_GB" -gt "$CURRENT_SIZE_GB" ]; then
        INCREMENT_GB=$((TARGET_SIZE_GB - CURRENT_SIZE_GB))
        RESIZE_SIZE="+${INCREMENT_GB}G"
        echo "Calculated increment: $RESIZE_SIZE (from ${CURRENT_SIZE_GB}G to ${TARGET_SIZE_GB}G)"
    else
        echo "Disk is already at or above target size (${CURRENT_SIZE_GB}G >= ${TARGET_SIZE_GB}G)"
        RESIZE_SIZE=""
    fi
fi

# Skip resize if no increment needed
if [ -z "$RESIZE_SIZE" ]; then
    echo "No resize needed, disk is already at target size"
    exit 0
fi

# Use extjs endpoint with PUT method (as shown in user's example)
# Convert /api2/json to /api2/extjs
EXTJS_URL=$(echo "$PROXMOX_URL" | sed 's|/api2/json|/api2/extjs|')
RESIZE_URL="${EXTJS_URL}/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/resize"

echo "Resizing disk ${DISK_KEY} by ${RESIZE_SIZE}..."
# URL encode the size parameter (especially the + sign)
RESIZE_SIZE_ENCODED=$(echo "$RESIZE_SIZE" | sed 's/+/%2B/g')
RESULT=$(curl -s -k -X PUT \
    -b "PVEAuthCookie=${TICKET}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    --data-raw "disk=${DISK_KEY}&size=${RESIZE_SIZE_ENCODED}" \
    "${RESIZE_URL}")

echo "API Response: $RESULT"

if echo "$RESULT" | grep -qi "error\|failed\|null"; then
    echo "Warning: Failed to resize disk via API: $RESULT"
    exit 0  # Don't fail the build, let the VM-side script handle it
else
    echo "Successfully resized Proxmox disk to $RESIZE_SIZE"
    echo "Waiting 10 seconds for Proxmox to process the resize..."
    sleep 10
    
    # Verify the resize by checking VM config again
    VM_CONFIG_AFTER=$(curl -s -k -b "PVEAuthCookie=${TICKET}" "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/config")
    if command -v jq &> /dev/null; then
        DISK_VALUE_AFTER=$(echo "$VM_CONFIG_AFTER" | jq -r ".data.${DISK_KEY}" 2>/dev/null)
    else
        DISK_VALUE_AFTER=$(echo "$VM_CONFIG_AFTER" | grep -oE "\"${DISK_KEY}\":\"[^\"]*" | head -1 | cut -d'"' -f4)
    fi
    if [ -n "$DISK_VALUE_AFTER" ] && [ "$DISK_VALUE_AFTER" != "null" ]; then
        echo "Disk configuration after resize: $DISK_VALUE_AFTER"
    fi
fi
