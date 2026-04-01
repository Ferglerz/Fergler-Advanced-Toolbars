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
    chip_widget = true,
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

local function preview_chip_layout(ctx, rel_x, rel_y, render_width, mode_ids)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local chips = {}
    for _, pid in ipairs(mode_ids) do
        local m = mode_by_id(pid)
        if m then
            chips[#chips + 1] = { id = m.id, mode = m }
        end
    end
    local total = #chips
    if total <= 0 then
        return {}
    end
    local usable_w = math.max(40, render_width - 8)
    local per_w = math.floor((usable_w - CHIP_GAP * (total - 1)) / total)
    per_w = math.max(24, per_w)
    local row_w = total * per_w + CHIP_GAP * (total - 1)
    if row_w > render_width - 8 then
        return nil
    end
    local x = rel_x + (render_width - row_w) / 2
    for _, c in ipairs(chips) do
        c.x = x
        c.y = row_y
        c.w = per_w
        c.h = chip_h
        x = x + per_w + CHIP_GAP
    end
    return chips
end

--- Widget browser: grouped multiswitch when wide enough.
local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local mx, my = coords:getRelativeMouse()
    local chips = preview_chip_layout(ctx, rel_x, rel_y, render_width, PREVIEW_MODE_IDS)
    if not chips then
        DRAWING.drawWidgetCenteredValueText(ctx, "Ruler time", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end
    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        is_selected_segment = function(c)
            return self._active_id == c.mode.id
        end,
    })
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

    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        is_selected_segment = function(c)
            return self._active_id == c.mode.id
        end,
    })
end

return widget
