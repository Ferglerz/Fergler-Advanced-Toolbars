-- Utils/widget_factory.lua
--
-- Widget authoring (pick one):
--   Readout only          → plain table (see volume_readout.lua)
--   Mode multiswitch      → WIDGET.CHIP_MODE.new (see project_timebase.lua)
--   Bespoke + slide grid  → WIDGET.CHIP_MODE.bind_slide_out (see metronome_control.lua)
--   Toggle / multi rows   → WIDGET.Segmented
--   Action chip row       → WIDGET.DISCRETE_CHIP_ROW.new (see item_rate_nudge.lua)
--   Spinner + slide rates → WIDGET.SpinnerSlideOut.new (see playback_rate.lua; rare)
--   Host + option slide-out → WIDGET.OPTIONS_SLIDE_OUT helpers + WIDGET.Segmented (see lock_settings.lua)
--   Bespoke UI            → renderCustom and/or segment render_custom_chip
--
-- Facade exports: CHIP_MODE, DISCRETE_CHIP_ROW, SpinnerSlideOut, SLIDER_QUICK_CHIPS, OPTIONS_SLIDE_OUT, ELEMENTS, DIM_CHIP, …
-- Override points: spec.renderCustom, spec.hitTestSubcontrols, segment render_custom_chip, etc.

local CHIP_ROW = require("Utils.Chips.chip_row")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local DRAWING = require("Utils.Draw.drawing")
local OPT_POPUP = require("Utils.Widget.widget_options_popup")
local ICON_FONTS = require("Utils.Core.icon_fonts")
local CHIP_HIT = require("Utils.Chips.chip_hit_prefix")
local PREVIEW_FB = require("Utils.Widget.widget_preview_fallback")
local CHIP_MODE = require("Utils.Widget.chip_mode_widget")
local FLEX_LAYOUT = require("Utils.Core.flex_layout")
local VIS = require("Utils.Widget.widget_visibility")
local WIDGET_TITLE = require("Utils.Widget.widget_title")
local DISCRETE_CHIP_ROW = require("Utils.Widget.discrete_chip_row_widget")
local SPINNER_SLIDE_OUT = require("Utils.widget_spinner_slide_out")
local SLIDER_QUICK_CHIPS = require("Utils.Widget.slider_quick_chips")
local DIM_CHIP = require("Utils.Widget.widget_draw_dim_chip")
local OPTIONS_SLIDE_OUT = require("Utils.Widget.options_slide_out")
local WIDGET_ELEMENTS = require("Utils.Widget.widget_elements")
local SEGMENTED = require("Utils.Widget.segmented_widget")

local M = {}

M.CHIP_ROW = CHIP_ROW
M.CHIP_MS = CHIP_MS
M.DRAWING = DRAWING
M.OPT_POPUP = OPT_POPUP
M.ICON_FONTS = ICON_FONTS
M.CHIP_HIT = CHIP_HIT
M.PREVIEW_FB = PREVIEW_FB
M.CHIP_MODE = CHIP_MODE
M.FLEX_LAYOUT = FLEX_LAYOUT
M.VIS = VIS
M.WIDGET_TITLE = WIDGET_TITLE
M.DISCRETE_CHIP_ROW = DISCRETE_CHIP_ROW
M.SpinnerSlideOut = SPINNER_SLIDE_OUT
M.SLIDER_QUICK_CHIPS = SLIDER_QUICK_CHIPS
M.OPTIONS_SLIDE_OUT = OPTIONS_SLIDE_OUT
M.DIM_CHIP = DIM_CHIP
M.ELEMENTS = WIDGET_ELEMENTS

--- Shared greyed-out state: set widget.is_disabled = function() return <bool> end
function M.isDisabled(widget)
    return COLOR_UTILS.isWidgetDisabled(widget)
end

-- Applies standard base properties to a widget definition
local function apply_base_props(widget, spec)
    widget.name = spec.name
    widget.category = spec.category or "Custom"
    widget.type = spec.type or "display"
    widget.update_interval = spec.update_interval or 0.2
    widget.description = spec.description or ""
    widget.label = spec.label or ""
    widget.chip_widget = true
    widget.suppress_tooltip = spec.suppress_tooltip ~= false
    widget.width = spec.width or 120

    if spec.slide_out then
        widget._slide_out_mode = true
    end

    if spec.slide_out_can_interact then
        widget.slide_out_can_interact = spec.slide_out_can_interact
    end

    if spec.init then
        spec.init(widget)
    end

    for k, v in pairs(spec.state or {}) do
        widget[k] = v
    end

    return widget
end

function M.Segmented(spec)
    return SEGMENTED.new(spec, apply_base_props)
end

return M
