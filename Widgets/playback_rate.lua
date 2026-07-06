-- Widgets/playback_rate.lua
-- Master play rate: multiswitch presets plus a spinner (− / semitone readout / +).
-- Layout: WIDGET.SpinnerSlideOut (clone this file only for similar spinner + slide-out rate widgets).

local WIDGET = require("Utils.Widget.widget_factory")
local CMD_RATE_UP = 40522
local CMD_RATE_DOWN = 40523

local RATES = {
    { id = "0.25", rate = 0.25, default_on = true, short_label = "0.25x" },
    { id = "0.5", rate = 0.5, default_on = true, short_label = "0.5x" },
    { id = "0.75", rate = 0.75, default_on = false, short_label = "0.75x" },
    { id = "1", rate = 1.0, default_on = true, short_label = "1x" },
    { id = "1.125", rate = 1.125, default_on = false, short_label = "1.125x" },
    { id = "1.25", rate = 1.25, default_on = true, short_label = "1.25x" },
    { id = "1.5", rate = 1.5, default_on = true, short_label = "1.5x" },
    { id = "1.75", rate = 1.75, default_on = false, short_label = "1.75x" },
    { id = "2", rate = 2.0, default_on = true, short_label = "2x" },
    { id = "2.5", rate = 2.5, default_on = false, short_label = "2.5x" },
    { id = "3", rate = 3.0, default_on = false, short_label = "3x" },
    { id = "4", rate = 4.0, default_on = true, short_label = "4x" },
}

WIDGET.CHIP_MS.normalize_chip_entries(RATES)

local LN2 = math.log(2)

local function rate_to_semitones(rate)
    rate = UTILS.asNumber(rate, nil)
    if not rate or rate <= 0 then
        return 0
    end
    return 12 * math.log(rate) / LN2
end

local function semitones_to_rate(st)
    st = UTILS.asNumber(st, nil)
    if not st then
        return nil
    end
    local r = math.pow(2, st / 12)
    if r < 0.25 then
        r = 0.25
    elseif r > 4.0 then
        r = 4.0
    end
    return r
end

local function format_semitones_display(st)
    st = UTILS.asNumber(st, 0) or 0
    if math.abs(st) < 1e-10 then
        return "0st"
    end
    return string.format("%g", st) .. "st"
end

local function parse_semitones_input(s)
    if type(s) ~= "string" then
        return nil
    end
    s = s:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("st%s*$", "")
    if s == "" or s == "+" or s == "-" or s == "." or s == "+." or s == "-." then
        return nil
    end
    return tonumber(s)
end

local function enabled_list(self)
    local list = {}
    for _, e in ipairs(RATES) do
        local v = self._included and self._included[e.id]
        if v == nil then
            v = e.default_on
        end
        if v == true then
            list[#list + 1] = e
        end
    end
    return list
end

local function active_preset_id(self, play_rate, list)
    play_rate = UTILS.asNumber(play_rate, nil)
    if not play_rate or not list or #list < 1 then
        return nil
    end
    local best_e, best_d
    for _, e in ipairs(list) do
        local er = UTILS.asNumber(e.rate, nil)
        if er then
            local d = math.abs(play_rate - er)
            if best_d == nil or d < best_d or (best_e and math.abs(d - best_d) < 1e-9 and er < best_e.rate) then
                best_d = d
                best_e = e
            end
        end
    end
    if best_e and type(best_d) == "number" and best_d < 0.11 then
        return best_e.id
    end
    return nil
end

return WIDGET.SpinnerSlideOut.new({
    name = "Playback Rate",
    category = "Time, grid & tempo",
    type = "display",
    update_interval = 0.05,
    description = "Master play rate: preset multiswitch (right-click to choose visible rates) and a semitone spinner "
        .. "(− / + use transport semitone nudge actions; center field is semitones vs 1.0×, type like pin offsets).",
    label = "",
    width = 280,
    settings_title = "Playback Rate Options",
    preview_title = "Play rate",
    preview_ids = { "0.75", "1", "1.25" },
    preview_selected_id = "1",

    modes = RATES,
    cmd_spinner_up = CMD_RATE_UP,
    cmd_spinner_down = CMD_RATE_DOWN,
    cmd_pitch_toggle = 40671,

    format = function(val)
        return string.format("%gx", val)
    end,

    col_primary = function()
        local rate = UTILS.asNumber(reaper.Master_GetPlayRate(0), nil)
        if rate and math.abs(rate - 1.0) > 0.0001 then
            return reaper.GetThemeColor("playrate_edited", 0)
        end
        return nil
    end,

    getValue = function(self)
        local r = UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
        self._play_rate = r
        self._active_ms_id = active_preset_id(self, r, enabled_list(self))
        return r
    end,

    active_preset_id = active_preset_id,

    on_mode_select = function(self, e)
        reaper.CSurf_OnPlayRateChange(e.rate)
        self._play_rate = e.rate
        self._active_ms_id = e.id
    end,

    spinner_overlay = {
        hint = "st, e.g. -2",
        get_live_rate = function()
            return UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
        end,
        rate_to_display = function(rate)
            return format_semitones_display(rate_to_semitones(rate))
        end,
        parse_input = parse_semitones_input,
        apply_semitones = semitones_to_rate,
        on_rate_applied = function(self, nr)
            reaper.CSurf_OnPlayRateChange(nr)
            self._play_rate = nr
        end,
    },
})
