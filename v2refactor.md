# AikoHyprSetup V2 Refactor Roadmap

This document lists redundant functions, global variables, and structural issues identified in the codebase for the V2 refactor.

## 1. Redundant Utility Functions

Multiple scripts redefine the same or very similar helper functions. These should be centralized into a `scripts/lib/utils.sh` file.

*   **`have()` / `command_exists`**:
    *   Found in: `install.sh`, `scripts/wallpaper.sh`.
    *   Goal: Centralize into a single robust check function.
*   **Logging & Icons (`log`, `warn`, `error`, `success`, `die`)**:
    *   Found in: `install.sh`, `scripts/diagnostics.sh`, `scripts/wallpaper.sh`, `scripts/theme-selector.sh`.
    *   Inconsistency: Different prefix labels (e.g., `[install]`, `[diag]`, `[wallpaper]`) and icon sets.
    *   Goal: Create a standardized logging library with optional component labels.
*   **`confirm()` logic**:
    *   Investigation: `utils.sh` has a standard version, but `menu.sh` still carries its own redundant version, and `install.sh` uses manual `read -r` in some places.
    *   Goal: Use the centralized `confirm` function everywhere.
*   **Terminal Cleanup Trap**:
    *   Found in: `scripts/aiko.sh`, `install.sh`, `scripts/menu.sh`.
    *   Goal: Centralize the trap setup and escape sequences.

## 2. Global Variable Inconsistencies

Many scripts redefine path variables and environment settings independently.

*   **Color Codes**:
    *   Investigation: Redefined in `install.sh`, `scripts/diagnostics.sh`, `build.sh`, `sys/error_handler.sh`, `scripts/menu.sh`.
    *   Goal: Single source of truth for CLI colors via `utils.sh`.
*   **Path Resolution (`PROJECT_ROOT`, `WAYBAR_DIR`, `SOURCE_DIR`, `REPO_DIR`)**:
    *   Investigation: Every script uses a different naming convention and detection logic (`readlink` vs hardcoded fallback).
    *   Goal: Add a standard path discovery logic to `utils.sh` that exports a standard set of path variables.
*   **Hardcoded Paths**:
    *   Investigation: Literal `/home/watashi` found in 8 `.desktop` files in `configs/applications/`.
    *   Goal: Use environment variables or continue patching but with a clearly defined placeholder in source files.
*   **Version Definition**:
    *   Found in: `scripts/aiko.sh`.
    *   Goal: Move to a shared config or defined once in `utils.sh` for all components to access.

## 3. Structural & Design Issues

*   **Installer Bloat**: `install.sh` contains over 800 lines of mixed logic (UI, file copying, package management).
    *   Goal: Split into modules (e.g., `lib/packages.sh`, `lib/config_installer.sh`).
*   **Widget Redundancy**: Most widget scripts (`widgets/**/*.sh`) are 90% identical in their launching logic.
    *   Goal: Create a common widget launcher script or a shared bootstrapper.
*   **Un-standardized Scripts**: Found 25 shell scripts that still don't source `utils.sh`.
    *   Goal: Systematic refactor of all scripts in `scripts/` and `widgets/`.

## 4. Specific Refactor Targets

*   **`scripts/menu.sh`**: Needs to be refactored to use `utils.sh` variables and logging.
*   **`scripts/lib/utils.sh`**: Needs to expand to include path discovery and versioning.
