#!/usr/bin/env python3
"""Copy a widget tier template into Widgets/ with a usable name."""

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = {
    "1": "tier1_readout.lua",
    "1b": "tier1_slider.lua",
    "1c": "tier1_dropdown.lua",
    "2": "tier2_chip_mode.lua",
    "3": "tier3_discrete_chips.lua",
    "4": "tier4_spinner_slide_out.lua",
    "5": "tier5_persisted_visibility.lua",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tier", choices=TEMPLATES)
    parser.add_argument("name", help="widget filename without .lua (lowercase_with_underscores)")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "Widgets")
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z][a-z0-9_]*", args.name):
        parser.error("name must be lowercase_with_underscores")
    dest = args.output_dir / f"{args.name}.lua"
    if dest.exists():
        parser.error(f"already exists: {dest}")
    source = ROOT / "Widgets" / "_templates" / TEMPLATES[args.tier]
    content = source.read_text(encoding="utf-8")
    display_name = " ".join(part.capitalize() for part in args.name.split("_"))
    content, count = re.subn(r'(name\s*=\s*)"[^"]+"',
                             lambda match: match.group(1) + '"' + display_name + '"',
                             content, count=1)
    if count != 1:
        parser.error(f"template has no widget name: {source}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    dest.write_text(content, encoding="utf-8")
    print(dest)


if __name__ == "__main__":
    main()
