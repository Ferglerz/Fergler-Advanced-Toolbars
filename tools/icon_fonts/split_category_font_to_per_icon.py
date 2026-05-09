#!/usr/bin/env python3
"""
Split a multi-glyph category TTF into one TTF per mapped Unicode code point.
Each output font maps its single icon glyph to U+0021 ('!'), matching the
Advanced Toolbars per-icon runtime convention (see docs/ICON_FONT_ONE_TTF_PER_ICON_PLAN.md).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont

DEFAULT_TARGET_UNICODE = 0x21  # '!'


def split_font_to_individual_as(
    input_path: Path,
    output_folder: Path,
    *,
    target_unicode: int = DEFAULT_TARGET_UNICODE,
    skip_controls: bool = True,
) -> None:
    output_folder.mkdir(parents=True, exist_ok=True)

    base = TTFont(input_path)
    unicode_map = dict(base.getBestCmap() or {})
    base.close()

    if not unicode_map:
        print(f"No cmap entries in {input_path}", file=sys.stderr)
        return

    for char_code in sorted(unicode_map.keys()):
        if skip_controls and char_code < 32:
            continue
        glyph_name = unicode_map[char_code]
        try:
            options = Options()
            options.layout_features = ["*"]
            subsetter = Subsetter(options=options)
            subsetter.populate(unicodes={char_code})

            new_font = TTFont(input_path)
            subsetter.subset(new_font)

            post = new_font.getBestCmap() or {}
            if not post:
                print(f"Skip U+{char_code:04X}: empty cmap after subset", file=sys.stderr)
                new_font.close()
                continue
            if len(post) > 1:
                # Prefer the codepoint we asked for
                gname = post.get(char_code)
                if gname is None:
                    (_, gname) = next(iter(post.items()))
            else:
                (_, gname) = next(iter(post.items()))

            for table in new_font["cmap"].tables:
                table.cmap = {target_unicode: gname}

            out = output_folder / f"U{char_code:04X}.ttf"
            new_font.save(os.fspath(out))
            new_font.close()
            print(f"Exported U+{char_code:04X} ({glyph_name!r}) -> '!' at {out}")
        except Exception as e:
            print(f"Could not process U+{char_code:04X}: {e}", file=sys.stderr)


def main() -> int:
    p = argparse.ArgumentParser(
        description="Split a category icon font into per-icon TTFs with glyph at U+0021."
    )
    p.add_argument("input_ttf", type=Path, help="Source multi-glyph .ttf")
    p.add_argument(
        "output_dir",
        type=Path,
        nargs="?",
        default=None,
        help="Output folder (default: <input_stem>_per_icon next to input)",
    )
    p.add_argument(
        "--target-unicode",
        type=lambda x: int(x, 0),
        default=DEFAULT_TARGET_UNICODE,
        help="Remap glyph to this code point (default: 0x21 / '!')",
    )
    p.add_argument(
        "--include-controls",
        action="store_true",
        help="Also emit fonts for cmap code points below U+0020",
    )
    args = p.parse_args()

    inp = args.input_ttf.resolve()
    if not inp.is_file():
        print(f"Not a file: {inp}", file=sys.stderr)
        return 1

    out_dir = args.output_dir
    if out_dir is None:
        out_dir = inp.parent / f"{inp.stem}_per_icon"
    else:
        out_dir = out_dir.resolve()

    split_font_to_individual_as(
        inp,
        out_dir,
        target_unicode=args.target_unicode,
        skip_controls=not args.include_controls,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
