-- widgets/marker_navigation.lua
-- Marker navigation: [< prev] [next >]

local CHIP_ROW = require("Renderers.Widgets.chip_row")
local OPT = require("Utils.widget_options_popup")
local DRAWING = require("Utils.drawing")

local EDGE_PAD = 6
local GAP = 6
local ROUND = 3
local PLUS_W = 22
local EXT_SECTION = "ATB_MarkerNavigationWidget"

local widget = {
    name = "Marker Navigation",
    category = "Time, grid & tempo",
    update_interval = 0.1,
    type = "display",
    width = 320,
    description = "Navigate markers/regions with arrows and preview previous/next names. Optional + chip can add marker at cursor.",
    chip_widget = true,
    _prev_marker = nil,
    _next_marker = nil,
    _show_plus_chip = true,
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
end

local function save_settings(self)
    reaper.SetProjExtState(0, EXT_SECTION, "show_plus_chip", self._show_plus_chip and "1" or "0")
end

local function enumerate_markers()
    local temp = {}
    local idx = 0
    while true do
        local retval, isrgn, pos, _, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, idx)
        if retval == 0 then
            break
        end
        local default_prefix = isrgn and "Region " or "Marker "
        table.insert(temp, {
            pos = pos,
            name = (name and name ~= "") and name or (default_prefix .. tostring(markrgnindexnumber or (#temp + 1))),
            isrgn = isrgn
        })
        idx = idx + 1
    end

    table.sort(temp, function(a, b)
        if math.abs(a.pos - b.pos) < 1e-6 then
            -- Sort regions first so they are encountered first and take precedence if positions match
            if a.isrgn and not b.isrgn then return true end
            if b.isrgn and not a.isrgn then return false end
        end
        return a.pos < b.pos 
    end)

    local out = {}
    for _, m in ipairs(temp) do
        if #out == 0 or math.abs(out[#out].pos - m.pos) >= 1e-6 then
            table.insert(out, m)
        end
    end

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
    local show_plus = self._show_plus_chip
    local left_w, right_w
    local plus_chip = nil

    if show_plus then
        left_w = math.floor((inner_w - PLUS_W - GAP * 2) / 2)
        if left_w < 0 then left_w = 0 end
        right_w = inner_w - PLUS_W - GAP * 2 - left_w
        if right_w < 0 then right_w = 0 end
    else
        left_w = math.floor((inner_w - GAP) / 2)
        if left_w < 0 then left_w = 0 end
        right_w = inner_w - GAP - left_w
        if right_w < 0 then right_w = 0 end
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

function widget.onSettingsMenu(self, ctx, button)
    load_settings(self)
    
    reaper.ImGui_TextDisabled(ctx, "Marker Navigation")
    reaper.ImGui_Spacing(ctx)

    local changed = false
    local ch_show, new_show = reaper.ImGui_Checkbox(ctx, "Show + chip", self._show_plus_chip)
    if ch_show then
        self._show_plus_chip = new_show
        changed = true
    end

    if changed then
        save_settings(self)
        OPT.commit_dynamic_widget_layout(button, ctx)
    end
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    local mx, my = coords:getRelativeMouse()
    local left_chip, plus_chip, right_chip = get_layout(self, rel_x, rel_y, render_width)

    local prev_name = self._prev_marker and self._prev_marker.name or "No previous"
    local next_name = self._next_marker and self._next_marker.name or "No next"

    local function draw_nav_chip(chip, label, enabled, arrow_left)
        local hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        DRAWING.drawWidgetPillArrowChip(ctx, coords, draw_list, chip, label, btn_txt, btn_bg, {
            arrow_left = arrow_left,
            enabled = enabled,
            hover = hover,
            rounding = ROUND,
            edge_pad = 6,
            ellipsis = "...",
        })
    end

    draw_nav_chip(left_chip, prev_name, self._prev_marker ~= nil, true)
    draw_nav_chip(right_chip, next_name, self._next_marker ~= nil, false)
    if plus_chip then
        local hover = coords:pointInRelativeRect(mx, my, plus_chip.x, plus_chip.y, plus_chip.w, plus_chip.h)
        DRAWING.drawWidgetPillChip(ctx, coords, draw_list, plus_chip, "+", btn_txt, btn_bg, {
            active = false,
            filled = true,
            hover = hover,
            rounding = ROUND,
        })
    end
end

return widget
