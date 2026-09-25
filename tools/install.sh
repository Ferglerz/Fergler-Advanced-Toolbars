#!/bin/bash
# Copy runtime Lua and icon fonts into a REAPER installation.
set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${REAPER_TOOLBARS_DIR:-/Users/ferg/Desktop/REAPER/Scripts/Fergler/Advanced Toolbars}"
watch=false
rsync_options=(--prune-empty-dirs)
dry_run=false
destination_set=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch) watch=true ;;
        --dry-run) dry_run=true; rsync_options+=(--dry-run) ;;
        -h|--help)
            echo "Usage: bash tools/install.sh [--watch] [--dry-run] [destination]"
            echo "Default: \$REAPER_TOOLBARS_DIR or $destination"
            echo "Watch checks every second. Stop with Ctrl-C. Restart the REAPER action to load changes."
            exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *)
            if $destination_set; then
                echo "Only one destination may be supplied." >&2
                exit 2
            fi
            destination="$1"
            destination_set=true ;;
    esac
    shift
done

if [[ -z "$destination" ]]; then
    echo "Destination cannot be empty." >&2
    exit 2
fi

install_files() {
    # Explicit runtime roots exclude development tools and User settings.
    # No deletion: preserve custom widgets, fonts, and existing user files.
    rsync -rltci "${rsync_options[@]}" \
        --include='/Advanced Toolbars.lua' \
        --include='/Bootstrap/' --include='/Data/' --include='/IconFonts/' \
        --include='/Managers/' --include='/Menus/' --include='/Parsing/' \
        --include='/Renderers/' --include='/Systems/' --include='/Utils/' \
        --include='/Widgets/' --include='/Windows/' \
        --exclude='/*' --exclude='.*' --exclude='_source_archive/' \
        --include='*/' --include='*.lua' --include='*.ttf' --exclude='*' \
        "$source_dir/" "$destination/"
}

echo "Installing to: $destination"
if ! $dry_run; then
    mkdir -p "$destination"
fi
install_files
if $watch; then
    echo "Watching for changes every second (Ctrl-C to stop)."
    trap 'exit 0' INT TERM
    while sleep 1; do
        install_files
    done
fi
