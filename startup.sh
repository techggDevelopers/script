#!/bin/bash

# Define log file
LOG_FILE="/var/log/startup-script.log"

# Ensure the log file exists and is writable
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Write timestamp and execution message to log file
echo "$(date '+%Y-%m-%d %H:%M:%S') - Script Executed" >> "$LOG_FILE"
