# DaVinci Resolve - Linux Mint

Install [DaVinci Resolve](https://www.blackmagicdesign.com/products/davinciresolve) on Linux Mint 22 with automatic dependency installation and library conflict resolution.

## Requirements

- **OS**: Linux Mint 22
- **DaVinci Resolve ZIP**: Downloaded from Blackmagic's website to `~/Downloads/`

## Quick Start

1. **Download DaVinci Resolve** from [blackmagicdesign.com](https://www.blackmagicdesign.com/products/davinciresolve)
   - Choose "DaVinci Resolve" (free) or "DaVinci Resolve Studio" (paid)
   - Select **Linux** and download the ZIP file
   - Save it to `~/Downloads/`

2. **Run the installer**:
```bash
git clone https://github.com/28allday/DaVinci-Resolve-Linux-Mint.git
cd DaVinci-Resolve-Linux-Mint
chmod +x DR_MINT.sh
./DR_MINT.sh
```

## What It Does

### 1. Installs FUSE Libraries

The Resolve installer is an AppImage-style archive that needs FUSE to mount itself. If FUSE isn't available, the script falls back to extracting the contents manually.

| Package | Purpose |
|---------|---------|
| `fuse` | FUSE kernel module and mount tools |
| `libfuse2` | Userspace library (`libfuse.so.2`) for AppImage support |

### 2. Installs Qt5 Libraries

Resolve's UI is built with Qt5. Linux Mint uses GTK (Cinnamon desktop) so Qt5 libraries aren't always present.

| Package | Purpose |
|---------|---------|
| `qtbase5-dev` + tools | Qt5 core framework |
| `libqt5core5a`, `libqt5gui5`, `libqt5widgets5` | Qt5 runtime libraries |
| `libqt5network5`, `libqt5dbus5` | Network and D-Bus communication |
| `libxrender1`, `libxrandr2`, `libxi6` | X11 rendering, monitor, and input extensions |
| `libxkbcommon-x11-0`, `libxcb-*` | Keyboard and X11 protocol libraries |
| `qtwayland5` | Wayland support |

### 3. Extracts and Runs Installer

- Finds the Resolve ZIP in `~/Downloads/`
- Extracts the ZIP to get the `.run` installer
- Tries running the installer with FUSE first
- Falls back to `--appimage-extract` if FUSE doesn't work
- Installs to `/opt/resolve`

### 4. Resolves Library Conflicts

Resolve bundles its own glib/gio libraries which conflict with Mint's newer system versions. The script:

| Library | Action | Why |
|---------|--------|-----|
| `libgio-2.0.so` | Moved to `not_used/` | Bundled version conflicts with system |
| `libgmodule-2.0.so` | Moved to `not_used/` | Bundled version conflicts with system |
| `libglib-2.0.so.0` | Replaced with system copy | Stable C ABI, safe to use system version |

### 5. Cleans Up

Removes the temporary extraction directory from `~/Downloads/`. The installed application stays at `/opt/resolve`.

## Files Installed

| Path | Purpose |
|------|---------|
| `/opt/resolve/` | Main application directory |
| `/opt/resolve/bin/resolve` | Resolve binary |
| `/opt/resolve/libs/` | Bundled libraries |
| `/opt/resolve/libs/not_used/` | Conflicting libraries moved out of the way |

## Troubleshooting

### Resolve won't start / crashes immediately

- Try launching from terminal to see errors: `/opt/resolve/bin/resolve`
- Check if GPU drivers are installed: `nvidia-smi` (NVIDIA) or `glxinfo | grep renderer` (AMD/Intel)

### "Cannot open display" or Qt plugin errors

The Qt environment variables may not be set. Try:
```bash
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms
/opt/resolve/bin/resolve
```

### Installer says "unsupported distribution"

The script sets `SKIP_PACKAGE_CHECK=1` to bypass this. If you still see it, the fallback extraction should handle it automatically.

### FUSE errors during installation

If you see FUSE-related errors, the script automatically falls back to `--appimage-extract`. No action needed.

### Missing library errors

Re-run the script — it will reinstall dependencies and redo the library conflict resolution.

## Updating Resolve

1. Download the new version ZIP from Blackmagic's website to `~/Downloads/`
2. Run the installer again:
```bash
./DR_MINT.sh
```

## Uninstalling

```bash
# Remove application
sudo rm -rf /opt/resolve

# Remove desktop entries (if created by Resolve's installer)
sudo rm -f /usr/share/applications/DaVinciResolve.desktop
rm -f ~/.local/share/applications/DaVinciResolve.desktop

# Remove user data (WARNING: deletes all projects and settings)
rm -rf ~/.local/share/DaVinciResolve
```

## Credits

- [Blackmagic Design](https://www.blackmagicdesign.com/) - DaVinci Resolve
- [Linux Mint](https://linuxmint.com/) - Target distribution

## License

This project is provided as-is.
