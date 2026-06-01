# AikoHyprSetup

A highly aesthetic Pink Anime configuration for Hyprland and Waybar, featuring interactive automation scripts and a seamless user experience.

## 📦 Pre-built Artifacts (GitHub Actions)

If you don't want to clone the repository manually, you can download the latest automated build generated directly from the `master` branch.

1. Go to the [Actions tab](https://github.com/watashi-00/AikoHyprSetup/actions) in this repository.
2. Click on the latest successful **Build and Package** workflow run.
3. Scroll down to the **Artifacts** section and download `AikoHyprSetup-Builds`.

This artifact contains three formats (`.tar.gz`, `.tar.xz`, and `.zip`). Extract your preferred format and run the installer:

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

## 🛠️ Structure and Locations
Repo Path: `./` | System Path: `~/.config/waybar/`

*   **`waybar/config.jsonc`**: Main configuration file (Top Bar). Defines modules like clock, battery, and spotify.
*   **`waybar/config-bottom.jsonc`**: Bottom bar configuration (dock/pill style).
*   **`waybar/config-left.jsonc`**: Left sidebar configuration (experimental).
*   **`waybar/config-screenshot.jsonc`**: Simplified floating bar used during screenshots or HUD.
*   **`themes/style.css`**: Global CSS for all bars. Controls colors, animations, and the "pink anime" look.
*   **`scripts/restart-waybar.sh`**: Script to kill and restart Waybar applying all configurations.

### 🎵 Media & Audio Scripts
*   **`scripts/spotify-art.sh`**: Downloads and displays the current album art.
*   **`scripts/spotify-info.sh`**: Returns "Artist - Title" for the main module.
*   **`scripts/spotify-playstate.sh`**: Dynamic Play/Pause icons.
*   **`scripts/audio-output.sh`** & **`scripts/audio-input.sh`**: Volume/Mute display and control for outputs and microphones.

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
*Updated on June 1, 2026.*
