#!/usr/bin/env bash

set -oue pipefail

# Dependencies
echo "[*] Installing runtime dependencies..."
dnf install -y gtk4 dbus sqlite librsvg2 gdk-pixbuf2

echo "[*] Installing build dependencies..."

# Capture currently installed packages to avoid removing pre-existing ones during cleanup
installed_before=$(rpm -qa --queryformat '%{NAME}\n' | sort)

dnf install -y rust cargo git gtk4-devel dbus-devel sqlite-devel librsvg2-devel gdk-pixbuf2-devel

# Capture newly installed packages
installed_after=$(rpm -qa --queryformat '%{NAME}\n' | sort)
newly_installed=$(comm -13 <(echo "$installed_before") <(echo "$installed_after"))

# Setup directories
echo "[*] Preparing build directories..."
git clone https://github.com/skxxtz/sherlock.git
cd sherlock

echo "[*] Building..."
cargo build --release
cp target/release/sherlock /usr/bin/

# Clean up
echo "[*] Cleaning up..."
if [ -n "$newly_installed" ]; then
    echo "[*] Removing newly installed development packages..."
    echo "$newly_installed" | xargs dnf remove -y
else
    echo "[*] No new packages to remove"
fi
cd ..
rm -rf sherlock

echo "[✓] Build and installation complete!"
