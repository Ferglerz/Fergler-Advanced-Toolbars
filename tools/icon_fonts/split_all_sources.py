#!/usr/bin/env python3
"""Split every .ttf in IconFonts/_source_archive into IconFonts/icons/<stem>/."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def category_dir_name(source_stem: str) -> str:
    """Strip trailing _<digits> from archive filename stem (Tools_17 -> Tools)."""
    return re.sub(r"_\d+$", "", source_stem)

# Run as script: parent dir on path
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from split_category_font_to_per_icon import split_font_to_individual_as


def main() -> int:
    script_path = Path(__file__).resolve()
    working_copy = script_path.parents[2]
    icon_fonts = working_copy / "IconFonts"
    archive = icon_fonts / "_source_archive"
    icons_root = icon_fonts / "icons"

    if not archive.is_dir():
        print(f"Missing archive dir: {archive}", file=sys.stderr)
        return 1

    ttfs = sorted(archive.glob("*.ttf"))
    if not ttfs:
        print(f"No .ttf files in {archive}", file=sys.stderr)
        return 1

    icons_root.mkdir(parents=True, exist_ok=True)

    for inp in ttfs:
        out_dir = icons_root / category_dir_name(inp.stem)
        print(f"\n=== {inp.name} -> {out_dir.relative_to(icon_fonts)} ===")
        split_font_to_individual_as(inp, out_dir)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
