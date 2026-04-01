# Plan: One TTF per icon (icon name from filename)

## Problem statement

Today, **each icon category is a single font file** (for example `Something_28.ttf`). Many glyphs live in one font, starting at a fixed code point (U+00C0, “À”). Buttons store **`icon_font`** (path) and **`icon_char`** (the UTF-8 string for that code point).

**Downsides:**

- The meaningful identity of an icon is an opaque pair `(font path, character)`, not a human name.
- You need a **lookup table** (or external documentation) to map “what you see” to “what it means.”
- Filename conventions like `Name_28` encode **count**, not individual icon names.

**Proposed direction:**

- **One `.ttf` file per icon**, where the **stem of the filename** (e.g. `Play`, `Stop`, `Record`) is the **canonical icon name**.
- At runtime, each per-icon font exposes its glyph at a **single fixed code point: U+0041 (`'A'`)**. A **fontTools** pipeline (below) subsets each source glyph and **remaps the cmap** so every exported font encodes its icon at `0x41`. The **name comes from the output filename**, not from enumerating Unicode ranges inside a category font.

Persisted data can remain **`icon_font` + `icon_char`**: for per-icon fonts, **`icon_char` is always `"A"`** (optional later: omit `icon_char` and default to `"A"` in code).

**Legacy vs new mapping**

| Mode | Source | Runtime glyph |
|------|--------|----------------|
| Legacy (current) | One multi-glyph `.ttf` per category (`_*N*.ttf`), glyphs from U+00C0 (“À”) upward | Stored per button in `icon_char` |
| Per-icon (new) | One `.ttf` per icon after split + remap | Fixed **`"A"`** (U+0041) for every per-icon font |

---

## Current implementation (reference)

| Area | Behavior |
|------|----------|
| `Advanced Toolbars.lua` | Scans `IconFonts/*.ttf`, parses `_*digits*.ttf` for glyph count, builds `ICON_FONTS[]` with `path`, `display_name`, `icon_range` from U+00C0 (legacy). Per-icon mode uses a single slot at **U+0041**. |
| `Windows/Icon_Selector.lua` | Duplicates scan logic; lists “fonts” (categories); grid iterates code ranges; selection sets `icon_char` + `icon_font`. |
| `Renderers/04_Content.lua` | `loadIconFont` resolves font by path / `getBaseFontName`. |
| `Utils/utils.lua` | `getBaseFontName` strips `_*digits*` before `.ttf` — important for matching when multiple files share a logical family name. |
| Config / parse | `icon_char`, `icon_font` saved and loaded via `Config_Manager` / `Parse_Toolbars`. |

---

## Target behavior

1. **Discovery:** Scan `IconFonts/` for `.ttf` files. Each file = one icon entry whose **id/name** is derived from the filename (stem), with documented rules (see below).
2. **`ICON_FONTS` entries:** Each entry represents **one icon**, not one category. Fields might include: `path`, `icon_id` or `name` (from filename), `display_name` (formatted for UI), and `icon_range` **{ start = 0x41, laFin = 0x41 }** or a shared constant **`ICON_UNICODE = 0x41`** used when rendering and in the selector.
3. **Selector UI:** Replace “pick category, then pick glyph from grid” with **one scrollable list or grid of named icons** (search/filter by name). Optionally group by subfolder later (`IconFonts/Transport/Play.ttf` → group “Transport”).
4. **Rendering:** Push the correct per-icon ImGui font; draw **`"A"`** (or `utf8(0x41)`) for that font. No per-button glyph variation for per-icon mode—identity is **`icon_font` path** (and optional display name from stem).
5. **Toolbar reload icon / `Global_Settings_Menu`:** `ensureReloadIconFont` today targets `FontIcons` by base name. Redefine to “first available icon font” or a dedicated `UI.ttf` shipped with the script — do not assume a multi-glyph `FontIcons` file exists.

---

## Build pipeline: `fontTools` (pip) + split script

**Install (once per machine / venv):**

```bash
pip install fonttools
```

Use the **`fonttools`** package on PyPI (imports: `fontTools.ttLib`, `fontTools.subset`). Pin a version in `requirements.txt` when you add the script to the repo.

**Role:** Take an existing **category font** (many glyphs) and produce **one `.ttf` per glyph**, each with that glyph moved to **U+0041** so the Reaper script can treat every icon font identically at runtime.

**Reference script** (adapt paths, error handling, and naming as needed):

```python
import os
from fontTools.ttLib import TTFont
from fontTools.subset import Subsetter, Options

def split_font_to_individual_as(input_path, output_folder):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    base_font = TTFont(input_path)
    unicode_map = base_font.getBestCmap()
    target_unicode = 0x41  # 'A'

    for char_code, glyph_name in unicode_map.items():
        try:
            char_repr = chr(char_code) if char_code > 32 else f"uni{char_code}"
            safe_name = "".join(x for x in char_repr if x.isalnum()) or f"char_{char_code}"

            options = Options()
            options.layout_features = ["*"]
            subsetter = Subsetter(options=options)
            subsetter.populate(unicodes=[char_code])

            new_font = TTFont(input_path)
            subsetter.subset(new_font)

            for table in new_font["cmap"].tables:
                table.cmap = {target_unicode: glyph_name}

            output_filename = os.path.join(output_folder, f"font_char_{safe_name}.ttf")
            new_font.save(output_filename)
            print(f"Exported: {char_repr} as 'A' to {output_filename}")
        except Exception as e:
            print(f"Could not process character {char_code}: {e}")

    base_font.close()

# split_font_to_individual_as("your_font.ttf", "split_characters")
```

**Naming the icons:** The sample emits `font_char_*.ttf` from source characters. For **semantic names** (`Play.ttf`, `Mute.ttf`), either:

- **Rename** files after generation to match your icon vocabulary, or  
- **Extend the script** with a sidecar map (CSV/JSON): `source_codepoint or glyph_name → output_stem`, and write `"{stem}.ttf"`.

**Validation:** Open a few outputs in a font viewer or re-load with `TTFont` and confirm `getBestCmap()` is `{65: '<glyphname>'}`.

**Implementation notes:**

- Run this **offline**; commit only the resulting `.ttf` files under `IconFonts/` (or document a release step). Reaper users do **not** need Python at runtime.
- Verify **subset + cmap rewrite** order against your source fonts; complex fonts may need extra tables or `notdef` handling—test edge glyphs (control chars, PUA).
- **Reserved filename:** avoid clashing with legacy patterns (`_*N*.ttf`) if both modes coexist; use a separate subfolder or detection rule.

---

## Filename and naming rules (specify before coding)

- **Stem = icon id:** e.g. `Play.ttf` → `Play`. Recommend documenting: ASCII letters, numbers, underscore; no spaces or reserved OS characters (align with `UTILS.getSafeFilename` if users type names elsewhere).
- **Display name:** Reuse or extend `UTILS.formatFontName` (e.g. `Play_Alt` → “Play Alt”) — avoid stripping digits that are part of the icon name unless you introduce a separate convention.
- **Conflict policy:** Two files whose stems normalize to the same id → define error logging vs. last-wins vs. subdirectory prefix in the displayed name.
- **Deprecation:** Old `Category_N.ttf` files either supported during a **migration window** (see below) or replaced in one release with a clear changelog.

---

## Implementation phases

### Phase 1 — Unify scanning (single source of truth)

- Extract **one function** (e.g. `IconFonts.scanIconFonts(script_path)`) used by both `Advanced Toolbars.lua` and `Icon_Selector.lua` so behavior cannot drift.
- Implement **mode detection** or **explicit config**:
  - **Legacy mode:** existing `_*N*.ttf` multi-glyph fonts (current behavior).
  - **Per-icon mode:** each `.ttf` is one icon; ignore or repurpose the `_N` suffix rule (e.g. only treat as legacy when pattern matches and you opt in).

Deliverable: identical `ICON_FONTS` / font map shape in both call sites.

### Phase 2 — Data model for per-icon fonts

- For per-icon files, set `icon_range` to **one code point** (start == end == **0x41**) matching the **fontTools remap**. Do **not** use U+00C0 for new assets unless you keep a legacy branch.
- When saving buttons that use per-icon fonts, **`icon_char` can always be `"A"`**; migration may set this automatically when loading old configs that pointed at multi-glyph fonts.
- Add optional **`icon_id`** on each entry (redundant with path but useful for UI and future refactors).
- Adjust **`getBaseFontName`** / matching logic: today stripping `_digits` collapses `Foo_1.ttf` and `Foo_2.ttf` to the same base name. Per-icon fonts need **unique** resolution — typically **full stem** or **full relative path** as the key. Plan explicit rules for `loadIconFont` and saved `icon_font` paths.

### Phase 3 — Icon selector UX

- Replace category list + glyph grid with:
  - **Search box** (filter by display name / stem).
  - **Grid or list** of icons (each cell: preview using that font + fixed char, label = name under/beside).
- Performance: for hundreds of fonts, consider **virtualized** scrolling or lazy font attach if ReaImGui allows; if not, document a practical upper bound.

### Phase 4 — Font loading and contexts

- `CreateToolbar` already attaches every `ICON_FONTS[i].font` to each toolbar context. **N icons ⇒ N ImGui fonts** — measure memory and startup cost; if problematic, plan **lazy attach** (only fonts in use + selector-visible subset) as a follow-up.

### Phase 5 — Migration and compatibility

- **Existing configs** store `icon_font` paths pointing at old multi-glyph files. Options:
  - **A.** Ship a **migration script** or one-time conversion that maps old `(font, char)` to a new per-icon path via a generated map table.
  - **B.** Keep **legacy reader**: if path matches old convention, keep range iteration in selector only for those files.
  - **C.** Breaking change: document re-export as per-icon fonts and re-pick icons in UI.

Pick one strategy and document it in release notes.

### Phase 6 — Cleanup and docs

- Remove duplicated scan code paths.
- Update any user-facing text (“Place TTF files…”).
- Document **pip / fonttools** for maintainers: `requirements.txt`, how to run the split script, and that **glyph address for icons is `A`**.
- Optional: add `IconFonts/README.md` describing layout and naming (only if you want repo-level user docs).

---

## Testing checklist

- Fresh install: empty `IconFonts` → graceful empty state.
- Single per-icon font → appears in selector, saves and reloads correctly.
- Multiple toolbar windows / contexts → icon renders in each.
- Mixed legacy + per-icon (if supported) → no wrong font / wrong glyph.
- `getBaseFontName` and saved paths stable across Windows vs. macOS/Linux path separators (existing `normalizeSlashes` usage).

---

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Many TTFs → slow startup / high memory | Lazy font loading; icon subset; or pack sprites (out of scope unless needed). |
| Filename collisions | Strict naming doc + optional subfolders for namespaces. |
| Per-icon font cmap not exactly `{65: glyph}` | Standardize on the **fontTools** pipeline; validate outputs before shipping. |
| Python / pip not available for asset authors | Document install clearly; pre-build icons in repo so end users only need `.ttf` files. |
| `getBaseFontName` breaking matching | Move to path-based or full-stem keys for per-icon mode. |

---

## Summary

The restructure is **wiring, UX, and a fixed icon encoding**: **fontTools** splits category fonts into **one `.ttf` per icon** with each glyph remapped to **`'A'` (U+0041)**. The script is maintained with **`pip install fonttools`**. At runtime, one canonical scanner builds **`ICON_FONTS` as a flat list of named icons**; the selector picks by **filename stem**; rendering uses **`icon_font` + `"A"`** for per-icon entries. Legacy multi-glyph fonts can remain on **U+00C0** until migrated. Serialized **`icon_font` + `icon_char`** stays compatible if per-icon buttons store **`icon_char = "A"`** (or default it in code).

---

## Open questions (resolve during implementation)

1. Subfolder support for grouping (`IconFonts/Group/Name.ttf`)?
2. Keep `icon_char` forever or migrate to optional field with default **`"A"`** for per-icon mode?
3. Maximum number of icon fonts you want to support without lazy loading?
4. Single shared “UI icons” font for non-toolbar chrome vs. reusing first user icon?
5. Sidecar **codepoint → name** map for the split script vs. manual renames only?
