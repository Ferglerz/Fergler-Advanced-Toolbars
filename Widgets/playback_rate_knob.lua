-- Widgets/playback_rate_knob.lua
local WIDGET = require("Utils.Widget.widget_factory")

local snap_decimals = { 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0 }
local snap_semitones = {}
for i = -24, 24 do
    table.insert(snap_semitones, math.max(0.25, math.min(4.0, 2 ^ (i / 12))))
end

local CMD_PITCH_TOGGLE = 40671
local PITCH_ICON = "icons/Music/Tuning Fork.ttf"

local RATE_PRESETS = {
    { id = "0.25", short_label = "0.25x", value = 0.25 },
    { id = "0.5", short_label = "0.5x", value = 0.5 },
    { id = "0.75", short_label = "0.75x", value = 0.75 },
    { id = "1", short_label = "1x", value = 1.0 },
    { id = "1.25", short_label = "1.25x", value = 1.25 },
    { id = "1.5", short_label = "1.5x", value = 1.5 },
    { id = "2", short_label = "2x", value = 2.0 },
    { id = "4", short_label = "4x", value = 4.0 },
}

local PITCH_TOGGLE = {
    id = "pitch",
    short_label = "Pitch",
    icon = PITCH_ICON,
    toggle = true,
    get_state = function()
        return reaper.GetToggleCommandState(CMD_PITCH_TOGGLE) == 1
    end,
    on_click = function()
        reaper.Main_OnCommand(CMD_PITCH_TOGGLE, 0)
    end,
}

local SLIDE_OUT_ENTRIES = {}
for _, preset in ipairs(RATE_PRESETS) do
    SLIDE_OUT_ENTRIES[#SLIDE_OUT_ENTRIES + 1] = preset
end

local widget = {
    name = "Playback Rate",
    category = "Time, grid & tempo",
    type = "slider",
    slider_style = "simple_knob",
    knob_bg_direction = "left",
    width = 96,
    fixed_width = true,
    min_value = 0.25,
    max_value = 4.0,
    default_value = 1.0,
    title = "Rate",
    description = "Master play rate knob. Hover for rate presets and pitch-mode toggle. Right-click for semitone snap.",
    snap_points = snap_decimals,
    fine_scale = 0.1,
    update_interval = 0.05,
    _use_semitones = false,

    applyPersistedOptions = function(self, opts)
        if type(opts) == "table" and type(opts.use_semitones) == "boolean" then
            self._use_semitones = opts.use_semitones
        end
        self.snap_points = self._use_semitones and snap_semitones or snap_decimals
    end,

    exportPersistedOptions = function(self)
        return { use_semitones = self._use_semitones }
    end,

    format = function(value)
        return string.format("%.0f%%", value * 100)
    end,

    renderCustom = function(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local bg_only = self._edit_bg_only == true
        local preview = self._preview_mode == true
        local body_h = WIDGET.CHIP_ROW.widget_body_height(layout)
        WIDGET.ELEMENTS.knob(ctx, self, coords, draw_list, rel_x, rel_y, render_width, body_h, text_color, bg_color, false, preview, "simple_knob", bg_only)
    end,

    onSettingsMenu = function(self, ctx, button)
        reaper.ImGui_TextDisabled(ctx, "Playback Rate Options")
        reaper.ImGui_Spacing(ctx)

        local ch, new_semitones = reaper.ImGui_Checkbox(ctx, "Snap to Semitones", self._use_semitones)
        if ch then
            self._use_semitones = new_semitones
            self.snap_points = self._use_semitones and snap_semitones or snap_decimals
            WIDGET.OPT_POPUP.commit_dynamic_widget_layout(button, ctx)
        end
    end,

    col_primary = function()
        local rate = UTILS.asNumber(reaper.Master_GetPlayRate(0), nil)
        if rate and math.abs(rate - 1.0) > 0.0001 then
            return reaper.GetThemeColor("playrate_edited", 0)
        end
        return nil
    end,

    getValue = function()
        return UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
    end,

    setValue = function(value)
        reaper.CSurf_OnPlayRateChange(value)
    end,
}

WIDGET.SLIDER_QUICK_CHIPS.attach(widget, {
    slide_out = true,
    slide_out_chip_rows = 2,
    prefix = "prk_",
    entry_rows = { SLIDE_OUT_ENTRIES },
    slide_toggles = { PITCH_TOGGLE },
    match_tolerance = 0.08,
})

return widget
