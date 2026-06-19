-- widgets/master_rms_dim.lua
-- Master peak meters + peak dB + RMS-style level + solo dim chip; right-click to show/hide parts (at least one must stay visible).

local CHIP_ROW = require("Renderers._Widgets_chip_row")
local VIS = require("Utils.widget_visibility")
local PEAK_METERS = require("Utils.widget_draw_peak_meters")
local DIM_CHIP = require("Utils.widget_draw_dim_chip")
local FLEX_LAYOUT = require("Utils.flex_layout")

local ROW_PAD = 4

local DISPLAY_IDS = { "meters", "peak_db", "rms_db", "dim" }

local DISPLAY_META = {
    meters = { menu = "Peak meters" },
    peak_db = { menu = "Peak dB readout" },
    rms_db = { menu = "RMS level" },
    dim = { menu = "Solo dim chip" },
}

local DIM_LABEL = "Dim"
local DIM_CMD = 40745 -- Options: Solo inactive / dim soloed tracks
local MASTER_TCP_TOGGLE = 40075

local METER_W = 8
local METER_GAP = 2
local DIM_GAP = 4
local DIM_MIN_W = 36

local widget = {
    name = "Master RMS / Dim",
    category = "Mix & monitoring",
    update_interval = 0.033,
    type = "display",
    width = 132,
    format = "%.1f dB",
    label = "",
    description = "Master stereo peak meters, peak dB, RMS-style level (smoothed), and solo dim chip. Right-click to choose visible elements. Click dim chip toggles solo dim; click elsewhere toggles master track in TCP.",
    chip_widget = true,
    suppress_tooltip = true,

    peak_level = -60,
    left_level = -60,
    right_level = -60,
    session_peak = -60,
    rms_db = -60,
    clip_indicator = false,
    last_play_state = 0,
    _rms_sq_ema = nil,
    _visible = nil,
    _open_context = false,
    _solo_dim_on = false,
}

local function ensure_vis(self)
    VIS.ensure_bool_field(self, DISPLAY_IDS, "_visible")
end

local function visible_count(self)
    return VIS.count_enabled(self, DISPLAY_IDS, "_visible")
end

local function show_part(self, id)
    ensure_vis(self)
    return self._visible[id] ~= false
end

function widget.applyPersistedOptions(self, opts)
    VIS.apply_persisted_bool_map(self, opts, {
        ordered_ids = DISPLAY_IDS,
        field = "_visible",
        persist_key = "visible",
        restore_id = "meters",
        min_after_apply = 1,
    })
end

function widget.exportPersistedOptions(self)
    ensure_vis(self)
    return VIS.export_bool_map(self, { ordered_ids = DISPLAY_IDS, field = "_visible", persist_key = "visible" })
end

local function try_peakinfo(track, ch)
    local ok, v = pcall(reaper.Track_GetPeakInfo, track, ch)
    if ok and type(v) == "number" and v == v and v >= 0 then
        return v
    end
    return nil
end

function widget.getValue(self)
    local play_state = reaper.GetPlayState()
    local is_playing = (play_state & 1) == 1 or (play_state & 4) == 4
    local was_playing = (self.last_play_state & 1) == 1 or (self.last_play_state & 4) == 4

    if is_playing and not was_playing then
        self.session_peak = -60
        self.clip_indicator = false
        self._rms_sq_ema = nil
    end

    self._solo_dim_on = reaper.GetToggleCommandState(DIM_CMD) == 1

    local master_track = reaper.GetMasterTrack(0)
    if master_track then
        local left_peak = try_peakinfo(master_track, 0) or 0
        local right_peak = try_peakinfo(master_track, 1) or left_peak

        local lrms = try_peakinfo(master_track, 2)
        local rrms = try_peakinfo(master_track, 3)

        self.left_level = UTILS.peakLinearToDb(left_peak)
        self.right_level = UTILS.peakLinearToDb(right_peak)
        self.peak_level = math.max(self.left_level, self.right_level)

        local rms_lin = nil
        if lrms and rrms then
            rms_lin = math.max(lrms, rrms)
        elseif lrms then
            rms_lin = lrms
        elseif rrms then
            rms_lin = rrms
        end
        if rms_lin ~= nil then
            self.rms_db = UTILS.peakLinearToDb(rms_lin)
        else
            local mono_lin = math.max(left_peak, right_peak)
            local sq = mono_lin * mono_lin
            self._rms_sq_ema = (self._rms_sq_ema or 0) * 0.92 + sq * 0.08
            self.rms_db = UTILS.peakLinearToDb(math.sqrt(math.max(self._rms_sq_ema, 1e-20)))
        end

        if is_playing then
            self.session_peak = math.max(self.session_peak or -60, self.peak_level)
        end

        if self.peak_level > -0.1 then
            self.clip_indicator = true
        end
    end

    if play_state == 1 and self.last_play_state == 0 then
        self.clip_indicator = false
    end
    self.last_play_state = play_state

    return self.peak_level
end

local function meter_block_width()
    return METER_W * 2 + METER_GAP
end

local function text_column_width(ctx, self)
    if not ctx then
        return 72
    end
    local w = 0
    if show_part(self, "peak_db") then
        local s = string.format(self.format or "%.1f dB", self.session_peak or self.peak_level)
        w = math.max(w, reaper.ImGui_CalcTextSize(ctx, s) or 0)
    end
    if show_part(self, "rms_db") then
        local s = string.format("R %.1f", self.rms_db or -60)
        w = math.max(w, reaper.ImGui_CalcTextSize(ctx, s) or 0)
    end
    return math.ceil(w)
end

local function dim_cell_width(ctx)
    if not ctx then
        return DIM_MIN_W
    end
    return math.max(DIM_MIN_W, math.ceil(reaper.ImGui_CalcTextSize(ctx, DIM_LABEL) + 10))
end

local function get_rms_groups(self, ctx)
    local groups = {}
    local g1 = {}
    local g2 = {}
    if show_part(self, "meters") then
        table.insert(g1, { id="meters", w=meter_block_width() })
    end
    if show_part(self, "peak_db") then
        local s = string.format(self.format or "%.1f dB", self.session_peak or self.peak_level)
        table.insert(g1, { id="peak_db", w=math.ceil(reaper.ImGui_CalcTextSize(ctx, s)), txt=s })
    end
    if show_part(self, "rms_db") then
        local s = string.format("R %.1f", self.rms_db or -60)
        table.insert(g2, { id="rms_db", w=math.ceil(reaper.ImGui_CalcTextSize(ctx, s)), txt=s })
    end
    if show_part(self, "dim") then
        table.insert(g2, { id="dim", w=dim_cell_width(ctx) })
    end
    if #g1 > 0 then table.insert(groups, g1) end
    if #g2 > 0 then table.insert(groups, g2) end
    return groups
end

function widget.getLayoutWidth(self, ctx, is_vertical)
    ensure_vis(self)
    if visible_count(self) < 1 then return 80 end
    local groups = get_rms_groups(self, ctx)
    local w = 0
    
    if is_vertical then
        for _, g in ipairs(groups) do
            for _, it in ipairs(g) do
                w = math.max(w, it.w)
            end
        end
    else
        for _, g in ipairs(groups) do
            for _, it in ipairs(g) do
                w = w + it.w + DIM_GAP
            end
        end
        w = w - DIM_GAP
    end
    
    local inset = CHIP_ROW.button_rounding_content_pad()
    local pad = ROW_PAD + inset
    return math.max(80, w + pad * 2)
end

function widget.getLayoutHeight(self, ctx, inner_width, is_vertical_toolbar)
    if not is_vertical_toolbar then return CONFIG.SIZES.HEIGHT end
    ensure_vis(self)
    local groups = get_rms_groups(self, ctx)
    local inset = CHIP_ROW.button_rounding_content_pad()
    local pad = ROW_PAD + inset
    local inner_w = math.max(10, (inner_width or self.width or 132) - pad * 2)
    local lines = FLEX_LAYOUT.wrap_groups(groups, inner_w, DIM_GAP, DIM_GAP)
    
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local h_per_line = (#lines > 1) and (line_h + 8) or CONFIG.SIZES.HEIGHT
    local total_h = #lines * h_per_line + (#lines - 1) * DIM_GAP
    return total_h
end

local function widget_content_height(layout)
    return (layout and layout.height) or CONFIG.SIZES.HEIGHT
end

local function layout_geometry(ctx, self, rel_x, rel_y, render_width, layout)
    local is_vertical = layout and layout.is_vertical
    local groups = get_rms_groups(self, ctx)
    local inset = CHIP_ROW.button_rounding_content_pad()
    local pad = ROW_PAD + inset
    local inner_w = math.max(10, render_width - pad * 2)
    local max_w = inner_w
    
    local lines = FLEX_LAYOUT.wrap_groups(groups, max_w, DIM_GAP, DIM_GAP)
    
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local rects = {}
    
    local base_h = CONFIG.SIZES.HEIGHT
    local h_per_line = base_h
    if is_vertical and #lines > 1 then
        h_per_line = line_h + 8
    end
    
    local total_h = #lines * h_per_line + (#lines - 1) * DIM_GAP
    local h = layout and layout.height or base_h
    local y = rel_y + (h - total_h) / 2
    
    for _, line in ipairs(lines) do
        local x = rel_x + pad
        for _, it in ipairs(line.items) do
            rects[it.id] = { x = x, y = y, w = it.w, h = h_per_line, txt = it.txt }
            x = x + it.w + DIM_GAP
        end
        y = y + h_per_line + DIM_GAP
    end
    return rects
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    if not ctx then
        return nil
    end
    local rects = layout_geometry(ctx, self, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    if rects.dim and coords:pointInRelativeRect(mx, my, rects.dim.x, rects.dim.y, rects.dim.w, rects.dim.h) then
        return "dim"
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "dim" then
        reaper.Main_OnCommand(DIM_CMD, 0)
        return true
    end
    return false
end

function widget.onClick(self, _sub_hit)
    reaper.Main_OnCommand(MASTER_TCP_TOGGLE, 0)
end

function widget.onRightClick(self, _button)
    self._open_context = true
end

function widget.onRightClickSubcontrol(self, _sub_id, _button)
    self._open_context = true
end

local function draw_context_menu(self, ctx, button)
    ensure_vis(self)
    local rows = {}
    for _, pid in ipairs(DISPLAY_IDS) do
        local id = pid
        rows[#rows + 1] = {
            label = DISPLAY_META[id].menu,
            get = function(h)
                return h._visible[id] ~= false
            end,
            set = function(h, v)
                h._visible[id] = v
            end,
        }
    end
    VIS.draw_checkbox_popup(ctx, button, self, {
        popup_prefix = "master_rms_dim_ctx",
        title = "Visible elements",
        rows = rows,
        total_visible = visible_count,
    })
end

function widget.onWidgetFrame(self, ctx, button)
    draw_context_menu(self, ctx, button)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, _bg_color)
    ensure_vis(self)
    local rects = layout_geometry(ctx, self, rel_x, rel_y, render_width, layout)

    local mx, my = coords:getRelativeMouse()

    if rects.meters then
        PEAK_METERS.draw_stereo_vertical(draw_list, coords, {
            x_left = rects.meters.x,
            y = rects.meters.y + 4,
            meter_w = METER_W,
            gap = METER_GAP,
            height = rects.meters.h - 8,
            left_db = self.left_level,
            right_db = self.right_level,
            peak_db = self.peak_level,
            clip_indicator = self.clip_indicator,
            corner_round = 2,
        })
    end

    if rects.peak_db then
        local line_h = reaper.ImGui_GetTextLineHeight(ctx)
        local ty = rects.peak_db.y + (rects.peak_db.h - line_h) / 2
        local dx, dy = coords:relativeToDrawList(rects.peak_db.x, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_color, rects.peak_db.txt)
    end

    if rects.rms_db then
        local line_h = reaper.ImGui_GetTextLineHeight(ctx)
        local ty = rects.rms_db.y + (rects.rms_db.h - line_h) / 2
        local dx, dy = coords:relativeToDrawList(rects.rms_db.x, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_color, rects.rms_db.txt)
    end

    if rects.dim then
        DIM_CHIP.draw(draw_list, coords, ctx, {
            x = rects.dim.x,
            y = rects.dim.y,
            w = rects.dim.w,
            h = rects.dim.h,
            mx = mx,
            my = my,
            label = DIM_LABEL,
            text_color = text_color,
            dim_on = self._solo_dim_on == true,
            lavender = 0x967BB8FF,
            hover_alpha = 0x55,
            round = 3,
            variant = "hover_only_when_off",
        })
    end
end

return widget
