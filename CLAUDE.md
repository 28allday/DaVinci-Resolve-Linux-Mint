# CLAUDE.md - Project Memories

## Project Overview
- **What**: Bash installer script (`DR_MINT.sh`) for DaVinci Resolve on Linux Mint 22
- **Repo**: `28allday/DaVinci-Resolve-Linux-Mint`
- **Owner**: 28allday
- **License**: As-is (no formal license)

## Architecture
- Single bash script (`DR_MINT.sh`) — no other source files
- Script must be run with `sudo`; uses `logname`/`SUDO_USER` to resolve the real user
- Installs to `/opt/resolve`
- Expects DaVinci Resolve ZIP in `~/Downloads/`

## Script Flow (DR_MINT.sh)
1. Installs FUSE libraries (`fuse`, `libfuse2`)
2. Installs Qt5 libraries (extensive list for UI support)
3. Finds and extracts DaVinci Resolve ZIP from ~/Downloads/
4. Runs `.run` installer with FUSE; falls back to `--appimage-extract` if FUSE fails
5. Resolves library conflicts (moves bundled `libgio`/`libgmodule` to `not_used/`, copies system `libglib-2.0.so.0`)
6. Cleans up temp extraction directory

## Key Technical Details
- Uses `set -eo pipefail` for strict error handling
- `SKIP_PACKAGE_CHECK=1` bypasses Resolve's distro check (it only officially supports CentOS/RHEL)
- Qt env vars (`QT_QPA_PLATFORM_PLUGIN_PATH`, `QT_PLUGIN_PATH`, `LD_LIBRARY_PATH`) are set for installer GUI
- Library conflict: Resolve bundles old glib/gio that clash with Mint's newer system versions
- Does NOT touch bundled `libc++`/`libc++abi` — C++ ABI dependencies would break

## Code Quality
- Script has been through shellcheck review (PR #1)
- Fixes applied: pipefail added, privilege check fixed (`id -u` instead of `whoami`), glob safety for `libgio*`/`libgmodule*` patterns
- Comments are detailed and comprehensive

## Git History
- `ca4438d` — Initial commit
- `a6b1472` — Added detailed comments and README
- `024cb07` — Fixed security/robustness issues (shellcheck)
- `89b1d08` — Added video guide to README
- `987db8f` — Fixed pipefail, privilege check, glob safety (PR #1)
- `a8b494f` — Merged PR #1

## README
- Includes embedded YouTube video thumbnail linking to guide
- Comprehensive: requirements, quick start, what-it-does tables, troubleshooting, uninstall instructions
