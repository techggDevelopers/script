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

# Stop SMB share and unmount if mounted
if mount | grep -q "$SMB_SHARE_PATH"; then
  umount "$MOUNT_POINT" &> /dev/null || log "WARNING: Failed to unmount SMB share."
  log "Unmounted SMB share."
fi

# Remove SMB share configuration from smb.conf
if grep -q "$SMB_SHARE_NAME" "$SMB_CONF"; then
  sed -i "/\[$SMB_SHARE_NAME\]/,/^$/d" "$SMB_CONF" &> /dev/null || log "WARNING: Failed to modify smb.conf."
  log "Removed SMB share configuration from smb.conf."
fi

# Restart Samba service
systemctl restart smbd &> /dev/null
if ! systemctl is-active smbd &> /dev/null; then
  log "WARNING: Failed to restart Samba service."
else
  log "Samba service restarted."
fi

# Securely remove sensitive files
if [ -d "$TARGET_DIR" ]; then
  find "$TARGET_DIR" -type f -exec shred -u -v {} \; &> /dev/null || log "WARNING: Failed to shred files."
  rm -rf "$TARGET_DIR" &> /dev/null || log "WARNING: Failed to remove directory."
  log "Sensitive files securely erased and directory removed."
else
  log "WARNING: Target directory does not exist."
fi

# Shut down Tailscale VPN service
if tailscale status &> /dev/null; then
  tailscale down &> /dev/null || log "WARNING: Failed to stop Tailscale."
  log "Tailscale service stopped."
else
  log "Tailscale is not running."
fi

# Stop CasaOS services
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
    systemctl stop "$service" &> /dev/null && log "Stopped $service." || log "WARNING: Failed to stop $service."
  else
    log "WARNING: $service not found."
  fi
done

log "Cleanup process completed."
