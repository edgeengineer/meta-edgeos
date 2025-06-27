#!/bin/bash

UUID_FILE="/etc/edgeos/device-uuid"
SERVICE_FILE="/etc/avahi/services/edgeos-dns.service"

if [ -f "$UUID_FILE" ]; then
    UUID=$(cat "$UUID_FILE")
    sed -i "s/SOME_DEVICE_ID/$UUID/" "$SERVICE_FILE"
else
    echo "Error: UUID file not found"
    exit 1
fi 