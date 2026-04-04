-- Widgets/Under Development/lock_settings.lua
-- Project lock settings: master Options: Toggle locking (1135) plus per-mode toggles (Main section IDs from REAPER 5.94x list).
-- Horizontal toolbar: Lock + one flush multi-toggle row. Vertical toolbar: Lock row then one multi-toggle row per group.

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")

local PAD_Y = 2
local ROW_GAP = 4
local CHIP_ROUND = ROW.CHIP_ROUND
local TOGGLE_PAD_H = 10
local TOGGLE_LABEL = "Lock"
local LOCK_TRACK_GAP = 4
local SEG_PAD_H = 4

local CMD_MASTER = 1135

local TIME_LOOP = {
    { id = "time", short_label = "Time", label = "Time selection", cmd = 40573 },
    { id = "loop", short_label = "Loop", label = "Loop points", cmd = 40629 },
}

local ITEMS = {
    { id = "item_full", short_label = "Full", label = "Items (full)", cmd = 40576 },
    { id = "item_lr", short_label = "L/R", label = "Items (prevent left/right movement)", cmd = 40579 },
    { id = "item_ud", short_label = "U/D", label = "Items (prevent up/down movement)", cmd = 40582 },
    { id = "item_edge", short_label = "Edge", label = "Item edges", cmd = 40597 },
    { id = "item_fade", short_label = "Fade", label = "Item fade/volume handles", cmd = 40600 },
    { id = "item_stretch", short_label = "Str", label = "Item stretch markers", cmd = 41854 },
}

local ENVS = {
    { id = "take_env", short_label = "Take", label = "Take envelopes", cmd = 41851 },
    { id = "track_env", short_label = "Trk", label = "Track envelopes", cmd = 40585 },
}

local MARKS = {
    { id = "region", short_label = "Rgn", label = "Regions", cmd = 40588 },
    { id = "marker", short_label = "Mrk", label = "Markers", cmd = 40591 },
    { id = "tsig", short_label = "Tsig", label = "Time signature markers", cmd = 40594 },
}

CHIP_MS.normalize_chip_entries(TIME_LOOP)
CHIP_MS.normalize_chip_entries(ITEMS)
CHIP_MS.normalize_chip_entries(ENVS)
CHIP_MS.normalize_chip_entries(MARKS)

local ALL_ORDER = {}
for _, e in ipairs(TIME_LOOP) do
    ALL_ORDER[#ALL_ORDER + 1] = e
end
for _, e in ipairs(ITEMS) do
    ALL_ORDER[#ALL_ORDER + 1] = e
end
for _, e in ipairs(ENVS) do
    ALL_ORDER[#ALL_ORDER + 1] = e
end
for _, e in ipairs(MARKS) do
    ALL_ORDER[#ALL_ORDER + 1] = e
end

local ROW_GROUPS = { TIME_LOOP, ITEMS, ENVS, MARKS }

local PREFIX = "lock_"
local SUB_MASTER = "lock_m"

local widget = {
    name = "Lock Settings",
    category = "Under Development",
    type = "display",
    update_interval = 0,
    width = 360,
    label = "",
    description = "Enable locking (Main:1135) and toggle lock modes in one horizontal row, or stacked rows on a vertical toolbar. Uses Main toggle actions 40573–41854 (multi-toggle track, minimum segment width).",
    chip_widget = true,
    suppress_tooltip = true,
}

local function row_line_height(ctx)
    return ROW.chip_line_height(ctx)
end

local function chip_width_for_entry(ctx, e)
    local cap = CHIP_MS.chip_caption(e)
    return math.ceil(reaper.ImGui_CalcTextSize(ctx, cap)) + SEG_PAD_H * 2
end

local function toggle_on(cmd)
    local ok, st = pcall(reaper.GetToggleCommandState, cmd)
    return ok and st == 1
end

--- Flush horizontal segments for `entries` at row_top_y; chip gap zero.
local function layout_flush_row(ctx, rel_x, row_top_y, entries)
    local chip_h = row_line_height(ctx)
    local pad_x = 4 + ROW.button_rounding_content_pad()
    local x = rel_x + pad_x
    local chips = {}
    for _, e in ipairs(entries) do
        local w = chip_width_for_entry(ctx, e)
        chips[#chips + 1] = {
            id = e.id,
            x = x,
            y = row_top_y,
            w = w,
            h = chip_h,
            mode = e,
        }
        x = x + w
    end
    return chips, x
end

function widget.getLayoutWidth(self, ctx)
    if not ctx or not reaper.ImGui_CalcTextSize then
        return self.width or 360
    end
    local toggle_w = reaper.ImGui_CalcTextSize(ctx, TOGGLE_LABEL) + TOGGLE_PAD_H * 2
    toggle_w = math.max(toggle_w, 36)
    local sum_mt = 0
    for _, e in ipairs(ALL_ORDER) do
        sum_mt = sum_mt + chip_width_for_entry(ctx, e)
    end
    local R = ROW.button_rounding_content_pad()
    local natural = 4 + R + toggle_w + LOCK_TRACK_GAP + sum_mt + 4 + R
    return ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    local lh = row_line_height(ctx)
    local R = ROW.button_rounding_content_pad()
    if is_vertical_toolbar then
        return (PAD_Y + R) * 2 + lh * 5 + ROW_GAP * 4
    end
    return (PAD_Y + R) * 2 + lh
end

function widget.getValue(self)
    self._master_on = toggle_on(CMD_MASTER)
    self._on = {}
    for _, e in ipairs(ALL_ORDER) do
        self._on[e.id] = toggle_on(e.cmd)
    end
    return 0
end

function widget.layout_geometry(self, ctx, rel_x, rel_y, render_width, layout)
    local chip_h = row_line_height(ctx)
    local R = ROW.button_rounding_content_pad()
    local y = rel_y + PAD_Y + R
    local pad_x = 4 + R
    local toggle_w = reaper.ImGui_CalcTextSize(ctx, TOGGLE_LABEL) + TOGGLE_PAD_H * 2
    toggle_w = math.max(toggle_w, 36)
    local vert = layout and layout.is_vertical

    if vert then
        local usable = math.max(40, render_width - pad_x * 2)
        self._toggle_rect = {
            x = rel_x + pad_x,
            y = y,
            w = usable,
            h = chip_h,
        }
        y = y + chip_h + ROW_GAP
        self._chips_all = nil
        self._row_chips = {}
        for _, group in ipairs(ROW_GROUPS) do
            local chips, _right = layout_flush_row(ctx, rel_x, y, group)
            self._row_chips[#self._row_chips + 1] = chips
            y = y + chip_h + ROW_GAP
        end
        return
    end

    self._row_chips = nil
    local toggle = {
        x = rel_x + pad_x,
        y = y,
        w = toggle_w,
        h = chip_h,
    }
    self._toggle_rect = toggle
    local x0 = toggle.x + toggle.w + LOCK_TRACK_GAP
    local chips = {}
    local x = x0
    for _, e in ipairs(ALL_ORDER) do
        local w = chip_width_for_entry(ctx, e)
        chips[#chips + 1] = {
            id = e.id,
            x = x,
            y = y,
            w = w,
            h = chip_h,
            mode = e,
        }
        x = x + w
    end
    self._chips_all = chips
end

local function hit_chips(mx, my, coords, chips)
    if not chips then
        return nil
    end
    for _, chip in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            return PREFIX .. chip.mode.id
        end
    end
    return nil
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    self:layout_geometry(ctx, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local t = self._toggle_rect
    if t and coords:pointInRelativeRect(mx, my, t.x, t.y, t.w, t.h) then
        return SUB_MASTER
    end
    if self._chips_all then
        return hit_chips(mx, my, coords, self._chips_all)
    end
    for _, row in ipairs(self._row_chips or {}) do
        local hit = hit_chips(mx, my, coords, row)
        if hit then
            return hit
        end
    end
    return nil
end

local function find_cmd(id)
    for _, e in ipairs(ALL_ORDER) do
        if e.id == id then
            return e.cmd
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == SUB_MASTER then
        reaper.Main_OnCommand(CMD_MASTER, 0)
        return true
    end
    local id = sub_id and sub_id:match("^lock_(.+)$")
    if not id then
        return false
    end
    local cmd = find_cmd(id)
    if cmd and cmd > 0 then
        reaper.Main_OnCommand(cmd, 0)
        return true
    end
    return false
end

local function draw_toggle_chip(ctx, coords, draw_list, chip, text, is_active, is_hover, btn_txt, btn_bg)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
        disabled = false,
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

local function draw_multi_toggle_row(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, slide_ns)
    if not chips or #chips == 0 then
        return
    end
    local mx, my = coords:getRelativeMouse()
    CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        multi_toggle = true,
        slide_namespace = slide_ns,
        is_selected_segment = function(c)
            return self._on[c.mode.id] == true
        end,
    })
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    if self._preview_mode then
        self._master_on = true
        self._on = {
            time = true,
            loop = false,
            item_full = false,
            item_lr = true,
            item_ud = false,
            item_edge = false,
            item_fade = true,
            item_stretch = false,
            take_env = false,
            track_env = true,
            region = false,
            marker = true,
            tsig = false,
        }
    end
    self:layout_geometry(ctx, rel_x, rel_y, render_width, layout)

    local mx, my = coords:getRelativeMouse()
    local t = self._toggle_rect
    if t then
        local hov = coords:pointInRelativeRect(mx, my, t.x, t.y, t.w, t.h)
        draw_toggle_chip(ctx, coords, draw_list, t, TOGGLE_LABEL, self._master_on, hov, btn_txt, btn_bg)
    end

    if self._chips_all then
        draw_multi_toggle_row(ctx, self, self._chips_all, coords, draw_list, btn_txt, btn_bg, "lock_all")
        return
    end
    local ns = 1
    for _, row in ipairs(self._row_chips or {}) do
        draw_multi_toggle_row(ctx, self, row, coords, draw_list, btn_txt, btn_bg, "lock_r" .. tostring(ns))
        ns = ns + 1
    end
end

return widget
