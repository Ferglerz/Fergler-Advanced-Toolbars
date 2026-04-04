-- Widgets/Under Development/screensets_widget.lua
-- Save/load 4 track-view screensets with named 2x2 slots.

local CHIP_ROW = require("Renderers._Widgets_chip_row")

local MODE_W = 50
local GAP = 4
local ROUND = 3

local EXT_SECTION = "ATB_ScreensetsWidget"

local widget = {
    name = "Screensets",
    category = "Under Development",
    update_interval = 0.5,
    type = "display",
    width = 255,
    label = "",
    description = "Load/save 4 named track-view screensets in a 2x2 grid. Right-click slot to rename.",
    chip_widget = true,
    _mode = "load",
    _names = { "Set 1", "Set 2", "Set 3", "Set 4" },
    _last_slot_hit = nil,
}

local function slot_key(slot)
    return "name_" .. tostring(slot)
end

local function load_slot_name(slot)
    local ok, value = reaper.GetProjExtState(0, EXT_SECTION, slot_key(slot))
    if ok == 1 and value and value ~= "" then
        return value
    end
    return "Set " .. tostring(slot)
end

local function save_slot_name(slot, value)
    reaper.SetProjExtState(0, EXT_SECTION, slot_key(slot), value or "")
end

local function draw_rect(draw_list, coords, x, y, w, h, color, r)
    r = r or ROUND
    local x1, y1 = coords:relativeToDrawList(x, y)
    local x2, y2 = coords:relativeToDrawList(x + w, y + h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color, r)
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

local function get_layout(rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local R = CHIP_ROW.button_rounding_content_pad()
    local inner_y = rel_y + 4 + R
    local inner_h = math.max(12, h - 8 - R * 2)

    local mode_load = {
        id = "mode_load",
        x = rel_x + 4 + R,
        y = inner_y,
        w = MODE_W,
        h = math.floor((inner_h - GAP) / 2),
    }
    local mode_save = {
        id = "mode_save",
        x = mode_load.x,
        y = mode_load.y + mode_load.h + GAP,
        w = MODE_W,
        h = inner_h - mode_load.h - GAP,
    }

    local grid_x = mode_load.x + MODE_W + 8
    local grid_w = math.max(20, rel_x + render_width - grid_x - 4 - R)
    local cell_w = math.floor((grid_w - GAP) / 2)
    local cell_h = math.floor((inner_h - GAP) / 2)

    local slots = {
        { id = "slot_1", slot = 1, x = grid_x, y = inner_y, w = cell_w, h = cell_h },
        { id = "slot_2", slot = 2, x = grid_x + cell_w + GAP, y = inner_y, w = cell_w, h = cell_h },
        { id = "slot_3", slot = 3, x = grid_x, y = inner_y + cell_h + GAP, w = cell_w, h = cell_h },
        { id = "slot_4", slot = 4, x = grid_x + cell_w + GAP, y = inner_y + cell_h + GAP, w = cell_w, h = cell_h },
    }

    return mode_load, mode_save, slots
end

local function execute_slot(mode, slot)
    if slot < 1 or slot > 4 then
        return
    end
    if mode == "save" then
        reaper.Main_OnCommand(40463 + slot, 0)
    else
        reaper.Main_OnCommand(40443 + slot, 0)
    end
end

function widget.getValue(self)
    for slot = 1, 4 do
        self._names[slot] = load_slot_name(slot)
    end
    return 0
end

function widget.hitTestSubcontrols(self, _ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local mode_load, mode_save, slots = get_layout(rel_x, rel_y, render_width)

    self._last_slot_hit = nil

    if coords:pointInRelativeRect(mx, my, mode_load.x, mode_load.y, mode_load.w, mode_load.h) then
        return "mode_load"
    end
    if coords:pointInRelativeRect(mx, my, mode_save.x, mode_save.y, mode_save.w, mode_save.h) then
        return "mode_save"
    end

    for _, cell in ipairs(slots) do
        if coords:pointInRelativeRect(mx, my, cell.x, cell.y, cell.w, cell.h) then
            self._last_slot_hit = cell.slot
            return cell.id
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "mode_load" then
        self._mode = "load"
        return true
    end
    if sub_id == "mode_save" then
        self._mode = "save"
        return true
    end
    local slot = sub_id and tonumber(sub_id:match("^slot_(%d)$"))
    if slot then
        execute_slot(self._mode, slot)
        return true
    end
    return false
end

function widget.onRightClick(self)
    local slot = self._last_slot_hit
    if not slot then
        return
    end
    local current = self._names[slot] or ("Set " .. tostring(slot))
    local ok, out = reaper.GetUserInputs("Rename Screenset Slot", 1, "Name for slot " .. tostring(slot) .. ":", current)
    if not ok then
        return
    end
    out = (out or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if out == "" then
        out = "Set " .. tostring(slot)
    end
    self._names[slot] = out
    save_slot_name(slot, out)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    local mx, my = coords:getRelativeMouse()
    local mode_load, mode_save, slots = get_layout(rel_x, rel_y, render_width)

    local function draw_mode(chip, text, active)
        local hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local bg_col, txt_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
            active = active,
            hover = hover and not active,
        })
        draw_rect(draw_list, coords, chip.x, chip.y, chip.w, chip.h, bg_col, ROUND)
        local tw = reaper.ImGui_CalcTextSize(ctx, text)
        local tx = chip.x + (chip.w - tw) / 2
        local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, txt_col, text)
    end

    draw_mode(mode_load, "Load", self._mode == "load")
    draw_mode(mode_save, "Save", self._mode == "save")

    for _, cell in ipairs(slots) do
        local hover = coords:pointInRelativeRect(mx, my, cell.x, cell.y, cell.w, cell.h)
        local bg_col, txt_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
            active = false,
            hover = hover,
        })
        draw_rect(draw_list, coords, cell.x, cell.y, cell.w, cell.h, bg_col, ROUND)

        local name = self._names[cell.slot] or ("Set " .. tostring(cell.slot))
        local display = trim_to_width(ctx, name, math.max(8, cell.w - 8))
        local tw = reaper.ImGui_CalcTextSize(ctx, display)
        local tx = cell.x + (cell.w - tw) / 2
        local ty = cell.y + (cell.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, txt_col, display)
    end
end

return widget
