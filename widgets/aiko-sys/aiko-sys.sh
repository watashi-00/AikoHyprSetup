#!/usr/bin/env bash

# Launch Aiko System monitor widget
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/aiko-sys.py"
