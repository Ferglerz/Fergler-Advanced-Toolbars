-- Widgets/playback_rate.lua
-- Master play rate: multiswitch presets plus a spinner (− / semitone readout / +).
-- − / + use transport actions 40523 / 40522 (semitone nudge). Readout is semitones vs 1.0× (12-TET), ImGui entry like pin offsets.

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local SPINNER = require("Utils.chip_spinner")

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

CHIP_MS.normalize_chip_entries(RATES)

--- REAPER Lua tonumber() accepts strings only; API values may already be numbers.
local function as_number(v, default)
    local ty = type(v)
    if ty == "number" then
        if v ~= v then
            return default
        end
        return v
    end
    if ty == "string" then
        return tonumber(v) or default
    end
    return default
end

local LN2 = math.log(2)

local function rate_to_semitones(rate)
    rate = as_number(rate, nil)
    if not rate or rate <= 0 then
        return 0
    end
    return 12 * math.log(rate) / LN2
end

local function semitones_to_rate(st)
    st = as_number(st, nil)
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

--- Display buffer: numeric part + literal "st" (matches accepted input).
local function format_semitones_display(st)
    st = as_number(st, 0) or 0
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

local function rate_by_id(id)
    for _, e in ipairs(RATES) do
        if e.id == id then
            return e
        end
    end
    return nil
end

local PREFIX_MS = "pr_ms_"
local PREFIX_SP = "pr_sp_"

local MS_GAP = 6
local MIN_CHIP = 22
local PREVIEW_IDS = { "0.25", "0.5", "1", "1.25", "1.5", "2", "4" }

local function ensure_included(self)
    if not self._included then
        self._included = {}
    end
end

local function is_included(self, entry)
    ensure_included(self)
    local v = self._included[entry.id]
    if v == nil then
        return entry.default_on
    end
    return v == true
end

local function enabled_list(self)
    local list = {}
    for _, e in ipairs(RATES) do
        if is_included(self, e) then
            list[#list + 1] = e
        end
    end
    return list
end

local function count_included(self)
    ensure_included(self)
    local n = 0
    for _, e in ipairs(RATES) do
        if is_included(self, e) then
            n = n + 1
        end
    end
    return n
end

local function active_preset_id(self, play_rate, list)
    play_rate = as_number(play_rate, nil)
    if not play_rate or not list or #list < 1 then
        return nil
    end
    local best_e, best_d
    for _, e in ipairs(list) do
        local er = as_number(e.rate, nil)
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

local function layout_multiswitch_chips(ctx, rel_x, rel_y, ms_width, layout, list)
    return ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, ms_width, layout, list, {
        min_chip_w = MIN_CHIP,
        pad_x = 4,
    })
end

--- Columns used when the multiswitch is on a horizontal toolbar (up to 2 rows when height fits).
local function horizontal_multiswitch_cols(ctx, n)
    if not ctx or not reaper.ImGui_GetTextLineHeight or n < 1 then
        return math.max(1, n)
    end
    local chip_h = ROW.chip_line_height(ctx)
    local gap = ROW.CHIP_GAP
    local btn_h = tonumber(CONFIG.SIZES.HEIGHT) or chip_h
    local rows = (2 * chip_h + gap <= btn_h) and 2 or 1
    return math.ceil(n / rows)
end

local function multiswitch_block_height(ctx, n, is_vertical, inner_w)
    if not is_vertical then
        return CONFIG.SIZES.HEIGHT
    end
    if not ctx or not inner_w then
        return CONFIG.SIZES.HEIGHT
    end
    local inset = ROW.button_rounding_content_pad()
    local pad_y = 4 + inset
    local pad_x = 4 + inset
    local chip_h = ROW.chip_line_height(ctx)
    local gap = ROW.CHIP_GAP
    local usable_w = math.max(40, inner_w - pad_x * 2)
    local cols = (usable_w >= 2 * MIN_CHIP + gap) and 2 or 1
    cols = math.min(cols, math.max(1, n))
    local rows = math.ceil(n / cols)
    local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
    return pad_y + grid_h + pad_y
end

local function readout_width(ctx)
    local samples = { "-24st", "12.5st", "0st" }
    local w = 0
    for _, s in ipairs(samples) do
        local tw = as_number(reaper.ImGui_CalcTextSize(ctx, s), 0)
        w = math.max(w, tw)
    end
    return math.ceil(w + 10)
end

local widget = {
    name = "Playback Rate",
    category = "Time, grid & tempo",
    type = "display",
    update_interval = 0.05,
    description = "Master play rate: preset multiswitch (right-click to choose visible rates) and a semitone spinner "
        .. "(− / + use transport semitone nudge actions; center field is semitones vs 1.0×, type like pin offsets).",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 280,
    _included = nil,
    _play_rate = 1.0,
    _active_ms_id = nil,
    _open_rates_context = false,
    _st_buf = "0st",
    _st_overlay_focused = false,
    _sp_readout_rel = nil,
}

function widget.col_primary()
    local rate = as_number(reaper.Master_GetPlayRate(0), nil)
    if rate and math.abs(rate - 1.0) > 0.0001 then
        return reaper.GetThemeColor("playrate_edited", 0)
    end
    return nil
end

function widget.applyPersistedOptions(self, opts)
    ensure_included(self)
    if type(opts) ~= "table" or type(opts.included) ~= "table" then
        return
    end
    for k, on in pairs(opts.included) do
        if rate_by_id(k) then
            self._included[k] = on == true
        end
    end
end

function widget.exportPersistedOptions(self)
    ensure_included(self)
    local inc = {}
    for _, e in ipairs(RATES) do
        inc[e.id] = is_included(self, e)
    end
    return { included = inc }
end

function widget.getValue(self)
    ensure_included(self)
    local r = as_number(reaper.Master_GetPlayRate(0), 1.0)
    self._play_rate = r
    local list = enabled_list(self)
    self._active_ms_id = active_preset_id(self, r, list)
    return r
end

function widget.getLayoutWidth(self, ctx)
    if not ctx or not reaper.ImGui_CalcTextSize then
        return math.max(120, self.width or 280)
    end
    ensure_included(self)
    local n = count_included(self)
    if n < 1 then
        n = 1
    end
    local inset = ROW.button_rounding_content_pad()
    local pad = (4 * 2) + inset * 2
    local gap = ROW.CHIP_GAP
    local cols = horizontal_multiswitch_cols(ctx, n)
    local ms_w = pad + cols * MIN_CHIP + gap * math.max(0, cols - 1)
    local rw = readout_width(ctx)
    local spin_w = SPINNER.total_width(ctx, rw)
    local total = ms_w + MS_GAP + spin_w
    return ROW.apply_preview_width_cap(self, math.max(100, math.ceil(total)))
end

function widget.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar or not ctx then
        return CONFIG.SIZES.HEIGHT
    end
    ensure_included(self)
    local n = count_included(self)
    if n < 1 then
        n = 1
    end
    local iw = as_number(inner_w, nil) or as_number(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
    local ms_h = multiswitch_block_height(ctx, n, true, iw)
    local sh = SPINNER.chip_line_height(ctx)
    local inset = ROW.button_rounding_content_pad()
    return ms_h + ROW.CHIP_GAP + sh + 4 + inset
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    if self._preview_mode then
        return nil
    end
    render_width = as_number(render_width, nil) or as_number(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
    ensure_included(self)
    local mx, my = coords:getRelativeMouse()
    local list = enabled_list(self)
    if #list < 1 then
        return nil
    end

    local vert = layout and layout.is_vertical
    local rw = readout_width(ctx)
    local spin_total = SPINNER.total_width(ctx, rw)

    if vert then
        local inset = ROW.button_rounding_content_pad()
        local chips, ms_outer_h = layout_multiswitch_chips(ctx, rel_x, rel_y, render_width, layout, list)
        local hit = ROW.hit_test_chips(mx, my, coords, chips, PREFIX_MS)
        if hit then
            return hit
        end
        local spin_y = rel_y + ms_outer_h + ROW.CHIP_GAP
        local spin_x = rel_x + inset + math.max(0, (render_width - 2 * inset - spin_total) / 2)
        local minus, readout, plus = SPINNER.layout_horizontal(ctx, spin_x, spin_y, SPINNER.chip_line_height(ctx), rw)
        local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
        if sp == "minus" or sp == "plus" then
            return PREFIX_SP .. sp
        end
        return nil
    end

    local ms_w = math.max(40, render_width - spin_total - MS_GAP)
    local chips = layout_multiswitch_chips(ctx, rel_x, rel_y, ms_w, layout, list)
    local hit = ROW.hit_test_chips(mx, my, coords, chips, PREFIX_MS)
    if hit then
        return hit
    end
    if #chips > 0 then
        local last = chips[#chips]
        local spin_x = last.x + last.w + MS_GAP
        local minus, readout, plus = SPINNER.layout_horizontal(ctx, spin_x, rel_y, CONFIG.SIZES.HEIGHT, rw)
        local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
        if sp == "minus" or sp == "plus" then
            return PREFIX_SP .. sp
        end
        return nil
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if not sub_id then
        return false
    end
    local ms = sub_id:match("^pr_ms_(.+)$")
    if ms then
        local e = rate_by_id(ms)
        if e then
            reaper.CSurf_OnPlayRateChange(e.rate)
            self._play_rate = e.rate
            self._active_ms_id = e.id
            return true
        end
        return false
    end
    local sp = sub_id:match("^pr_sp_(.+)$")
    if sp == "minus" then
        reaper.Main_OnCommand(CMD_RATE_DOWN, 0)
        return true
    end
    if sp == "plus" then
        reaper.Main_OnCommand(CMD_RATE_UP, 0)
        return true
    end
    return false
end

local function mark_layout_dirty(button, ctx)
    if not button then
        return
    end
    if button.widget and button.widget.getLayoutWidth and ctx then
        local ok, w = pcall(button.widget.getLayoutWidth, button.widget, ctx)
        if ok and type(w) == "number" then
            button.widget.width = w
        end
    end
    button:clearLayoutCache()
    button:saveChanges()
end

function widget.onRightClick(self, button)
    self._open_rates_context = true
    self._context_button = button
end

function widget.onRightClickSubcontrol(self, _sub_id, button)
    self._open_rates_context = true
    self._context_button = button
end

local function draw_rates_context(self, ctx, button)
    local key = "##playback_rate_ctx_" .. tostring(button and button.instance_id or self._button_instance_id or "x")
    if self._open_rates_context then
        reaper.ImGui_OpenPopup(ctx, key)
        self._open_rates_context = false
    end

    if not reaper.ImGui_BeginPopup(ctx, key) then
        return
    end

    ensure_included(self)
    reaper.ImGui_TextDisabled(ctx, "Show in rate switch")
    local changed = false
    for _, e in ipairs(RATES) do
        local on = is_included(self, e)
        local label = string.format("%gx", e.rate)
        if reaper.ImGui_MenuItem(ctx, label, nil, on) then
            local would_off = on and count_included(self) <= 1
            if not would_off then
                self._included[e.id] = not on
                changed = true
            end
        end
    end
    reaper.ImGui_EndPopup(ctx)

    if changed then
        mark_layout_dirty(button or self._context_button, ctx)
    end
end

local function draw_semitone_overlay(self, ctx, _button)
    if self._preview_mode then
        return
    end
    local geom = self._sp_readout_rel
    if not geom or not COORDINATES then
        return
    end

    if not self._st_overlay_focused then
        local live = as_number(reaper.Master_GetPlayRate(0), 1.0)
        self._st_buf = format_semitones_display(rate_to_semitones(live))
    end
    self._st_buf = self._st_buf or "0st"

    local coords = COORDINATES.new(ctx)
    local sx, sy = coords:relativeToDrawList(geom.x, geom.y)
    reaper.ImGui_PushID(ctx, "pr_st_" .. tostring(self._button_instance_id or "x"))
    reaper.ImGui_SetCursorScreenPos(ctx, sx, sy)
    reaper.ImGui_SetNextItemWidth(ctx, geom.w)
    local ch, tx = reaper.ImGui_InputTextWithHint(ctx, "##st", "st, e.g. -2", self._st_buf)
    if ch and tx then
        self._st_buf = tx
        local trimmed = (self._st_buf:gsub("%s", ""))
        local st = parse_semitones_input(trimmed)
        if st ~= nil then
            local nr = semitones_to_rate(st)
            reaper.CSurf_OnPlayRateChange(nr)
            self._play_rate = nr
        end
    end
    self._st_overlay_focused = reaper.ImGui_IsItemFocused(ctx) or reaper.ImGui_IsItemActive(ctx)
    reaper.ImGui_PopID(ctx)
end

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local subset = {}
    for _, pid in ipairs(PREVIEW_IDS) do
        local e = rate_by_id(pid)
        if e then
            subset[#subset + 1] = e
        end
    end
    local mx, my = coords:getRelativeMouse()
    if #subset < #PREVIEW_IDS then
        DRAWING.drawWidgetCenteredValueText(ctx, "Play rate", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end
    local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, subset, {
        min_chip_w = MIN_CHIP,
        pad_x = 4,
    })
    if chips and #chips > 0 then
        CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
            mx = mx,
            my = my,
            enabled = true,
            mixed = false,
            chip_round = ROW.CHIP_ROUND,
            slide_namespace = "pr_prev",
            grid_layout = true,
            is_selected_segment = function(c)
                return not c.blank and c.mode and c.mode.id == "1"
            end,
        })
    else
        DRAWING.drawWidgetCenteredValueText(ctx, "Play rate", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
    end
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    render_width = as_number(render_width, nil) or as_number(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    if self._preview_mode then
        self._sp_readout_rel = nil
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        return
    end

    self._sp_readout_rel = nil
    ensure_included(self)
    local list = enabled_list(self)
    if #list < 1 then
        self._included["1"] = true
        list = enabled_list(self)
    end

    local mx, my = coords:getRelativeMouse()
    local vert = layout and layout.is_vertical
    local rw = readout_width(ctx)
    local play_r = as_number(self._play_rate, nil) or as_number(reaper.Master_GetPlayRate(0), 1.0)
    local active_id = self._active_ms_id or active_preset_id(self, play_r, list)

    local function label_for_chip(c)
        if not c.mode then
            return ""
        end
        return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
    end

    if vert then
        local inset = ROW.button_rounding_content_pad()
        local chips, ms_outer_h = layout_multiswitch_chips(ctx, rel_x, rel_y, render_width, layout, list)
        CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
            mx = mx,
            my = my,
            enabled = true,
            mixed = false,
            chip_round = ROW.CHIP_ROUND,
            slide_namespace = "pr_ms",
            grid_layout = true,
            label_for = label_for_chip,
            is_selected_segment = function(c)
                return not c.blank and active_id ~= nil and c.mode ~= nil and c.mode.id == active_id
            end,
        })
        local spin_total = SPINNER.total_width(ctx, rw)
        local spin_y = rel_y + ms_outer_h + ROW.CHIP_GAP
        local spin_x = rel_x + inset + math.max(0, (render_width - 2 * inset - spin_total) / 2)
        local minus, readout, plus = SPINNER.layout_horizontal(ctx, spin_x, spin_y, SPINNER.chip_line_height(ctx), rw)
        self._sp_readout_rel = { x = readout.x, y = readout.y, w = readout.w, h = readout.h }
        local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
        SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
        SPINNER.draw_segment(ctx, coords, draw_list, readout, "", btn_txt, btn_bg, sm == "readout")
        SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
        return
    end

    local spin_total = SPINNER.total_width(ctx, rw)
    local ms_w = math.max(40, render_width - spin_total - MS_GAP)
    local chips = layout_multiswitch_chips(ctx, rel_x, rel_y, ms_w, layout, list)
    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = ROW.CHIP_ROUND,
        slide_namespace = "pr_ms",
        grid_layout = true,
        label_for = label_for_chip,
        is_selected_segment = function(c)
            return not c.blank and active_id ~= nil and c.mode ~= nil and c.mode.id == active_id
        end,
    })

    if #chips > 0 then
        local last = chips[#chips]
        local spin_x = last.x + last.w + MS_GAP
        local minus, readout, plus = SPINNER.layout_horizontal(ctx, spin_x, rel_y, CONFIG.SIZES.HEIGHT, rw)
        self._sp_readout_rel = { x = readout.x, y = readout.y, w = readout.w, h = readout.h }
        local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
        SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
        SPINNER.draw_segment(ctx, coords, draw_list, readout, "", btn_txt, btn_bg, sm == "readout")
        SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
    end
end

function widget.onWidgetFrame(self, ctx, button)
    draw_rates_context(self, ctx, button)
    draw_semitone_overlay(self, ctx, button)
end

return widget
