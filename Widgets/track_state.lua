-- widgets/track_state.lua
-- Track state indicator with Record-arm / Mute / Solo square cells, plus Solo dim chip.

local VIS = require("Utils.widget_visibility")
local DIM_CHIP = require("Utils.widget_draw_dim_chip")

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

local widget = {
    name = "Track State",
    category = "Project & surfaces",
    update_interval = 0.1,
    type = "display",
    width = 116,
    label = "",
    description = "Shows global track status for Record-arm, Mute, and Solo; Solo dim on/off (action 40745) on the Dim chip. Click R/M/S clears that state project-wide; click Dim toggles solo dim. Right-click to choose visible chips.",
    chip_widget = true,
    _any_armed = false,
    _any_muted = false,
    _any_soloed = false,
    _solo_dim_on = false,
    _visible = nil,
    _open_context = false,
}

local function ensure_vis(self)
    VIS.ensure_bool_field(self, ORDER, "_visible")
end

local function visible_count(self)
    return VIS.count_enabled(self, ORDER, "_visible")
end

local function show_part(self, id)
    ensure_vis(self)
    return self._visible[id] ~= false
end

function widget.applyPersistedOptions(self, opts)
    VIS.apply_persisted_bool_map(self, opts, {
        ordered_ids = ORDER,
        field = "_visible",
        persist_key = "visible",
        restore_id = "r",
        min_after_apply = 1,
    })
end

function widget.exportPersistedOptions(self)
    ensure_vis(self)
    return VIS.export_bool_map(self, { ordered_ids = ORDER, field = "_visible", persist_key = "visible" })
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

local function cell_strip_origin(rel_x, rel_y, render_width, ctx, self)
    local h = CONFIG.SIZES.HEIGHT
    local total_w = strip_total_width(ctx, self)
    local start_x = rel_x + math.floor((render_width - total_w) / 2)
    local start_y = rel_y + math.floor((h - CELL_SIZE) / 2)
    return start_x, start_y
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
    return 0
end

function widget.getLayoutWidth(self, ctx)
    ensure_vis(self)
    local R = math.max(0, math.floor(tonumber(CONFIG.SIZES.ROUNDING) or 0))
    local inner = strip_total_width(ctx, self)
    return math.max(self.width or 0, inner + R * 2 + 10)
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width)
    if not ctx then
        return nil
    end
    ensure_vis(self)
    local mx, my = coords:getRelativeMouse()
    local start_x, start_y = cell_strip_origin(rel_x, rel_y, render_width, ctx, self)
    local x = start_x
    local first = true
    for _, id in ipairs(ORDER) do
        if show_part(self, id) then
            if not first then
                x = x + CELL_GAP
            end
            first = false
            local w = id == "dim" and dim_cell_width(ctx) or CELL_SIZE
            if coords:pointInRelativeRect(mx, my, x, start_y, w, CELL_SIZE) then
                return id
            end
            x = x + w
        end
    end
    return nil
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

function widget.onRightClick(self, _button)
    self._open_context = true
end

function widget.onRightClickSubcontrol(self, _sub_id, _button)
    self._open_context = true
end

local function draw_context_menu(self, ctx, button)
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
    VIS.draw_checkbox_popup(ctx, button, self, {
        popup_prefix = "track_state_ctx",
        title = "Visible chips",
        rows = rows,
        total_visible = visible_count,
    })
end

function widget.onWidgetFrame(self, ctx, button)
    draw_context_menu(self, ctx, button)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color, _layout, _bg_color)
    ensure_vis(self)
    local start_x, start_y = cell_strip_origin(rel_x, rel_y, render_width, ctx, self)
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

    local x = start_x
    local first = true
    for _, id in ipairs(ORDER) do
        if show_part(self, id) then
            if not first then
                x = x + CELL_GAP
            end
            first = false

            if id == "dim" then
                local dim_w_cell = dim_cell_width(ctx)
                DIM_CHIP.draw(draw_list, coords, ctx, {
                    x = x,
                    y = start_y,
                    w = dim_w_cell,
                    h = CELL_SIZE,
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
                x = x + dim_w_cell
            else
                local i = RMS_IDX[id]
                local cell_rel_x = x
                local cell_rel_y = start_y
                local x1, y1 = coords:relativeToDrawList(cell_rel_x, cell_rel_y)
                local x2, y2 = coords:relativeToDrawList(cell_rel_x + CELL_SIZE, cell_rel_y + CELL_SIZE)
                local col = STATE_COLORS[i]
                local is_hover =
                    coords:pointInRelativeRect(mx, my, cell_rel_x, cell_rel_y, CELL_SIZE, CELL_SIZE)
                local hover_col = (col & 0xFFFFFF00) | HOVER_ALPHA

                if active[i] then
                    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, col, CELL_ROUND)
                    if is_hover then
                        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, hover_col, CELL_ROUND)
                    end
                else
                    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, BG_IDLE, CELL_ROUND)
                    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, col, CELL_ROUND, 0, CELL_STROKE)
                    if is_hover then
                        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, hover_col, CELL_ROUND)
                    end
                end

                local txt = LABEL_TEXT[i]
                local tw = reaper.ImGui_CalcTextSize(ctx, txt)
                local tx = cell_rel_x + (CELL_SIZE - tw) / 2
                local ty = cell_rel_y + (CELL_SIZE - reaper.ImGui_GetTextLineHeight(ctx)) / 2
                local tdx, tdy = coords:relativeToDrawList(tx, ty)
                reaper.ImGui_DrawList_AddText(draw_list, tdx, tdy, LABEL_COL, txt)

                x = x + CELL_SIZE
            end
        end
    end

    if pushed_font then
        reaper.ImGui_PopFont(ctx)
    end
end

return widget
