#!/usr/bin/env python3
"""Shift IconFonts/icons/Transport/*.ttf glyph U+0041 down in the em square (Y−).

Matches the old UI nudge (~3px at CONFIG.ICON_FONT.SIZE 14). Re-run after regenerating TTFs."""

from __future__ import annotations

import sys
from pathlib import Path

from fontTools.misc.transform import Transform
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

# Toolbar icon draw uses CONFIG.ICON_FONT.SIZE ≈ 14; prior code used +3 px downward.
PIXELS_DOWN = 3
REFERENCE_PX = 14

TRANSPORT_DIR = Path(__file__).resolve().parent.parent.parent / "IconFonts" / "icons" / "Transport"


def dy_font_units(font: TTFont) -> int:
    upem = int(font["head"].unitsPerEm)
    return -round(PIXELS_DOWN * upem / REFERENCE_PX)


def shift_glyph_a(ttf_path: Path) -> None:
    font = TTFont(str(ttf_path))
    cmap = font["cmap"].getBestCmap()
    if 0x41 not in cmap:
        raise SystemExit(f"{ttf_path.name}: no cmap entry for U+0041")
    gname = cmap[0x41]
    dy = dy_font_units(font)
    gs = font.getGlyphSet()
    pen = TTGlyphPen(gs)
    gs[gname].draw(TransformPen(pen, Transform(1, 0, 0, 1, 0, dy)))
    font["glyf"][gname] = pen.glyph()
    font.save(str(ttf_path))


def main() -> None:
    if not TRANSPORT_DIR.is_dir():
        print(f"Missing {TRANSPORT_DIR}", file=sys.stderr)
        sys.exit(1)
    for ttf in sorted(TRANSPORT_DIR.glob("*.ttf")):
        shift_glyph_a(ttf)
        print(ttf.name)


if __name__ == "__main__":
    main()
