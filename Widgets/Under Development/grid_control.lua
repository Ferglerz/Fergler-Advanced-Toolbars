-- Widgets/Under Development/grid_control.lua
-- Grid control for Main arrange and active MIDI editor.

local CHIP_GAP = 4
local CHIP_V_PAD = 3
local CHIP_ROUND = 3

-- "Grid: Use the same grid division in arrange view and MIDI editor" (toggle).
local CMD_GRID_SYNC_MIDI_ARRANGE = 42010

local SYNC_LABEL, SYNC_PAD_H, SYNC_PAD_V = "SYNC", 10, 3

local GRID_ITEMS = {
    { id = "1", value = 1.0, main = 40781, midi = 40204 },
    { id = "1/2", value = 0.5, main = 40780, midi = 40203 },
    { id = "1/4", value = 0.25, main = 40779, midi = 40201 },
    { id = "1/8", value = 0.125, main = 40778, midi = 40197 },
    { id = "1/16", value = 0.0625, main = 40776, midi = 40192 },
    { id = "1/32", value = 0.03125, main = 40775, midi = 40190 },
    { id = "1/64", value = 0.015625, main = 40774, midi = 41020 },
}

local widget = {
    name = "Grid Control",
    category = "Under Development",
    update_interval = 0.1,
    type = "display",
    width = 320,
    label = "",
    description = "Set Main or MIDI grid quickly. SYNC: MIDI editor follows arrange grid division (Reaper grid option).",
    chip_widget = true,
    _context = "main",
    _selected_id = "1/4",
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

local function sync_left_allocation_w(ctx)
    if not ctx then
        return 52
    end
    local _, _, cw = DRAWING.getTextChipMetrics(ctx, SYNC_LABEL, SYNC_PAD_H, SYNC_PAD_V)
    return 4 + cw + 8
end

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 320
    if ctx and reaper.ImGui_GetTextLineHeight then
        local min_options = #GRID_ITEMS * 20 + CHIP_GAP * (#GRID_ITEMS - 1)
        local computed = sync_left_allocation_w(ctx) + min_options + 4
        natural = math.max(natural, computed)
    end
    local cap = tonumber(self._preview_width_cap)
    if cap and cap > 0 then
        return math.min(natural, cap)
    end
    return natural
end

local function get_layout(ctx, rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local _, _, sync_w, sync_h = DRAWING.getTextChipMetrics(ctx, SYNC_LABEL, SYNC_PAD_H, SYNC_PAD_V)
    local sync_x = rel_x + 4
    local sync_y = rel_y + (h - sync_h) / 2
    local sync_rect = { x = sync_x, y = sync_y, w = sync_w, h = sync_h }

    local chips = {}
    local options_start = rel_x + sync_left_allocation_w(ctx)
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

    return sync_rect, chips
end

function widget.getValue(self)
    local context, value = detect_context_and_value()
    self._context = context
    self._selected_id = nearest_grid_id(value)
    return value or 0
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local sync_rect, chips = get_layout(ctx, rel_x, rel_y, render_width)

    if coords:pointInRelativeRect(mx, my, sync_rect.x, sync_rect.y, sync_rect.w, sync_rect.h) then
        return "sync"
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
    if sub_id == "sync" then
        reaper.Main_OnCommand(CMD_GRID_SYNC_MIDI_ARRANGE, 0)
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

local PREVIEW_GRID_IDS = { "1/4", "1/8", "1/16" }

--- Preview: grouped grid fractions when width allows.
local function preview_grid_multiswitch_chips(ctx, rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local chips = {}
    for _, gid in ipairs(PREVIEW_GRID_IDS) do
        for _, item in ipairs(GRID_ITEMS) do
            if item.id == gid then
                chips[#chips + 1] = { id = item.id, item = item }
                break
            end
        end
    end
    if #chips < #PREVIEW_GRID_IDS then
        return nil
    end
    local options_start = rel_x + sync_left_allocation_w(ctx)
    local options_w = math.max(30, rel_x + render_width - options_start - 4)
    local count = #chips
    local per_w = math.floor((options_w - CHIP_GAP * (count - 1)) / count)
    per_w = math.max(20, per_w)
    local row_w = count * per_w + CHIP_GAP * (count - 1)
    if row_w > options_w then
        return nil
    end
    local x = options_start
    for _, c in ipairs(chips) do
        c.x = x
        c.y = row_y
        c.w = per_w
        c.h = chip_h
        x = x + per_w + CHIP_GAP
    end
    return chips
end

local function draw_sync_chip(ctx, coords, draw_list, rel_x, rel_y, height, mx, my, btn_txt, btn_bg)
    local _, _, sync_w, sync_h = DRAWING.getTextChipMetrics(ctx, SYNC_LABEL, SYNC_PAD_H, SYNC_PAD_V)
    local sx = rel_x + 4
    local sy = rel_y + (height - sync_h) / 2
    local sync_on = reaper.GetToggleCommandState(CMD_GRID_SYNC_MIDI_ARRANGE) == 1
    local hover = coords:pointInRelativeRect(mx, my, sx, sy, sync_w, sync_h)
    local chip_bg, chip_txt = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = sync_on,
        hover = hover,
    })
    DRAWING.drawTextChip(ctx, coords, draw_list, sx, sy, sync_w, sync_h, SYNC_LABEL, {
        bg_color = chip_bg,
        text_color = chip_txt,
        rounding = CHIP_ROUND,
    })
end

--- Widget browser: SYNC chip + grouped grid row; fallback label if too narrow.
local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local mx, my = coords:getRelativeMouse()

    local grid_chips = preview_grid_multiswitch_chips(ctx, rel_x, rel_y, render_width)
    if not grid_chips then
        DRAWING.drawWidgetCenteredValueText(ctx, "Grid", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end

    draw_sync_chip(ctx, coords, draw_list, rel_x, rel_y, h, mx, my, btn_txt, btn_bg)

    CHIP_MULTISWITCH.draw(ctx, self, grid_chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        label_for = function(c)
            return c.id
        end,
        is_selected_segment = function(c)
            return self._selected_id == c.id
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
    local _, chips = get_layout(ctx, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local height = CONFIG.SIZES.HEIGHT

    draw_sync_chip(ctx, coords, draw_list, rel_x, rel_y, height, mx, my, btn_txt, btn_bg)

    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        label_for = function(c)
            return c.id
        end,
        is_selected_segment = function(c)
            return self._selected_id == c.id
        end,
    })
end

return widget
