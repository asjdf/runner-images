#!/bin/bash -e
################################################################################
##  File:  install-ms-repos.sh
##  Desc:  Install official Microsoft package repos for the distribution
################################################################################

# Wait for dpkg lock to be released
wait_for_dpkg_lock() {
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ! lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
           ! lsof /var/lib/dpkg/lock >/dev/null 2>&1 && \
           ! lsof /var/cache/apt/archives/lock >/dev/null 2>&1; then
            return 0
        fi
        
        echo "Waiting for dpkg lock to be released (attempt $attempt/$max_attempts)..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "Warning: dpkg lock still held after $max_attempts attempts, proceeding anyway..."
    return 0
}

os_label=$(lsb_release -rs)

# Wait for any existing dpkg operations to complete
wait_for_dpkg_lock

# Stop and disable automatic updates to prevent lock conflicts
systemctl stop apt-daily.timer 2>/dev/null || true
systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
systemctl stop apt-daily.service 2>/dev/null || true
systemctl stop apt-daily-upgrade.service 2>/dev/null || true

# Wait again after stopping services
wait_for_dpkg_lock

# Install Microsoft repository
wget https://packages.microsoft.com/config/ubuntu/$os_label/packages-microsoft-prod.deb

# Use dpkg wrapper if available, otherwise use dpkg directly with retry
if [ -f /usr/local/bin/dpkg ]; then
    /usr/local/bin/dpkg -i packages-microsoft-prod.deb
else
    # Retry logic for dpkg
    for i in {1..10}; do
        if dpkg -i packages-microsoft-prod.deb 2>&1 | grep -q "dpkg frontend lock"; then
            echo "dpkg lock detected, waiting and retrying (attempt $i/10)..."
            sleep 5
        else
            break
        fi
    done
fi

# update
apt-get install apt-transport-https ca-certificates curl software-properties-common
apt-get update
apt-get dist-upgrade
