# AikoHyprSetup

A versatile, highly aesthetic, and fully customizable environment for Hyprland and Waybar. Featuring multiple visual styles, interactive Python widgets, and a modular automation engine for a seamless desktop experience.

## 📦 Pre-built Artifacts (GitHub Releases)

If you don't want to clone the repository manually, you can download the latest stable build from the [Releases page](https://github.com/watashi-00/AikoHyprSetup/releases).

1. Go to the **Latest Release**.
2. Scroll down to the **Assets** section.
3. Download the version that suits you (`.tar.gz`, `.tar.xz`, or `.zip`).

Extract your preferred format and run the installer:

**For `.tar.gz`:**
```bash
tar -xzf AikoHyprSetup-*.tar.gz
cd AikoHyprSetup
./install.sh
```

**For `.tar.xz`:**
```bash
tar -xf AikoHyprSetup-*.tar.xz
cd AikoHyprSetup
./install.sh
```

**For `.zip`:**
```bash
unzip AikoHyprSetup-*.zip
cd AikoHyprSetup
./install.sh
```

## ✨ Features & Aiko CLI v2

AikoHyprSetup comes with a powerful global CLI command and a suite of interactive Python widgets that run right on your desktop. The setup is now completely modular, using a centralized utility library for consistent performance and design.

Once installed, you can use the `aiko` command from anywhere to manage your environment:

```bash
aiko --help         # Show all available commands
aiko --theme        # Open the interactive Theme Selector
aiko --wallpaper    # Open the interactive Wallpaper Selector
aiko --launcher     # Open application launcher (Wofi)
aiko --power        # Open stylized power menu
aiko --clip         # Open clipboard history
aiko --screenshot   # Open screenshot utility bar
aiko --diag         # Run system health and dependencies diagnostics
aiko --restart      # Reload Waybar and Hyprland
```

### 🧩 Interactive Widgets
The setup includes rich, standalone floating widgets for Waybar. They are now powered by a unified launcher that handles binary fallbacks and environment detection:
*   `aiko --note` : A sticky note app for quick thoughts.
*   `aiko --clock` : A beautiful oversized desktop clock.
*   `aiko --player` : A dedicated media player controller with cover art.
*   `aiko --usercard` : A customizable profile card (`aiko --edit-usercard` to configure).
*   `aiko --sys` : A system resource monitor (`aiko --edit-logo` to configure your distro logo).
*   `aiko --weather` & `aiko --list` : Weather and To-Do list integrations.

*Pro tip: Use `aiko --all` to launch the full widget dashboard at once!*

## 🤝 Contributing

Contributions are welcome! To maintain project stability, we use a structured workflow:

1.  **Default Branch**: The `test` branch is our default development branch. All Pull Requests should target `test`.
2.  **Protected Master**: The `master` branch is protected and reserved for stable releases. Merges to `master` require a Pull Request and at least one approving review.
3.  **Community Standards**: Please read our [Code of Conduct](CODE_OF_CONDUCT.md) and [Contributing Guidelines](CONTRIBUTING.md) before submitting.

## 🛠️ Structure and Locations
Repo Path: `./` | System Path: `~/.config/waybar/`

*   **`waybar/`**: Contains the bar configuration files (Top, Bottom, Left, Screenshot).
*   **`scripts/lib/`**: The core logic of V2. Contains modular scripts for system handling, packages, and configurations.
*   **`scripts/`**: Specialized helper scripts (Wallpaper, Theme Selector, Listeners).
*   **`widgets/`**: Standalone GTK/Python widgets.
*   **`themes/`**: Style definitions for all bars and widgets.

### 🎵 Media & Audio Scripts
*   **`scripts/spotify-art.sh`**: Downloads and displays the current album art.
*   **`scripts/spotify-info.sh`**: Returns "Artist - Title" for the main module.
*   **`scripts/audio-output.sh`** & **`scripts/audio-input.sh`**: Volume/Mute display and control.

## 🚀 Hyprland & System
*   **`configs/hypr/hyprland.conf`**: Base Hyprland configuration (binds, window rules).
*   **`scripts/minimize.sh`**: Script to manage window "minimization" in Hyprland.
*   **`scripts/screenshot.sh`**: Shortcut for taking screenshots (fullscreen or area) using `grim` and `slurp`.

## 📂 Other Apps (Backups)
*   **`configs/mako/config`**: Mako configuration (lightweight notifications).
*   **`configs/wofi/config`**: Base Wofi configuration.
*   **`configs/wofi/style.css`**: Wofi menu styling. This is a real file, not a symlink.
*   **`scripts/launcher.sh`**: Opens Wofi as an app launcher.
*   **`scripts/clipboard-history.sh`**: Opens clipboard history via Wofi (`cliphist`).
*   **`scripts/clipboard-listener.sh`**: Logs clipboard to `cliphist` using `wl-paste --watch`.

## 🔧 Maintenance
*   **`install.sh`**: Universal installer. Detects package managers, installs dependencies, copies payloads, and creates backups.
*   **`scripts/update-backups.sh`**: Script to sync system files (`~/.config/...`) back to this repository.

---

## 📦 Required Dependencies

### Core
*   **`hyprland`**, **`waybar`**, **`wofi`**, **`mako`**, **`hyprpaper`**, **`kitty`**, **`jq`**.

### Audio and Media
*   **`playerctl`**, **`cava`**, **`pipewire`**, **`pipewire-pulse`**/**`pipewire-pulseaudio`**, **`wireplumber`**, **`pavucontrol`**.
*   Volume scripts use `pactl`; Hyprland binds use `wpctl`.

### System Utilities
*   **`wl-clipboard`**, **`cliphist`**, **`libnotify`/`libnotify-bin`**, **`network-manager-applet`/`network-manager-gnome`**, **`grim`**, **`slurp`**, **`curl`**, **`hyprpicker`**, **`swappy`**, **`xdg-utils`**, **`bluez`**.
*   `hyprpicker`, `swappy`, `bluetoothctl`, `pavucontrol`, `cava`, and `nm-applet` are optional; the desktop works without them, but specific modules/shortcuts will lose functionality.

### Visuals (Fonts and Icons)
*   **JetBrains Mono Nerd Font** and **Font Awesome**.
*   Package names vary by distro: `ttf-jetbrains-mono-nerd`, `fonts-jetbrains-mono`, `jetbrains-mono-fonts`, `ttf-jetbrains-mono`; `ttf-font-awesome`, `fonts-font-awesome`, `fontawesome-fonts`, `font-awesome`.

---

## 📥 Universal Installer

Run from the root of this package:

```bash
./install.sh
```

Useful options:

```bash
./install.sh --dry-run      # simulates copies/installation
./install.sh --no-packages  # only installs configuration files
./install.sh --no-hypr      # does not overwrite ~/.config/hypr/hyprland.conf
```

The installer:

*   Detects `pacman`, `apt-get`, `dnf`, `zypper`, or `apk`.
*   Installs packages one by one and continues if a name doesn't exist in that distro version.
*   Copies:
    *   Waybar files to `~/.config/waybar/`;
    *   `configs/hypr/hyprland.conf` to `~/.config/hypr/hyprland.conf`;
    *   `configs/mako/*` to `~/.config/mako/`;
    *   `configs/wofi/*` to `~/.config/wofi/`.
*   Creates a timestamped backup before replacing existing files.
*   Normalizes old paths like `/home/watashi` to the user's `$HOME`.
*   Marks `.sh` scripts as executable.
*   At the end, offers a choice to `Reset interface` or `Exit`.

## 🧩 Package Matrix by Distro

| Family | Manager | Packages used by the installer |
| --- | --- | --- |
| Arch/Endeavour/Manjaro | `pacman` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard cliphist libnotify network-manager-applet grim slurp curl hyprpicker swappy xdg-utils bluez ttf-font-awesome ttf-jetbrains-mono-nerd polkit-kde-agent` |
| Debian/Ubuntu/Mint | `apt-get` | `hyprland waybar wofi mako-notifier hyprpaper kitty jq playerctl cava pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard cliphist libnotify-bin network-manager-gnome grim slurp curl hyprpicker swappy xdg-utils bluez fonts-font-awesome fonts-jetbrains-mono polkit-kde-agent-1` |
| Fedora | `dnf` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard cliphist libnotify NetworkManager-applet grim slurp curl hyprpicker swappy xdg-utils bluez fontawesome-fonts jetbrains-mono-fonts polkit-kde` |
| openSUSE | `zypper` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard cliphist libnotify-tools NetworkManager-applet grim slurp curl hyprpicker swappy xdg-utils bluez fontawesome-fonts jetbrains-mono-fonts polkit-kde-agent-6` |
| Alpine | `apk` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard cliphist libnotify network-manager-applet grim slurp curl hyprpicker swappy xdg-utils bluez font-awesome ttf-jetbrains-mono polkit-kde-agent` |

Not every version of every distro publishes Hyprland and all utilities in standard repos. The installer marks these as pending instead of aborting.

## 📦 Packaging Model

This directory is now the package root. To distribute, maintain this structure:

```text
.
├── install.sh
├── build.sh
├── README.md
├── LICENSE
├── configs/
├── scripts/
├── themes/
├── waybar/
├── widgets/
└── assets/
```

Important rules:

*   Do not use absolute paths from your user in source files.
*   Do not version symlinks pointing outside the package.
*   Everything Hyprland calls directly must exist in the package or be installed as a dependency.
*   External configs go into the `configs/` subfolder and `install.sh` decides the final destination.

---
*Updated on June 4, 2026.*
