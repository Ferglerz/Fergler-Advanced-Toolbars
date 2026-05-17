#!/usr/bin/env python3
"""Shift lock icon TTF glyph U+0041 down in the em square (Y−), matching shift_transport_icons_down.

Same nudge as Transport (~3px at 14px toolbar icon size). Re-run after regenerating TTFs.

Skips files already processed (private table ZShf marker) unless --force. Restore from backup to re-run without --force."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from fontTools.misc.transform import Transform
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables.DefaultTable import DefaultTable

# Match shift_transport_icons_down.py
PIXELS_DOWN = 3
REFERENCE_PX = 14

# Private marker: do not double-shift in place
_MARKER_TAG = "ZShf"
_MARKER_DATA = b"ATBgl1"  # Advanced Toolbars glyph lock shift v1


def _defaults() -> list[Path]:
    root = Path(__file__).resolve().parent.parent.parent
    return [
        root / "IconFonts" / "icons" / "Tools" / "Lock Closed.ttf",
        root / "IconFonts" / "icons" / "Tools" / "Lock Open.ttf",
        Path("/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Fergler/Envelope Brush Tool/Lock Closed.ttf"),
        Path("/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Fergler/Envelope Brush Tool/Lock Open.ttf"),
    ]


def dy_font_units(font: TTFont) -> int:
    upem = int(font["head"].unitsPerEm)
    return -round(PIXELS_DOWN * upem / REFERENCE_PX)


def _already_marked(font: TTFont) -> bool:
    try:
        t = font.get(_MARKER_TAG)
        return t is not None and getattr(t, "data", None) == _MARKER_DATA
    except KeyError:
        return False


def _set_marker(font: TTFont) -> None:
    tab = DefaultTable(_MARKER_TAG)
    tab.data = _MARKER_DATA
    font[_MARKER_TAG] = tab


def shift_lock_font(ttf_path: Path, *, force: bool) -> bool:
    """Return True if glyph was shifted and file saved."""
    if not ttf_path.is_file():
        print(f"missing: {ttf_path}", file=sys.stderr)
        return False

    font = TTFont(str(ttf_path))
    if not force and _already_marked(font):
        print(f"skip (already shifted): {ttf_path.name}")
        return False

    cmap = font["cmap"].getBestCmap()
    if 0x41 not in cmap:
        raise SystemExit(f"{ttf_path.name}: no cmap entry for U+0041")

    gname = cmap[0x41]
    dy = dy_font_units(font)
    gs = font.getGlyphSet()
    pen = TTGlyphPen(gs)
    gs[gname].draw(TransformPen(pen, Transform(1, 0, 0, 1, 0, dy)))
    font["glyf"][gname] = pen.glyph()
    _set_marker(font)
    font.save(str(ttf_path))
    print(ttf_path)
    return True


def main() -> None:
    ap = argparse.ArgumentParser(description="Shift U+0041 down in lock icon TTFs (same as Transport).")
    ap.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="Extra .ttf paths (default set runs if omitted)",
    )
    ap.add_argument("--force", action="store_true", help="Shift even if marker table is present")
    args = ap.parse_args()

    todo: list[Path] = [p.resolve() for p in args.paths] if args.paths else _defaults()
    for p in todo:
        shift_lock_font(p, force=args.force)
    if not args.paths:
        exists = [p for p in todo if p.is_file()]
        if not exists:
            print("No default lock TTF paths found.", file=sys.stderr)
            sys.exit(1)



if __name__ == "__main__":
    main()
