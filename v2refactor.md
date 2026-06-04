# AikoHyprSetup v2.0.0 - Refactor Status

## ✅ Step 1: Centralizing Utility Functions (COMPLETED)
*   Standardized colors, icons, and logging in `scripts/lib/utils.sh`.
*   Centralized `have()` and `confirm()` functions.
*   Standardized terminal cleanup and escape sequence management.
*   Refactored all core scripts: `aiko.sh`, `install.sh`, `diagnostics.sh`, `wallpaper.sh`, `theme-selector.sh`, `menu.sh`.

## ✅ Step 2: Global Variable & Path Standardization (COMPLETED)
*   Single source of truth for `AIKO_VERSION` in `utils.sh`.
*   Unified path discovery logic (`get_aiko_paths`) in `utils.sh` providing `AIKO_ROOT`, `AIKO_SCRIPTS`, etc.
*   Replaced hardcoded home paths in source files with `@HOME@` placeholder.
*   Core scripts now use standardized variables instead of independent resolution logic.

## ✅ Step 3: Structural & Design Refactor (COMPLETED)
*   **Installer Modularization**: Split `install.sh` into smaller functional scripts in `scripts/lib/` (`system.sh`, `packages.sh`, `configs.sh`, `health.sh`).
*   **Unified Widget Launcher**: Created `scripts/lib/widget_launcher.sh` which handles all widgets, including toggling and fallbacks.
*   **Cleaned Launchers**: Updated all `.desktop` files and Hyprland keybindings to use the global `aiko` command.
*   **Reduced Boilerplate**: Removed all redundant `.sh` files from widget directories.

## ✅ Step 4: Final Standardization & UX (COMPLETED)
*   Standardized logic-heavy helper scripts in `scripts/` (`launcher.sh`, `icon-gen.sh`, `screenshot.sh`, etc.) to use `utils.sh`.
*   Verified path consistency in Python widgets.
*   Updated `restart-waybar.sh` to use unified launcher logic.
*   **Official Version Bump**: Project upgraded to **v2.0.0**.
