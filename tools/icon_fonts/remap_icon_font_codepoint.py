#!/usr/bin/env python3
"""Remap a single Unicode code point in .ttf cmap tables (e.g. per-icon icon fonts)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from fontTools.ttLib import TTFont


def remap_file(path: Path, old_u: int, new_u: int) -> bool:
    font = TTFont(path)
    best = dict(font.getBestCmap() or {})
    if old_u not in best:
        font.close()
        return False
    gname = best[old_u]
    for table in font["cmap"].tables:
        d = dict(table.cmap)
        if old_u in d:
            del d[old_u]
        d[new_u] = gname
        table.cmap = d
    font.save(path)
    font.close()
    return True


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--from",
        dest="old_u",
        type=lambda x: int(x, 0),
        required=True,
        help="Old Unicode scalar (e.g. 0x41)",
    )
    p.add_argument(
        "--to",
        dest="new_u",
        type=lambda x: int(x, 0),
        required=True,
        help="New Unicode scalar (e.g. 0x21)",
    )
    p.add_argument(
        "paths",
        nargs="+",
        type=Path,
        help="One or more .ttf files or directories (recursive for *.ttf)",
    )
    args = p.parse_args()

    files: list[Path] = []
    for raw in args.paths:
        r = raw.resolve()
        if r.is_file() and r.suffix.lower() == ".ttf":
            files.append(r)
        elif r.is_dir():
            files.extend(sorted(r.rglob("*.ttf")))
        else:
            print(f"Skip (not file/dir): {r}", file=sys.stderr)

    n_ok = 0
    n_skip = 0
    for fpath in files:
        if remap_file(fpath, args.old_u, args.new_u):
            print(f"Remapped U+{args.old_u:04X} -> U+{args.new_u:04X}: {fpath}")
            n_ok += 1
        else:
            print(f"No U+{args.old_u:04X} in cmap: {fpath}", file=sys.stderr)
            n_skip += 1

    print(f"Done: {n_ok} updated, {n_skip} skipped", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
