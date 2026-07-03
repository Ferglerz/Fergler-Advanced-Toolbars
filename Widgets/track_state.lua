-- widgets/track_state.lua
-- Track state indicator with Record-arm / Mute / Solo square cells, plus Solo dim chip.

local WIDGET = require("Utils.widget_factory")
local DIM_CHIP = WIDGET.DIM_CHIP

local CELL_SIZE = 22
local CELL_GAP = 3
local CELL_ROUND = 4
local CELL_STROKE = 1.0
local HOVER_ALPHA = 0x3A
local LABEL_TEXT = { "R", "M", "S" }
local LABEL_COL = 0xFFFFFFFF
local LABEL_SIZE_BOOST = 1
local BG_IDLE = 0x101010FF
local RED = 0xCC3333FF
local YELLOW = 0xD4AF37FF
local LAVENDER = 0xB57EDCFF
local DIM_LABEL = "Dim"
local DIM_CELL_W = 34
local STATE_COLORS = { RED, RED, YELLOW }

local ORDER = { "r", "m", "s", "dim" }
local RMS_IDX = { r = 1, m = 2, s = 3 }
local PART_META = {
    r = { menu = "Record arm" },
    m = { menu = "Mute" },
    s = { menu = "Solo" },
    dim = { menu = "Solo dim chip" },
}

-- Options: Solo dim (toggle)
local SOLO_DIM_CMD = 40745

-- Solo-in-front dim level config var: integer dB*10 (e.g. -180 = -18 dB).
local DIM_DB10_VAR = "solodimdb10"
local DIM_DB_MIN = -60.0
local DIM_DB_MAX = -1.0
local DIM_DB10_DEFAULT = -120

local widget = {
    name = "Track State",
    category = "Project & surfaces",
    update_interval = 0.1,
    type = "display",
    width = 116,
    label = "",
    description = "Shows global track status for Record-arm, Mute, and Solo; Solo dim on/off (action 40745) on the Dim chip. Click R/M/S clears that state project-wide; click Dim toggles solo dim. Hover the Dim chip for a slider to set the dim level. Right-click to choose visible chips.",
    chip_widget = true,
    _slide_out_mode = true,
    _any_armed = false,
    _any_muted = false,
    _any_soloed = false,
    _solo_dim_on = false,
    _solo_dim_db10 = DIM_DB10_DEFAULT,
    _slide_hover_gate = false,
    _st_overlay_focused = false,
    _visible = nil,
    _open_context = false,
}

local function read_dim_db10()
    if reaper.SNM_GetIntConfigVar then
        local ok, v = pcall(reaper.SNM_GetIntConfigVar, DIM_DB10_VAR, DIM_DB10_DEFAULT)
        if ok and v then
            return v
        end
    end
    return DIM_DB10_DEFAULT
end

local function set_dim_db10(v)
    v = math.floor(v + 0.5)
    local max10 = math.floor(DIM_DB_MAX * 10 + 0.5)
    local min10 = math.floor(DIM_DB_MIN * 10 + 0.5)
    if v > max10 then
        v = max10
    elseif v < min10 then
        v = min10
    end
    if reaper.SNM_SetIntConfigVar then
        pcall(reaper.SNM_SetIntConfigVar, DIM_DB10_VAR, v)
    end
    return v
end

local function ensure_vis(self)
    WIDGET.VIS.ensure_bool_field(self, ORDER, "_visible")
end

local function visible_count(self)
    return WIDGET.VIS.count_enabled(self, ORDER, "_visible")
end

local function show_part(self, id)
    ensure_vis(self)
    return self._visible[id] ~= false
end

function widget.applyPersistedOptions(self, opts)
    WIDGET.VIS.apply_persisted_bool_map(self, opts, {
        ordered_ids = ORDER,
        field = "_visible",
        persist_key = "visible",
        restore_id = "r",
        min_after_apply = 1,
    })
end

function widget.exportPersistedOptions(self)
    ensure_vis(self)
    return WIDGET.VIS.export_bool_map(self, { ordered_ids = ORDER, field = "_visible", persist_key = "visible" })
end

local function any_tracks_state()
    local count = reaper.CountTracks(0)
    local any_armed, any_muted, any_soloed = false, false, false

    for i = 0, count - 1 do
        local tr = reaper.GetTrack(0, i)
        if tr then
            if not any_armed and reaper.GetMediaTrackInfo_Value(tr, "I_RECARM") > 0.5 then
                any_armed = true
            end
            if not any_muted and reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") > 0.5 then
                any_muted = true
            end
            if not any_soloed and reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") > 0.5 then
                any_soloed = true
            end
        end

        if any_armed and any_muted and any_soloed then
            break
        end
    end

    return any_armed, any_muted, any_soloed
end

local function solo_dim_toggle_state()
    local ok, st = pcall(reaper.GetToggleCommandState, SOLO_DIM_CMD)
    return ok and st == 1
end

local function dim_cell_width(ctx)
    local dim_w = DIM_CELL_W
    if ctx and reaper.ImGui_GetFont then
        local f = reaper.ImGui_GetFont(ctx)
        if f then
            local sz = (CONFIG.SIZES.TEXT or 12) + LABEL_SIZE_BOOST
            reaper.ImGui_PushFont(ctx, f, sz)
            dim_w = math.max(DIM_CELL_W, math.ceil(reaper.ImGui_CalcTextSize(ctx, DIM_LABEL) + 10))
            reaper.ImGui_PopFont(ctx)
        end
    end
    return dim_w
end

local function strip_total_width(ctx, self)
    ensure_vis(self)
    local tw = 0
    local n = 0
    for _, id in ipairs(ORDER) do
        if show_part(self, id) then
            tw = tw + (id == "dim" and dim_cell_width(ctx) or CELL_SIZE)
            n = n + 1
        end
    end
    if n > 1 then
        tw = tw + (n - 1) * CELL_GAP
    end
    return tw
end

-- Positioned cells for the visible strip. Uniformly shrinks cells/gap when the natural strip is
-- wider than render_width (picker preview ~104px, narrow vertical toolbars) so nothing clips or
-- pushes the origin negative. Shared by render + hit-test to keep them in sync.
local function strip_cells(ctx, self, rel_x, rel_y, render_width)
    ensure_vis(self)
    local h = CONFIG.SIZES.HEIGHT
    local ids = {}
    for _, id in ipairs(ORDER) do
        if show_part(self, id) then
            ids[#ids + 1] = id
        end
    end
    local n = #ids
    if n == 0 then
        return {}
    end

    local cell = CELL_SIZE
    local dim_w = dim_cell_width(ctx)
    local gap = CELL_GAP

    local function total()
        local tw = 0
        for _, id in ipairs(ids) do
            tw = tw + (id == "dim" and dim_w or cell)
        end
        if n > 1 then
            tw = tw + (n - 1) * gap
        end
        return tw
    end

    local avail = math.max(1, render_width - 6)
    local natural = total()
    if natural > avail then
        local scale = math.max(0.55, avail / natural)
        cell = math.max(14, math.floor(cell * scale))
        dim_w = math.max(22, math.floor(dim_w * scale))
        gap = math.max(1, math.floor(gap * scale))
    end

    local total_w = total()
    local start_x = rel_x + math.max(0, math.floor((render_width - total_w) / 2))
    local start_y = rel_y + math.floor((h - cell) / 2)

    local cells = {}
    local x = start_x
    for i, id in ipairs(ids) do
        if i > 1 then
            x = x + gap
        end
        local w = (id == "dim") and dim_w or cell
        cells[#cells + 1] = { id = id, x = x, y = start_y, w = w, h = cell }
        x = x + w
    end
    return cells
end

local function clear_all_for_state(sub_id)
    local count = reaper.CountTracks(0)
    for i = 0, count - 1 do
        local tr = reaper.GetTrack(0, i)
        if tr then
            if sub_id == "r" then
                reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 0)
            elseif sub_id == "m" then
                reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 0)
            elseif sub_id == "s" then
                reaper.SetMediaTrackInfo_Value(tr, "I_SOLO", 0)
            end
        end
    end
    reaper.TrackList_AdjustWindows(false)
end

function widget.getValue(self)
    self._any_armed, self._any_muted, self._any_soloed = any_tracks_state()
    self._solo_dim_on = solo_dim_toggle_state()
    if not self._dim_slider_active then
        self._solo_dim_db10 = read_dim_db10()
    end
    return 0
end

function widget.getLayoutWidth(self, ctx)
    ensure_vis(self)
    local R = math.max(0, math.floor(tonumber(CONFIG.SIZES.ROUNDING) or 0))
    local inner = strip_total_width(ctx, self)
    return math.max(self.width or 0, inner + R * 2 + 10)
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    -- The dim-level slider in the slide-out handles its own drag interaction.
    if is_slide_out or self._is_rendering_slide_out then
        return nil
    end
    if not ctx then
        return nil
    end
    ensure_vis(self)
    local mx, my = coords:getRelativeMouse()
    local hit = nil
    for _, c in ipairs(strip_cells(ctx, self, rel_x, rel_y, render_width)) do
        if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
            hit = c.id
            break
        end
    end
    -- Only open the slide-out while the Dim chip itself is hovered.
    self._slide_hover_gate = (hit == "dim") and show_part(self, "dim")
    return hit
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "r" then
        clear_all_for_state("r")
        self._any_armed = false
    elseif sub_id == "m" then
        clear_all_for_state("m")
        self._any_muted = false
    elseif sub_id == "s" then
        clear_all_for_state("s")
        self._any_soloed = false
    elseif sub_id == "dim" then
        reaper.Main_OnCommand(SOLO_DIM_CMD, 0)
    end
end

function widget.onSettingsMenu(self, ctx, button)
    ensure_vis(self)
    local rows = {}
    for _, pid in ipairs(ORDER) do
        local id = pid
        rows[#rows + 1] = {
            label = PART_META[id].menu,
            get = function(h)
                return h._visible[id] ~= false
            end,
            set = function(h, v)
                h._visible[id] = v
            end,
        }
    end
    WIDGET.VIS.draw_checkbox_list(ctx, button, self, {
        title = "Visible chips",
        rows = rows,
        total_visible = visible_count,
    })
end

local function dim_db_normalized(db10)
    local db = (db10 or DIM_DB10_DEFAULT) / 10.0
    local n = (db - DIM_DB_MIN) / (DIM_DB_MAX - DIM_DB_MIN)
    if n < 0 then
        n = 0
    elseif n > 1 then
        n = 1
    end
    return n
end

-- Horizontal dim-level slider drawn inside the slide-out panel.
local function render_dim_slider(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color)
    text_color = text_color or LABEL_COL
    local panel_h = self._slide_panel_h or CONFIG.SIZES.HEIGHT or 28
    local fully_open = (self._slide_t or 0) >= 1.0

    local pad_x = 10
    local track_h = 6
    local track_x1 = rel_x + pad_x
    local track_x2 = rel_x + render_width - pad_x
    local track_w = math.max(1, track_x2 - track_x1)
    local track_y = rel_y + panel_h - track_h - 6

    local active = false
    if fully_open then
        reaper.ImGui_SetCursorPos(ctx, rel_x, rel_y)
        reaper.ImGui_InvisibleButton(ctx, "##atb_dim_slider_" .. tostring(self._button_instance_id or "x"), math.max(1, render_width), math.max(1, panel_h))
        active = reaper.ImGui_IsItemActive(ctx)
    end

    if active then
        local mxr = coords:getRelativeMouse()
        local n = (mxr - track_x1) / track_w
        if n < 0 then
            n = 0
        elseif n > 1 then
            n = 1
        end
        local db = DIM_DB_MIN + n * (DIM_DB_MAX - DIM_DB_MIN)
        self._solo_dim_db10 = set_dim_db10(db * 10)
    end
    -- Keep the slide-out open while dragging even if the cursor leaves the panel.
    self._dim_slider_active = active
    self._st_overlay_focused = active

    local normalized = dim_db_normalized(self._solo_dim_db10)

    WIDGET.DRAWING.drawRectFilledRelative(coords, draw_list, track_x1, track_y, track_w, track_h, 0x222222FF, track_h / 2)
    if normalized > 0 then
        WIDGET.DRAWING.drawRectFilledRelative(coords, draw_list, track_x1, track_y, track_w * normalized, track_h, LAVENDER, track_h / 2)
    end

    local handle_x, handle_y = coords:relativeToDrawList(track_x1 + track_w * normalized, track_y + track_h / 2)
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, handle_x, handle_y, track_h - 1, COLOR_UTILS.setAlpha(text_color, 0xFF), 20)

    local db_val = (self._solo_dim_db10 or DIM_DB10_DEFAULT) / 10.0
    local upper_h = math.max(1, track_y - rel_y - 1)
    WIDGET.DRAWING.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y + 1, render_width, upper_h, string.format("Dim %.1f dB", db_val), text_color, 0)
end

function widget.slide_height(self, ctx, host_w, host_h, layout)
    if layout and layout.is_vertical then
        return host_h
    end
    return CONFIG.SIZES.HEIGHT or 28
end

function widget.slide_width(self, ctx, host_w, host_h, layout)
    if layout and layout.is_vertical then
        return math.max(140, host_w or 0)
    end
    return host_w
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color, _layout, _bg_color)
    ensure_vis(self)

    if self._is_rendering_slide_out then
        render_dim_slider(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color)
        return
    end

    local cells = strip_cells(ctx, self, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local pushed_font = false
    local current_font = reaper.ImGui_GetFont(ctx)
    local label_font_size = (CONFIG.SIZES.TEXT or 12) + LABEL_SIZE_BOOST
    if current_font then
        reaper.ImGui_PushFont(ctx, current_font, label_font_size)
        pushed_font = true
    end

    local active = {
        self._any_armed == true,
        self._any_muted == true,
        self._any_soloed == true,
    }

    for _, c in ipairs(cells) do
        if c.id == "dim" then
            DIM_CHIP.draw(draw_list, coords, ctx, {
                x = c.x,
                y = c.y,
                w = c.w,
                h = c.h,
                mx = mx,
                my = my,
                label = DIM_LABEL,
                text_color = LABEL_COL,
                dim_on = self._solo_dim_on == true,
                lavender = LAVENDER,
                bg_idle = BG_IDLE,
                hover_alpha = HOVER_ALPHA,
                round = CELL_ROUND,
                stroke = CELL_STROKE,
            })
        else
            local i = RMS_IDX[c.id]
            local col = STATE_COLORS[i]
            local is_hover = coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h)
            local hover_col = COLOR_UTILS.setAlpha(col, HOVER_ALPHA)

            if active[i] then
                WIDGET.DRAWING.drawChipBackground(coords, draw_list, c.x, c.y, c.w, c.h, is_hover and hover_col or col, { rounding = CELL_ROUND })
            else
                WIDGET.DRAWING.drawChipBackground(coords, draw_list, c.x, c.y, c.w, c.h, is_hover and hover_col or BG_IDLE, { rounding = CELL_ROUND, border_color = col })
            end

            WIDGET.DRAWING.drawCenteredText(ctx, coords, draw_list, c.x, c.y, c.w, c.h, LABEL_TEXT[i], LABEL_COL, 0)
        end
    end

    if pushed_font then
        reaper.ImGui_PopFont(ctx)
    end
end

return widget
