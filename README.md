# Hyprland & Waybar Pink Anime Setup

This repository contains a complete and aesthetic configuration for Hyprland and Waybar, focusing on usability and a "pink anime" visual style. It includes automation scripts, a universal installer, and support for multiple modules.

## 🛠️ Structure and Locations
Repo Path: `./` | System Path: `~/.config/waybar/`

*   **`config.jsonc`**: Main configuration file (Top Bar). Defines modules like clock, battery, and spotify.
*   **`config-bottom.jsonc`**: Bottom bar configuration (dock/pill style).
*   **`config-left.jsonc`**: Left sidebar configuration (experimental).
*   **`config-screenshot.jsonc`**: Simplified floating bar used during screenshots or HUD.
*   **`style.css`**: Global CSS for all bars. Controls colors, animations, and the "pink anime" look.
*   **`restart-waybar.sh`**: Script to kill and restart Waybar applying all configurations.

### 🎵 Media & Audio Scripts
*   **`spotify-art.sh`**: Downloads and displays the current album art.
*   **`spotify-info.sh`**: Returns "Artist - Title" for the main module.
*   **`spotify-playstate.sh`**: Dynamic Play/Pause icons.
*   **`audio-output.sh`** & **`audio-input.sh`**: Volume/Mute display and control for outputs and microphones.

## 🚀 Hyprland & System
*   **`hypr-config/hyprland.conf`**: Backup of the main Hyprland configuration (binds, window rules).
*   **`hyprland.conf.sample`**: Example base configuration.
*   **`minimize.sh`**: Script to manage window "minimization" in Hyprland.
*   **`screenshot.sh`**: Shortcut for taking screenshots (fullscreen or area) using `grim` and `slurp`.

## 📂 Other Apps (Backups)
*   **`mako-config/config`**: Mako configuration (lightweight notifications).
*   **`wofi-config/config`**: Base Wofi configuration.
*   **`wofi-config/style.css`**: Wofi menu styling. This is a real file, not a symlink.
*   **`launcher.sh`**: Opens Wofi as an app launcher.
*   **`clipboard-history.sh`**: Opens clipboard history via Wofi (`cliphist`).
*   **`clipboard-listener.sh`**: Logs clipboard to `cliphist` using `wl-paste --watch`.

## 🔧 Maintenance
*   **`install.sh`**: Universal installer. Detects package managers, installs dependencies, copies payloads, and creates backups.
*   **`update-backups.sh`**: Script to sync system files (`~/.config/...`) back to this repository.

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
    *   `hypr-config/hyprland.conf` to `~/.config/hypr/hyprland.conf`;
    *   `mako-config/*` to `~/.config/mako/`;
    *   `wofi-config/*` to `~/.config/wofi/`.
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
├── config*.jsonc
├── style.css
├── *.sh
├── hypr-config/
├── mako-config/
└── wofi-config/
```

Important rules:

*   Do not use absolute paths from your user in source files.
*   Do not version symlinks pointing outside the package.
*   Everything Hyprland calls directly must exist in the package or be installed as a dependency.
*   External configs go into subfolders (`hypr-config`, `mako-config`, `wofi-config`) and `install.sh` decides the final destination.

---
*Updated on 05/30/2026.*
