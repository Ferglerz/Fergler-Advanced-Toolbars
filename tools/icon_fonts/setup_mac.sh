#!/usr/bin/env bash
# One-time setup on macOS for svg_folder_to_per_icon_ttfs.py (FontForge + fonttools).
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Install Homebrew first: https://brew.sh" >&2
  exit 1
fi

brew install fontforge

PY="${PYTHON:-}"
if [[ -z "$PY" ]]; then
  if [[ -x /opt/homebrew/bin/python3 ]]; then
    PY=/opt/homebrew/bin/python3
  elif [[ -x /usr/local/bin/python3 ]]; then
    PY=/usr/local/bin/python3
  else
    PY="$(command -v python3 || true)"
  fi
fi

if [[ -z "$PY" ]]; then
  echo "No python3 found." >&2
  exit 1
fi

echo "Using: $PY"
"$PY" -m pip install --user -U fonttools

if ! "$PY" -c "import fontforge" 2>/dev/null; then
  echo "fontforge module not importable with $PY." >&2
  echo "Try: export PYTHON=/path/to/homebrew/bin/python3" >&2
  echo "Or run: $(brew --prefix fontforge 2>/dev/null)/bin/python3 -c 'import fontforge'" >&2
  exit 1
fi

echo "OK: fontforge and fonttools available."
"$PY" -c "import fontforge; import fontTools; print('fontforge OK, fonttools OK')"
