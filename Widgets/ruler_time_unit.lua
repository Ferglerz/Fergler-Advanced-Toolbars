-- widgets/ruler_time_unit.lua
-- Primary ruler time-unit chips (View: Time unit for ruler: … actions).
-- Secondary ruler editing is intentionally omitted (deprioritized).

local CHIP_GAP = 3
local CHIP_H_PAD = 4
local CHIP_V_PAD = 2
local CHIP_ROUND = 3
local BG_IDLE = 0x131313FF
local BG_ACTIVE = 0x2E70B8FF
local BG_HOVER = 0x232323FF
local TEXT_IDLE = 0xD9D9D9FF
local TEXT_ACTIVE = 0xFFFFFFFF

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

local function draw_chip(ctx, coords, draw_list, chip, text, is_active, is_hover)
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
    local bg = is_active and BG_ACTIVE or BG_IDLE
    if is_hover and not is_active then
        bg = BG_HOVER
    end
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg, CHIP_ROUND)

    local tc = is_active and TEXT_ACTIVE or TEXT_IDLE
    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, tc, text)
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

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color)
    local chips = chip_layout(ctx, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()

    for _, chip in ipairs(chips) do
        local is_hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local is_active = self._active_id == chip.id
        draw_chip(ctx, coords, draw_list, chip, chip.mode.label, is_active, is_hover)
    end
end

return widget
