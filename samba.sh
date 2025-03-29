#!/bin/bash
set -e
mkdir /files
samba_conf="/etc/samba/smb.conf"
samba_dir="/files"
share_name="files"
# prompt for usernames
read -p "Enter the Samba username (e.g., admin): " smb_user

# Password prompt
read -s -p "Enter the Samba password: " smb_pass
echo
read -s -p "Confirm the Samba password: " smb_pass_confirm
echo

# Password check
if [ "$smb_pass" != "$smb_pass_confirm" ]; then
  echo "❌ Passwords do not match. Aborting."
  exit 1
fi

# Ensure directory exists
if [ ! -d "$samba_dir" ]; then
  echo "📁 Directory does not exist. Creating it..."
  mkdir -p "$samba_dir"
fi

# Backup original smb.conf
cp "$samba_conf" "$samba_conf.bak"

# Extract only the [global] section
awk -v RS= -v ORS="\n\n" '!/\['"$share_name"'\]/' "$samba_conf.bak" > "$samba_conf"

# Ensure username map is enabled
if ! grep -q "username map = /etc/samba/smbusers" "$samba_conf"; then
  sed -i '/^\[global\]/a username map = /etc/samba/smbusers' "$samba_conf"
fi

# Append new share block
cat >> "$samba_conf" <<EOL

[$share_name]
   path = $samba_dir
   read only = no
   browsable = yes
   guest ok = no
   writable = yes
   valid users = $smb_user
   create mask = 0755
   directory mask = 0755
EOL

# Create system user if not present
if ! id -u "$smb_user" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "$smb_user"
fi

# Set directory permissions
chown -R "$smb_user:$smb_user" "$samba_dir"
chmod -R 770 "$samba_dir"

# Update /etc/samba/smbusers mapping
grep -v "^$smb_user =" /etc/samba/smbusers 2>/dev/null > /tmp/smbusers.tmp || true
echo "$smb_user = $smb_user" >> /tmp/smbusers.tmp
mv /tmp/smbusers.tmp /etc/samba/smbusers

# Add user to Samba
( echo "$smb_pass"; echo "$smb_pass" ) | smbpasswd -a -s "$smb_user"

# Restart services
systemctl restart smbd nmbd

echo "✅ Samba share [$share_name] created at $samba_dir, accessible to user '$smb_user'. All previous shares removed."
