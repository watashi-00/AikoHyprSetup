# AikoHyprSetup - Future Widget Ideas

This document contains a brainstorming list of "mini-apps" and widgets to be developed for the AikoHyprSetup environment. These components should integrate seamlessly with the dynamic theme system, utilizing Wofi, custom GTK scripts, or floating terminals.

## 1. Aiko-Note
A minimal, floating quick-note application (like a sticky note).
*   **Concept**: A borderless, themeable window that allows rapid text entry and saves state automatically.
*   **Implementation Idea**: A simple Python/GTK script or a heavily customized `wofi` input field.

## 2. Aiko-Sys
A system status monitor dashboard.
*   **Concept**: A popup panel showing detailed CPU, RAM, GPU usage, and temperatures, styled consistently with the active theme.
*   **Implementation Idea**: A bash script utilizing `top`, `free`, and `sensors`, piped into a formatted `wofi` or `yad` dialog.

## 3. Aiko-Search
An advanced search utility.
*   **Concept**: Goes beyond standard application launching. Allows direct web searches (e.g., prefixing with `g:` for Google, `y:` for YouTube) or file finding.
*   **Implementation Idea**: Wrapping `wofi` with a custom bash script that parses the input and determines the action.

## 4. Aiko-Calendar
An interactive, theme-aware calendar.
*   **Concept**: A visual calendar popup, possibly linked to the Waybar clock module.
*   **Implementation Idea**: Utilizing `cal` or a Python script to generate a formatted grid, displayed in a centered floating window.

---
*Feel free to add more ideas here as the project evolves.*
