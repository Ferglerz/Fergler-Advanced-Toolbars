-- Widgets/Under Development/ruler_time_unit.lua
-- Primary ruler time-unit chips (View: Time unit for ruler: … actions).

local CHIP_GAP = 3
local CHIP_V_PAD = 2
local CHIP_ROUND = 3

local MODES = {
    { id = "ms", label = "M:S", command_id = 40365 },
    { id = "mb_ms", label = "M:B/M:S", command_id = 40366 },
    { id = "mb", label = "M:B", command_id = 40367 },
    { id = "sec", label = "Sec", command_id = 40368 },
    { id = "smp", label = "Smp", command_id = 40369 },
    { id = "tc", label = "TC", command_id = 40370 },
    { id = "mbmin", label = "M:B+", command_id = 41916 },
    { id = "mbmin_ms", label = "M:B+/M:S", command_id = 41918 },
    { id = "afrm", label = "A.Frm", command_id = 41973 },
}

local widget = {
    name = "Ruler Time Unit",
    category = "Under Development",
    update_interval = 0.2,
    type = "display",
    width = 520,
    label = "",
    description = "Primary ruler time format chips. Secondary ruler modes are not edited here (deprioritized).",
    _active_id = nil,
    _last_click_id = nil,
}

local function mode_by_id(id)
    for _, m in ipairs(MODES) do
        if m.id == id then
            return m
        end
    end
    return nil
end

local function detect_active_mode_id()
    for _, m in ipairs(MODES) do
        local ok, st = pcall(reaper.GetToggleCommandState, m.command_id)
        if ok and st == 1 then
            return m.id
        end
    end
    return nil
end

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 520
    if ctx and reaper.ImGui_GetTextLineHeight then
        local total = #MODES
        local per_min = 24
        local computed = 8 + total * per_min + CHIP_GAP * (total - 1)
        natural = math.max(natural, computed)
    end
    local cap = tonumber(self._preview_width_cap)
    if cap and cap > 0 then
        return math.min(natural, cap)
    end
    return natural
end

local function chip_layout(ctx, rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local total = #MODES
    local usable_w = math.max(40, render_width - 8)
    local per_w = math.floor((usable_w - CHIP_GAP * (total - 1)) / total)
    per_w = math.max(24, per_w)
    local x = rel_x + 4
    local chips = {}
    for _, m in ipairs(MODES) do
        chips[#chips + 1] = {
            id = m.id,
            x = x,
            y = row_y,
            w = per_w,
            h = chip_h,
            mode = m,
        }
        x = x + per_w + CHIP_GAP
    end
    return chips
end

local function draw_chip(ctx, coords, draw_list, chip, text, is_active, is_hover, btn_txt, btn_bg)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
    })
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROUND)

    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, text)
end

function widget.getValue(self)
    local from_reaper = detect_active_mode_id()
    if from_reaper then
        self._active_id = from_reaper
    elseif self._last_click_id then
        self._active_id = self._last_click_id
    else
        self._active_id = nil
    end
    return 0
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local chips = chip_layout(ctx, rel_x, rel_y, render_width)
    for _, chip in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            return "ruler_" .. chip.id
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    local id = sub_id and sub_id:match("^ruler_(.+)$")
    if not id then
        return false
    end
    local m = mode_by_id(id)
    if not m or not m.command_id then
        return false
    end
    reaper.Main_OnCommand(m.command_id, 0)
    self._last_click_id = id
    self._active_id = id
    return true
end

local PREVIEW_MODE_IDS = { "ms", "sec", "tc" }

--- Widget browser: three representative chips; centered label if too narrow.
local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local mx, my = coords:getRelativeMouse()

    local segments = {}
    local total_w = -CHIP_GAP
    for _, pid in ipairs(PREVIEW_MODE_IDS) do
        local m = mode_by_id(pid)
        if m then
            local tw = reaper.ImGui_CalcTextSize(ctx, m.label)
            local cw = math.max(24, tw + 6)
            segments[#segments + 1] = { mode = m, w = cw }
            total_w = total_w + cw + CHIP_GAP
        end
    end

    if total_w > render_width - 8 then
        DRAWING.drawWidgetCenteredValueText(ctx, "Ruler time", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end

    local x = rel_x + (render_width - total_w) / 2
    for _, seg in ipairs(segments) do
        local m = seg.mode
        local chip = {
            id = m.id,
            x = x,
            y = row_y,
            w = seg.w,
            h = chip_h,
            mode = m,
        }
        local is_hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local is_active = self._active_id == chip.id
        draw_chip(ctx, coords, draw_list, chip, chip.mode.label, is_active, is_hover, btn_txt, btn_bg)
        x = x + seg.w + CHIP_GAP
    end
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    if self._preview_mode then
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        return
    end
    local chips = chip_layout(ctx, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()

    for _, chip in ipairs(chips) do
        local is_hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local is_active = self._active_id == chip.id
        draw_chip(ctx, coords, draw_list, chip, chip.mode.label, is_active, is_hover, btn_txt, btn_bg)
    end
end

return widget
