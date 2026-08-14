-- Utils/Widget/spinner_slide_out_host.lua
-- Spinner + slide-out preset factory: state, slide-out planning, preview, widget construction.

local ROW = require("Utils.Chips.chip_row")
local SPINNER = require("Utils.Chips.chip_spinner")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local PREVIEW_FB = require("Utils.Widget.widget_preview_fallback")
local BASE = require("Utils.Widget.chip_widget_base")
local SLIDE_HOST = require("Utils.Widget.slide_out_chip_host")

local attach_interact = require("Utils.Widget.spinner_slide_out_interact")
local attach_render = require("Utils.Widget.spinner_slide_out_render")

local M = {}

function M.default_widget_id(spec)
    if spec.widget_id then
        return spec.widget_id
    end
    local id = ""
    for word in (spec.name or "widget"):gmatch("%S+") do
        id = id .. word:sub(1, 1):lower()
    end
    if id == "" then
        id = "w"
    end
    return id
end

function M.default_preview_ids(modes)
    local ids = {}
    for _, m in ipairs(modes) do
        if m.default_on ~= false then
            ids[#ids + 1] = m.id
        end
    end
    if #ids < 1 and modes[1] then
        ids[1] = modes[1].id
    end
    return ids
end

function M.default_preview_selected_id(modes)
    for _, m in ipairs(modes) do
        if m.id == "1" then
            return "1"
        end
    end
    for _, m in ipairs(modes) do
        local r = UTILS.asNumber(m.rate, nil)
        if r and math.abs(r - 1.0) < 1e-9 then
            return m.id
        end
    end
    return modes[1] and modes[1].id or "1"
end

function M.default_readout_width(ctx)
    local samples = { "-24st", "12.5st", "0st" }
    local w = 0
    for _, s in ipairs(samples) do
        local tw = UTILS.asNumber(reaper.ImGui_CalcTextSize(ctx, s), 0)
        w = math.max(w, tw)
    end
    return math.ceil(w + 10)
end

local function attach_state(widget, spec, env)
    local MODES = env.MODES
    local mode_by_id = env.mode_by_id

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
        for _, e in ipairs(MODES) do
            if is_included(self, e) then
                list[#list + 1] = e
            end
        end
        return list
    end

    local function count_included(self)
        ensure_included(self)
        local n = 0
        for _, e in ipairs(MODES) do
            if is_included(self, e) then
                n = n + 1
            end
        end
        return n
    end

    env.ensure_included = ensure_included
    env.is_included = is_included
    env.enabled_list = enabled_list
    env.count_included = count_included

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
                if mode_by_id(k) then
                    self._included[k] = on == true
                end
            end
        end
    end

    function widget.exportPersistedOptions(self)
        ensure_included(self)
        local inc = {}
        for _, e in ipairs(MODES) do
            inc[e.id] = is_included(self, e)
        end
        return { included = inc, show_spinner = self._show_spinner, show_pitch = self._show_pitch }
    end

    function widget.getValue(self)
        if spec.getValue then
            return spec.getValue(self)
        end
        ensure_included(self)
        return self._play_rate
    end
end

local function attach_slide_out(widget, spec, env)
    local MODES = env.MODES
    local MIN_CHIP = env.MIN_CHIP
    local enabled_list = env.enabled_list
    local ensure_included = env.ensure_included

    local function multiswitch_layout_opts()
        return {
            pad_x = 4,
            chip_pad_h = 6,
            min_chip_w = MIN_CHIP,
            sizing = "fill",
            caption_for = function(e)
                if spec.caption_for then
                    return spec.caption_for(widget, e)
                end
                return e.short_label or UTILS.formatWidgetValue(widget, e.rate)
            end,
        }
    end

    env.multiswitch_layout_opts = multiswitch_layout_opts

    local function cache_slide_plan(self, ctx, host_w, host_h, layout)
        ensure_included(self)
        local list = enabled_list(self)
        if #list < 1 then
            list = MODES
        end
        return ROW.cache_slide_out_plan(self, ctx, host_w, host_h, layout, list, multiswitch_layout_opts())
    end

    env.cache_slide_plan = cache_slide_plan

    local function slide_out_layout_opts(self, ctx, panel_w, panel_h, layout)
        local plan = self._slide_out_plan or cache_slide_plan(self, ctx, panel_w, panel_h, layout)
        local opts = multiswitch_layout_opts()
        opts.rows = plan.rows
        opts.height = panel_h
        return opts
    end

    env.slide_out_layout_opts = slide_out_layout_opts

    local function layout_multiswitch_chips(ctx, rel_x, rel_y, ms_width, layout, list)
        return ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, ms_width, layout, list, multiswitch_layout_opts())
    end

    env.layout_multiswitch_chips = layout_multiswitch_chips

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

    env.horizontal_multiswitch_cols = horizontal_multiswitch_cols

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
        local cell_w = ROW.uniform_chip_cell_width(ctx, MODES, multiswitch_layout_opts())
        local cols = (usable_w >= 2 * cell_w + gap) and 2 or 1
        cols = math.min(cols, math.max(1, n))
        local rows = math.ceil(n / cols)
        local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
        return pad_y + grid_h + pad_y
    end

    env.multiswitch_block_height = multiswitch_block_height

    function widget.slide_height(self, ctx, host_w, host_h, layout)
        local plan = cache_slide_plan(self, ctx, host_w, host_h, layout)
        return plan.h
    end

    function widget.slide_width(self, ctx, host_w, host_h, layout)
        local plan = cache_slide_plan(self, ctx, host_w, host_h, layout)
        return SLIDE_HOST.panel_width(host_w, plan, layout)
    end
end

local function attach_preview(widget, spec, env)
    local PREVIEW_IDS = env.PREVIEW_IDS
    local PREVIEW_NAMESPACE = env.PREVIEW_NAMESPACE
    local PREVIEW_SELECTED_ID = env.PREVIEW_SELECTED_ID
    local PREVIEW_TITLE = env.PREVIEW_TITLE
    local mode_by_id = env.mode_by_id
    local multiswitch_layout_opts = env.multiswitch_layout_opts

    local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        local h = CONFIG.SIZES.HEIGHT
        local subset = {}
        for _, pid in ipairs(PREVIEW_IDS) do
            local e = mode_by_id(pid)
            if e then
                subset[#subset + 1] = e
            end
        end
        local mx, my = coords:getRelativeMouse()
        if PREVIEW_FB.when(ctx, #subset < #PREVIEW_IDS, PREVIEW_TITLE, rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
            return
        end
        local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, subset, multiswitch_layout_opts())
        if chips and #chips > 0 then
            SLIDE_HOST.draw_ms(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
                mx = mx,
                my = my,
                enabled = true,
                mixed = false,
                chip_round = ROW.CHIP_ROUND,
                slide_namespace = PREVIEW_NAMESPACE,
                grid_layout = true,
                is_selected_segment = function(c)
                    return not c.blank and c.mode and c.mode.id == PREVIEW_SELECTED_ID
                end,
            })
        else
            PREVIEW_FB.draw_centered_title(ctx, PREVIEW_TITLE, rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        end
    end

    env.render_preview = render_preview
end

function M.new(spec, layout_api)
    local MODES = spec.modes or {}
    CHIP_MS.normalize_chip_entries(MODES)

    local WID = M.default_widget_id(spec)
    local MS_PREFIX = spec.ms_prefix or (WID .. "_ms_")
    local SP_PREFIX = spec.sp_prefix or (WID .. "_sp_")
    local PITCH_SUB_ID = spec.pitch_sub_id or (WID .. "_pitch")
    local MS_GAP = spec.ms_gap or 6
    local MIN_CHIP = spec.min_chip_w or 22
    local PREVIEW_IDS = spec.preview_ids or M.default_preview_ids(MODES)
    local CMD_SPINNER_UP = spec.cmd_spinner_up
    local CMD_SPINNER_DOWN = spec.cmd_spinner_down
    local CMD_PITCH_TOGGLE = spec.cmd_pitch_toggle
    local SLIDE_NAMESPACE = spec.slide_namespace or (WID .. "_ms")
    local PREVIEW_NAMESPACE = spec.preview_namespace or (WID .. "_prev")
    local PREVIEW_SELECTED_ID = spec.preview_selected_id or M.default_preview_selected_id(MODES)
    local PREVIEW_TITLE = spec.preview_title or (spec.name or "Presets")
    local PITCH_ICON = spec.pitch_icon or "icons/Music/Tuning Fork.ttf"
    local SPINNER_OVERLAY = spec.spinner_overlay

    local function mode_by_id(id)
        return BASE.mode_by_id(MODES, id)
    end

    local readout_width = spec.readout_width or M.default_readout_width

    local function resolve_active_preset_id(self, play_rate, list)
        if spec.active_preset_id then
            return spec.active_preset_id(self, play_rate, list)
        end
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

    local function layout_spinner_area(ctx, render_width, rw, show_spinner, show_pitch, is_vertical)
        return layout_api.layout_spinner_area(ctx, render_width, rw, show_spinner, show_pitch, is_vertical, MS_GAP)
    end

    local env = {
        M = layout_api,
        MODES = MODES,
        WID = WID,
        MS_PREFIX = MS_PREFIX,
        SP_PREFIX = SP_PREFIX,
        PITCH_SUB_ID = PITCH_SUB_ID,
        MS_GAP = MS_GAP,
        MIN_CHIP = MIN_CHIP,
        PREVIEW_IDS = PREVIEW_IDS,
        CMD_SPINNER_UP = CMD_SPINNER_UP,
        CMD_SPINNER_DOWN = CMD_SPINNER_DOWN,
        CMD_PITCH_TOGGLE = CMD_PITCH_TOGGLE,
        SLIDE_NAMESPACE = SLIDE_NAMESPACE,
        PREVIEW_NAMESPACE = PREVIEW_NAMESPACE,
        PREVIEW_SELECTED_ID = PREVIEW_SELECTED_ID,
        PREVIEW_TITLE = PREVIEW_TITLE,
        PITCH_ICON = PITCH_ICON,
        SPINNER_OVERLAY = SPINNER_OVERLAY,
        mode_by_id = mode_by_id,
        readout_width = readout_width,
        resolve_active_preset_id = resolve_active_preset_id,
        layout_spinner_area = layout_spinner_area,
        toolbar_body_h = layout_api._toolbar_body_h,
        compute_toolbar_spinner_layout = layout_api.compute_toolbar_spinner_layout,
        compute_preview_vertical_layout = layout_api.compute_preview_vertical_layout,
        compute_preview_horizontal_layout = layout_api.compute_preview_horizontal_layout,
        apply_sp_readout_screen = layout_api.apply_sp_readout_screen,
        hit_toolbar_spinner_layout = layout_api.hit_toolbar_spinner_layout,
        hover_toolbar_spinner_segment = layout_api.hover_toolbar_spinner_segment,
    }

    local widget = BASE.apply_base_widget(spec, {
        update_interval = 0.05,
        default_width = 280,
        extra = {
            _included = nil,
            _show_spinner = true,
            _show_pitch = true,
            _slide_out_mode = true,
            _play_rate = 1.0,
            _active_ms_id = nil,
            _open_rates_context = false,
            _st_buf = nil,
            _st_overlay_focused = false,
            _sp_readout_rel = nil,
            _pitch_rel = nil,
            _sp_readout_screen = nil,
        },
    })

    if spec.format then
        widget.format = spec.format
    end
    if spec.col_primary then
        widget.col_primary = spec.col_primary
    end

    for k, v in pairs(spec.state or {}) do
        widget[k] = v
    end

    attach_state(widget, spec, env)
    attach_slide_out(widget, spec, env)
    attach_preview(widget, spec, env)
    attach_interact(widget, spec, env)
    attach_render(widget, spec, env)

    local enabled_list = env.enabled_list
    local ensure_included = env.ensure_included
    local count_included = env.count_included
    local horizontal_multiswitch_cols = env.horizontal_multiswitch_cols
    local multiswitch_block_height = env.multiswitch_block_height

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
            preview_list = MODES
        end
        local ms_w = ROW.uniform_multiswitch_width(ctx, preview_list, cols, env.multiswitch_layout_opts())
        local total = ms_w
        if self._show_spinner ~= false then
            local rw = readout_width(ctx)
            local spin_w = SPINNER.total_width(ctx, rw)
            total = total + MS_GAP + spin_w
        end
        if self._show_pitch ~= false then
            total = total + MS_GAP + 26
        end
        return ROW.apply_preview_width_cap(self, math.max(100, math.ceil(total)))
    end

    function widget.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar)
        if not is_vertical_toolbar or not ctx then
            return CONFIG.SIZES.HEIGHT
        end
        if not self._preview_mode then
            local iw = UTILS.asNumber(inner_w, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
            local rw = readout_width(ctx)
            local sp_layout = layout_spinner_area(ctx, iw, rw, self._show_spinner, self._show_pitch, true)
            if sp_layout.stacked then
                local chip_h = SPINNER.chip_line_height(ctx)
                local inset = ROW.button_rounding_content_pad()
                return math.max(CONFIG.SIZES.HEIGHT or 28, chip_h * 2 + 2 + inset * 2)
            end
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
            local rw = readout_width(ctx)
            local sp_layout = layout_spinner_area(ctx, iw, rw, self._show_spinner, self._show_pitch, true)
            if sp_layout.stacked then
                local chip_h = SPINNER.chip_line_height(ctx)
                local total_h = chip_h * 2 + 2
                return math.max(CONFIG.SIZES.HEIGHT or 28, ms_h + ROW.CHIP_GAP + total_h + 4 + inset)
            else
                local sh = SPINNER.chip_line_height(ctx)
                return math.max(CONFIG.SIZES.HEIGHT or 28, ms_h + ROW.CHIP_GAP + sh + 4 + inset)
            end
        end
        return math.max(CONFIG.SIZES.HEIGHT or 28, ms_h + 4 + inset)
    end

    BASE.apply_spec_overrides(widget, spec, {
        "renderCustom",
        "hitTestSubcontrols",
        "onSubcontrolClick",
        "getLayoutWidth",
        "getLayoutHeight",
        "getValue",
        "onSettingsMenu",
        "applyPersistedOptions",
        "exportPersistedOptions",
        "onWidgetFrame",
    })

    return widget
end

return M
