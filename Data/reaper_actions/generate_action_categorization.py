#!/usr/bin/env python3
"""
Parse Ultraschall-format REAPER action list exports (tab-separated Section, Id, Action)
and emit Lua tables:
  - flat list
  - nested categorization tree
  - one file per top-level category for easier organization

Run from repo root:
  python3 Data/reaper_actions/generate_action_categorization.py

Inputs (default): Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt
Outputs:
  - reaper_actions_flat.lua
  - reaper_actions_categorization.lua
  - category_manifest.lua
  - categories/*.lua
"""

from __future__ import annotations

import sys
import shutil
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt"
OUT_DIR = ROOT / "Data/reaper_actions"
CATEGORIES_DIR = OUT_DIR / "categories"
WIDGET_OMISSIONS_REPORT_PATH = OUT_DIR / "widget_omissions_report.txt"
SUBCATEGORY_CHUNK_SIZE = 500
IGNORE_TITLE_PHRASES = (
    "mousewheel/midi relative only",
    "midi cc relative/mousewheel",
    "midi cc/osc only",
    "(midi cc/mousewheel only)",
    "(only valid within custom actions)",
    "seconds before next action",
    "second before next action",
    "skip next action if cc parameter",
    "cc: set cc lane to ",
    "set track automation mode to ",
    "set default mouse modifier action for ",
)
WIDGET_SUGGESTION_MIN_SERIES_SIZE = 4
IGNORE_SWS_ACTIONS = True
IGNORE_MIDI_EDITOR_ACTIONS = True
IGNORE_NOTATION_ACTIONS = False
DEDUPE_CROSS_SECTION_DUPLICATES = True
USE_VECTOR_CLUSTER_SPLIT = True
USE_PREFIX_PRESPLIT = True
PREFIX_PRESPLIT_MIN_ACTIONS = 10
USE_SECOND_PASS_RECLUSTER = True
SECOND_PASS_MIN_ACTIONS = 10
USE_POSTCOLON_WORD_PRESPLIT = True
POSTCOLON_WORD_PRESPLIT_MIN_OCCURRENCES = 4
WORD_CLUSTER_STOPWORDS = {
    "the", "and", "for", "to", "of", "in", "on", "at", "by", "from", "with", "without",
    "a", "an", "is", "as", "or", "all", "set", "toggle", "show", "hide", "open", "close",
    "item", "items", "track", "tracks", "midi", "action", "actions",
}
WORD_CLUSTER_BIAS_TERMS = {
    "glue",
    "select",
    "solo",
    "mute",
    "apply",
    "vcas",
    "toggle",
    "show",
    "arm",
    "record",
    "quantize",
    "nudge",
    "trim",
    "fade",
    "automation",
    "items",
    "color",
}
WORD_CLUSTER_BIAS_REPEAT = 3
WORD_CLUSTER_BIAS_PHRASES = (
    "grid: set to",
    "item: cycle through",
    "stretch marker",
    "set take channel mode ",
)
MANUAL_WIDGET_OMISSION_TITLE_PREFIXES = (
    "View: Time unit for ruler:",
)
TOGGLE_VARIANTS = ("toggle", "enable", "disable")


@dataclass
class ActionRow:
    section: str
    command_id: str
    title: str
    menu_context: Optional[str] = None  # section 3 only


def parse_ultraschall(path: Path) -> Tuple[List[ActionRow], Dict[str, Any]]:
    """Return regular actions (section 2) and metadata from the file header."""
    text = path.read_text(encoding="utf-8", errors="replace").splitlines()
    meta: Dict[str, Any] = {
        "source_file": str(path.relative_to(ROOT)),
        "attribution": (
            "Compiled by Meo-Ada Mespotine for Ultraschall; REAPER 5.941 + SWS 2.9.7. "
            "https://mespotin.uber.space/Ultraschall/misc_docs/ACTIONS_List_of_Reaper_Actions_including_undocumented_ones.txt"
        ),
    }
    regular: List[ActionRow] = []
    in_regular = False
    for line in text:
        raw = line.rstrip("\n")
        if raw.strip() == '2. "Regular" Actions:':
            in_regular = True
            continue
        if raw.strip().startswith("3. Menu only actions"):
            break
        if not in_regular:
            continue
        if not raw.strip() or raw.lstrip().startswith("These actions"):
            continue
        if "Section" in raw and "Id" in raw and "Action" in raw:
            continue
        parts = raw.split("\t")
        parts = [p.strip() for p in parts if p.strip() != ""]
        if len(parts) < 3:
            continue
        section, cid, title = parts[0], parts[1], parts[2]
        if section == "Section" and cid == "Id":
            continue
        regular.append(ActionRow(section=section, command_id=cid, title=title))
    return regular, meta


def filter_actions(rows: List[ActionRow]) -> Tuple[List[ActionRow], Dict[str, Any]]:
    kept: List[ActionRow] = []
    removed_count_by_phrase = {p: 0 for p in IGNORE_TITLE_PHRASES}
    removed_total = 0
    sws_removed = 0
    midi_editor_removed = 0
    notation_removed = 0

    for row in rows:
        section_l = _low(row.section)

        # Optional hard toggle to drop SWS/Xenakios/FNG extension actions from consideration.
        if IGNORE_SWS_ACTIONS and (
            row.title.startswith("SWS")
            or row.title.startswith("Xenakios")
            or row.title.startswith("FNG:")
            or ("sws" in _low(row.title) and row.title.startswith("Script:"))
        ):
            sws_removed += 1
            continue

        # Optional toggle to drop MIDI editor-only actions.
        if IGNORE_MIDI_EDITOR_ACTIONS and (
            section_l == "midi editor"
            or section_l == "midi event list editor"
            or section_l == "midi inline editor"
            or section_l.startswith("midi")
        ):
            midi_editor_removed += 1
            continue

        # Optional toggle to drop notation actions.
        if IGNORE_NOTATION_ACTIONS and (
            row.title.startswith("Notation:")
            or section_l == "notation editor"
            or section_l.startswith("notation")
        ):
            notation_removed += 1
            continue

        title_l = _low(row.title)
        matched_phrase = None
        for phrase in IGNORE_TITLE_PHRASES:
            if phrase in title_l:
                matched_phrase = phrase
                break
        if matched_phrase:
            removed_total += 1
            removed_count_by_phrase[matched_phrase] += 1
        else:
            kept.append(row)

    report = {
        "filters_applied": list(IGNORE_TITLE_PHRASES),
        "ignore_sws_actions_enabled": IGNORE_SWS_ACTIONS,
        "filtered_out_sws_count": sws_removed,
        "ignore_midi_editor_actions_enabled": IGNORE_MIDI_EDITOR_ACTIONS,
        "filtered_out_midi_editor_count": midi_editor_removed,
        "ignore_notation_actions_enabled": IGNORE_NOTATION_ACTIONS,
        "filtered_out_notation_count": notation_removed,
        "filtered_out_count": removed_total,
        "filtered_out_by_phrase": removed_count_by_phrase,
    }
    return kept, report


def dedupe_actions(rows: List[ActionRow]) -> Tuple[List[ActionRow], Dict[str, Any]]:
    if not DEDUPE_CROSS_SECTION_DUPLICATES:
        return rows, {
            "dedupe_enabled": False,
            "deduped_count": 0,
            "deduped_group_count": 0,
        }

    # Prefer canonical sections when duplicates occur.
    section_priority = {
        "Main": 0,
        "MIDI Editor": 1,
        "MIDI Event List Editor": 2,
        "MIDI Inline Editor": 3,
    }

    grouped: Dict[Tuple[str, str], List[ActionRow]] = {}
    for row in rows:
        key = (str(row.command_id), _low(str(row.title)).strip())
        grouped.setdefault(key, []).append(row)

    deduped_rows: List[ActionRow] = []
    deduped_count = 0
    deduped_group_count = 0

    for key in sorted(grouped.keys(), key=lambda k: (k[0], k[1])):
        group = grouped[key]
        if len(group) == 1:
            deduped_rows.append(group[0])
            continue

        deduped_group_count += 1
        deduped_count += len(group) - 1
        group_sorted = sorted(
            group,
            key=lambda r: (section_priority.get(r.section, 999), r.section, r.command_id),
        )
        deduped_rows.append(group_sorted[0])

    report = {
        "dedupe_enabled": True,
        "deduped_count": deduped_count,
        "deduped_group_count": deduped_group_count,
    }
    return deduped_rows, report


def _normalize_ws(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def extract_toggle_variant_key(title: str) -> Optional[Tuple[str, str]]:
    """
    Return (variant, canonical_key) where canonical_key replaces one toggle-like
    variant token (toggle/enable/disable) with a placeholder.
    """
    lowered = _low(title)
    m = re.search(r"\b(toggle|enable|disable)\b", lowered)
    if not m:
        return None
    variant = str(m.group(1))
    canonical = lowered[: m.start()] + "{toggle_variant}" + lowered[m.end() :]
    return variant, _normalize_ws(canonical)


def filter_toggle_enable_disable_variants(rows: List[ActionRow]) -> Tuple[List[ActionRow], Dict[str, Any]]:
    """
    Where otherwise-identical actions exist as toggle/enable/disable variants,
    keep only one toggle action and omit the rest.
    """
    grouped: Dict[Tuple[str, str], List[Tuple[int, ActionRow, str]]] = {}
    for idx, row in enumerate(rows):
        extracted = extract_toggle_variant_key(row.title)
        if not extracted:
            continue
        variant, canonical_key = extracted
        grouped.setdefault((_low(row.section), canonical_key), []).append((idx, row, variant))

    to_drop_indexes = set()
    dropped_count = 0
    matched_group_count = 0
    skipped_no_toggle_count = 0
    over_three_groups: List[Dict[str, Any]] = []

    for (_section_key, canonical_key), entries in grouped.items():
        if len(entries) < 2:
            continue

        variants_present = {variant for _, _, variant in entries}
        has_enable_or_disable = "enable" in variants_present or "disable" in variants_present
        if "toggle" not in variants_present or not has_enable_or_disable:
            continue

        matched_group_count += 1
        if len(entries) > 3:
            over_three_groups.append(
                {
                    "canonical_key": canonical_key,
                    "entry_count": len(entries),
                    "variants_present": sorted(variants_present),
                    "actions": [
                        {
                            "section": row.section,
                            "command_id": row.command_id,
                            "title": row.title,
                            "action_key": f"{row.section}:{row.command_id}",
                            "variant": variant,
                        }
                        for _, row, variant in entries
                    ],
                }
            )

        toggle_entries = [entry for entry in entries if entry[2] == "toggle"]
        if not toggle_entries:
            skipped_no_toggle_count += 1
            continue

        keep_index = min(toggle_entries, key=lambda e: e[0])[0]
        for idx, _row, _variant in entries:
            if idx == keep_index:
                continue
            to_drop_indexes.add(idx)
            dropped_count += 1

    kept_rows = [row for idx, row in enumerate(rows) if idx not in to_drop_indexes]
    report = {
        "toggle_variant_filter": {
            "enabled": True,
            "variants": list(TOGGLE_VARIANTS),
            "matched_group_count": matched_group_count,
            "filtered_out_count": dropped_count,
            "skipped_no_toggle_group_count": skipped_no_toggle_count,
            "groups_over_three_count": len(over_three_groups),
            "groups_over_three": over_three_groups,
        }
    }
    return kept_rows, report


def extract_numeric_series_template(title: str) -> Optional[Tuple[str, int, str]]:
    """
    Extract a template where the final numeric token varies.
    Example:
      'Markers: Go to marker 11' -> ('Markers: Go to marker {n}', 11, '')
    """
    # Pattern 1: trailing adjacent range, e.g. "... channels 01/02".
    # This is treated as a numeric-series keyed by the first number.
    pair_match = re.match(r"^(.*?)(\d+)\s*/\s*(\d+)([^0-9]*)$", title)
    if pair_match:
        prefix, first_str, second_str, suffix = (
            pair_match.group(1),
            pair_match.group(2),
            pair_match.group(3),
            pair_match.group(4),
        )
        if len(prefix.strip()) >= 4:
            try:
                first_n = int(first_str)
                second_n = int(second_str)
            except ValueError:
                first_n = -1
                second_n = -1
            if first_n >= 0 and second_n == first_n + 1:
                template = f"{prefix}{{n}}/{{n+1}}{suffix}"
                return template, first_n, suffix

    # Pattern 2: simple trailing numeric token.
    m = re.match(r"^(.*?)(\d+)([^0-9]*)$", title)
    if not m:
        return None
    prefix, number_str, suffix = m.group(1), m.group(2), m.group(3)
    if len(prefix.strip()) < 4:
        return None
    try:
        n = int(number_str)
    except ValueError:
        return None
    template = f"{prefix}{{n}}{suffix}"
    return template, n, suffix


def detect_widget_series_suggestions(rows: List[ActionRow]) -> Tuple[List[ActionRow], Dict[str, Any], Dict[str, Any]]:
    grouped: Dict[str, List[Tuple[ActionRow, int]]] = {}
    for row in rows:
        parsed = extract_numeric_series_template(row.title)
        if not parsed:
            continue
        template, number_value, _suffix = parsed
        key = f"{row.section}::{template}"
        grouped.setdefault(key, []).append((row, number_value))

    omitted_action_keys = set()
    suggestions: List[Dict[str, Any]] = []

    for key in sorted(grouped.keys()):
        entries = grouped[key]
        if len(entries) < WIDGET_SUGGESTION_MIN_SERIES_SIZE:
            continue

        entries_sorted = sorted(entries, key=lambda item: (item[1], item[0].title))
        rows_for_group = [r for r, _ in entries_sorted]
        values = sorted({n for _, n in entries})
        if len(values) < WIDGET_SUGGESTION_MIN_SERIES_SIZE:
            continue

        section, template = key.split("::", 1)
        for row in rows_for_group:
            omitted_action_keys.add(f"{row.section}:{row.command_id}")

        sample = rows_for_group[0]
        suggestions.append(
            {
                "suggestion_type": "numeric_action_series",
                "widget_kind": "selector_or_go_to",
                "section": section,
                "template_title": template,
                "example_title": sample.title,
                "series_size": len(rows_for_group),
                "range_min": values[0],
                "range_max": values[-1],
                "numeric_values": values,
                "omitted_action_keys": [f"{r.section}:{r.command_id}" for r in rows_for_group],
                "omitted_titles": [r.title for r in rows_for_group],
                "reason": (
                    "Detected repeated numbered actions better represented by a compact widget "
                    "instead of one button per number."
                ),
            }
        )

    kept: List[ActionRow] = []
    for row in rows:
        if f"{row.section}:{row.command_id}" in omitted_action_keys:
            continue
        kept.append(row)

    report = {
        "widget_series_detection": {
            "min_series_size": WIDGET_SUGGESTION_MIN_SERIES_SIZE,
            "omitted_count": len(omitted_action_keys),
            "suggestion_count": len(suggestions),
        }
    }

    suggestion_payload = {
        "schema": (
            "Widget suggestions derived from repeated numbered action-series. "
            "Suggested groups are omitted from the main action outputs."
        ),
        "suggestion_count": len(suggestions),
        "omitted_action_count": len(omitted_action_keys),
        "suggestions": suggestions,
    }
    return kept, report, suggestion_payload


def apply_manual_widget_omissions(rows: List[ActionRow]) -> Tuple[List[ActionRow], Dict[str, Any], Dict[str, Any]]:
    if not MANUAL_WIDGET_OMISSION_TITLE_PREFIXES:
        report = {
            "manual_widget_omissions": {
                "enabled": False,
                "configured_prefix_count": 0,
                "omitted_count": 0,
                "suggestion_count": 0,
            }
        }
        payload = {
            "schema": "Manually configured widget-omission groups based on title prefixes.",
            "suggestion_count": 0,
            "omitted_action_count": 0,
            "suggestions": [],
        }
        return rows, report, payload

    prefix_to_rows: Dict[str, List[ActionRow]] = {}
    kept: List[ActionRow] = []
    for row in rows:
        matched_prefix: Optional[str] = None
        for prefix in MANUAL_WIDGET_OMISSION_TITLE_PREFIXES:
            if row.title.startswith(prefix):
                matched_prefix = prefix
                break
        if matched_prefix is None:
            kept.append(row)
            continue
        prefix_to_rows.setdefault(matched_prefix, []).append(row)

    suggestions: List[Dict[str, Any]] = []
    omitted_count = 0
    for prefix in MANUAL_WIDGET_OMISSION_TITLE_PREFIXES:
        grouped_rows = prefix_to_rows.get(prefix, [])
        if not grouped_rows:
            continue
        grouped_rows = sorted(grouped_rows, key=lambda r: (r.section, r.command_id, r.title))
        omitted_count += len(grouped_rows)
        suggestions.append(
            {
                "suggestion_type": "manual_widget_series",
                "widget_kind": "custom_widget",
                "title_prefix": prefix,
                "series_size": len(grouped_rows),
                "omitted_action_keys": [f"{r.section}:{r.command_id}" for r in grouped_rows],
                "omitted_titles": [r.title for r in grouped_rows],
                "reason": (
                    "Manually omitted for dedicated widget UI."
                ),
            }
        )

    report = {
        "manual_widget_omissions": {
            "enabled": True,
            "configured_prefix_count": len(MANUAL_WIDGET_OMISSION_TITLE_PREFIXES),
            "omitted_count": omitted_count,
            "suggestion_count": len(suggestions),
        }
    }
    payload = {
        "schema": "Manually configured widget-omission groups based on title prefixes.",
        "suggestion_count": len(suggestions),
        "omitted_action_count": omitted_count,
        "suggestions": suggestions,
    }
    return kept, report, payload


def format_widget_omissions_report(widget_omissions_payload: Dict[str, Any]) -> str:
    suggestions = widget_omissions_payload.get("suggestions", [])
    lines: List[str] = []
    if not suggestions:
        lines.append("Widget omissions: none")
        return "\n".join(lines) + "\n"

    def ordered_main_categories() -> List[str]:
        known = list(TOP_LABELS.keys())
        # Include any new/unexpected keys deterministically.
        for s in suggestions:
            keys = s.get("omitted_action_keys", [])
            titles = s.get("omitted_titles", [])
            if not keys or not titles:
                continue
            first_key = str(keys[0])
            try:
                section, cid = first_key.split(":", 1)
            except ValueError:
                continue
            row = ActionRow(section=section, command_id=cid, title=str(titles[0]))
            cat = top_category(row)
            if cat not in known:
                known.append(cat)
        return known

    def classify_suggestion(suggestion: Dict[str, Any]) -> Tuple[str, str]:
        keys = suggestion.get("omitted_action_keys", [])
        titles = suggestion.get("omitted_titles", [])
        if not keys or not titles:
            return "other", "all"
        first_key = str(keys[0])
        try:
            section, cid = first_key.split(":", 1)
        except ValueError:
            return "other", "all"
        row = ActionRow(section=section, command_id=cid, title=str(titles[0]))
        main = top_category(row)
        if main == "items":
            return main, item_subcategory(row.title)
        return main, "all"

    grouped: Dict[Tuple[str, str], List[Dict[str, Any]]] = {}
    for s in suggestions:
        main, sub = classify_suggestion(s)
        grouped.setdefault((main, sub), []).append(s)

    lines.append("")
    lines.append("Widget omissions (for refinement review):")

    for main_key in ordered_main_categories():
        main_label = str(TOP_LABELS.get(main_key, main_key))
        sub_items: List[str] = []
        # Preserve SUB_LABELS insertion order when main == items.
        if main_key == "items":
            sub_items = list(SUB_LABELS.keys())
            # Add any unexpected subcategories.
            for (_, sub_key) in grouped.keys():
                if _ == main_key and sub_key not in sub_items:
                    sub_items.append(sub_key)
        else:
            sub_items = ["all"]

        # Emit only subcategories that exist.
        for sub_key in sub_items:
            if (main_key, sub_key) not in grouped:
                continue

            sub_label = (
                str(SUB_LABELS.get(sub_key, sub_key))
                if main_key == "items"
                else "All actions"
            )
            lines.append("")
            lines.append(main_label)
            lines.append(f"  {sub_label}")

            block = grouped[(main_key, sub_key)]
            block_sorted = sorted(
                block,
                key=lambda s: (
                    -int(s.get("series_size", 0)),
                    str(s.get("template_title", s.get("title_prefix", ""))),
                    str(s.get("example_title", "")),
                ),
            )

            for s in block_sorted:
                suggestion_type = str(s.get("suggestion_type", "widget_series"))
                section = str(s.get("section", "") or "")
                template = str(s.get("template_title", s.get("title_prefix", "")) or "")
                series_size = int(s.get("series_size", 0) or 0)
                lines.append(
                    f"    - {suggestion_type}"
                    + (f" | {section}" if section else "")
                    + f" | {template} | {series_size} actions"
                )

                keys = s.get("omitted_action_keys", [])
                titles = s.get("omitted_titles", [])
                for key, title in zip(keys, titles):
                    lines.append(f"      {key} | {title}")

    return "\n".join(lines) + "\n"


def print_widget_omissions_report(widget_omissions_payload: Dict[str, Any]) -> None:
    print(format_widget_omissions_report(widget_omissions_payload), end="")


def _low(s: str) -> str:
    return s.lower()


def item_subcategory(title: str) -> str:
    """Sub-key under 'items' for Item:/Take:/Item edit:/Item properties: rows."""
    t = _low(title)
    if title.startswith("Take:"):
        return "takes_and_lanes"
    if title.startswith("Item edit:"):
        if any(k in t for k in ("grow", "shrink", "edge")):
            return "editing_edges"
        if any(
            k in t
            for k in (
                "move",
                "nudge",
                "relative grid",
                "position of item",
            )
        ):
            return "position_and_nudge"
        if any(k in t for k in ("split", "glue", "trim", "heal", "remove", "ripple")):
            return "editing_moves"
        if any(k in t for k in ("fade", "crossfade")):
            return "fades_and_crossfades"
        return "editing_moves"
    if title.startswith("Item properties:"):
        if any(k in t for k in ("pitch", "playrate", "playback rate", "stretch", "timebase", "tempo", "item rate", "preserve pitch")):
            return "pitch_playrate_and_time"
        if "channel mode" in t or "phase" in t or "stereo" in t:
            return "pan_and_stereo"
        if "volume" in t or "gain" in t or "normalize" in t or "db" in t:
            return "volume_and_gain"
        if "take" in t or "comp" in t or "play all take" in t:
            return "takes_and_lanes"
        if "fade" in t or "snap offset" in t:
            return "fades_and_crossfades"
        if "note" in t or "midi" in t:
            return "midi_and_notes"
        if "fx" in t or "preset" in t:
            return "fx_and_presets"
        if any(k in t for k in ("mute", "unmute", "lock", "unlock", "loop section", "loop item")):
            return "mute_lock_and_loop"
        return "properties_other"
    # Item:
    if any(
        k in t
        for k in (
            "pitch",
            "playrate",
            "playback rate",
            "preserve pitch",
            "time stretch",
            "stretch",
            "set item rate",
        )
    ):
        return "pitch_playrate_and_time"
    if any(k in t for k in ("volume", "gain", "normalize", " db", "db ", "mute active take")):
        return "volume_and_gain"
    if any(k in t for k in ("pan", "width", "stereo")):
        return "pan_and_stereo"
    if any(
        k in t
        for k in (
            "take",
            "takes",
            "lane",
            "comp",
            "explode",
            "implode",
            "active take",
            "multitake",
        )
    ):
        return "takes_and_lanes"
    if any(k in t for k in ("fade", "crossfade", "snap offset")):
        return "fades_and_crossfades"
    if any(k in t for k in ("fx", "vst", "show fx", "remove fx")):
        return "fx_and_presets"
    if any(
        k in t
        for k in (
            "glue",
            "split",
            "trim",
            "heal",
            "remove items",
            "copy",
            "paste",
            "cut",
            "render",
            "freeze",
            "reverse",
            "quantize item",
        )
    ):
        return "editing_moves"
    if any(k in t for k in ("midi", "note row")):
        return "midi_and_notes"
    if any(k in t for k in ("select", "mouse", "unselect")):
        return "selection"
    return "other"


def top_category(row: ActionRow) -> str:
    title = row.title
    sec = row.section
    t = _low(title)

    if title.startswith("SWS") or title.startswith("Xenakios") or title.startswith("FNG:"):
        return "extensions_sws_and_related"

    midi_sections = (
        "MIDI Editor",
        "MIDI Event List Editor",
        "MIDI Inline Editor",
    )
    if sec in midi_sections or sec.startswith("MIDI"):
        return "midi_editor_and_inline"

    if title.startswith("Track:"):
        return "tracks"
    if title.startswith("Item:") or title.startswith("Take:") or title.startswith(
        "Item edit:"
    ) or title.startswith("Item properties:"):
        return "items"

    if title.startswith("Transport:"):
        return "transport"
    if title.startswith("View:"):
        return "view"
    if title.startswith("Edit:"):
        return "edit"
    if title.startswith("Options:"):
        return "options"
    if title.startswith("Envelope:") or title.startswith("Envelope "):
        return "envelopes"
    if title.startswith("Automation:") or title.startswith("Automation "):
        return "automation"
    if title.startswith("Markers:") or title.startswith("Marker "):
        return "markers"
    if title.startswith("Regions:") or title.startswith("Region "):
        return "regions"
    if title.startswith("Time selection:"):
        return "time_selection"
    if title.startswith("File:") or title.startswith("Project:"):
        return "project_and_file"
    if title.startswith("Toolbar:") or title.startswith("Toolbars:"):
        return "toolbars"
    if title.startswith("Grid:"):
        return "grid"
    if title.startswith("Mixer:"):
        return "mixer"
    if title.startswith("Locking:") or title.startswith("Lock "):
        return "locking"
    if title.startswith("Screenset:"):
        return "screensets"
    if title.startswith("Action:"):
        return "actions_and_customization"
    if title.startswith("Notation:"):
        return "notation"
    if title.startswith("Peaks:"):
        return "peaks_and_media"
    if title.startswith("Channel:"):
        return "routing_and_channels"
    if title.startswith("Cursor:") or title.startswith("Navigate:"):
        return "cursor_and_navigation"
    if title.startswith("Group:"):
        return "groups"
    if title.startswith("Layout:"):
        return "layout"
    if title.startswith("CC:") or title.startswith("Insert note") or title.startswith(
        "Set length for next inserted note"
    ):
        return "midi_editor_and_inline"
    if title.startswith("Step input:"):
        return "midi_step_input"
    if "sws" in t and title.startswith("Script:"):
        return "extensions_sws_and_related"

    return "other"


SUB_LABELS = {
    "pitch_playrate_and_time": "Pitch, play rate, and time",
    "volume_and_gain": "Volume and gain",
    "pan_and_stereo": "Pan, phase, and channel mode",
    "takes_and_lanes": "Takes, lanes, and comping",
    "fades_and_crossfades": "Fades, crossfades, and snap offset",
    "fx_and_presets": "FX and presets on items/takes",
    "editing_moves": "Editing, glue, split, trim, remove",
    "editing_edges": "Trim edges (grow/shrink item bounds)",
    "position_and_nudge": "Position, move, and nudge",
    "midi_and_notes": "MIDI content on items",
    "selection": "Selection and mouse targeting",
    "mute_lock_and_loop": "Mute, lock, and source loop",
    "properties_other": "Item properties (dialogs and other)",
    "other": "Other item-related",
}

TOP_LABELS = {
    "tracks": "Tracks",
    "items": "Items and takes",
    "midi_editor_and_inline": "MIDI editor, event list, and inline",
    "transport": "Transport",
    "view": "View",
    "edit": "Edit",
    "options": "Options",
    "envelopes": "Envelopes",
    "automation": "Automation",
    "markers": "Markers",
    "regions": "Regions",
    "time_selection": "Time selection",
    "project_and_file": "Project and file",
    "toolbars": "Toolbars",
    "grid": "Grid",
    "mixer": "Mixer",
    "locking": "Locking",
    "screensets": "Screensets",
    "actions_and_customization": "Actions and customization",
    "notation": "Notation",
    "peaks_and_media": "Peaks and media",
    "routing_and_channels": "Routing and channels",
    "cursor_and_navigation": "Cursor and navigation",
    "groups": "Groups",
    "layout": "Layout",
    "midi_step_input": "MIDI step input",
    "extensions_sws_and_related": "Extensions (SWS and related)",
    "other": "Uncategorized / general",
}


def row_to_dict(row: ActionRow) -> Dict[str, Any]:
    d: Dict[str, Any] = {
        "section": row.section,
        "command_id": row.command_id,
        "title": row.title,
        "action_key": f"{row.section}:{row.command_id}",
        "appearance": {
            "custom_name": None,
            "icon_char": None,
            "icon_font": None,
            "icon_path": None,
            "custom_color": None,
            "hide_label": False,
        },
    }
    if row.menu_context:
        d["menu_context"] = row.menu_context
    return d


def _lua_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def _is_lua_identifier(key: str) -> bool:
    if not key:
        return False
    if not (key[0].isalpha() or key[0] == "_"):
        return False
    for ch in key[1:]:
        if not (ch.isalnum() or ch == "_"):
            return False
    return True


def to_lua(value: Any, indent: int = 0) -> str:
    pad = " " * indent
    next_pad = " " * (indent + 2)

    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return '"' + _lua_escape(value) + '"'
    if isinstance(value, list):
        if not value:
            return "{}"
        lines = ["{"]
        for item in value:
            lines.append(f"{next_pad}{to_lua(item, indent + 2)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    if isinstance(value, dict):
        if not value:
            return "{}"
        lines = ["{"]
        for k, v in value.items():
            key = k if _is_lua_identifier(k) else f'["{_lua_escape(str(k))}"]'
            lines.append(f"{next_pad}{key} = {to_lua(v, indent + 2)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    raise TypeError(f"Unsupported type for Lua serialization: {type(value)}")


def write_lua_table(path: Path, variable_name: str, payload: Dict[str, Any]) -> None:
    lua = f"local {variable_name} = {to_lua(payload)}\n\nreturn {variable_name}\n"
    path.write_text(lua, encoding="utf-8")


def write_passed_actions_flat_file(path: Path, rows: List[ActionRow]) -> None:
    """
    Write a plain-text flat list of final kept actions.
    Format: section<TAB>command_id<TAB>title<TAB>action_key
    """
    lines = ["section\tcommand_id\ttitle\taction_key"]
    for row in rows:
        lines.append(f"{row.section}\t{row.command_id}\t{row.title}\t{row.section}:{row.command_id}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_passed_actions_organized_file(path: Path, rows: List[ActionRow]) -> None:
    """
    Write actions grouped by the same macro categories/subcategories as the Lua categorization.
    This is rule-based grouping + deterministic sorting (no clustering/semantic re-splitting).
    """
    grouped: Dict[Tuple[str, str], List[ActionRow]] = {}
    mains_seen: set[str] = set()
    subs_seen_by_main: Dict[str, set[str]] = {}

    for row in rows:
        main = top_category(row)
        if main == "items":
            sub = item_subcategory(row.title)
        else:
            sub = "all"

        mains_seen.add(main)
        subs_seen_by_main.setdefault(main, set()).add(sub)
        grouped.setdefault((main, sub), []).append(row)

    main_keys_sorted = sorted(mains_seen, key=lambda k: str(TOP_LABELS.get(k, k)))

    lines: List[str] = []
    lines.append("Widget actions (passed-through) organized by macro categories")
    lines.append("")

    for main_key in main_keys_sorted:
        main_label = str(TOP_LABELS.get(main_key, main_key))
        lines.append(main_label)

        if main_key == "items":
            preferred_sub_order = [k for k in SUB_LABELS.keys() if k in subs_seen_by_main.get(main_key, set())]
            remaining_subs = sorted(
                subs_seen_by_main.get(main_key, set()) - set(preferred_sub_order),
                key=lambda k: str(SUB_LABELS.get(k, k)),
            )
            sub_keys = preferred_sub_order + remaining_subs
        else:
            sub_keys = ["all"]

        for sub_key in sub_keys:
            if (main_key, sub_key) not in grouped:
                continue

            sub_label = str(SUB_LABELS.get(sub_key, sub_key)) if main_key == "items" else "All actions"
            lines.append(f"  {sub_label}")
            lines.append("section\tcommand_id\ttitle\taction_key")

            bucket = grouped[(main_key, sub_key)]
            bucket.sort(key=lambda r: (str(r.section), str(r.command_id), str(r.title)))
            for row in bucket:
                lines.append(f"{row.section}\t{row.command_id}\t{row.title}\t{row.section}:{row.command_id}")
            lines.append("")

    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def safe_filename(value: str) -> str:
    # Filesystem-safe display name:
    # - spaces instead of underscores
    # - title-style capitalization
    # - keep "and" lowercase unless first word
    cleaned = re.sub(r"[_\-.]+", " ", str(value))
    cleaned = re.sub(r"[^A-Za-z0-9 ]+", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    if not cleaned:
        return "Category"

    parts = cleaned.split(" ")
    titled: List[str] = []
    for i, part in enumerate(parts):
        low = part.lower()
        if i > 0 and low == "and":
            titled.append("and")
        else:
            titled.append(low[:1].upper() + low[1:])
    return " ".join(titled)


def _vectorize_base_tokens(text: str) -> List[str]:
    text = re.sub(r"\d+", " num ", text)
    text = re.sub(r"[^a-z0-9_:\s]+", " ", text)
    return [token for token in text.split() if token != "the"]


def _shared_prefix_tokens(token_lists: List[List[str]]) -> List[str]:
    if not token_lists:
        return []
    prefix = list(token_lists[0])
    for tokens in token_lists[1:]:
        i = 0
        max_i = min(len(prefix), len(tokens))
        while i < max_i and prefix[i] == tokens[i]:
            i += 1
        prefix = prefix[:i]
        if not prefix:
            break
    return prefix


def _title_for_vectorization(action: Dict[str, Any], shared_prefix_tokens: Optional[List[str]] = None) -> str:
    text = str(action.get("title", "")).lower()
    original_text = text
    tokens = _vectorize_base_tokens(text)
    if shared_prefix_tokens:
        common_len = len(shared_prefix_tokens)
        if common_len > 0 and len(tokens) > common_len and tokens[:common_len] == shared_prefix_tokens:
            tokens = tokens[common_len:]
    boosted = list(tokens)
    for token in tokens:
        if token in WORD_CLUSTER_BIAS_TERMS:
            # Repeat bias tokens to increase their TF-IDF weight in clustering.
            boosted.extend([token] * max(0, WORD_CLUSTER_BIAS_REPEAT - 1))
    for phrase in WORD_CLUSTER_BIAS_PHRASES:
        if phrase in original_text:
            phrase_token = phrase.replace(":", "").replace(" ", "_")
            boosted.extend([phrase_token] * WORD_CLUSTER_BIAS_REPEAT)
    return " ".join(boosted)


def _cluster_label_from_centroid(terms: List[str]) -> str:
    keep: List[str] = []
    for term in terms:
        if not term or term == "num":
            continue
        if term.isdigit():
            continue
        if term in ("set", "toggle", "track", "item", "midi", "view", "edit"):
            continue
        keep.append(term)
        if len(keep) >= 3:
            break
    if not keep:
        return "cluster"
    return "_".join(keep)


def _tokenize_title_words(text: str) -> List[str]:
    clean = _low(text)
    clean = re.sub(r"\d+", " num ", clean)
    clean = re.sub(r"[^a-z0-9_:\s]+", " ", clean)
    parts = [p for p in clean.split() if p]
    tokens: List[str] = []
    for part in parts:
        if part == "num":
            continue
        if len(part) <= 1:
            continue
        if part in WORD_CLUSTER_BIAS_TERMS:
            tokens.append(part)
            continue
        if part in WORD_CLUSTER_STOPWORDS:
            continue
        tokens.append(part)
    return tokens


def _semantic_signature(action: Dict[str, Any]) -> str:
    title = str(action.get("title", ""))
    after_colon = title.split(":", 1)[1].strip() if ":" in title else title
    tokens = _tokenize_title_words(after_colon)
    if not tokens:
        return "misc"
    if len(tokens) == 1:
        return tokens[0]
    return f"{tokens[0]}_{tokens[1]}"


def estimate_word_based_cluster_count(actions: List[Dict[str, Any]]) -> Dict[str, Any]:
    n_actions = len(actions)
    if n_actions <= 1:
        return {"n_clusters": 1, "reason": "single_action"}

    signatures: Counter[str] = Counter()
    vocab = set()
    for action in actions:
        title = str(action.get("title", ""))
        for token in _tokenize_title_words(title):
            vocab.add(token)
        signatures[_semantic_signature(action)] += 1

    if len(vocab) < 6 or len(signatures) <= 1:
        return {
            "n_clusters": 1,
            "reason": "low_word_diversity",
            "vocab_size": len(vocab),
            "signature_count": len(signatures),
        }

    ordered = signatures.most_common()
    coverage_target = int(round(n_actions * 0.70))
    coverage = 0
    coverage_groups = 0
    for _sig, count in ordered:
        coverage += count
        coverage_groups += 1
        if coverage >= coverage_target:
            break

    vocab_signal = int(round(len(vocab) ** 0.5))
    repeated_signature_count = sum(1 for _sig, c in ordered if c >= 2)
    if repeated_signature_count < 2:
        repeated_signature_count = len(ordered)

    n_clusters = max(2, max(coverage_groups, vocab_signal))
    n_clusters = min(n_clusters, repeated_signature_count, n_actions)

    return {
        "n_clusters": max(1, n_clusters),
        "reason": "word_based",
        "vocab_size": len(vocab),
        "signature_count": len(signatures),
        "coverage_groups": coverage_groups,
    }


def extract_title_prefix(action: Dict[str, Any]) -> Tuple[str, str]:
    title = str(action.get("title", ""))
    m = re.match(r"^\s*([^:]{2,40}):\s+.+$", title)
    if not m:
        return "misc", "Misc"
    label = m.group(1).strip()
    if not label:
        return "misc", "Misc"
    return safe_filename(_low(label)), label


def extract_postcolon_lead_word(action: Dict[str, Any]) -> Optional[str]:
    title = str(action.get("title", ""))
    after_colon = title.split(":", 1)[1].strip() if ":" in title else title
    tokens = _tokenize_title_words(after_colon)
    if not tokens:
        return None
    return tokens[0]


def split_actions_by_postcolon_word(actions: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    if not USE_POSTCOLON_WORD_PRESPLIT or len(actions) < POSTCOLON_WORD_PRESPLIT_MIN_OCCURRENCES:
        return [{"id": "all", "label": "All", "actions": actions}], {
            "postcolon_presplit_enabled": USE_POSTCOLON_WORD_PRESPLIT,
            "postcolon_presplit_applied": False,
            "postcolon_presplit_min_occurrences": POSTCOLON_WORD_PRESPLIT_MIN_OCCURRENCES,
            "postcolon_presplit_bucket_count": 1,
        }

    word_counts: Counter[str] = Counter()
    action_words: List[Optional[str]] = []
    for action in actions:
        word = extract_postcolon_lead_word(action)
        action_words.append(word)
        if word:
            word_counts[word] += 1

    qualifying_words = {
        word for word, count in word_counts.items()
        if count >= POSTCOLON_WORD_PRESPLIT_MIN_OCCURRENCES
    }
    if len(qualifying_words) <= 1:
        return [{"id": "all", "label": "All", "actions": actions}], {
            "postcolon_presplit_enabled": USE_POSTCOLON_WORD_PRESPLIT,
            "postcolon_presplit_applied": False,
            "postcolon_presplit_min_occurrences": POSTCOLON_WORD_PRESPLIT_MIN_OCCURRENCES,
            "postcolon_presplit_bucket_count": 1,
            "postcolon_presplit_qualifying_words": sorted(qualifying_words),
        }

    grouped: Dict[str, List[Dict[str, Any]]] = {}
    misc_actions: List[Dict[str, Any]] = []
    for action, word in zip(actions, action_words):
        if word and word in qualifying_words:
            grouped.setdefault(word, []).append(action)
        else:
            misc_actions.append(action)

    buckets: List[Dict[str, Any]] = []
    for word in sorted(grouped.keys(), key=lambda w: (-len(grouped[w]), w)):
        buckets.append(
            {
                "id": safe_filename(word),
                "label": safe_filename(word),
                "actions": grouped[word],
            }
        )
    if misc_actions:
        buckets.append(
            {
                "id": "Other",
                "label": "Other",
                "actions": misc_actions,
            }
        )

    return buckets, {
        "postcolon_presplit_enabled": USE_POSTCOLON_WORD_PRESPLIT,
        "postcolon_presplit_applied": True,
        "postcolon_presplit_min_occurrences": POSTCOLON_WORD_PRESPLIT_MIN_OCCURRENCES,
        "postcolon_presplit_bucket_count": len(buckets),
        "postcolon_presplit_qualifying_words": sorted(qualifying_words),
    }


def split_actions_vector_or_chunk(
    actions: List[Dict[str, Any]],
    trim_shared_prefix: bool = False,
) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    """
    Return semantic file groups for one already-selected bucket.
    Uses TF-IDF + MiniBatchKMeans when available; falls back to simple chunking.
    """
    if not actions:
        return [{"id": "Group", "label": "Cluster 1", "prefix_key": "all", "prefix_label": "All", "actions": []}], {
            "method": "empty",
            "file_group_count": 1,
        }

    if not USE_VECTOR_CLUSTER_SPLIT:
        groups = []
        chunk_count = max(1, (len(actions) + SUBCATEGORY_CHUNK_SIZE - 1) // SUBCATEGORY_CHUNK_SIZE)
        for i in range(chunk_count):
            start = i * SUBCATEGORY_CHUNK_SIZE
            end = start + SUBCATEGORY_CHUNK_SIZE
            groups.append(
                {
                    "id": f"Chunk {i + 1:02d}",
                    "label": f"Chunk {i + 1}",
                    "prefix_key": "all",
                    "prefix_label": "All",
                    "actions": actions[start:end],
                }
            )
        return groups, {
            "method": "chunk",
            "file_group_count": len(groups),
        }

    try:
        from sklearn.cluster import MiniBatchKMeans
        from sklearn.feature_extraction.text import TfidfVectorizer
    except Exception:
        groups = []
        chunk_count = max(1, (len(actions) + SUBCATEGORY_CHUNK_SIZE - 1) // SUBCATEGORY_CHUNK_SIZE)
        for i in range(chunk_count):
            start = i * SUBCATEGORY_CHUNK_SIZE
            end = start + SUBCATEGORY_CHUNK_SIZE
            groups.append(
                {
                    "id": f"Chunk {i + 1:02d}",
                    "label": f"Chunk {i + 1}",
                    "prefix_key": "all",
                    "prefix_label": "All",
                    "actions": actions[start:end],
                }
            )
        return groups, {
            "method": "chunk_fallback_missing_sklearn",
            "file_group_count": len(groups),
        }

    cluster_plan = estimate_word_based_cluster_count(actions)
    n_clusters = int(cluster_plan.get("n_clusters", 1))
    if n_clusters <= 1:
        return [{"id": "Group", "label": "Cluster 1", "prefix_key": "all", "prefix_label": "All", "actions": actions}], {
            "method": "vector_single",
            "file_group_count": 1,
            "cluster_plan": cluster_plan,
        }

    shared_prefix_tokens: List[str] = []
    if trim_shared_prefix and len(actions) >= SECOND_PASS_MIN_ACTIONS:
        token_lists = [_vectorize_base_tokens(_low(str(a.get("title", "")))) for a in actions]
        candidate_prefix = _shared_prefix_tokens(token_lists)
        # Require a meaningful shared prefix before trimming.
        if len(candidate_prefix) >= 2:
            shared_prefix_tokens = candidate_prefix

    texts = [_title_for_vectorization(a, shared_prefix_tokens=shared_prefix_tokens) for a in actions]
    vectorizer = TfidfVectorizer(ngram_range=(1, 2), min_df=1, max_features=5000)
    X = vectorizer.fit_transform(texts)

    model = MiniBatchKMeans(n_clusters=n_clusters, random_state=42, n_init=10, batch_size=256)
    labels = model.fit_predict(X)
    feature_names = vectorizer.get_feature_names_out()

    raw_groups: Dict[int, List[Dict[str, Any]]] = {}
    for i, action in enumerate(actions):
        raw_groups.setdefault(int(labels[i]), []).append(action)

    # Avoid noisy one-action output files by folding tiny clusters into
    # the largest cluster. This keeps related variants (for example 0.5x/2x)
    # together when KMeans over-splits a very small action bucket.
    tiny_cluster_merge_count = 0
    if len(raw_groups) > 1:
        largest_cluster_id = max(raw_groups.keys(), key=lambda cid: len(raw_groups[cid]))
        tiny_cluster_ids = [
            cid for cid in sorted(raw_groups.keys())
            if cid != largest_cluster_id and len(raw_groups[cid]) < 2
        ]
        for cid in tiny_cluster_ids:
            raw_groups[largest_cluster_id].extend(raw_groups[cid])
            tiny_cluster_merge_count += len(raw_groups[cid])
            del raw_groups[cid]

    groups: List[Dict[str, Any]] = []
    for cluster_id in sorted(raw_groups.keys()):
        cluster_actions = sorted(raw_groups[cluster_id], key=lambda a: str(a.get("title", "")))
        centroid = model.cluster_centers_[cluster_id]
        top_idx = centroid.argsort()[-8:][::-1]
        top_terms = [str(feature_names[j]) for j in top_idx if centroid[j] > 0]
        tag = _cluster_label_from_centroid(top_terms)
        semantic_name = safe_filename(tag)
        if not semantic_name:
            semantic_name = "Group"
        groups.append(
            {
                "id": semantic_name,
                "label": f"Cluster {cluster_id + 1} ({tag})",
                "prefix_key": "all",
                "prefix_label": "All",
                "actions": cluster_actions,
            }
        )

    groups.sort(key=lambda g: (-len(g["actions"]), g["id"]))

    return groups, {
        "method": "vector_tfidf_kmeans",
        "file_group_count": len(groups),
        "requested_clusters": n_clusters,
        "tiny_cluster_merge_count": tiny_cluster_merge_count,
        "trim_shared_prefix_enabled": bool(trim_shared_prefix),
        "trim_shared_prefix_tokens": shared_prefix_tokens,
        "cluster_plan": cluster_plan,
    }


def split_actions_for_output_files(actions: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    """
    Pre-split by title prefix (text before ':') and then split each bucket semantically.
    Example prefixes: Edit, Cursor, Track, Item, etc.
    """
    if not actions:
        return split_actions_vector_or_chunk(actions)

    def apply_second_pass(groups: List[Dict[str, Any]], base_meta: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
        if not USE_SECOND_PASS_RECLUSTER:
            return groups, base_meta

        refined_groups: List[Dict[str, Any]] = []
        second_pass_split_count = 0
        second_pass_created_groups = 0

        for group in groups:
            group_actions = list(group.get("actions", []))
            if len(group_actions) < SECOND_PASS_MIN_ACTIONS:
                refined_groups.append(group)
                continue

            child_groups, child_meta = split_actions_vector_or_chunk(group_actions, trim_shared_prefix=True)
            if len(child_groups) <= 1:
                refined_groups.append(group)
                continue

            second_pass_split_count += 1
            second_pass_created_groups += len(child_groups)
            parent_id = str(group.get("id", "Group"))
            parent_label = str(group.get("label", "Group"))

            for child in child_groups:
                child_id = safe_filename(str(child.get("id", "Cluster")))
                refined_groups.append(
                    {
                        "id": safe_filename(f"{parent_id} {child_id}"),
                        "label": f"{parent_label} / {child.get('label', 'Cluster')}",
                        "prefix_key": group.get("prefix_key", "all"),
                        "prefix_label": group.get("prefix_label", "All"),
                        "actions": list(child.get("actions", [])),
                        "parent_split_method": child_meta.get("method"),
                    }
                )

        if second_pass_split_count == 0:
            return groups, base_meta

        merged_meta = dict(base_meta)
        merged_meta["method"] = f"{base_meta.get('method', 'split')}+second_pass"
        merged_meta["second_pass_enabled"] = True
        merged_meta["second_pass_min_actions"] = SECOND_PASS_MIN_ACTIONS
        merged_meta["second_pass_split_count"] = second_pass_split_count
        merged_meta["second_pass_created_groups"] = second_pass_created_groups
        merged_meta["file_group_count"] = len(refined_groups)
        return refined_groups, merged_meta

    def split_one_prefix_bucket(prefix_key: str, prefix_label: str, bucket_actions: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], List[str], bool]:
        groups_local: List[Dict[str, Any]] = []
        split_methods_local: List[str] = []

        postcolon_buckets, postcolon_meta = split_actions_by_postcolon_word(bucket_actions)
        postcolon_applied = bool(postcolon_meta.get("postcolon_presplit_applied", False))

        for post_bucket in postcolon_buckets:
            post_id = str(post_bucket.get("id", "All"))
            post_label = str(post_bucket.get("label", "All"))
            post_actions = list(post_bucket.get("actions", []))
            semantic_groups, semantic_meta = split_actions_vector_or_chunk(post_actions)
            split_methods_local.append(str(semantic_meta.get("method")))

            for semantic_group in semantic_groups:
                semantic_id = str(semantic_group.get("id", "Group"))
                semantic_label = str(semantic_group.get("label", "Cluster"))
                if post_id != "all":
                    group_id = safe_filename(f"{post_id} {semantic_id}")
                    group_label = f"{prefix_label} [{post_label}] - {semantic_label}"
                else:
                    group_id = safe_filename(semantic_id)
                    group_label = f"{prefix_label} - {semantic_label}"

                groups_local.append(
                    {
                        "id": group_id,
                        "label": group_label,
                        "prefix_key": prefix_key,
                        "prefix_label": prefix_label,
                        "actions": semantic_group.get("actions", []),
                    }
                )

        return groups_local, split_methods_local, postcolon_applied

    if not USE_PREFIX_PRESPLIT:
        base_groups, base_meta = split_actions_vector_or_chunk(actions)
        return apply_second_pass(base_groups, base_meta)

    buckets: Dict[str, Dict[str, Any]] = {}
    for action in actions:
        prefix_key, prefix_label = extract_title_prefix(action)
        if prefix_key not in buckets:
            buckets[prefix_key] = {"label": prefix_label, "actions": []}
        buckets[prefix_key]["actions"].append(action)

    # Keep tiny prefix groups from exploding file count: fold into misc.
    folded_misc: List[Dict[str, Any]] = []
    stable_buckets: List[Tuple[str, Dict[str, Any]]] = []
    for key, payload in buckets.items():
        if key != "misc" and len(payload["actions"]) < PREFIX_PRESPLIT_MIN_ACTIONS:
            folded_misc.extend(payload["actions"])
        else:
            stable_buckets.append((key, payload))

    if folded_misc:
        misc_payload = next((p for k, p in stable_buckets if k == "misc"), None)
        if misc_payload is None:
            misc_payload = {"label": "Misc", "actions": []}
            stable_buckets.append(("misc", misc_payload))
        misc_payload["actions"].extend(folded_misc)

    # If no meaningful split emerged, do normal split.
    if len(stable_buckets) <= 1:
        if USE_POSTCOLON_WORD_PRESPLIT and stable_buckets:
            key, payload = stable_buckets[0]
            label = str(payload["label"])
            groups, split_methods, postcolon_applied = split_one_prefix_bucket(
                key, label, list(payload["actions"])
            )
            if postcolon_applied:
                base_meta = {
                    "method": "postcolon_presplit_then_semantic",
                    "prefix_group_count": 1,
                    "file_group_count": len(groups),
                    "nested_split_methods": sorted(set(split_methods)),
                    "postcolon_presplit_enabled": True,
                    "postcolon_presplit_applied_prefix_groups": 1,
                }
                return apply_second_pass(groups, base_meta)
        base_groups, base_meta = split_actions_vector_or_chunk(actions)
        return apply_second_pass(base_groups, base_meta)

    stable_buckets.sort(key=lambda kv: (-len(kv[1]["actions"]), kv[0]))
    groups: List[Dict[str, Any]] = []
    split_methods: List[str] = []
    postcolon_applied_prefix_groups = 0

    for prefix_index, (prefix_key, payload) in enumerate(stable_buckets, start=1):
        prefix_label = str(payload["label"])
        bucket_actions = list(payload["actions"])
        bucket_groups, bucket_methods, postcolon_applied = split_one_prefix_bucket(
            prefix_key, prefix_label, bucket_actions
        )
        groups.extend(bucket_groups)
        split_methods.extend(bucket_methods)
        if postcolon_applied:
            postcolon_applied_prefix_groups += 1

    base_meta = {
        "method": "prefix_presplit_then_semantic",
        "prefix_group_count": len(stable_buckets),
        "file_group_count": len(groups),
        "nested_split_methods": sorted(set(split_methods)),
        "postcolon_presplit_enabled": USE_POSTCOLON_WORD_PRESPLIT,
        "postcolon_presplit_applied_prefix_groups": postcolon_applied_prefix_groups,
        "postcolon_presplit_min_occurrences": POSTCOLON_WORD_PRESPLIT_MIN_OCCURRENCES,
    }
    return apply_second_pass(groups, base_meta)


def build_tree(rows: List[ActionRow]) -> Dict[str, Any]:
    top: Dict[str, Dict[str, List[ActionRow]]] = {}
    for row in rows:
        cat = top_category(row)
        if cat not in top:
            top[cat] = {}
        if cat == "items":
            sub = item_subcategory(row.title)
            top[cat].setdefault(sub, []).append(row)
        else:
            top[cat].setdefault("_leaf", []).append(row)

    tree_children: List[Dict[str, Any]] = []
    for cat_key in sorted(top.keys(), key=lambda k: TOP_LABELS.get(k, k)):
        submap = top[cat_key]
        label = TOP_LABELS.get(cat_key, cat_key)
        if cat_key == "items":
            sub_children: List[Dict[str, Any]] = []
            for sub_key in sorted(submap.keys(), key=lambda k: SUB_LABELS.get(k, k)):
                actions = [row_to_dict(r) for r in submap[sub_key]]
                sub_children.append(
                    {
                        "id": f"items.{sub_key}",
                        "label": SUB_LABELS.get(sub_key, sub_key),
                        "action_count": len(actions),
                        "actions": actions,
                    }
                )
            tree_children.append(
                {
                    "id": cat_key,
                    "label": label,
                    "action_count": sum(c["action_count"] for c in sub_children),
                    "children": sub_children,
                }
            )
        else:
            actions = [row_to_dict(r) for r in submap.get("_leaf", [])]
            tree_children.append(
                {
                    "id": cat_key,
                    "label": label,
                    "action_count": len(actions),
                    "actions": actions,
                }
            )

    total = sum(n["action_count"] for n in tree_children)
    return {"categories": tree_children, "total_categorized_actions": total}


def write_split_category_files(tree_payload: Dict[str, Any], source_file: str) -> List[Dict[str, Any]]:
    if CATEGORIES_DIR.exists():
        shutil.rmtree(CATEGORIES_DIR)
    CATEGORIES_DIR.mkdir(parents=True, exist_ok=True)
    manifest: List[Dict[str, Any]] = []

    for cat_index, category in enumerate(tree_payload.get("categories", []), start=1):
        category_id = str(category.get("id", "category"))
        category_label = str(category.get("label", category_id))
        category_folder = CATEGORIES_DIR / f"{cat_index:02d} {safe_filename(category_id)}"
        category_folder.mkdir(parents=True, exist_ok=True)

        # Standardize to one subcategory layer:
        # - categories with native children keep those
        # - leaf categories get synthetic "all" subcategory
        if isinstance(category.get("children"), list):
            subcategories = category["children"]
        else:
            subcategories = [
                {
                    "id": f"{category_id}.all",
                    "label": "All actions",
                    "action_count": category.get("action_count", 0),
                    "actions": category.get("actions", []),
                }
            ]

        manifest_subcategories: List[Dict[str, Any]] = []

        for sub_index, sub in enumerate(subcategories, start=1):
            sub_id = str(sub.get("id", "subcategory"))
            sub_label = str(sub.get("label", sub_id))
            sub_actions = list(sub.get("actions", []))
            # Avoid middleman folders for synthetic leaf subcategories (*.all).
            is_synthetic_all = sub_id == f"{category_id}.all"
            if is_synthetic_all:
                sub_folder = category_folder
            else:
                sub_folder = category_folder / f"{sub_index:02d} {safe_filename(sub_id)}"
            sub_folder.mkdir(parents=True, exist_ok=True)

            chunk_files: List[str] = []
            file_groups, split_meta = split_actions_for_output_files(sub_actions)
            prefix_folder_map: Dict[str, Path] = {}
            prefix_order = 0
            used_group_file_basenames = set()

            for group_index, group in enumerate(file_groups, start=1):
                group_actions = group["actions"]
                group_id = str(group["id"])
                group_label = str(group["label"])
                prefix_key = str(group.get("prefix_key", "all"))
                prefix_label = str(group.get("prefix_label", "All"))
                base_name = safe_filename(group_id) or "Group"
                unique_name = base_name
                name_index = 2
                while unique_name in used_group_file_basenames:
                    unique_name = f"{base_name} {name_index}"
                    name_index += 1
                used_group_file_basenames.add(unique_name)
                group_name = f"{unique_name}.lua"

                if split_meta.get("method") == "prefix_presplit_then_semantic":
                    if prefix_key not in prefix_folder_map:
                        prefix_order += 1
                        prefix_folder = sub_folder / f"{prefix_order:02d} {safe_filename(prefix_key)}"
                        prefix_folder.mkdir(parents=True, exist_ok=True)
                        prefix_folder_map[prefix_key] = prefix_folder
                    target_folder = prefix_folder_map[prefix_key]
                else:
                    target_folder = sub_folder

                chunk_path = target_folder / group_name
                chunk_rel_path = chunk_path.relative_to(ROOT).as_posix()

                chunk_payload = {
                    "source_file": source_file,
                    "schema": (
                        "File-group of actions for one macro category + subcategory, "
                        "split by vector similarity where available. "
                        "Each action includes an editable appearance placeholder block."
                    ),
                    "category_id": category_id,
                    "category_label": category_label,
                    "subcategory_id": sub_id,
                    "subcategory_label": sub_label,
                    "group_index": group_index,
                    "group_count": len(file_groups),
                    "group_id": group_id,
                    "group_label": group_label,
                    "prefix_key": prefix_key,
                    "prefix_label": prefix_label,
                    "split_method": split_meta.get("method"),
                    "action_count": len(group_actions),
                    "actions": group_actions,
                }
                write_lua_table(chunk_path, "action_chunk", chunk_payload)
                chunk_files.append(chunk_rel_path)

            manifest_subcategories.append(
                {
                    "id": sub_id,
                    "label": sub_label,
                    "action_count": len(sub_actions),
                    "folder": sub_folder.relative_to(ROOT).as_posix(),
                    "split_method": split_meta.get("method"),
                    "files": chunk_files,
                }
            )

        manifest.append(
            {
                "id": category_id,
                "label": category_label,
                "action_count": category.get("action_count"),
                "folder": category_folder.relative_to(ROOT).as_posix(),
                "subcategories": manifest_subcategories,
            }
        )

    return manifest


def main() -> int:
    inp = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_INPUT
    if not inp.is_file():
        print(f"Missing input: {inp}", file=sys.stderr)
        return 1

    rows_raw, meta = parse_ultraschall(inp)
    rows_after_phrase_filter, filter_report = filter_actions(rows_raw)
    rows_after_dedupe, dedupe_report = dedupe_actions(rows_after_phrase_filter)
    rows_after_toggle_variant_filter, toggle_variant_report = filter_toggle_enable_disable_variants(rows_after_dedupe)
    rows_after_manual_widget_omissions, manual_widget_report, manual_widget_payload = apply_manual_widget_omissions(rows_after_toggle_variant_filter)
    rows, widget_series_report, widget_series_payload = detect_widget_series_suggestions(rows_after_manual_widget_omissions)
    widget_report = {
        "widget_series_detection": {
            "min_series_size": WIDGET_SUGGESTION_MIN_SERIES_SIZE,
            "manual_omitted_count": int(manual_widget_report["manual_widget_omissions"]["omitted_count"]),
            "numeric_series_omitted_count": int(widget_series_report["widget_series_detection"]["omitted_count"]),
            "omitted_count": int(manual_widget_report["manual_widget_omissions"]["omitted_count"])
            + int(widget_series_report["widget_series_detection"]["omitted_count"]),
            "manual_suggestion_count": int(manual_widget_report["manual_widget_omissions"]["suggestion_count"]),
            "numeric_series_suggestion_count": int(widget_series_report["widget_series_detection"]["suggestion_count"]),
            "suggestion_count": int(manual_widget_report["manual_widget_omissions"]["suggestion_count"])
            + int(widget_series_report["widget_series_detection"]["suggestion_count"]),
        },
        **manual_widget_report,
    }
    widget_omissions_payload = {
        "schema": (
            "Widget suggestions/omissions derived from manual rules and repeated numbered action-series. "
            "Suggested groups are omitted from the main action outputs."
        ),
        "suggestion_count": int(manual_widget_payload.get("suggestion_count", 0))
        + int(widget_series_payload.get("suggestion_count", 0)),
        "omitted_action_count": int(manual_widget_payload.get("omitted_action_count", 0))
        + int(widget_series_payload.get("omitted_action_count", 0)),
        "suggestions": list(manual_widget_payload.get("suggestions", []))
        + list(widget_series_payload.get("suggestions", [])),
    }
    passed_flat_text_path = OUT_DIR / "reaper_actions_passed_flat.txt"
    write_passed_actions_flat_file(passed_flat_text_path, rows)

    include_organized_passed = "--include-organized-passed" in sys.argv
    requested_lua_outputs = "--with-lua" in sys.argv
    passed_flat_organized_text_path = OUT_DIR / "reaper_actions_passed_flat_organized.txt"

    # Your Lua runtime depends on these being present. If you run with text-only mode
    # but the Lua files are missing, we fall back to generating them once.
    required_manifest_path = OUT_DIR / "category_manifest.lua"
    required_categories_dir = CATEGORIES_DIR
    generate_lua_outputs = requested_lua_outputs or (
        not required_manifest_path.exists() or not required_categories_dir.exists()
    )

    if include_organized_passed:
        write_passed_actions_organized_file(passed_flat_organized_text_path, rows)

    WIDGET_OMISSIONS_REPORT_PATH.write_text(
        format_widget_omissions_report(widget_omissions_payload),
        encoding="utf-8",
    )
    print_widget_omissions_report(widget_omissions_payload)

    if generate_lua_outputs:
        flat_path = OUT_DIR / "reaper_actions_flat.lua"
        tree_path = OUT_DIR / "reaper_actions_categorization.lua"
        manifest_path = OUT_DIR / "category_manifest.lua"

        flat_payload = {
            **meta,
            **filter_report,
            **dedupe_report,
            **toggle_variant_report,
            **widget_report,
            "action_count": len(rows),
            "actions": [row_to_dict(r) for r in rows],
        }
        write_lua_table(flat_path, "actions_flat", flat_payload)

        tree_payload = {
            **meta,
            **filter_report,
            **dedupe_report,
            **toggle_variant_report,
            **widget_report,
            "schema": (
                "Nested categories with full action entries under each leaf as Lua tables. "
                "Each action includes an editable appearance placeholder block."
            ),
            "categorization_note": (
                "Rule-based grouping for navigation; refine by editing "
                "generate_action_categorization.py. Items include native Item:, Take:, "
                "Item edit:, and Item properties: actions."
            ),
            **build_tree(rows),
        }
        write_lua_table(tree_path, "actions_categorization", tree_payload)

        manifest_payload = {
            "source_file": str(inp.relative_to(ROOT)),
            "schema": (
                "Index of folderized category output: macro category folders, "
                "one layer of subcategory folders, and one or more Lua action-chunk files per subcategory."
            ),
            "categories": write_split_category_files(
                tree_payload, str(inp.relative_to(ROOT))
            ),
        }
        write_lua_table(manifest_path, "category_manifest", manifest_payload)

    print(
        f"Parsed {len(rows_raw)} actions, filtered out {filter_report['filtered_out_count']}, "
        f"deduped {dedupe_report['deduped_count']}, "
        f"toggle-variant filtered {toggle_variant_report['toggle_variant_filter']['filtered_out_count']}, "
        f"widget-omitted {widget_report['widget_series_detection']['omitted_count']}, kept {len(rows)}"
    )
    if toggle_variant_report["toggle_variant_filter"]["groups_over_three_count"] > 0:
        print(
            "Toggle-variant groups with >3 actions: "
            f"{toggle_variant_report['toggle_variant_filter']['groups_over_three_count']}"
        )
    print(f"Wrote passed-through flat list -> {passed_flat_text_path.relative_to(ROOT)}")
    print(f"Wrote widget omissions report -> {WIDGET_OMISSIONS_REPORT_PATH.relative_to(ROOT)}")
    if include_organized_passed:
        print(
            f"Wrote passed-through organized list -> {passed_flat_organized_text_path.relative_to(ROOT)}"
        )
    if generate_lua_outputs:
        print(f"Wrote {len(rows)} actions -> {flat_path.relative_to(ROOT)}")
        print(f"Wrote categorization tree -> {tree_path.relative_to(ROOT)}")
        print(f"Wrote category manifest -> {manifest_path.relative_to(ROOT)}")
        print(f"Wrote split categories -> {CATEGORIES_DIR.relative_to(ROOT)}")
    else:
        print("Skipped Lua output generation (text outputs only).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
