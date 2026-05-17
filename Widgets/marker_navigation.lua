-- widgets/marker_navigation.lua
-- Marker navigation: [< prev] [next >]

local CHIP_ROW = require("Renderers._Widgets_chip_row")
local OPT = require("Utils.widget_options_popup")

local EDGE_PAD = 6
local GAP = 6
local ROUND = 3
local MIN_SIDE_W = 56
local PLUS_W = 22
local EXT_SECTION = "ATB_MarkerNavigationWidget"

local widget = {
    name = "Marker Navigation",
    category = "Time, grid & tempo",
    update_interval = 0.1,
    type = "display",
    width = 320,
    description = "Navigate markers with arrows and preview previous/next marker names. Optional + chip can add marker at cursor.",
    chip_widget = true,
    _prev_marker = nil,
    _next_marker = nil,
    _show_plus_chip = true,
    _plus_min_width = 290,
    _settings_loaded = false,
}

local function load_settings(self)
    if self._settings_loaded then
        return
    end
    self._settings_loaded = true

    local ok1, show = reaper.GetProjExtState(0, EXT_SECTION, "show_plus_chip")
    if ok1 == 1 and show ~= "" then
        self._show_plus_chip = (show == "1")
    end

    local ok2, minw = reaper.GetProjExtState(0, EXT_SECTION, "plus_min_width")
    if ok2 == 1 and minw ~= "" then
        local n = tonumber(minw)
        if n and n >= 200 then
            self._plus_min_width = math.floor(n)
        end
    end
end

local function save_settings(self)
    reaper.SetProjExtState(0, EXT_SECTION, "show_plus_chip", self._show_plus_chip and "1" or "0")
    reaper.SetProjExtState(0, EXT_SECTION, "plus_min_width", tostring(self._plus_min_width))
end

local function enumerate_markers()
    local out = {}
    local idx = 0
    while true do
        local retval, isrgn, pos, _, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, idx)
        if retval == 0 then
            break
        end
        if not isrgn then
            out[#out + 1] = {
                pos = pos,
                name = (name and name ~= "") and name or ("Marker " .. tostring(markrgnindexnumber or (#out + 1))),
            }
        end
        idx = idx + 1
    end
    table.sort(out, function(a, b) return a.pos < b.pos end)
    return out
end

local function nearest_neighbors(markers, cursor_pos)
    local prev_m, next_m = nil, nil
    for _, m in ipairs(markers) do
        if m.pos < cursor_pos then
            prev_m = m
        elseif m.pos > cursor_pos then
            next_m = m
            break
        end
    end
    return prev_m, next_m
end

function widget.getValue(self)
    load_settings(self)
    local markers = enumerate_markers()
    local cur = reaper.GetCursorPositionEx and reaper.GetCursorPositionEx(0) or reaper.GetCursorPosition()
    self._prev_marker, self._next_marker = nearest_neighbors(markers, cur or 0)
    return 0
end

local function get_layout(self, rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local arrow_h = math.max(16, h - 10)
    local y = rel_y + (h - arrow_h) / 2

    local edge = EDGE_PAD + CHIP_ROW.button_rounding_content_pad()
    local inner_x = rel_x + edge
    local inner_w = math.max(40, render_width - edge * 2)
    local show_plus = self._show_plus_chip and (render_width >= (self._plus_min_width or 290))
    local left_w, right_w
    local plus_chip = nil

    if show_plus and (inner_w - (PLUS_W + GAP * 2) >= MIN_SIDE_W * 2) then
        left_w = math.floor((inner_w - PLUS_W - GAP * 2) / 2)
        right_w = inner_w - PLUS_W - GAP * 2 - left_w
    else
        show_plus = false
        left_w = math.floor((inner_w - GAP) / 2)
        right_w = inner_w - GAP - left_w
    end

    local left_chip = { id = "left", x = inner_x, y = y, w = left_w, h = arrow_h }
    if show_plus then
        plus_chip = { id = "add", x = inner_x + left_w + GAP, y = y, w = PLUS_W, h = arrow_h }
    end
    local right_x
    if show_plus and plus_chip then
        right_x = plus_chip.x + plus_chip.w + GAP
    else
        right_x = inner_x + left_w + GAP
    end
    local right_chip = { id = "right", x = right_x, y = y, w = right_w, h = arrow_h }

    return left_chip, plus_chip, right_chip
end

function widget.hitTestSubcontrols(self, _ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local left_chip, plus_chip, right_chip = get_layout(self, rel_x, rel_y, render_width)
    local targets = { left_chip, right_chip }
    if plus_chip then
        table.insert(targets, 2, plus_chip)
    end
    for _, t in ipairs(targets) do
        if coords:pointInRelativeRect(mx, my, t.x, t.y, t.w, t.h) then
            return t.id
        end
    end
    return nil
end

local function jump_to_marker(marker)
    if not marker then
        return
    end
    reaper.SetEditCurPos(marker.pos, true, true)
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "left" then
        jump_to_marker(self._prev_marker)
        return true
    end
    if sub_id == "add" then
        local pos = reaper.GetCursorPositionEx and reaper.GetCursorPositionEx(0) or reaper.GetCursorPosition()
        reaper.AddProjectMarker2(0, false, pos or 0, 0, "", -1, 0)
        return true
    end
    if sub_id == "right" then
        jump_to_marker(self._next_marker)
        return true
    end
    return false
end

local function trim_to_width(ctx, text, max_w)
    if reaper.ImGui_CalcTextSize(ctx, text) <= max_w then
        return text
    end
    local out = text
    while #out > 1 and reaper.ImGui_CalcTextSize(ctx, out .. "...") > max_w do
        out = out:sub(1, -2)
    end
    return out .. "..."
end

local function draw_settings_popup(self, ctx, button)
    load_settings(self)
    local btn = button or self._context_button
    local key = "##marker_nav_settings_" .. tostring(btn and btn.instance_id or self._button_instance_id or "x")
    OPT.consume_open_popup(ctx, key, self, "_open_marker_nav_settings")
    local visible, pad_pushed = OPT.begin_popup_padded(ctx, key)
    if not visible then
        return
    end

    reaper.ImGui_TextDisabled(ctx, "Marker navigation")
    reaper.ImGui_Spacing(ctx)

    local changed = false
    local ch_show, new_show = reaper.ImGui_Checkbox(ctx, "Show + chip when there's room", self._show_plus_chip)
    if ch_show then
        self._show_plus_chip = new_show
        changed = true
    end

    reaper.ImGui_TextDisabled(ctx, "Minimum toolbar width before the + chip appears")
    local min_w = self._plus_min_width or 290
    local ch_w, new_w = reaper.ImGui_SliderInt(ctx, "##marker_nav_plus_min_w", min_w, 200, 2000, "%d px")
    if ch_w then
        self._plus_min_width = math.floor(new_w)
        changed = true
    end

    OPT.end_popup_padded(ctx, pad_pushed)

    if changed then
        save_settings(self)
        OPT.commit_dynamic_widget_layout(btn, ctx)
    end
end

function widget.onRightClick(self, button)
    load_settings(self)
    self._open_marker_nav_settings = true
    self._context_button = button
end

function widget.onRightClickSubcontrol(self, _sub_id, button)
    load_settings(self)
    self._open_marker_nav_settings = true
    self._context_button = button
end

function widget.onWidgetFrame(self, ctx, button)
    draw_settings_popup(self, ctx, button)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    local mx, my = coords:getRelativeMouse()
    local left_chip, plus_chip, right_chip = get_layout(self, rel_x, rel_y, render_width)

    local function draw_chip(chip, label, enabled, arrow_left)
        local hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local bg_col, txt_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
            active = false,
            hover = hover and enabled,
            disabled = not enabled,
        })
        local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
        local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, ROUND)
        local text_max = math.max(10, chip.w - 24)
        local show_label = trim_to_width(ctx, label, text_max)
        local tw = reaper.ImGui_CalcTextSize(ctx, show_label)
        local tx
        if arrow_left then
            tx = chip.x + chip.w - tw - 6
        else
            tx = chip.x + 6
        end
        local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, txt_col, show_label)

        local ax
        if arrow_left then
            ax = chip.x + 6
        else
            ax = chip.x + chip.w - reaper.ImGui_CalcTextSize(ctx, ">") - 6
        end
        local adx, ady = coords:relativeToDrawList(ax, ty)
        reaper.ImGui_DrawList_AddText(draw_list, adx, ady, txt_col, arrow_left and "<" or ">")
    end

    local function draw_plus(chip)
        local hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local bg_col, txt_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
            active = false,
            hover = hover,
        })
        local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
        local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, ROUND)
        local tw = reaper.ImGui_CalcTextSize(ctx, "+")
        local tx = chip.x + (chip.w - tw) / 2
        local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, txt_col, "+")
    end

    local prev_name = self._prev_marker and self._prev_marker.name or "No previous marker"
    local next_name = self._next_marker and self._next_marker.name or "No next marker"
    draw_chip(left_chip, prev_name, self._prev_marker ~= nil, true)
    draw_chip(right_chip, next_name, self._next_marker ~= nil, false)
    if plus_chip then
        draw_plus(plus_chip)
    end
end

return widget
