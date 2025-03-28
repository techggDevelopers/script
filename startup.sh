#!/bin/bash
echo "Startup script executed at $(date)" | tee -a /tmp/startup.log
env | tee -a /tmp/startup.log
