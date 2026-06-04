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
    *   Found in: `scripts/menu.sh` (as function), `install.sh` (manual `read -r`).
    *   Goal: Use the centralized function everywhere.
*   **Terminal Cleanup Trap**:
    *   Found in: `scripts/aiko.sh`, `install.sh`.
    *   Goal: Centralize the trap setup and escape sequences.

## 2. Global Variable Inconsistencies

Many scripts redefine path variables and environment settings independently.

*   **Color Codes**:
    *   Redefined in: `install.sh`, `scripts/diagnostics.sh`, `build.sh`, `sys/error_handler.sh`, `scripts/gpu_setup/src/generic_use/colors.sh`.
    *   Goal: Single source of truth for CLI colors.
*   **Path Resolution (`PROJECT_ROOT`, `WAYBAR_DIR`, `SOURCE_DIR`)**:
    *   Redefined in: Every major script.
    *   Issue: Some use `readlink -f`, some use hardcoded fallback paths.
    *   Goal: Centralized environment discovery sourced at the start of every script.
*   **Hardcoded Paths**:
    *   Issue: Literal `/home/watashi` exists in many files and relies on `sed` patching during installation.
    *   Goal: Use environment variables or relative paths calculated at runtime.
*   **Version Definition**:
    *   Found in: `scripts/aiko.sh`.
    *   Goal: Should be accessible globally by all components.

## 3. Structural & Design Issues

*   **Installer Bloat**: `install.sh` contains over 800 lines of mixed logic (UI, file copying, package management).
    *   Goal: Split into modules (e.g., `lib/packages.sh`, `lib/config_installer.sh`).
*   **Widget Redundancy**: Most widget scripts (`widgets/**/*.sh`) perform very similar tasks (checking for binary, python modules, and finding paths).
    *   Goal: Create a common widget launcher/wrapper or a shared bootstrapper to reduce boilerplate in each widget folder.
*   **Theme Management**: The system relies on `theme.css` symlinks in every widget folder.
    *   Goal: Centralize how widgets load themes (perhaps a global environment variable or a more robust dynamic loader).
*   **Dependency Management**: Dependency lists are hardcoded in `install.sh` and `scripts/diagnostics.sh`.
    *   Goal: Centralize the dependency manifest.
*   **Configuration Handling**: Scripts manually `grep`/`sed` configuration files.
    *   Goal: Standardize config reading/writing (perhaps using a simple key=value helper).

## 4. Specific Refactor Targets

*   **`scripts/menu.sh`**: This is a great modular base, but it's used inconsistently.
*   **`sys/error_handler.sh`**: Should be integrated into the central utility library.
*   **`scripts/gpu_setup/`**: Ensure this remains clean as it hands over the terminal.
