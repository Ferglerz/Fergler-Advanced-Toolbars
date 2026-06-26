-- Widgets/playback_rate.lua
-- Master play rate: multiswitch presets plus a spinner (− / semitone readout / +).
-- − / + use transport actions 40523 / 40522 (semitone nudge). Readout is semitones vs 1.0× (12-TET), ImGui entry like pin offsets.

local ROW = require("Renderers.Widgets.chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local SPINNER = require("Utils.chip_spinner")
local VIS = require("Utils.widget_visibility")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")
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

--- Display buffer: numeric part + literal "st" (matches accepted input).
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
    if self._show_pitch == nil then
        self._show_pitch = true
    end
    if self._show_spinner == nil then
        self._show_spinner = true
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

local function multiswitch_layout_opts()
    return {
        pad_x = 4,
        chip_pad_h = 6,
        min_chip_w = MIN_CHIP,
        caption_for = function(e)
            return e.short_label or tostring(e.rate)
        end,
    }
end

local function cache_playback_slide_plan(self, ctx, host_w, host_h, layout)
    ensure_included(self)
    local list = enabled_list(self)
    if #list < 1 then
        list = RATES
    end
    local constraints = {}
    if layout and layout.is_vertical then
        constraints.panel_h = host_h
    else
        constraints.panel_w = host_w
    end
    local w, h, rows, cols = ROW.plan_slide_out_panel(ctx, list, multiswitch_layout_opts(), constraints)
    self._slide_out_plan = { w = w, h = h, rows = rows, cols = cols }
    return self._slide_out_plan
end

local function playback_slide_out_layout_opts(self, ctx, panel_w, panel_h, layout)
    local plan = self._slide_out_plan or cache_playback_slide_plan(self, ctx, panel_w, panel_h, layout)
    local opts = multiswitch_layout_opts()
    opts.rows = plan.rows
    opts.height = panel_h
    return opts
end

local function layout_multiswitch_chips(ctx, rel_x, rel_y, ms_width, layout, list)
    return ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, ms_width, layout, list, multiswitch_layout_opts())
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
    local cell_w = ROW.uniform_chip_cell_width(ctx, RATES, multiswitch_layout_opts())
    local cols = (usable_w >= 2 * cell_w + gap) and 2 or 1
    cols = math.min(cols, math.max(1, n))
    local rows = math.ceil(n / cols)
    local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
    return pad_y + grid_h + pad_y
end

local function readout_width(ctx)
    local samples = { "-24st", "12.5st", "0st" }
    local w = 0
    for _, s in ipairs(samples) do
        local tw = UTILS.asNumber(reaper.ImGui_CalcTextSize(ctx, s), 0)
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
    _show_spinner = true,
    _show_pitch = true,
    _slide_out_mode = true,
    _play_rate = 1.0,
    _active_ms_id = nil,
    _open_rates_context = false,
    _st_buf = "0st",
    _st_overlay_focused = false,
    _sp_readout_rel = nil,
    _pitch_rel = nil,
}

function widget.col_primary()
    local rate = UTILS.asNumber(reaper.Master_GetPlayRate(0), nil)
    if rate and math.abs(rate - 1.0) > 0.0001 then
        return reaper.GetThemeColor("playrate_edited", 0)
    end
    return nil
end

function widget.applyPersistedOptions(self, opts)
    ensure_included(self)
    if type(opts) ~= "table" then
        return
    end
    if opts.show_spinner ~= nil then
        self._show_spinner = opts.show_spinner
    end
    if opts.show_pitch ~= nil then
        self._show_pitch = opts.show_pitch
    end
    if type(opts.included) == "table" then
        for k, on in pairs(opts.included) do
            if rate_by_id(k) then
                self._included[k] = on == true
            end
        end
    end
end

function widget.exportPersistedOptions(self)
    ensure_included(self)
    local inc = {}
    for _, e in ipairs(RATES) do
        inc[e.id] = is_included(self, e)
    end
    return { included = inc, show_spinner = self._show_spinner, show_pitch = self._show_pitch }
end

function widget.getValue(self)
    ensure_included(self)
    local r = UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
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
    if not self._preview_mode then
        local rw = readout_width(ctx)
        local elements_w = 0
        if self._show_spinner ~= false then
            elements_w = elements_w + SPINNER.total_width(ctx, rw)
        end
        if self._show_pitch ~= false then
            elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26
        end
        local inset = ROW.button_rounding_content_pad()
        local pad = (4 * 2) + inset * 2
        return ROW.apply_preview_width_cap(self, math.max(40, math.ceil(elements_w + pad)))
    end
    local n = count_included(self)
    if n < 1 then
        n = 1
    end
    local cols = horizontal_multiswitch_cols(ctx, n)
    local preview_list = enabled_list(self)
    if #preview_list < 1 then
        preview_list = RATES
    end
    local ms_w = ROW.uniform_multiswitch_width(ctx, preview_list, cols, multiswitch_layout_opts())
    local total = ms_w
    if self._show_spinner ~= false then
        local rw = readout_width(ctx)
        local spin_w = SPINNER.total_width(ctx, rw)
        total = total + MS_GAP + spin_w
    end
    if self._show_pitch ~= false then
        total = total + MS_GAP + 26 -- 26 width for pitch chip
    end
    return ROW.apply_preview_width_cap(self, math.max(100, math.ceil(total)))
end

function widget.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar or not ctx then
        return CONFIG.SIZES.HEIGHT
    end
    if not self._preview_mode then
        return CONFIG.SIZES.HEIGHT
    end
    ensure_included(self)
    local n = count_included(self)
    if n < 1 then
        n = 1
    end
    local iw = UTILS.asNumber(inner_w, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
    local ms_h = multiswitch_block_height(ctx, n, true, iw)
    local inset = ROW.button_rounding_content_pad()
    if self._show_spinner ~= false or self._show_pitch ~= false then
        local sh = SPINNER.chip_line_height(ctx)
        return ms_h + ROW.CHIP_GAP + sh + 4 + inset
    end
    return ms_h + 4 + inset
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    if self._preview_mode then
        return nil
    end
    render_width = UTILS.asNumber(render_width, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
    ensure_included(self)
    local mx, my = coords:getRelativeMouse()
    local rw = readout_width(ctx)
    local spin_total = SPINNER.total_width(ctx, rw)

    -- 1. Toolbar source widget hit-testing (Spinner + Pitch chip)
    if not is_slide_out then
        local elements_w = 0
        if self._show_spinner ~= false then elements_w = elements_w + spin_total end
        if self._show_pitch ~= false then elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26 end
        
        local inset = ROW.button_rounding_content_pad()
        local current_x = rel_x + inset + math.max(0, (render_width - 2 * inset - elements_w) / 2)
        
        if self._show_spinner ~= false then
            local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, rel_y, CONFIG.SIZES.HEIGHT, rw)
            local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
            if sp == "minus" or sp == "plus" then
                return PREFIX_SP .. sp
            end
            current_x = current_x + spin_total + MS_GAP
        end
        
        if self._show_pitch ~= false then
            local chip_h = SPINNER.chip_line_height(ctx)
            if coords:pointInRelativeRect(mx, my, current_x, rel_y + (CONFIG.SIZES.HEIGHT - chip_h) / 2, 26, chip_h) then
                return "pr_pitch"
            end
        end
        return nil
    end

    -- 2. Slide-out window hit-testing (Only check presets)
    if is_slide_out then
        local list = enabled_list(self)
        local slide_opts = playback_slide_out_layout_opts(self, ctx, render_width, self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout), layout)
        local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, list, slide_opts)
        local hit = ROW.hit_test_chips(mx, my, coords, chips, PREFIX_MS)
        if hit then
            return hit
        end
        return nil
    end

    local list = enabled_list(self)
    if #list < 1 then
        return nil
    end

    local vert = layout and layout.is_vertical

    if vert then
        local inset = ROW.button_rounding_content_pad()
        local chips, ms_outer_h = layout_multiswitch_chips(ctx, rel_x, rel_y, render_width, layout, list)
        local hit = ROW.hit_test_chips(mx, my, coords, chips, PREFIX_MS)
        if hit then
            return hit
        end
        local extra_y = rel_y + ms_outer_h + ROW.CHIP_GAP
        local elements_w = 0
        if self._show_spinner ~= false then elements_w = elements_w + spin_total end
        if self._show_pitch ~= false then elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26 end
        
        local current_x = rel_x + inset + math.max(0, (render_width - 2 * inset - elements_w) / 2)

        if self._show_spinner ~= false then
            local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, extra_y, SPINNER.chip_line_height(ctx), rw)
            local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
            if sp == "minus" or sp == "plus" then
                return PREFIX_SP .. sp
            end
            current_x = current_x + spin_total + MS_GAP
        end
        
        if self._show_pitch ~= false then
            if coords:pointInRelativeRect(mx, my, current_x, extra_y, 26, SPINNER.chip_line_height(ctx)) then
                return "pr_pitch"
            end
        end
        return nil
    end

    local ms_w = render_width
    local elements_w = 0
    if self._show_spinner ~= false then elements_w = elements_w + spin_total end
    if self._show_pitch ~= false then elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26 end
    if elements_w > 0 then
        ms_w = math.max(40, render_width - elements_w - MS_GAP)
    end
    
    local chips = layout_multiswitch_chips(ctx, rel_x, rel_y, ms_w, layout, list)
    local hit = ROW.hit_test_chips(mx, my, coords, chips, PREFIX_MS)
    if hit then
        return hit
    end
    
    if elements_w > 0 and #chips > 0 then
        local last = chips[#chips]
        local current_x = last.x + last.w + MS_GAP
        
        if self._show_spinner ~= false then
            local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, rel_y, CONFIG.SIZES.HEIGHT, rw)
            local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
            if sp == "minus" or sp == "plus" then
                return PREFIX_SP .. sp
            end
            current_x = current_x + spin_total + MS_GAP
        end
        
        if self._show_pitch ~= false then
            local chip_h = SPINNER.chip_line_height(ctx)
            if coords:pointInRelativeRect(mx, my, current_x, rel_y + (CONFIG.SIZES.HEIGHT - chip_h) / 2, 26, chip_h) then
                return "pr_pitch"
            end
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if not sub_id then
        return false
    end
    if sub_id == "pr_pitch" then
        reaper.Main_OnCommand(40671, 0)
        return true
    end
    local ms = CHIP_HIT.strip(PREFIX_MS, sub_id)
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
    local sp = CHIP_HIT.strip(PREFIX_SP, sub_id)
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

function widget.onSettingsMenu(self, ctx, button)
    ensure_included(self)
    local rows = {}
    rows[#rows + 1] = {
        label = "Show Semitone Spinner",
        get = function(h)
            if h._show_spinner == nil then return true end
            return h._show_spinner
        end,
        set = function(h, v)
            h._show_spinner = v
        end,
    }
    rows[#rows + 1] = {
        label = "Show Preserve Pitch",
        get = function(h)
            if h._show_pitch == nil then return true end
            return h._show_pitch
        end,
        set = function(h, v)
            h._show_pitch = v
        end,
    }
    for _, entry in ipairs(RATES) do
        local e = entry
        rows[#rows + 1] = {
            label = string.format("%gx", e.rate),
            get = function(h)
                return is_included(h, e)
            end,
            set = function(h, v)
                h._included[e.id] = v
            end,
        }
    end
    VIS.draw_checkbox_list(ctx, button, self, {
        title = "Playback Rate Options",
        rows = rows,
        total_visible = count_included,
    })
end

local function draw_semitone_overlay(self, ctx, _button)
    if self._preview_mode then
        return
    end
    local geom = self._sp_readout_screen
    if not geom then
        return
    end

    if not self._st_overlay_focused then
        local live = UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
        self._st_buf = format_semitones_display(rate_to_semitones(live))
    end
    self._st_buf = self._st_buf or "0st"

    reaper.ImGui_PushID(ctx, "pr_st_" .. tostring(self._button_instance_id or "x"))
    reaper.ImGui_SetCursorPos(ctx, geom.rel_x, geom.rel_y)
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
    if PREVIEW_FB.when(ctx, #subset < #PREVIEW_IDS, "Play rate", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
        return
    end
    local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, subset, multiswitch_layout_opts())
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
        PREVIEW_FB.draw_centered_title(ctx, "Play rate", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
    end
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    render_width = UTILS.asNumber(render_width, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)

    local mx, my = coords:getRelativeMouse()
    local vert = layout and layout.is_vertical
    local rw = readout_width(ctx)
    local play_r = UTILS.asNumber(self._play_rate, nil) or UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
    local active_id = self._active_ms_id or active_preset_id(self, play_r, enabled_list(self))

    local function label_for_chip(c)
        if not c.mode then
            return ""
        end
        return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
    end

    -- 1. Toolbar source widget rendering (Draw spinner + pitch chip)
    if not self._is_rendering_slide_out and not self._preview_mode then
        local spin_total = SPINNER.total_width(ctx, rw)
        local elements_w = 0
        if self._show_spinner ~= false then elements_w = elements_w + spin_total end
        if self._show_pitch ~= false then elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26 end
        
        local inset = ROW.button_rounding_content_pad()
        local current_x = rel_x + inset + math.max(0, (render_width - 2 * inset - elements_w) / 2)
        
        if self._show_spinner ~= false then
            local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, rel_y, CONFIG.SIZES.HEIGHT, rw)
            
            -- Store exact relative coordinate of readout box for text overlay
            self._sp_readout_screen = {
                rel_x = readout.x,
                rel_y = readout.y,
                w = readout.w,
                h = readout.h
            }
            
            local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
            SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
            SPINNER.draw_segment(ctx, coords, draw_list, readout, "", btn_txt, btn_bg, sm == "readout")
            SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
            current_x = current_x + spin_total + MS_GAP
        else
            self._sp_readout_screen = nil
        end
        
        if self._show_pitch ~= false then
            local st_pitch = reaper.GetToggleCommandState(40671) == 1
            local chip_h = SPINNER.chip_line_height(ctx)
            local pt_rect = {x = current_x, y = rel_y + (CONFIG.SIZES.HEIGHT - chip_h) / 2, w = 26, h = chip_h}
            local pt_hit = coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h)
            SPINNER.draw_segment(ctx, coords, draw_list, pt_rect, "P", btn_txt, btn_bg, pt_hit, st_pitch)
        end
        return
    end

    -- 2. Slide-out window contents rendering (Draw ONLY presets in 2-row/2-column grid)
    if self._is_rendering_slide_out and not self._preview_mode then
        ensure_included(self)
        local list = enabled_list(self)

        local slide_opts = playback_slide_out_layout_opts(self, ctx, render_width, self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout), layout)
        local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, list, slide_opts)

        CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
            mx = mx,
            my = my,
            enabled = true,
            mixed = false,
            chip_round = ROW.CHIP_ROUND,
            slide_namespace = "pr_ms",
            grid_layout = true,
            label_for = label_for_chip,
            rel_x = rel_x,
            rel_y = rel_y,
            alpha_factor = self._slide_alpha_factor,
            is_selected_segment = function(c)
                return not c.blank and active_id ~= nil and c.mode ~= nil and c.mode.id == active_id
            end,
        })
        return
    end

    -- 3. Inline / Preview Mode Rendering (Original multi-chip inline display)
    if self._preview_mode then
        self._sp_readout_screen = nil
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        return
    end

    self._sp_readout_screen = nil
    ensure_included(self)
    local list = enabled_list(self)
    if #list < 1 then
        self._included["1"] = true
        list = enabled_list(self)
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
        
        local extra_y = rel_y + ms_outer_h + ROW.CHIP_GAP
        local elements_w = 0
        if self._show_spinner ~= false then elements_w = elements_w + spin_total end
        if self._show_pitch ~= false then elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26 end
        
        local current_x = rel_x + inset + math.max(0, (render_width - 2 * inset - elements_w) / 2)

        if self._show_spinner ~= false then
            local spin_total = SPINNER.total_width(ctx, rw)
            local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, extra_y, SPINNER.chip_line_height(ctx), rw)
            self._sp_readout_screen = {
                rel_x = readout.x,
                rel_y = readout.y,
                w = readout.w,
                h = readout.h
            }
            local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
            SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
            SPINNER.draw_segment(ctx, coords, draw_list, readout, "", btn_txt, btn_bg, sm == "readout")
            SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
            current_x = current_x + spin_total + MS_GAP
        end
        if self._show_pitch ~= false then
            local st_pitch = reaper.GetToggleCommandState(40671) == 1
            local pt_rect = {x = current_x, y = extra_y, w = 26, h = SPINNER.chip_line_height(ctx)}
            local pt_hit = coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h)
            SPINNER.draw_segment(ctx, coords, draw_list, pt_rect, "P", btn_txt, btn_bg, pt_hit, st_pitch)
        end
        return
    end

    local ms_w = render_width
    local elements_w = 0
    if self._show_spinner ~= false then elements_w = elements_w + spin_total end
    if self._show_pitch ~= false then elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26 end
    if elements_w > 0 then
        ms_w = math.max(40, render_width - elements_w - MS_GAP)
    end
    
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

    if elements_w > 0 and #chips > 0 then
        local last = chips[#chips]
        local spin_x = last.x + last.w + MS_GAP
        if self._show_spinner ~= false then
            local spin_total = SPINNER.total_width(ctx, rw)
            local minus, readout, plus = SPINNER.layout_horizontal(ctx, spin_x, rel_y, CONFIG.SIZES.HEIGHT, rw)
            self._sp_readout_screen = {
                rel_x = readout.x,
                rel_y = readout.y,
                w = readout.w,
                h = readout.h
            }
            local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
            SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
            SPINNER.draw_segment(ctx, coords, draw_list, readout, "", btn_txt, btn_bg, sm == "readout")
            SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
            spin_x = spin_x + spin_total + MS_GAP
        end
        if self._show_pitch ~= false then
            local st_pitch = reaper.GetToggleCommandState(40671) == 1
            local chip_h = SPINNER.chip_line_height(ctx)
            local pt_rect = {x = spin_x, y = rel_y + (CONFIG.SIZES.HEIGHT - chip_h) / 2, w = 26, h = chip_h}
            local pt_hit = coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h)
            SPINNER.draw_segment(ctx, coords, draw_list, pt_rect, "P", btn_txt, btn_bg, pt_hit, st_pitch)
        end
    end
end

function widget.slide_height(self, ctx, host_w, host_h, layout)
    local plan = cache_playback_slide_plan(self, ctx, host_w, host_h, layout)
    return plan.h
end

function widget.slide_width(self, ctx, host_w, host_h, layout)
    local plan = cache_playback_slide_plan(self, ctx, host_w, host_h, layout)
    if layout and layout.is_vertical then
        return plan.w
    end
    return host_w
end

function widget.onWidgetFrame(self, ctx, button)
    draw_semitone_overlay(self, ctx, button)
end

return widget
