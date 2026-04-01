-- Widgets/Under Development/grid_control.lua
-- Grid control for Main arrange and active MIDI editor.

local CHIP_GAP = 4
local MODE_CHIP_W = 18
local CHIP_V_PAD = 3
local CHIP_ROUND = 3

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
    category = "Under Development",
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

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 320
    if ctx and reaper.ImGui_GetTextLineHeight then
        local mode_w = MODE_CHIP_W + CHIP_GAP + MODE_CHIP_W
        local min_options = #GRID_ITEMS * 20 + CHIP_GAP * (#GRID_ITEMS - 1)
        local computed = 4 + mode_w + 8 + min_options + 4
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

local function draw_chip(ctx, coords, draw_list, chip, text, is_active, is_hover, btn_txt, btn_bg, disabled)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
        disabled = disabled,
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

--- Widget browser tiles: N/P + selected grid chip; fallback label if too narrow.
local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
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
    local sel = self._selected_id or "1/4"
    local tw = reaper.ImGui_CalcTextSize(ctx, sel)
    local gw = math.max(28, tw + 8)
    local need = mode_p.x + mode_p.w + CHIP_GAP + gw - rel_x + 4
    if need > render_width - 4 then
        DRAWING.drawWidgetCenteredValueText(ctx, "Grid", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end
    local gx = rel_x + render_width - gw - 4
    if gx < mode_p.x + mode_p.w + CHIP_GAP then
        gx = mode_p.x + mode_p.w + CHIP_GAP
    end
    if gx + gw > rel_x + render_width - 4 then
        DRAWING.drawWidgetCenteredValueText(ctx, "Grid", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end
    local sel_chip = {
        id = sel,
        x = gx,
        y = row_y,
        w = gw,
        h = chip_h,
    }
    local mx, my = coords:getRelativeMouse()
    local mode_n_active = not self._use_preserve
    local mode_p_active = self._use_preserve
    local is_midi = (self._context == "midi")
    draw_chip(
        ctx,
        coords,
        draw_list,
        mode_n,
        "N",
        mode_n_active,
        coords:pointInRelativeRect(mx, my, mode_n.x, mode_n.y, mode_n.w, mode_n.h),
        btn_txt,
        btn_bg,
        false
    )
    draw_chip(
        ctx,
        coords,
        draw_list,
        mode_p,
        "P",
        mode_p_active,
        coords:pointInRelativeRect(mx, my, mode_p.x, mode_p.y, mode_p.w, mode_p.h),
        btn_txt,
        btn_bg,
        not is_midi and not mode_p_active
    )
    local is_active = true
    local is_hover = coords:pointInRelativeRect(mx, my, sel_chip.x, sel_chip.y, sel_chip.w, sel_chip.h)
    draw_chip(ctx, coords, draw_list, sel_chip, sel, is_active, is_hover, btn_txt, btn_bg, false)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    if self._preview_mode then
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        return
    end
    local mode_n, mode_p, chips = get_layout(ctx, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local is_midi = (self._context == "midi")

    local mode_n_active = not self._use_preserve
    local mode_p_active = self._use_preserve

    draw_chip(
        ctx,
        coords,
        draw_list,
        mode_n,
        "N",
        mode_n_active,
        coords:pointInRelativeRect(mx, my, mode_n.x, mode_n.y, mode_n.w, mode_n.h),
        btn_txt,
        btn_bg,
        false
    )
    draw_chip(
        ctx,
        coords,
        draw_list,
        mode_p,
        "P",
        mode_p_active,
        coords:pointInRelativeRect(mx, my, mode_p.x, mode_p.y, mode_p.w, mode_p.h),
        btn_txt,
        btn_bg,
        not is_midi and not mode_p_active
    )

    for _, chip in ipairs(chips) do
        local is_active = (self._selected_id == chip.id)
        local is_hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        draw_chip(ctx, coords, draw_list, chip, chip.id, is_active, is_hover, btn_txt, btn_bg, false)
    end

    local context_label = is_midi and "MIDI" or "MAIN"
    local hint = self._use_preserve and (is_midi and "Preserve" or "Normal") or "Normal"
    local footer = context_label .. " · " .. hint
    local footer_w = reaper.ImGui_CalcTextSize(ctx, footer)
    local fx = rel_x + render_width - footer_w - 4
    local fy = rel_y + 1
    local dx, dy = coords:relativeToDrawList(fx, fy)
    local dim = btn_txt & 0xFFFFFF00 | 0xAA
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, dim, footer)
end

return widget
