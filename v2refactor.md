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

## 🚧 Step 3: Structural & Design Refactor (IN PROGRESS)
*   **Installer Modularization**: Split `install.sh` into smaller functional scripts (packages, configs, health).
*   **Widget Launcher Optimization**: Create a unified launcher script to replace the redundant `.sh` files in each widget folder.
*   **Configuration Library**: Create a shared helper for reading/writing config files consistently.

## 🔜 Step 4: Final Standardization & UX
*   Refactor smaller helper scripts in `scripts/`.
*   Review all Python widgets for consistent error handling and path usage.
*   Final testing and version bump to v2.0.0.
