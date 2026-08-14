-- Widgets/Under Development/transport_controls.lua
-- Chip-style transport controls. Optional glyphs from IconFonts/icons/Transport/*.ttf (one glyph at U+0041 per file).
-- Falls back to short text labels when a file is missing. Project time on the right.
-- Right-click a chip: open the same settings dialogs as the stock transport (e.g. play → external
-- timecode / LTC sync settings). Right-click empty area or project time: widget visibility menu (saved in toolbar config).

local WIDGET = require("Utils.Widget.widget_factory")
local ROW = WIDGET.CHIP_ROW

local RECORD_MODES = {
    { id = "rec_norm", short_label = "Norm", label = "Record: normal", cmd = 40252 },
    { id = "rec_time", short_label = "Time", label = "Record: time selection auto-punch", cmd = 40076 },
    { id = "rec_item", short_label = "Auto", label = "Record: selected item auto-punch", cmd = 40253 },
}
WIDGET.CHIP_MS.normalize_chip_entries(RECORD_MODES)

local SETTINGS = {
    play_timecode = 40619,
    metronome_preroll = 40363,
    project_recording = 40934,
    audio_device = 40099,
    loop_link_ts = 40621,
}

local TRANSPORT_ITEMS = {
    { id = "home", short_label = "|<", label = "Go to start", cmd = 40042, icon_file = "Back.ttf" },
    { id = "rewind", short_label = "<<", label = "Rewind", cmd = 40084, settings_cmd = SETTINGS.metronome_preroll, icon_file = "Back.ttf" },
    { id = "play", short_label = ">", label = "Play", cmd = 1007, settings_cmd = SETTINGS.play_timecode, icon_file = "Play.ttf" },
    { id = "pause", short_label = "||", label = "Pause", cmd = 1008, settings_cmd = SETTINGS.metronome_preroll, icon_file = "Pause.ttf" },
    { id = "stop", short_label = "[]", label = "Stop", cmd = 1016, settings_cmd = SETTINGS.audio_device, icon_file = "Stop.ttf" },
    { id = "record", short_label = "O", label = "Record", cmd = 1013, settings_cmd = SETTINGS.project_recording },
    { id = "repeat_toggle", short_label = "R", label = "Repeat", cmd = 1068, settings_cmd = SETTINGS.loop_link_ts, icon_file = "Reset Forward.ttf" },
    { id = "forward", short_label = ">>", label = "Forward", cmd = 40085, settings_cmd = SETTINGS.metronome_preroll, icon_file = "Forward.ttf" },
    { id = "end_", short_label = ">|", label = "Go to end", cmd = 40043, icon_file = "Forward.ttf" },
}
WIDGET.CHIP_MS.normalize_chip_entries(TRANSPORT_ITEMS)

local PREVIEW_CHIP_IDS = { "play", "pause", "stop" }

local function default_visible_copy()
    local t = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        t[it.id] = true
    end
    return t
end

local function ensure_state(self)
    if self._visible then
        return
    end
    self._visible = default_visible_copy()
end

local function transport_visible_slot_count(self)
    ensure_state(self)
    local n = self._show_time == true and 1 or 0
    for _, it in ipairs(TRANSPORT_ITEMS) do
        if self._visible[it.id] ~= false then
            n = n + 1
        end
    end
    return n
end

local function project_time_string()
    local position = reaper.GetPlayPosition()
    if reaper.GetPlayState() == 0 then
        position = reaper.GetCursorPosition()
    end
    local ruler_time = reaper.format_timestr_pos(position, "", -1)
    if ruler_time:find("[:%.]") then
        return ruler_time
    end
    local hms_time = reaper.format_timestr_pos(position, "", 5)
    return ruler_time .. " (" .. hms_time .. ")"
end

local function parse_jump_time(input)
    input = input:match("^%s*(.-)%s*$")
    if input == "" then
        return nil
    end

    if input:lower():find("[hms]") and not input:find(":") then
        local total_seconds = 0
        local parsed_any = false
        for val, unit in input:lower():gmatch("([%d%.]+)(%a+)") do
            local num = tonumber(val)
            if num then
                if unit == "h" or unit == "hr" or unit == "hour" or unit == "hours" then
                    total_seconds = total_seconds + num * 3600
                    parsed_any = true
                elseif unit == "m" or unit == "min" or unit == "minute" or unit == "minutes" then
                    total_seconds = total_seconds + num * 60
                    parsed_any = true
                elseif unit == "s" or unit == "sec" or unit == "second" or unit == "seconds" then
                    total_seconds = total_seconds + num
                    parsed_any = true
                elseif unit == "ms" or unit == "msec" or unit == "millisecond" or unit == "milliseconds" then
                    total_seconds = total_seconds + num / 1000
                    parsed_any = true
                end
            end
        end
        if parsed_any then
            return total_seconds
        end
    end

    if input:find(":") then
        local parts = {}
        for part in input:gmatch("[^:]+") do
            parts[#parts + 1] = part
        end
        if #parts == 4 then
            local h = tonumber(parts[1]) or 0
            local m = tonumber(parts[2]) or 0
            local s = tonumber(parts[3]) or 0
            local ms_str = parts[4]
            local ms = tonumber(ms_str) or 0
            local ms_frac = ms / (10 ^ #ms_str)
            return h * 3600 + m * 60 + s + ms_frac
        end
        if #parts == 3 then
            local m = tonumber(parts[1]) or 0
            local s = tonumber(parts[2]) or 0
            local ms_str = parts[3]
            local ms = tonumber(ms_str) or 0
            local ms_frac = ms / (10 ^ #ms_str)
            return m * 60 + s + ms_frac
        end
        if #parts == 2 then
            local m = tonumber(parts[1]) or 0
            local s = tonumber(parts[2]) or 0
            return m * 60 + s
        end
    end

    local measure, beat, cent = input:match("^(%d+)%.(%d+)%.(%d+)$")
    if measure and beat and cent then
        local tpos = tonumber(beat) - 1 + tonumber(cent) / (10 ^ #cent)
        return reaper.TimeMap2_beatsToTime(0, tpos, tonumber(measure) - 1)
    end

    local measure2, beat2 = input:match("^(%d+)%.(%d+)$")
    if measure2 and beat2 then
        return reaper.TimeMap2_beatsToTime(0, tonumber(beat2) - 1, tonumber(measure2) - 1)
    end

    local sec = tonumber(input)
    if sec then
        return sec
    end

    local native = reaper.parse_timestr_pos(input, -1)
    if native and native ~= 0 then
        return native
    end

    return nil
end

local function refresh_record_mode(self)
    if self._preview_mode then
        self._active_rec = "rec_norm"
        return
    end
    self._active_rec = nil
    for _, e in ipairs(RECORD_MODES) do
        local ok, st = pcall(reaper.GetToggleCommandState, e.cmd)
        if ok and st == 1 then
            self._active_rec = e.id
            return
        end
    end
end

local function apply_record_mode(self, chip_id)
    for _, e in ipairs(RECORD_MODES) do
        if e.id == chip_id then
            if self._active_rec ~= chip_id and e.cmd and e.cmd > 0 then
                reaper.Main_OnCommand(e.cmd, 0)
            end
            return true
        end
    end
    return false
end

local function refresh_transport_state(self)
    ensure_state(self)
    self._play_state = reaper.GetPlayState() or 0
    self._repeat_on = reaper.GetToggleCommandState(1068) == 1
    refresh_record_mode(self)
end

local function applyPersistedOptions(self, opts)
    ensure_state(self)
    if type(opts) ~= "table" then
        return
    end
    if opts.show_time ~= nil then
        self._show_time = opts.show_time == true
    end
    if type(opts.visible) ~= "table" then
        return
    end
    for id, on in pairs(opts.visible) do
        if self._visible[id] ~= nil then
            self._visible[id] = on == true
        end
    end
end

local function exportPersistedOptions(self)
    ensure_state(self)
    local vis = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        vis[it.id] = self._visible[it.id] ~= false
    end
    return {
        visible = vis,
        show_time = self._show_time == true,
    }
end

local function visible_item_list(self)
    ensure_state(self)
    local list = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        if self._visible[it.id] ~= false then
            list[#list + 1] = it
        end
    end
    return list
end

local function transport_item_by_id(id)
    for _, it in ipairs(TRANSPORT_ITEMS) do
        if it.id == id then
            return it
        end
    end
    return nil
end

local function run_transport_command(id)
    local it = transport_item_by_id(id)
    if not it then
        return false
    end
    reaper.Main_OnCommand(it.cmd, 0)
    return true
end

local function run_settings_command(id)
    local it = transport_item_by_id(id)
    if not it or not it.settings_cmd then
        return false
    end
    reaper.Main_OnCommand(it.settings_cmd, 0)
    return true
end

local function jump_to_time_from_input()
    local current = project_time_string()
    local ok, out = reaper.GetUserInputs("Jump to Time or Position", 1, "Time / Position:,extrawidth=150", current)
    if not ok or out == "" then
        return false
    end
    local t = parse_jump_time(out)
    if not t then
        return false
    end
    reaper.SetEditCurPos(t, true, true)
    return true
end

local function playback_flags(self)
    local play_state = self._play_state or 0
    return {
        playing = (play_state & 1) == 1,
        paused = (play_state & 2) == 2,
        recording = (play_state & 4) == 4,
    }
end

local RECORD_PREFIX = "rec_mode_"
local RECORD_SLIDE_OPTS = {
    pad_x = 4,
    chip_gap = 3,
    chip_pad_h = 6,
    min_chip_w = 36,
    rows = 1,
}

local CHIP_GAP = 4
local CHIP_H_PAD = 6
local CHIP_V_PAD = 3
local CHIP_ROUND = 3
local ROW_PAD_X = 4
local BG_RECORD_ARM = 0x8B2E2EFF
local TEXT_ON_RECORD_ARM = 0xFFFFFFFF

local MOMENTARY_CHIP_IDS = {
    home = true,
    rewind = true,
    forward = true,
    end_ = true,
}
local TIME_READOUT_REF = "88:88:88.888"
local TIME_READOUT_H_PAD = 12

local TRANSPORT_ICON_CHAR = utf8.char(WIDGET.ICON_FONTS.ICON_CODEPOINT)

local widget = {
    name = "Transport",
    category = "Under Development",
    update_interval = 0.05,
    type = "display",
    width = 380,
    label = "",
    description = "REAPER-style transport chips plus project time. Hover Record for Norm / Time / Auto punch modes. Right-click a chip for transport-related settings; right-click empty space or the time display to choose visible controls.",
    chip_widget = true,
    _slide_out_mode = true,
    _slide_hover_gate = false,
    _visible = nil,
    _show_time = true,
    _open_context = false,
    _play_state = 0,
    _repeat_on = false,
    _active_rec = nil,
}

function widget.applyPersistedOptions(self, opts)
applyPersistedOptions(self, opts)
end

function widget.exportPersistedOptions(self)
    return exportPersistedOptions(self)
end

local function time_readout_cell_width(ctx)
    if not ctx or not reaper.ImGui_CalcTextSize then
        return 0
    end
    local tw = reaper.ImGui_CalcTextSize(ctx, TIME_READOUT_REF) or 0
    if tw <= 0 then
        return 0
    end
    return tw + TIME_READOUT_H_PAD
end

local function transport_icon_rel_path(filename)
    if type(filename) ~= "string" or filename == "" then
        return nil
    end
    local sub_folder = filename:find("Reset") and "Reset" or "Transport"
    return "icons/" .. sub_folder .. "/" .. filename
end

local function transport_icon_font_for_item(it)
    if not it or not it.icon_file then
        return nil
    end
    local rel = transport_icon_rel_path(it.icon_file)
    if not rel then
        return nil
    end
    local mode = WIDGET.ICON_FONTS.resolveToolbarIcon(rel)
    return mode.use_icons and mode.font or nil
end

local function chip_cell_width(ctx, it)
    local font = transport_icon_font_for_item(it)
    if font then
        local icon_sz = WIDGET.CHIP_ROW.magnet_icon_size(ctx)
        local w = WIDGET.DRAWING.measureIconChipWidth(ctx, font, TRANSPORT_ICON_CHAR, CHIP_H_PAD, icon_sz)
        if w then
            return w
        end
    end
    return select(3, WIDGET.DRAWING.getTextChipMetrics(ctx, WIDGET.CHIP_MS.chip_caption(it), CHIP_H_PAD, 0))
end

local function draw_transport_chip_foreground(ctx, coords, draw_list, chip, text_col, label_text)
    local icon_sz = WIDGET.CHIP_ROW.magnet_icon_size(ctx)
    WIDGET.DRAWING.drawIconChipForeground(ctx, coords, draw_list, chip, chip.icon_font, TRANSPORT_ICON_CHAR, icon_sz, text_col, label_text)
end

function widget.getValue(self)
refresh_transport_state(self)
    return 0
end

local function get_transport_groups(self, ctx, chip_h)
    local groups = {}
    local list = visible_item_list(self)
    local item_map = {}
    for _, it in ipairs(list) do
        local cw = chip_cell_width(ctx, it)
        item_map[it.id] = {
            id = it.id,
            label = WIDGET.CHIP_MS.chip_caption(it),
            cmd = it.cmd,
            mode = it,
            icon_font = transport_icon_font_for_item(it),
            w = cw,
            h = chip_h,
        }
    end

    local group_defs = {
        { "home", "rewind" },
        { "play", "pause", "stop" },
        { "record", "repeat_toggle" },
        { "forward", "end_" },
    }

    for _, g in ipairs(group_defs) do
        local current_group = {}
        for _, id in ipairs(g) do
            if item_map[id] then
                current_group[#current_group + 1] = item_map[id]
            end
        end
        if #current_group > 0 then
            groups[#groups + 1] = current_group
        end
    end

    if not self._show_time then
        return groups
    end

    local time_w = time_readout_cell_width(ctx)
    if time_w <= 0 then
        return groups
    end

    groups[#groups + 1] = {
        { id = "time", w = time_w, h = chip_h, txt = project_time_string(), is_time = true },
    }
    return groups
end

function widget.getLayoutWidth(self, ctx, layout_is_vertical)
    if not ctx then
        return self.width or 320
    end
ensure_state(self)
    local inset = WIDGET.CHIP_ROW.button_rounding_content_pad()
    local w = ROW_PAD_X + inset
    local list = visible_item_list(self)
    for i, it in ipairs(list) do
        w = w + chip_cell_width(ctx, it)
        if i < #list then
            w = w + CHIP_GAP
        end
    end
    if self._show_time then
        local time_w = time_readout_cell_width(ctx)
        if time_w > 0 then
            w = w + CHIP_GAP + time_w
        end
    end
    w = w + ROW_PAD_X + inset
    local base = math.max(120, math.ceil(w))
    local cap = tonumber(self._preview_width_cap)
    if cap and cap > 0 then
        return math.min(base, cap)
    end
    return base
end

function widget.getLayoutHeight(self, ctx, inner_width, is_vertical_toolbar)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
ensure_state(self)
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local groups = get_transport_groups(self, ctx, chip_h)
    local inset = WIDGET.CHIP_ROW.button_rounding_content_pad()
    local inner_w = math.max(10, (inner_width or self.width or 320) - (ROW_PAD_X + inset) * 2)
    local lines = WIDGET.FLEX_LAYOUT.wrap_groups(groups, inner_w, CHIP_GAP, CHIP_GAP)
    local pad = ROW_PAD_X + inset
    return math.max(CONFIG.SIZES.HEIGHT or 28, pad * 2 + #lines * chip_h + math.max(0, #lines - 1) * CHIP_GAP)
end

local function layout_chips(ctx, self, rel_x, rel_y, render_width, layout)
    ensure_state(self)
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local groups = get_transport_groups(self, ctx, chip_h)
    local is_vertical = layout and layout.is_vertical

    local chips, deferred, meta = WIDGET.CHIP_ROW.layout_flex_wrap_groups(ctx, rel_x, rel_y, render_width, layout, groups, {
        row_pad_x = ROW_PAD_X,
        pad_y = ROW_PAD_X + WIDGET.CHIP_ROW.button_rounding_content_pad(),
        chip_gap = CHIP_GAP,
        chip_h = chip_h,
        defer_item = function(it)
            return it.is_time == true
        end,
    })

    local time_x, time_w, time_y
    if not self._show_time then
        return chips, time_x, time_w, meta.chip_h, time_y
    end

    for _, it in ipairs(deferred) do
        if it.is_time then
            time_w = it.w
            time_y = it.y
            if is_vertical then
                time_x = it.x
            else
                time_x = math.max(it.x, rel_x + render_width - meta.pad_x - time_w)
            end
        end
    end

    return chips, time_x, time_w, meta.chip_h, time_y
end

local function layout_visibility_key(self)
    ensure_state(self)
    local parts = { self._show_time and "1" or "0" }
    for _, it in ipairs(TRANSPORT_ITEMS) do
        parts[#parts + 1] = self._visible[it.id] ~= false and "1" or "0"
    end
    return table.concat(parts, "")
end

local function layout_chips_cached(ctx, self, rel_x, rel_y, render_width, layout)
    local frame_time = _G.FRAME_TIME
    local cache_key = string.format(
        "%s|%s|%s|%s|%s",
        rel_x,
        rel_y,
        render_width,
        layout and layout.is_vertical and "v" or "h",
        layout_visibility_key(self)
    )
    if frame_time and self._transport_layout_frame == frame_time and self._transport_layout_key == cache_key and self._transport_layout_cache then
        local c = self._transport_layout_cache
        return c.chips, c.time_x, c.time_w, c.chip_h, c.time_y
    end
    local chips, time_x, time_w, chip_h, time_y = layout_chips(ctx, self, rel_x, rel_y, render_width, layout)
    if frame_time then
        self._transport_layout_frame = frame_time
        self._transport_layout_key = cache_key
        self._transport_layout_cache = {
            chips = chips,
            time_x = time_x,
            time_w = time_w,
            chip_h = chip_h,
            time_y = time_y,
        }
    end
    return chips, time_x, time_w, chip_h, time_y
end

local function record_chip_visible(self)
    ensure_state(self)
    return self._visible.record ~= false
end

local function layout_record_slide(self, ctx, rel_x, rel_y, render_width, layout)
    local h = self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout) or CONFIG.SIZES.HEIGHT
    if not self._slide_out_plan then
        ROW.cache_slide_out_plan(self, ctx, render_width, h, layout, RECORD_MODES, RECORD_SLIDE_OPTS)
    end
    return ROW.layout_slide_out_multiswitch(ctx, rel_x, rel_y, render_width, h, RECORD_MODES, RECORD_SLIDE_OPTS, self._slide_out_plan)
end

local function hit_test_record_slide(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local chips = layout_record_slide(self, ctx, rel_x, rel_y, render_width, layout)
    return ROW.hit_test_chips(mx, my, coords, chips, RECORD_PREFIX)
end

local function render_record_slide(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color, layout)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    local mx, my = coords:getRelativeMouse()
    local chips = layout_record_slide(self, ctx, rel_x, rel_y, render_width, layout)
    WIDGET.CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        grid_layout = true,
        slide_namespace = "rec_mode_so",
        alpha_factor = self._slide_alpha_factor,
        is_selected_segment = function(c)
            return self._active_rec == c.mode.id
        end,
    })
end

function widget.slide_width(self, ctx, host_w, host_h, layout)
    local plan = ROW.cache_slide_out_plan(self, ctx, host_w, host_h, layout, RECORD_MODES, RECORD_SLIDE_OPTS)
    return ROW.slide_out_panel_width(host_w, plan.w, layout)
end

function widget.slide_height(self, ctx, host_w, host_h, layout)
    if not self._slide_out_plan then
        ROW.cache_slide_out_plan(self, ctx, host_w, host_h, layout, RECORD_MODES, RECORD_SLIDE_OPTS)
    end
    return self._slide_out_plan.h
end

function widget.slide_out_anchor(self, ctx, coords, rel_x, rel_y, render_width, layout)
    if not record_chip_visible(self) or not ctx then
        return nil
    end
    local chips = layout_chips_cached(ctx, self, rel_x, rel_y, render_width, layout)
    for _, chip in ipairs(chips) do
        if chip.id == "record" then
            return chip.x, chip.y, chip.w, chip.h
        end
    end
    return nil
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out or self._is_rendering_slide_out then
        return hit_test_record_slide(self, ctx, coords, rel_x, rel_y, render_width, layout)
    end

    local mx, my = coords:getRelativeMouse()
    local chips, time_x, time_w, chip_h, time_y = layout_chips_cached(ctx, self, rel_x, rel_y, render_width, layout)

    for _, chip in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            local hit = "btn_" .. chip.id
            self._slide_hover_gate = (chip.id == "record") and record_chip_visible(self)
            return hit
        end
    end

    if self._show_time and time_x and time_w > 0 and time_y then
        if coords:pointInRelativeRect(mx, my, time_x, time_y, time_w, chip_h) then
            self._slide_hover_gate = false
            return "time"
        end
    end

    self._slide_hover_gate = false
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    local rec_id = WIDGET.CHIP_HIT.strip(RECORD_PREFIX, sub_id)
    if rec_id and apply_record_mode(self, rec_id) then
        return true
    end

    if sub_id == "time" then
        return jump_to_time_from_input()
    end

    local id = WIDGET.CHIP_HIT.strip("btn_", sub_id)
    if not id then
        return false
    end
    return run_transport_command(id)
end

function widget.onSubcontrolRightClick(self, sub_id, _button)
    local id = WIDGET.CHIP_HIT.strip("btn_", sub_id)
    if not id then
        return false
    end
    return run_settings_command(id)
end

function widget.onSettingsMenu(self, ctx, button)
ensure_state(self)
    local rows = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        local id = it.id
        rows[#rows + 1] = {
            label = it.label,
            get = function(h)
                return h._visible[id] ~= false
            end,
            set = function(h, v)
                h._visible[id] = v
            end,
        }
    end
    rows[#rows + 1] = { separator = true }
    rows[#rows + 1] = {
        label = "Show project time",
        get = function(h)
            return h._show_time == true
        end,
        set = function(h, v)
            h._show_time = v
        end,
    }
    WIDGET.VIS.draw_checkbox_list(ctx, button, self, {
        title = "Transport Widget",
        rows = rows,
        total_visible = transport_visible_slot_count,
    })
end

local function draw_chip(ctx, coords, draw_list, chip, btn_txt, btn_bg, is_active, is_hover, is_record_arm)
    if is_record_arm then
        WIDGET.DRAWING.drawChipBackground(coords, draw_list, chip.x, chip.y, chip.w, chip.h, BG_RECORD_ARM, { rounding = CHIP_ROUND })
        draw_transport_chip_foreground(ctx, coords, draw_list, chip, TEXT_ON_RECORD_ARM, chip.label)
        return
    end

    WIDGET.DRAWING.drawWidgetPillIconChip(ctx, coords, draw_list, chip, btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
        rounding = CHIP_ROUND,
        icon_font = chip.icon_font,
        icon_char = TRANSPORT_ICON_CHAR,
        icon_sz = WIDGET.CHIP_ROW.magnet_icon_size(ctx),
        fallback_text = chip.label,
    })
end

local function multiswitch_selected(chip, flags)
    if chip.id == "play" then
        return flags.playing and not flags.paused
    end
    if chip.id == "pause" then
        return flags.paused
    end
    if chip.id == "stop" then
        return not flags.playing and not flags.paused
    end
    return false
end

local function draw_play_pause_stop_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, mx, my, flags)
    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        draw_chip_foreground = draw_transport_chip_foreground,
        label_for = function(c)
            return c.label
        end,
        is_selected_segment = function(chip)
            return multiswitch_selected(chip, flags)
        end,
    })
end

local function render_preview_strip(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2

ensure_state(self)
    local total_w = -CHIP_GAP
    local segments = {}
    for _, pid in ipairs(PREVIEW_CHIP_IDS) do
        local it = transport_item_by_id(pid)
        if it and self._visible[it.id] ~= false then
            local cw = chip_cell_width(ctx, it)
            segments[#segments + 1] = { it = it, w = cw }
            total_w = total_w + cw + CHIP_GAP
        end
    end

    if WIDGET.PREVIEW_FB.when(ctx, #segments == 0 or total_w > render_width - 8, "Transport", rel_x, rel_y, render_width, h, coords, draw_list, text_color, 0) then
        return
    end

    local x = rel_x + (render_width - total_w) / 2
    local mx, my = coords:getRelativeMouse()
    local flags = playback_flags(self)

    local chips = {}
    for _, seg in ipairs(segments) do
        local it = seg.it
        local cw = seg.w
        chips[#chips + 1] = {
            id = it.id,
            label = WIDGET.CHIP_MS.chip_caption(it),
            cmd = it.cmd,
            mode = it,
            icon_font = transport_icon_font_for_item(it),
            x = x,
            y = row_y,
            w = cw,
            h = chip_h,
        }
        x = x + cw + CHIP_GAP
    end

    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    draw_play_pause_stop_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, mx, my, flags)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    if self._preview_mode then
        render_preview_strip(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color)
        return
    end

    if self._is_rendering_slide_out then
        render_record_slide(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color, _layout)
        return
    end

    local mx, my = coords:getRelativeMouse()
    local chips, time_x, time_w, chip_h, time_y = layout_chips_cached(ctx, self, rel_x, rel_y, render_width, _layout)
    local flags = playback_flags(self)

    local i = 1
    while i <= #chips do
        local c0, c1, c2 = chips[i], chips[i + 1], chips[i + 2]
        if c0 and c1 and c2 and c0.id == "play" and c1.id == "pause" and c2.id == "stop" then
            draw_play_pause_stop_multiswitch(ctx, self, { c0, c1, c2 }, coords, draw_list, btn_txt, btn_bg, mx, my, flags)
            i = i + 3
        else
            local chip = chips[i]
            local is_active = false
            local is_record_arm = false
            if not MOMENTARY_CHIP_IDS[chip.id] then
                if chip.id == "play" then
                    is_active = flags.playing and not flags.paused
                elseif chip.id == "pause" then
                    is_active = flags.paused
                elseif chip.id == "stop" then
                    is_active = not flags.playing and not flags.paused
                elseif chip.id == "record" then
                    is_record_arm = flags.recording
                elseif chip.id == "repeat_toggle" then
                    is_active = self._repeat_on
                end
            end

            local hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
            draw_chip(ctx, coords, draw_list, chip, btn_txt, btn_bg, is_active, hover, is_record_arm)
            i = i + 1
        end
    end

    if not self._show_time or not time_x or not time_y then
        return
    end

    local txt = project_time_string()
    local time_hovered = coords:pointInRelativeRect(mx, my, time_x, time_y, time_w, chip_h)
    local draw_txt_col = text_color
    if time_hovered then
        WIDGET.DRAWING.drawChipBackground(coords, draw_list, time_x, time_y, time_w, chip_h, 0xFFFFFF80, { rounding = CHIP_ROUND })
        draw_txt_col = 0x131313FF
    end

    WIDGET.DRAWING.drawCenteredText(ctx, coords, draw_list, time_x, time_y, time_w, chip_h, txt, draw_txt_col, 0)
end

return widget
