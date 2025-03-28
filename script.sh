#!/bin/bash

# Set log file
LOG_FILE="/var/log/cleanup.log"

# Log function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Directory containing sensitive files
TARGET_DIR="/files/10 Files/Sensitive"
SMB_SHARE_PATH="/files"
SMB_SHARE_NAME="files"

# SMB server settings
SMB_CONF="/etc/samba/smb.conf"
MOUNT_POINT="/mnt/smb"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  exit 1  # Exit silently if the script is not run as root
fi

log "Started cleanup process."

# Stop SMB share and unmount if it's mounted
if mount | grep -q "$SMB_SHARE_PATH"; then
  umount "$MOUNT_POINT" &> /dev/null || { log "Failed to unmount SMB share."; exit 1; }
  log "Unmounted SMB share."
fi

# Remove SMB share configuration from smb.conf
if grep -q "$SMB_SHARE_NAME" "$SMB_CONF"; then
  sed -i "/\[$SMB_SHARE_NAME\]/,/^$/d" "$SMB_CONF" &> /dev/null
  log "Removed SMB share configuration from smb.conf."
fi

# Restart Samba service to apply changes
systemctl restart smbd &> /dev/null
if ! systemctl is-active smbd &> /dev/null; then
  log "Failed to restart Samba service."
  exit 1
fi
log "Samba service restarted."

# Check if the directory exists and securely remove the files
if [ -d "$TARGET_DIR" ]; then
"$TARGET_DIR" &> /dev/null
  find "$TARGET_DIR" -type f -exec shred -u -v {} \; &> /dev/null
  rm -rf "$TARGET_DIR" &> /dev/null
  log "Sensitive files securely erased and directory removed."
fi

# Shut down Tailscale VPN service
if tailscale status &> /dev/null; then
  tailscale down &> /dev/null || { log "Failed to stop Tailscale."; exit 1; }
  log "Tailscale service stopped."
fi

# CasaOS
CASA_SERVICES=(
  "casaos-app-management.service"
  "casaos-gateway.service"
  "casaos-local-storage.service"
  "casaos-message-bus.service"
  "casaos-user-service.service"
  "casaos.service"
)

for service in "${CASA_SERVICES[@]}"; do
  if systemctl list-units --type=service --all | grep -q "$service"; then
    systemctl stop "$service" &> /dev/null && log "Stopped $service."
  else
    log "WARNING: $service not found."
  fi
done

log "Cleanup process completed."
