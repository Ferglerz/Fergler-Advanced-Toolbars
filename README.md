# Advanced Toolbars

Custom, themeable toolbar windows for REAPER — built with ReaImGui. Run actions, live project controls, and rich widgets from floating or pinned toolbars you design yourself.

---

## ✨ What You Get

Advanced Toolbars replaces the need to juggle native floating toolbars with windows you can style, rearrange, and fill with live controls. Build one toolbar for transport, another for mixing, pin a strip to your track panel — all from a visual editor.

The script stays running while toolbars are open. Close every window and the script stops until you run it again from the Action List.

---

## 📋 Requirements

| Extension | Needed for |
|-----------|------------|
| **ReaImGui** | Everything — script won't start without it |
| **SWS Extension** | Action Search (assigning actions), plus several widgets (metronome, item rate, timebase, and more) |
| **js_ReaScriptAPI** | Pinning toolbars to REAPER UI regions and the Grid Ruler Chip |
| **FeedTheCat Adaptive Grid** | FTC Adaptive Grid widget only |

ReaImGui is the only hard requirement. Everything else unlocks specific features — the script runs fine without them, but those features simply won't appear or work.

---

## 🚀 Installation

1. Copy the script folder into your REAPER **Scripts** directory.
2. In REAPER, open **Actions → Show action list**, find **Advanced Toolbars**, and add it to a toolbar or shortcut.
3. Run the action. Your first toolbar window opens.

Your settings live in the script's **`User/`** folder — not REAPER's AppData. That makes backups and reinstalls straightforward. Keep `User/` if you move or update the script.

> **Fresh start tip:** If you're installing from a dev copy, you may want to clear sample configs in `User/toolbar_configs/` and start clean.

---

## ⚡ Quick Start

1. **Run** the Advanced Toolbars action.
2. Open the **settings menu** (gear icon on the toolbar).
3. Turn on **Edit Toolbars** to add, move, and customize buttons.
4. Click the **+** chips between buttons to insert actions, separators, or widgets.
5. Turn off edit mode when you're happy — changes save automatically.

---

## 🪟 Toolbar Windows

- **Multiple windows** — launch extra toolbars from settings; each picks its own layout.
- **One toolbar per window** — the same toolbar can't show in two windows at once (greyed out in the switcher).
- **Dock and undock** — use REAPER's docker or float freely.
- **Switch toolbars** — reload, rename, or pick a different saved toolbar from the settings menu.
- **Create from template** — spawn a new toolbar based on sections from your native `reaper-menu.ini`.
- **Toolbars List widget** — optional dropdown on any toolbar for quick switching (enable in settings).

Toolbars are saved as Lua files in **`User/toolbar_configs/`**. The script reads `reaper-menu.ini` for import templates only — it does not edit your REAPER menu file.

---

## ✏️ Edit Mode

Edit mode is where the magic happens.

- **Insert** actions, separators, widgets, or (experimental) preset clusters via **+** chips.
- **Drag and drop** buttons and whole groups — reorder within a toolbar or move between open windows.
- **Group tools** — rename groups, set layout split anchors for multi-row layouts.
- **Remove** buttons and separators from the button settings menu.
- **Escape** cancels an in-progress drag.

Exit edit mode and your layout writes to disk automatically (with debounced saves and rolling backups).

---

## 🔘 Buttons & Actions

Every button can run a REAPER action — or become something more.

- **Toggle and armed states** — buttons reflect live command state with dedicated color schemes.
- **Auto-arm** — actions that work "under mouse cursor" can arm automatically on click.
- **Right-click behavior** — arm, show a dropdown, launch an action, or do nothing.
- **Dropdown menus** — build multi-item menus with headings and separators; start from curated presets.
- **Action Search** — searchable catalog of Main-section actions (requires SWS). Use it when inserting or reassigning buttons.

---

## 🎨 Customization

Make every toolbar yours.

- **Names and icons** — custom labels, built-in icon fonts, or any image file via file picker.
- **Hide labels** — per button or globally.
- **Text alignment** — left, center, or right.
- **Colors** — per-button palettes or global schemes for normal, toggled, armed, separator, and group states.
- **Color presets** — save and reuse favorite combinations.
- **Visual polish** — button height, rounding, 3D depth, spacing, separator size, and shadow controls.
- **Grouping** — merge adjacent buttons visually; optional group labels above or below.

Open **Edit Colors** from settings for global theming, or right-click (or Cmd/Ctrl+click) any button for per-button options.

---

## 🧩 Widgets

Widgets turn buttons into live controls — sliders, readouts, chip switches, dropdowns, and more. Browse them in edit mode with a categorized picker and live preview.

**20 ready-to-use widgets** across five categories, plus **15 experimental widgets** labeled "Under Development" in the picker. Experimental widgets load and work like any other — they may change or break between updates.

### Time, Grid & Tempo

| Widget | What it does |
|--------|--------------|
| **Current Track Time** | Shows play/edit cursor time on the ruler |
| **Project Tempo Display** | BPM readout — click to tap tempo |
| **Marker Navigation** | Jump between markers; add new ones |
| **FTC Adaptive Grid** | Snap and grid controls via FeedTheCat *(requires FeedTheCat script)* |

### Items & Selection

| Widget | What it does |
|--------|--------------|
| **Item Pan Slider** | Pan all selected media items |
| **Item Spreader** | Spread items around their average center |
| **Selected Items Timebase** | Switch timebase mode for selected items |
| **Project Timebase** | Set project-wide timebase |
| **FNG Item Rate Nudge** | Nudge item playrate with SWS chips *(requires SWS)* |

### Mix & Monitoring

| Widget | What it does |
|--------|--------------|
| **Track Volume Slider** | Volume for selected tracks |
| **Track Volume Read-out** | dB display for last touched track |
| **Metronome Volume Slider** | Metronome level — right-click for settings |
| **Master Peak Display** | Stereo peak meter for the master bus |
| **Last Touched Param** | Shows and controls the last touched FX parameter |
| **Playback Rate** | Preset playback speeds and semitone adjustment |

### Project & Surfaces

| Widget | What it does |
|--------|--------------|
| **CPU Usage Display** | System and REAPER CPU *(macOS)* |
| **Track State** | Global record/mute/solo/dim at a glance |
| **Colour Swatch** | Pick and apply colors to tracks and items |
| **Toolbars List** | Switch toolbars or create from template |

### Under Development

Fifteen additional widgets — transport chips, screensets, region list, recording options, and more — appear under **Under Development** in the picker. They're fun to try, but names and behavior may shift as they mature.

---

## 📌 Pinning & Docking

**Docking** uses REAPER's native docker — your toolbar lives alongside other panels.

**Pinning** anchors a floating toolbar to REAPER's UI — the track control panel, arrange view, or transport bar. Pinning requires **js_ReaScriptAPI** and a **floating, undocked** window (pinning is disabled while docked).

Set alignment, horizontal and vertical offsets, and optional transparent chrome from **Settings → Pinning**.

---

## ⚙️ Settings Overview

Open the gear menu on any toolbar:

| Tab | Controls |
|-----|----------|
| **Visual** | Sizes, spacing, rounding, depth, grouping, label visibility |
| **Pinning** | Anchor region, alignment, offsets, transparent background |
| **Special Widgets** | Toolbars List widget on all toolbars; **Grid Ruler Chip** on the timeline ruler *(off by default)* |

Above the tabs: toolbar selector, reload, rename, launch new window, close toolbar, and edit-mode toggle.

---

## 🗂️ Config & Updates

- **Main config** — `User/Advanced Toolbars - User Config.lua` (colors, sizes, window state, widget memory).
- **Per-toolbar config** — `User/toolbar_configs/*.lua` (buttons, groups, widgets, dropdowns).
- **Auto-backup** — up to 30 timestamped backups in `User/config_backups/`.

On update, new settings are added automatically from defaults. Renamed or removed settings are **not** migrated — you may need to reconfigure after an update. That's intentional; it keeps the codebase clean.

---

## 🔬 Work in Progress

**Preset Browser** — browse a curated catalog of REAPER actions to bulk-populate toolbar buttons. It works today, but cluster names are auto-generated and will be refined. MIDI actions and numbered duplicates (like "Select track 1/2/3") are intentionally omitted.

---

## 💡 Tips

- **Cmd/Ctrl+click** a widget button to open button settings instead of the widget menu.
- **Action Search** needs SWS — without it, use numeric action IDs or the legacy prompt.
- **Grid Ruler Chip** lives under Settings → Special Widgets and needs js_ReaScriptAPI.
- **CPU Usage** widget currently targets macOS system metrics.

---

Built for REAPER power users who want toolbars that work as hard as they do. Happy customizing!
