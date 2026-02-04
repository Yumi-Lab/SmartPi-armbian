#!/bin/bash
# DietPi Auto-Install Script
# Runs on first boot to transform Armbian into full DietPi
# 100% offline - all files are already in the image

DIETPI_REPO="/opt/dietpi-source"
INSTALLER="${DIETPI_REPO}/.build/images/dietpi-installer"
LOG_FILE="/var/log/dietpi-auto-install.log"
DONE_FLAG="/boot/dietpi/.auto-install-done"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Exit if already done
if [[ -f "$DONE_FLAG" ]]; then
    log "DietPi auto-install already completed, skipping"
    exit 0
fi

log "============================================"
log "DietPi Auto-Install Starting"
log "============================================"

# Check if DietPi repo exists
if [[ ! -f "$INSTALLER" ]]; then
    log "ERROR: DietPi installer not found at $INSTALLER"
    log "Please ensure DietPi repository was copied during image creation"
    exit 1
fi

log "Found DietPi installer at $INSTALLER"
log "Starting DietPi installation (this may take 15-30 minutes)..."

# Set environment variables for automated installation
export HW_MODEL=25                    # Generic Allwinner H3
export DISTRO_TARGET=7                # Debian Bookworm
export WIFI_REQUIRED=1                # WiFi support
export IMAGE_CREATOR='Yumi'           # Custom image creator
export PREIMAGE_INFO='SmartPi Armbian' # Pre-image info
export GITOWNER='MichaIng'            # DietPi repo owner
export GITBRANCH='master'             # DietPi branch

# Run the installer
log "Executing DietPi installer with:"
log "  HW_MODEL=$HW_MODEL (Generic Allwinner H3)"
log "  DISTRO_TARGET=$DISTRO_TARGET (Bookworm)"
log "  WIFI_REQUIRED=$WIFI_REQUIRED"

# PATCH INSTALLER FOR 100% OFFLINE MODE
log "Patching installer for 100% offline installation..."

# Create a wrapper script that uses local repo instead of downloading
cat > /tmp/dietpi-installer-offline.sh << 'EOFOFFLINE'
#!/bin/bash
# Wrapper for offline DietPi installation

# Change to temp directory where installer expects to work
cd /tmp || exit 1

# Create the DietPi source directory that installer expects
BRANCH="${GITBRANCH:-master}"
SOURCE_DIR="DietPi-${BRANCH//\//-}"

# If directory doesn't exist, copy from local repo
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Copying local DietPi repository to $SOURCE_DIR..."
    cp -r /opt/dietpi-source "$SOURCE_DIR"
    echo "Local repository copied successfully"
else
    echo "Using existing $SOURCE_DIR directory"
fi

# Modify the installer to skip download step
INSTALLER_COPY="/opt/dietpi-source/.build/images/dietpi-installer"
cp "$INSTALLER_COPY" /tmp/dietpi-installer-patched

# Patch: Comment out the curl download line (line 618)
sed -i '618s/^/# PATCHED FOR OFFLINE: /' /tmp/dietpi-installer-patched
# Patch: Comment out tar extraction (line 621)
sed -i '621s/^/# PATCHED FOR OFFLINE: /' /tmp/dietpi-installer-patched
# Patch: Comment out tar removal (line 622)
sed -i '622s/^/# PATCHED FOR OFFLINE: /' /tmp/dietpi-installer-patched

# Run the patched installer
bash /tmp/dietpi-installer-patched "$@"
EOFOFFLINE

chmod +x /tmp/dietpi-installer-offline.sh

if /tmp/dietpi-installer-offline.sh >> "$LOG_FILE" 2>&1; then
    log "DietPi installation completed successfully!"

    # Mark as done
    touch "$DONE_FLAG"
    chmod 644 "$DONE_FLAG"

    log "Created completion flag: $DONE_FLAG"
    log "System will reboot to complete DietPi setup"
    log "============================================"
    log "DietPi Auto-Install Finished"
    log "============================================"

    # Disable this service (one-time run)
    systemctl disable dietpi-auto-install.service 2>/dev/null || true

    # Reboot to complete DietPi setup
    sleep 5
    reboot
else
    log "ERROR: DietPi installation failed!"
    log "Check $LOG_FILE for details"
    log "System will NOT reboot automatically"
    exit 1
fi
