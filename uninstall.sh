#!/usr/bin/env bash

echo "Uninstalling MTProtoMax Metrics Viewer..."
echo ""

if [ "$EUID" -ne 0 ]; then
   echo "ERROR: Please run as root"
   echo "Usage: sudo bash uninstall.sh"
   exit 1
fi

echo "Removing files..."
rm -rf /root/Metrics
rm -f /usr/local/bin/metrics
rm -f /usr/local/bin/metrics-live

echo ""
echo "Uninstall complete!"
echo ""
