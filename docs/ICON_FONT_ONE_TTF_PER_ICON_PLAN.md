# Plan: One TTF per icon (icon name from filename)

## Problem statement

Today, **each icon category is a single font file** (for example `Something_28.ttf`). Many glyphs live in one font, starting at a fixed code point (U+00C0, “À”). Buttons store **`icon_font`** (path) and **`icon_char`** (the UTF-8 string for that code point).

**Downsides:**

- The meaningful identity of an icon is an opaque pair `(font path, character)`, not a human name.
- You need a **lookup table** (or external documentation) to map “what you see” to “what it means.”
- Filename conventions like `Name_28` encode **count**, not individual icon names.

**Proposed direction:**

- **One `.ttf` file per icon**, where the **stem of the filename** (e.g. `Play`, `Stop`, `Record`) is the **canonical icon name**.
- At runtime, each font still exposes its glyph on a **single predictable code point** (same idea as today: one “slot” per font). The **name comes from the file**, not from enumerating Unicode ranges inside a multi-glyph font.

Persisted data can remain **`icon_font` + `icon_char`** if you keep a **fixed glyph** for every per-icon font (minimal change to serialization and parsing). Optional later: drop `icon_char` and derive the display character from config.

---

## Current implementation (reference)

| Area | Behavior |
|------|----------|
| `Advanced Toolbars.lua` | Scans `IconFonts/*.ttf`, parses `_*digits*.ttf` for glyph count, builds `ICON_FONTS[]` with `path`, `display_name`, `icon_range` from U+00C0. |
| `Windows/Icon_Selector.lua` | Duplicates scan logic; lists “fonts” (categories); grid iterates code ranges; selection sets `icon_char` + `icon_font`. |
| `Renderers/04_Content.lua` | `loadIconFont` resolves font by path / `getBaseFontName`. |
| `Utils/utils.lua` | `getBaseFontName` strips `_*digits*` before `.ttf` — important for matching when multiple files share a logical family name. |
| Config / parse | `icon_char`, `icon_font` saved and loaded via `Config_Manager` / `Parse_Toolbars`. |

---

## Target behavior

1. **Discovery:** Scan `IconFonts/` for `.ttf` files. Each file = one icon entry whose **id/name** is derived from the filename (stem), with documented rules (see below).
2. **`ICON_FONTS` entries:** Each entry represents **one icon**, not one category. Fields might include: `path`, `icon_id` or `name` (from filename), `display_name` (formatted for UI), and either `icon_range` collapsed to a single code point or a constant `ICON_CODEPOINT` used everywhere.
3. **Selector UI:** Replace “pick category, then pick glyph from grid” with **one scrollable list or grid of named icons** (search/filter by name). Optionally group by subfolder later (`IconFonts/Transport/Play.ttf` → group “Transport”).
4. **Rendering:** Unchanged at a high level: push the correct ImGui font, draw the same fixed `icon_char` string (or a shared constant).
5. **Toolbar reload icon / `Global_Settings_Menu`:** `ensureReloadIconFont` today targets `FontIcons` by base name. Redefine to “first available icon font” or a dedicated `UI.ttf` shipped with the script — do not assume a multi-glyph `FontIcons` file exists.

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

- For per-icon files, set `icon_range` to **one code point** (start == end == U+00C0 or cmap’s first glyph — **verify** with your actual exported fonts).
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
| Glyph not at U+00C0 in some exports | Read actual cmap or standardize export template (FontForge / builder script). |
| `getBaseFontName` breaking matching | Move to path-based or full-stem keys for per-icon mode. |

---

## Summary

The restructure is **mostly wiring and UX**: one canonical scanner, **`ICON_FONTS` as a flat list of named icons**, selector that picks by **name**, and careful **font identity / migration** rules. Serialized **`icon_font` + `icon_char`** can stay as-is if every per-icon font uses one fixed glyph, which limits churn in `Config_Manager` and `Parse_Toolbars`.

---

## Open questions (resolve during implementation)

1. Subfolder support for grouping (`IconFonts/Group/Name.ttf`)?
2. Keep `icon_char` forever or migrate to optional field with default constant?
3. Maximum number of icon fonts you want to support without lazy loading?
4. Single shared “UI icons” font for non-toolbar chrome vs. reusing first user icon?
