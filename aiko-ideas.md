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

---
*Feel free to add more ideas here as the project evolves.*
