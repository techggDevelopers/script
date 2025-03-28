#!/bin/bash

# Set log file
LOG_FILE="/var/log/restore.log"

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

log "Started restore process."

# Restore SMB share configuration if missing
if ! grep -q "[$SMB_SHARE_NAME]" "$SMB_CONF"; then
  echo "[$SMB_SHARE_NAME]" >> "$SMB_CONF"
  echo "   path = $SMB_SHARE_PATH" >> "$SMB_CONF"
  echo "   browseable = yes" >> "$SMB_CONF"
  echo "   read only = no" >> "$SMB_CONF"
  echo "   guest ok = no" >> "$SMB_CONF"
  log "Restored SMB share configuration."
fi

# Restart Samba service
systemctl restart smbd &> /dev/null
if systemctl is-active smbd &> /dev/null; then
  log "Samba service restarted."
else
  log "WARNING: Failed to restart Samba service."
fi

# Recreate sensitive files directory
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR" && log "Recreated sensitive files directory." || log "WARNING: Failed to recreate directory."
else
  log "Directory already exists."
fi

# Restart Tailscale service if installed
if command -v tailscale &> /dev/null; then
  systemctl restart tailscaled &> /dev/null
  if systemctl is-active tailscaled &> /dev/null; then
    log "Tailscale service restarted."
  else
    log "WARNING: Failed to restart Tailscale."
  fi
else
  log "Tailscale not installed."
fi

# Start CasaOS services
CASA_SERVICES=(
  "casaos-app-management.service"
  "casaos-gateway.service"
  "casaos-local-storage.service"
  "casaos-message-bus.service"
  "casaos-user-service.service"
  "casaos.service"
)

for service in "${CASA_SERVICES[@]}"; do
  systemctl start "$service" &> /dev/null && log "Started $service." || log "WARNING: Failed to start $service."
done

log "Restore process completed."
