# AikoHyprSetup - Future Widget Ideas

This document contains a brainstorming list of "mini-apps" and widgets to be developed for the AikoHyprSetup environment. These components should integrate seamlessly with the dynamic theme system, utilizing Wofi, custom GTK scripts, or floating terminals.

## 1. Aiko-Search
An advanced search utility.
*   **Concept**: Goes beyond standard application launching. Allows direct web searches (e.g., prefixing with `g:` for Google, `y:` for YouTube) or file finding.
*   **Implementation Idea**: Wrapping `wofi` with a custom bash script that parses the input and determines the action.

## 2. Aiko-Calendar
An interactive, theme-aware calendar.
*   **Concept**: A visual calendar popup, possibly linked to the Waybar clock module.
*   **Implementation Idea**: Utilizing `cal` or a Python script to generate a formatted grid, displayed in a centered floating window.

## 3. Aiko-Timer
A minimalist countdown and Pomodoro timer.
*   **Concept**: A small, floating timer for productivity, with notifications when time is up.
*   **Implementation Idea**: A Python/GTK script with a simple progress ring or a floating terminal running a custom timer script.

## 4. Aiko-Bluetooth
A streamlined Bluetooth device manager.
*   **Concept**: Quickly connect/disconnect known devices without opening a full settings app.
*   **Implementation Idea**: A `wofi` menu wrapping `bluetoothctl` for scanning and managing connections.

## 5. Aiko-Recorder
A simple screen and audio recording interface.
*   **Concept**: A tiny control panel to start/stop recording, select areas, and toggle microphone.
*   **Implementation Idea**: Wrapping `wf-recorder` or `gpu-screen-recorder` with a custom floating UI.

## 6. Aiko-LiveWallpaper (Wallpaper Engine Integration)
Study how Wallpaper Engine implements live wallpapers and make it work on Linux.
*   **Concept**: Enable the use of dynamic, animated, or interactive Scene/Web/Video wallpapers (like those from Steam's Wallpaper Engine).
*   **Implementation Idea**: Research tools like `linux-wallpaperengine` or custom background window layers (using mpv or webview wrappers) and integrate them into the wallpaper/theme selector.

---
*Feel free to add more ideas here as the project evolves.*
