# Widget authoring

Drop a `.lua` file in `Widgets/` (or a subfolder). Return a table with at least `name` and `type`. Reload Advanced Toolbars — it appears in the picker.

Copy from `_templates/` or run `python3 tools/scaffold_widget.py <tier> <filename>` from the repository root. The script supports tiers `1`, `1b`, `1c`, `2`, `3`, `4`, and `5` and refuses to overwrite an existing widget.

## Tiers (pick one)

| Tier | Use when | Entry point | Gold example |
|------|----------|-------------|--------------|
| 1 | Read-only value | Plain table, `type = "display"` | `volume_readout.lua` |
| 1b | Draggable control | Plain table, `type = "slider"` | `volume_slider.lua` |
| 1c | Popup list | Plain table, `type = "dropdown"` | `region_list.lua` |
| 2 | Mode multiswitch chips | `WIDGET.CHIP_MODE.new({...})` | `project_timebase.lua` |
| 3 | Action button chips | `WIDGET.DISCRETE_CHIP_ROW.new({...})` | `item_rate_nudge.lua` |
| 4 | Spinner + rate presets | `WIDGET.SpinnerSlideOut.new({...})` | `playback_rate.lua` |
| 5 | Custom layout / paint | `renderCustom`, manual hit-test | `track_state.lua` |

`_templates/` files are **not** loaded — copy and rename into `Widgets/`.

## Required fields

| Field | Notes |
|-------|-------|
| `name` | Shown in picker |
| `type` | `display`, `slider`, `dropdown`, or `colour_swatch` |
| `category` | Picker section (see `WIDGET_CATEGORY_ORDER` in `Managers/Widgets.lua`) |
| `getValue` | Called on interval; sets `widget.value` |

Common optional: `description`, `width`, `update_interval`, `label`, `format`, `title`.

## Hooks (renderer calls these)

| Hook | When |
|------|------|
| `getValue` | Poll project state |
| `setValue` | Slider/knob drag committed; receives `(value, widget_instance)` so one-argument callbacks remain valid |
| `renderCustom` | Replace default draw for `display` / `slider` |
| `display_text` | Override formatted readout string |
| `display_value_color` | Tint readout value |
| `getLayoutWidth` / `getLayoutHeight` | Dynamic size |
| `hitTestSubcontrols` | Return sub-id under cursor |
| `onSubcontrolClick` / `onSubcontrolRightClick` | Chip/cell clicks |
| `onClick` / `onRightClick` | Whole-widget click |
| `onHover` / `onMouseWheel` | Hover / wheel |
| `onSettingsMenu` | Right-click button → settings popup |
| `onWidgetFrame` | After each frame draw |
| `slide_width` / `slide_height` | Slide-out panel size |
| `applyPersistedOptions` / `exportPersistedOptions` | Per-button saved options |
| `scanRegions` / `scanTemplates` / `scanToolbars` / `scanMenuItems` | Refresh dropdown data |
| `init` | Once when factory builds widget |
| `col_primary` | Slider track colour from selection |
| `renderColourSwatch` | `colour_swatch` type paint |
| `is_disabled` | Dim slider when true |

Unknown `onXxx` hooks log a warning at load (`Utils/widget_validator.lua`).

## Factory spec (`WIDGET.CHIP_MODE`, etc.)

Use **`apply`** when a mode chip is clicked:

```lua
apply = function(self, mode)
    -- mode is the entry from your modes table
end,
```

`set_active_on_apply = false` keeps toolbar label unchanged until next `getValue` (mixed/aggregate UIs).

Override points: `renderCustom`, `hitTestSubcontrols`, `draw_chip`, `chip_width`, `can_interact`, `get_draw_state`.

## Persistence

Per-button options save in toolbar config when you implement:

```lua
function widget.exportPersistedOptions(self)
    return WIDGET.VIS.export_bool_map(self, {
        ordered_ids = { "a", "b" },
        field = "_visible",
        persist_key = "visible",
    })
end

function widget.applyPersistedOptions(self, opts)
    WIDGET.VIS.apply_persisted_bool_map(self, opts, {
        ordered_ids = { "a", "b" },
        field = "_visible",
        persist_key = "visible",
        restore_id = "a",
        min_after_apply = 1,
    })
end
```

See `_templates/tier5_persisted_visibility.lua` and `track_state.lua`.

## REAPER helpers

`UTILS` merges `Utils/reaper_utils.lua`:

```lua
UTILS.runAction(40798)              -- Main_OnCommand
UTILS.runNamedAction("_SWS_RESETRATE")
UTILS.withUndoBlock("My change", function()
    -- mutating calls
end)
```

Domain logic (which API, which action ID) stays in your widget file.

## Framework surface

**One import for widgets:**

```lua
local WIDGET = require("Utils.Widget.widget_factory")
```

| Export | Purpose |
|--------|---------|
| `WIDGET.CHIP_MODE` | Mode multiswitch rows |
| `WIDGET.DISCRETE_CHIP_ROW` | Action chip rows |
| `WIDGET.SpinnerSlideOut` | Playback-rate style spinner |
| `WIDGET.Segmented` | Multi-row toggle / multiswitch |
| `WIDGET.SLIDER_QUICK_CHIPS` | Pan/spread preset slide-out (`.attach(widget, opts)`) |
| `WIDGET.OPTIONS_SLIDE_OUT` | Host chip + slide-out row helpers |
| `WIDGET.ELEMENTS` | Default slider/knob/display render (`knob`, `slider`, …) |
| `WIDGET.DIM_CHIP` | Solo-dim style chip draw |
| `WIDGET.CHIP_ROW`, `WIDGET.DRAWING`, `WIDGET.VIS`, … | Lower-level building blocks |

Do not `require("Renderers.*")` or `require("Utils.widget_draw_*")` from widget files — use `WIDGET.*`.

## Injected instance fields (read-only for you)

Set by the renderer; do not persist:

| Field | Meaning |
|-------|---------|
| `_host_button` | Toolbar button hosting this instance |
| `_atb_controller_id` | Toolbar controller id (dropdowns) |
| `_preview_mode` | Picker thumbnail render |
| `_preview_width_cap` | Picker width limit |
| `_slide_out_mode` | Slide-out panel active |
| `_slide_alpha_factor` | Fade during slide animation |
| `_active_id` | Current mode chip id (`CHIP_MODE`) |

## Globals widgets may use

| Global | Role |
|--------|------|
| `UTILS` | Shared helpers |
| `CONFIG` | Sizes, colours, saved widget memory |
| `C` | Controllers (`C.WidgetsManager`, `C.IniManager`, …) |
| `TOOLBAR_CONTROLLERS` | Live toolbar controller list |
| `ensureIconFontAttachedToContext` | Icon font for chip labels |

## Categories

Production: `Time, grid & tempo`, `Items & selection`, `Mix & monitoring`, `Project & surfaces`, `General`.

Experimental: `category = "Under Development"` (subfolder optional).

## Checklist

1. Pick tier; copy template or gold example.
2. `local WIDGET = require("Utils.Widget.widget_factory")` if tier ≥ 2.
3. Implement `getValue` (and `setValue` for sliders).
4. Set `description` — shown in picker.
5. Reload script; check REAPER console for validator warnings.
6. Assign in edit mode; test click, slide-out, settings menu, save/reload toolbar.

## Regression checks

With Lua 5.4 and Python 3 installed, run `lua5.4 tests/test_regressions.lua` and
`python3 -m unittest discover -s tests -p 'test_*.py'` from the repository root.
GitHub Actions runs these checks and checks Lua syntax on each push and pull request.
