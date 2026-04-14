#!/usr/bin/env python3
"""
Build one TrueType font per SVG in a folder, matching existing per-icon FontIcons:

  - Single glyph mapped to U+0041 ('A'), same as IconFonts/icons/** and Utils/icon_fonts.lua
  - Name table: family/full/font name "FontIcons" (consistent with fonts generated via FontForge)

Uses the FontForge Python API the same way as https://github.com/carrasti/pysvg2font
(FontforgeFont.add_character / importOutlines). Requires:

  - apt: fontforge, python3-fontforge (Linux)
  - pip: pysvg2font (optional; used as the reference implementation; generation is in this script)

Example:

  python3 svg_folder_to_per_icon_ttfs.py \\
    "/path/to/SVG for Toolbars" \\
    ../../IconFonts/icons/Toolbar
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

try:
    import fontforge
except ImportError as e:
    raise SystemExit(
        "fontforge Python module is required (e.g. Ubuntu: "
        "sudo apt-get install fontforge python3-fontforge)"
    ) from e

# Match split_category_font_to_per_icon.py / Advanced Toolbars per-icon convention
TARGET_UNICODE = 0x41  # "A"
KERN = 15


class FontIconsPerGlyphFont:
    """One SVG -> one .ttf with glyph at U+0041, FontIcons naming (see Magnet.ttf)."""

    def __init__(self) -> None:
        self.font = fontforge.font()
        self.font.familyname = "FontIcons"
        self.font.fullname = "FontIcons"
        self.font.fontname = "FontIcons"

    def add_glyph_from_svg(self, svg_path: os.PathLike[str] | str) -> None:
        g = self.font.createChar(TARGET_UNICODE)
        g.importOutlines(os.fspath(svg_path))
        g.left_side_bearing = KERN
        g.right_side_bearing = KERN

    def save(self, path: os.PathLike[str] | str) -> None:
        self.font.generate(os.fspath(path))


def stem_to_output_name(stem: str) -> str:
    """Same base name as the SVG file, uppercased (user request)."""
    return f"{stem.upper()}.ttf"


def collect_svgs(directory: Path) -> list[Path]:
    """Non-recursive *.svg, sorted case-insensitively by stem."""
    svgs = sorted(directory.glob("*.svg"), key=lambda p: p.stem.lower())
    return svgs


def main() -> int:
    p = argparse.ArgumentParser(
        description="Convert each top-level .svg in a folder to its own FontIcons-style .ttf."
    )
    p.add_argument(
        "svg_dir",
        type=Path,
        help="Directory containing .svg files (non-recursive)",
    )
    p.add_argument(
        "output_dir",
        type=Path,
        help="Directory to write .ttf files into (created if missing)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="List planned outputs without writing files",
    )
    args = p.parse_args()

    svg_dir = args.svg_dir.resolve()
    if not svg_dir.is_dir():
        print(f"Not a directory: {svg_dir}", file=sys.stderr)
        return 1

    out_dir = args.output_dir.resolve()
    svgs = collect_svgs(svg_dir)
    if not svgs:
        print(f"No .svg files in {svg_dir}", file=sys.stderr)
        return 1

    collisions: dict[str, list[Path]] = {}
    for svg in svgs:
        name = stem_to_output_name(svg.stem)
        collisions.setdefault(name, []).append(svg)

    dupes = {k: v for k, v in collisions.items() if len(v) > 1}
    if dupes:
        for out_name, paths in sorted(dupes.items()):
            print(
                f"Duplicate output after uppercasing: {out_name} <- "
                + ", ".join(str(x) for x in paths),
                file=sys.stderr,
            )
        return 1

    if args.dry_run:
        for svg in svgs:
            print(f"{svg.name} -> {out_dir / stem_to_output_name(svg.stem)}")
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)

    # Windows-reserved / awkward names — rare for icons; strip trailing dots/spaces
    bad_tail = re.compile(r"[. ]+$")

    for svg in svgs:
        stem = svg.stem
        if bad_tail.search(stem):
            stem = bad_tail.sub("", stem)
        out_name = stem_to_output_name(stem)
        dest = out_dir / out_name
        font = FontIconsPerGlyphFont()
        try:
            font.add_glyph_from_svg(svg)
            font.save(dest)
        except Exception as e:
            print(f"Failed {svg}: {e}", file=sys.stderr)
            return 1
        print(f"{svg.name} -> {dest}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
