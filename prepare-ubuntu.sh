#!/bin/bash
set -euo pipefail

echo "[INFO] Installing Ubuntu build dependencies..."
sudo apt update -y
sudo apt install -y build-essential devscripts debhelper

echo "[INFO] Laying out Debian packaging tree..."
# Nothing else to do; run dpkg-buildpackage next
echo "[INFO] Build with: dpkg-buildpackage -us -uc -b"
