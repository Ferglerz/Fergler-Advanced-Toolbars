-- widgets/grid_control.lua
-- Grid control for Main arrange and active MIDI editor.

local CHIP_GAP = 4
local MODE_CHIP_W = 18
local CHIP_H_PAD = 5
local CHIP_V_PAD = 3
local CHIP_ROUND = 3
local BG_IDLE = 0x131313FF
local BG_ACTIVE = 0x2E70B8FF
local BG_HOVER = 0x232323FF
local TEXT_IDLE = 0xD9D9D9FF
local TEXT_ACTIVE = 0xFFFFFFFF
local TEXT_DISABLED = 0x7A7A7AFF

local GRID_ITEMS = {
    { id = "1", value = 1.0, main = 40781, midi = 40204 },
    { id = "1/2", value = 0.5, main = 40780, midi = 40203, midi_preserve = 41014 },
    { id = "1/4", value = 0.25, main = 40779, midi = 40201, midi_preserve = 41013 },
    { id = "1/8", value = 0.125, main = 40778, midi = 40197, midi_preserve = 41012 },
    { id = "1/16", value = 0.0625, main = 40776, midi = 40192, midi_preserve = 41011 },
    { id = "1/32", value = 0.03125, main = 40775, midi = 40190, midi_preserve = 41010 },
    { id = "1/64", value = 0.015625, main = 40774, midi = 41020, midi_preserve = 41009 },
}

local widget = {
    name = "Grid Control",
    update_interval = 0.1,
    type = "display",
    width = 320,
    label = "",
    description = "Set Main or MIDI grid quickly. N = normal, P = preserve grid type (MIDI).",
    _context = "main",
    _selected_id = "1/4",
    _use_preserve = false,
}

local function active_midi_editor()
    local me = reaper.MIDIEditor_GetActive()
    if not me then
        return nil, nil
    end
    local take = reaper.MIDIEditor_GetTake(me)
    if not take then
        return nil, nil
    end
    return me, take
end

local function detect_context_and_value()
    local me, take = active_midi_editor()
    if me and take then
        local grid = reaper.MIDI_GetGrid(take)
        if grid and grid > 0 then
            return "midi", grid
        end
    end
    local _, grid = reaper.GetSetProjectGrid(0, false)
    if not grid or grid <= 0 then
        grid = 0.25
    end
    return "main", grid
end

local function nearest_grid_id(value)
    local best_id = GRID_ITEMS[1].id
    local best_diff = math.huge
    for _, item in ipairs(GRID_ITEMS) do
        local d = math.abs((value or 0.25) - item.value)
        if d < best_diff then
            best_diff = d
            best_id = item.id
        end
    end
    return best_id
end

local function text_chip_width(ctx, text)
    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    return tw + CHIP_H_PAD * 2
end

local function get_layout(ctx, rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2

    local mode_n = {
        id = "mode_n",
        x = rel_x + 4,
        y = row_y,
        w = MODE_CHIP_W,
        h = chip_h,
    }
    local mode_p = {
        id = "mode_p",
        x = mode_n.x + mode_n.w + CHIP_GAP,
        y = row_y,
        w = MODE_CHIP_W,
        h = chip_h,
    }

    local chips = {}
    local options_start = mode_p.x + mode_p.w + 8
    local options_w = math.max(30, rel_x + render_width - options_start - 4)
    local count = #GRID_ITEMS
    local per_w = math.floor((options_w - CHIP_GAP * (count - 1)) / count)
    per_w = math.max(20, per_w)
    local x = options_start
    for _, item in ipairs(GRID_ITEMS) do
        chips[#chips + 1] = {
            id = item.id,
            x = x,
            y = row_y,
            w = per_w,
            h = chip_h,
            item = item,
        }
        x = x + per_w + CHIP_GAP
    end

    return mode_n, mode_p, chips
end

function widget.getValue(self)
    local context, value = detect_context_and_value()
    self._context = context
    self._selected_id = nearest_grid_id(value)
    return value or 0
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local mode_n, mode_p, chips = get_layout(ctx, rel_x, rel_y, render_width)

    if coords:pointInRelativeRect(mx, my, mode_n.x, mode_n.y, mode_n.w, mode_n.h) then
        return "mode_n"
    end
    if coords:pointInRelativeRect(mx, my, mode_p.x, mode_p.y, mode_p.w, mode_p.h) then
        return "mode_p"
    end

    for _, chip in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            return "grid_" .. chip.id
        end
    end
    return nil
end

local function run_grid_command(self, item)
    if not item then
        return
    end

    local context = self._context or "main"
    if context == "midi" then
        local me = reaper.MIDIEditor_GetActive()
        if not me then
            return
        end
        local cmd = item.midi
        if self._use_preserve and item.midi_preserve then
            cmd = item.midi_preserve
        end
        if cmd then
            reaper.MIDIEditor_OnCommand(me, cmd)
        end
        return
    end

    if item.main then
        reaper.Main_OnCommand(item.main, 0)
    end
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "mode_n" then
        self._use_preserve = false
        return true
    end
    if sub_id == "mode_p" then
        self._use_preserve = true
        return true
    end

    local id = sub_id and sub_id:match("^grid_(.+)$")
    if not id then
        return false
    end
    for _, item in ipairs(GRID_ITEMS) do
        if item.id == id then
            run_grid_command(self, item)
            self._selected_id = item.id
            return true
        end
    end
    return false
end

local function draw_chip(ctx, coords, draw_list, chip, text, is_active, is_hover, text_col, bg_col)
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROUND)

    if is_hover and not is_active then
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, BG_HOVER, CHIP_ROUND)
    end

    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, text)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color)
    local mode_n, mode_p, chips = get_layout(ctx, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local is_midi = (self._context == "midi")

    local mode_n_active = not self._use_preserve
    local mode_p_active = self._use_preserve
    local mode_p_text = is_midi and "P" or "P"

    draw_chip(
        ctx, coords, draw_list, mode_n, "N", mode_n_active,
        coords:pointInRelativeRect(mx, my, mode_n.x, mode_n.y, mode_n.w, mode_n.h),
        mode_n_active and TEXT_ACTIVE or TEXT_IDLE,
        mode_n_active and BG_ACTIVE or BG_IDLE
    )
    draw_chip(
        ctx, coords, draw_list, mode_p, mode_p_text, mode_p_active,
        coords:pointInRelativeRect(mx, my, mode_p.x, mode_p.y, mode_p.w, mode_p.h),
        (not is_midi and not mode_p_active) and TEXT_DISABLED or (mode_p_active and TEXT_ACTIVE or TEXT_IDLE),
        mode_p_active and BG_ACTIVE or BG_IDLE
    )

    for _, chip in ipairs(chips) do
        local is_active = (self._selected_id == chip.id)
        local is_hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        draw_chip(
            ctx,
            coords,
            draw_list,
            chip,
            chip.id,
            is_active,
            is_hover,
            is_active and TEXT_ACTIVE or TEXT_IDLE,
            is_active and BG_ACTIVE or BG_IDLE
        )
    end

    local context_label = is_midi and "MIDI" or "MAIN"
    local hint = self._use_preserve and (is_midi and "Preserve" or "Normal") or "Normal"
    local footer = context_label .. " · " .. hint
    local footer_w = reaper.ImGui_CalcTextSize(ctx, footer)
    local fx = rel_x + render_width - footer_w - 4
    local fy = rel_y + 1
    local dx, dy = coords:relativeToDrawList(fx, fy)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, 0xAAAAAAFF, footer)
end

return widget
