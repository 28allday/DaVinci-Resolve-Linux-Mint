#!/bin/bash
# ==============================================================================
# DaVinci Resolve Installer for Linux Mint 22
#
# DaVinci Resolve is a professional video editing suite by Blackmagic Design.
# It's distributed as a self-extracting .run file inside a ZIP archive.
# This script automates the installation on Linux Mint 22, handling:
#   - FUSE library installation (needed for the AppImage-style installer)
#   - Qt5 library installation (Resolve's UI depends on Qt5)
#   - ZIP extraction and installer execution
#   - Fallback AppImage extraction if FUSE isn't working
#   - Library conflict resolution (bundled glib/gio vs system versions)
#
# Prerequisites:
#   - Linux Mint 22
#   - DaVinci Resolve Linux ZIP downloaded to ~/Downloads/
#     (download from https://www.blackmagicdesign.com/products/davinciresolve)
#   - Internet connection (for installing packages)
#
# Usage:
#   chmod +x DR_MINT.sh
#   ./DR_MINT.sh
# ==============================================================================

set -eo pipefail  # Exit immediately if any command fails; catch pipe failures too

# Ensure the script is run with root privileges (needed for apt, chown, etc.)
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run with sudo (e.g., sudo ./DR_MINT.sh)."
    exit 1
fi

# Resolve the real user even when running with sudo. logname returns the
# user who originally logged in, not "root". This ensures we look for the
# ZIP in the correct home directory and set proper file ownership.
ACTIVE_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
HOME_DIR=$(getent passwd "$ACTIVE_USER" | cut -d: -f6)
DOWNLOADS_DIR="$HOME_DIR/Downloads"
EXTRACTION_DIR="/opt/resolve"
ZIP_FILE_PATTERN="DaVinci_Resolve_*.zip"

# ==================== Step 1: FUSE Libraries ====================
#
# The Resolve .run installer is an AppImage-style archive that normally
# uses FUSE (Filesystem in Userspace) to mount itself and run. Linux Mint
# doesn't always have FUSE installed by default.
#
# We need two things:
#   - fuse:     The FUSE kernel module and mount tools
#   - libfuse2: The userspace library (libfuse.so.2) that AppImages link against
#
# If FUSE still doesn't work after installation (e.g. in a container or
# restricted environment), the script falls back to --appimage-extract later.
echo "Checking for FUSE and libfuse.so.2..."
if ! dpkg -s fuse libfuse2 >/dev/null 2>&1; then
    echo "Installing FUSE..."
    sudo apt update
    sudo apt install -y fuse libfuse2
fi

if [ ! -f /lib/x86_64-linux-gnu/libfuse.so.2 ]; then
    echo "Error: libfuse.so.2 is not found. Installing libfuse2..."
    sudo apt install -y libfuse2
fi

# ==================== Step 2: Qt5 Libraries ====================
#
# DaVinci Resolve's UI is built with Qt5. On Linux Mint, the required Qt5
# packages aren't always installed because Mint uses GTK (Cinnamon desktop).
#
# These packages provide:
#   - qtbase5-dev + tools:     Qt5 core framework and build tools
#   - libqt5core/gui/widgets:  Qt5 runtime libraries for the UI
#   - libqt5network/dbus:      Network and D-Bus communication
#   - libxrender/xrandr/xi:    X11 rendering, monitor, and input extensions
#   - libxkbcommon-x11:        Keyboard handling under X11
#   - libxcb-*:                X11 protocol libraries (low-level display comms)
#   - qtwayland5:              Wayland support (if running under Wayland)
echo "Installing required Qt libraries..."
sudo apt install -y qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5dbus5 \
libxrender1 libxrandr2 libxi6 libxkbcommon-x11-0 libxcb-xinerama0 libxcb-xfixes0 qtwayland5 libxcb-glx0 libxcb-util1

# ==================== Step 3: Find the ZIP ====================
#
# The user must download the Resolve ZIP manually from Blackmagic's website
# (they require filling out a registration form). We look for it in
# ~/Downloads/ which is where browsers save files by default.
echo "Navigating to Downloads directory..."
if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "Error: Downloads directory not found at $DOWNLOADS_DIR."
    exit 1
fi
cd "$DOWNLOADS_DIR"

# ==================== Step 4: Extract ZIP ====================
#
# The download is a ZIP containing a .run file (self-extracting installer).
# We extract it to a temporary DaVinci_Resolve/ directory, set ownership
# to the real user (not root), and make files executable.
echo "Extracting DaVinci Resolve installer..."
ZIP_FILE=$(find . -maxdepth 1 -type f -name "$ZIP_FILE_PATTERN" -print -quit)
if [ -z "$ZIP_FILE" ]; then
    echo "Error: DaVinci Resolve ZIP file not found in $DOWNLOADS_DIR."
    exit 1
fi

unzip -o "$ZIP_FILE" -d DaVinci_Resolve/
chown -R "$ACTIVE_USER:$ACTIVE_USER" DaVinci_Resolve
chmod -R u+rwX,go+rX DaVinci_Resolve

# ==================== Step 5: Run Installer ====================
#
# The .run file is an AppImage-style self-extracting archive. We try two
# approaches:
#
#   1. Run it normally with FUSE (-a flag for auto/silent install)
#      SKIP_PACKAGE_CHECK=1 bypasses Resolve's built-in distro check
#      (it only officially supports CentOS/RHEL, not Mint)
#
#   2. If FUSE fails, fall back to --appimage-extract which extracts the
#      contents without needing FUSE, then manually move them to /opt/resolve
#
# Qt environment variables are set so the installer can find the system's
# Qt5 plugins for rendering its UI.
echo "Running the DaVinci Resolve installer..."
cd "$DOWNLOADS_DIR/DaVinci_Resolve"
INSTALLER_FILE=$(find . -type f -name "DaVinci_Resolve_*.run" -print -quit)
if [ -z "$INSTALLER_FILE" ]; then
    echo "Error: DaVinci Resolve installer (.run) file not found in extracted directory."
    exit 1
fi

chmod +x "$INSTALLER_FILE"

# Tell Qt where to find platform plugins so the installer GUI can render.
# QT_DEBUG_PLUGINS=1 prints diagnostic info if plugins fail to load.
export QT_DEBUG_PLUGINS=1
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms
export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Try FUSE-based install first, fall back to manual extraction
if ! SKIP_PACKAGE_CHECK=1 ./"$INSTALLER_FILE" -a; then
    echo "FUSE is not functional. Extracting AppImage contents..."
    ./"$INSTALLER_FILE" --appimage-extract || { echo "Error: AppImage extraction failed"; exit 1; }
    if [ ! -d "squashfs-root" ] || [ -z "$(ls -A squashfs-root)" ]; then
        echo "Error: Extraction produced empty directory"; exit 1
    fi
    sudo mkdir -p "$EXTRACTION_DIR"
    sudo cp -a squashfs-root/. "$EXTRACTION_DIR/"
    sudo chown -R root:root "$EXTRACTION_DIR"
    rm -rf squashfs-root
fi

# ==================== Step 6: Library Conflict Resolution ====================
#
# Resolve bundles its own versions of glib/gio/gmodule libraries, but these
# are often older than what Linux Mint provides. The bundled versions can
# cause crashes or "symbol not found" errors when they conflict with
# system libraries that other parts of Resolve also load.
#
# The fix: move Resolve's bundled gio and gmodule out of the way, and
# copy the system's glib into Resolve's lib directory. This is safe because
# glib has a very stable C ABI — newer versions are backwards-compatible.
#
# NOTE: We do NOT touch Resolve's bundled libc++/libc++abi — those have
# C++ ABI dependencies and replacing them would cause crashes.
echo "Resolving library conflicts..."
if [ -d "$EXTRACTION_DIR/libs" ]; then
    cd "$EXTRACTION_DIR/libs"
    sudo mkdir -p not_used
    for lib in libgio* libgmodule*; do
        [ -e "$lib" ] && sudo mv "$lib" not_used/
    done

    if [ -f /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0 ]; then
        sudo cp /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0 "$EXTRACTION_DIR/libs/"
    else
        echo "Warning: System library libglib-2.0.so.0 not found. Ensure compatibility manually."
    fi
else
    echo "Error: Installation directory $EXTRACTION_DIR/libs not found. Skipping library conflict resolution."
fi

# ==================== Step 7: Cleanup ====================
#
# Remove the temporary extraction directory from ~/Downloads/.
# The installed application stays at /opt/resolve.
echo "Cleaning up installation files..."
cd "$DOWNLOADS_DIR"
rm -rf DaVinci_Resolve

echo "DaVinci Resolve installation completed successfully!"