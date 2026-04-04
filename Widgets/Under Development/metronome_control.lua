-- Widgets/Under Development/metronome_control.lua
-- Metronome enable, playback/recording (projmetroen via SWS); click rate via actions 43703, 42456–42458.

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")

local CHIP_GAP = 6
local CHIP_V_PAD = 3
local CHIP_ROUND = 3
local M_PAD_H = 10
local PR_PAD_H = 8
local GROUP_GAP = 8

local CFG_EN = 1
local CFG_PLAY = 2
local CFG_REC = 4
local CFG_LOW_MASK = 7

local SPEEDS = {
    { id = "half", short_label = "0.5", label = "0.5×", cmd = 43703 },
    { id = "one", short_label = "1", label = "1×", cmd = 42456 },
    { id = "two", short_label = "2×", cmd = 42457 },
    { id = "four", short_label = "4×", cmd = 42458 },
}

CHIP_MS.normalize_chip_entries(SPEEDS)

local SUB_METRO = "metro_main"
local SUB_P = "metro_p"
local SUB_R = "metro_r"
local SPD_PREFIX = "metro_spd_"

local widget = {
    name = "Metronome Control",
    category = "Under Development",
    type = "display",
    update_interval = 0.15,
    description = "Metronome on/off, run during playback (P) and recording (R), and click rate (0.5×–4× via actions 43703 / 42456–42458). Right-click opens metronome / pre-roll settings. M/P/R need SWS (SNM); rate uses REAPER actions.",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 220,
    _en = false,
    _play = false,
    _rec = false,
    _rate_id = "one",
}

local function chip_line_height(ctx)
    return reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
end

local function metro_flags()
    local ok, v = pcall(reaper.SNM_GetIntConfigVar, "projmetroen", 0)
    if not ok then
        return 0
    end
    return math.floor((v or 0) + 0.5)
end

local function set_metro_flags(new_val)
    pcall(reaper.SNM_SetIntConfigVar, "projmetroen", new_val)
end

local function merge_low_bits(en, play, rec)
    local v = metro_flags()
    local high = v - (v & CFG_LOW_MASK)
    local low = 0
    if en then
        low = low | CFG_EN
    end
    if play then
        low = low | CFG_PLAY
    end
    if rec then
        low = low | CFG_REC
    end
    set_metro_flags(high | low)
end

local function detect_rate_id_from_actions()
    for _, s in ipairs(SPEEDS) do
        local ok, st = pcall(reaper.GetToggleCommandState, s.cmd)
        if ok and st == 1 then
            return s.id
        end
    end
    return nil
end

local function speed_by_id(id)
    for _, s in ipairs(SPEEDS) do
        if s.id == id then
            return s
        end
    end
    return SPEEDS[2]
end

local function left_block_width(ctx)
    if not ctx or not reaper.ImGui_CalcTextSize then
        return 4 + 44 + CHIP_GAP + 30 + CHIP_GAP + 30
    end
    local _, _, mw = DRAWING.getTextChipMetrics(ctx, "M", M_PAD_H, CHIP_V_PAD)
    local _, _, pw = DRAWING.getTextChipMetrics(ctx, "P", PR_PAD_H, CHIP_V_PAD)
    local _, _, rw = DRAWING.getTextChipMetrics(ctx, "R", PR_PAD_H, CHIP_V_PAD)
    return 4 + mw + CHIP_GAP + pw + CHIP_GAP + rw
end

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 220
    if ctx and reaper.ImGui_GetTextLineHeight then
        local spd = #SPEEDS * 20 + ROW.CHIP_GAP * (#SPEEDS - 1)
        natural = math.max(natural, left_block_width(ctx) + GROUP_GAP + spd + 4)
    end
    return ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    local chip_h = chip_line_height(ctx)
    local _, _, _, mh_m = DRAWING.getTextChipMetrics(ctx, "M", M_PAD_H, CHIP_V_PAD)
    local pad = 4
    local speeds_h = #SPEEDS * chip_h + math.max(0, #SPEEDS - 1) * ROW.CHIP_GAP
    return pad * 2 + mh_m + CHIP_GAP + chip_h + CHIP_GAP + speeds_h
end

function widget.getValue(self)
    local f = metro_flags()
    self._en = (f & CFG_EN) ~= 0
    self._play = (f & CFG_PLAY) ~= 0
    self._rec = (f & CFG_REC) ~= 0
    local rid = detect_rate_id_from_actions()
    if rid then
        self._rate_id = rid
    end
    return 0
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

--- Horizontal layout: [M][P][R] | [speed multiswitch]
local function layout_horizontal(ctx, rel_x, rel_y, render_width, layout)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = chip_line_height(ctx)
    local row_y = rel_y + (h - chip_h) / 2
    local x = rel_x + 4

    local _, _, mw, mh_m = DRAWING.getTextChipMetrics(ctx, "M", M_PAD_H, CHIP_V_PAD)
    local _, _, pw, _ = DRAWING.getTextChipMetrics(ctx, "P", PR_PAD_H, CHIP_V_PAD)
    local _, _, rw, _ = DRAWING.getTextChipMetrics(ctx, "R", PR_PAD_H, CHIP_V_PAD)

    local metro = { x = x, y = rel_y + (h - mh_m) / 2, w = mw, h = mh_m }
    x = x + mw + CHIP_GAP
    local p_rect = { x = x, y = row_y, w = pw, h = chip_h }
    x = x + pw + CHIP_GAP
    local r_rect = { x = x, y = row_y, w = rw, h = chip_h }
    x = x + rw + GROUP_GAP

    local spd_w = math.max(40, rel_x + render_width - x - 4)
    local gap = ROW.CHIP_GAP
    local n = #SPEEDS
    local per_w = math.floor((spd_w - gap * (n - 1)) / n)
    per_w = math.max(18, per_w)
    local speed_chips = {}
    for i, s in ipairs(SPEEDS) do
        speed_chips[#speed_chips + 1] = {
            id = s.id,
            x = x,
            y = row_y,
            w = per_w,
            h = chip_h,
            mode = s,
        }
        x = x + per_w + gap
    end

    return metro, p_rect, r_rect, speed_chips
end

--- Vertical: M full width; P | R; stacked speeds with multiswitch vertical.
local function layout_vertical(ctx, rel_x, rel_y, render_width, layout)
    local pad_x, pad_y = 4, 4
    local chip_h = chip_line_height(ctx)
    local usable = math.max(40, render_width - pad_x * 2)
    local y = rel_y + pad_y

    local _, _, mw, mh_m = DRAWING.getTextChipMetrics(ctx, "M", M_PAD_H, CHIP_V_PAD)
    local metro = { x = rel_x + pad_x, y = y, w = usable, h = mh_m }
    y = y + mh_m + CHIP_GAP

    local half = math.floor((usable - ROW.CHIP_GAP) / 2)
    half = math.max(half, 22)
    local w2 = usable - half - ROW.CHIP_GAP
    local p_rect = { x = rel_x + pad_x, y = y, w = half, h = chip_h }
    local r_rect = { x = rel_x + pad_x + half + ROW.CHIP_GAP, y = y, w = w2, h = chip_h }
    y = y + chip_h + CHIP_GAP

    local speed_chips = {}
    for _, s in ipairs(SPEEDS) do
        speed_chips[#speed_chips + 1] = {
            id = s.id,
            x = rel_x + pad_x,
            y = y,
            w = usable,
            h = chip_h,
            mode = s,
        }
        y = y + chip_h + ROW.CHIP_GAP
    end

    return metro, p_rect, r_rect, speed_chips
end

local function layout_all(ctx, rel_x, rel_y, render_width, layout)
    if layout and layout.is_vertical then
        return layout_vertical(ctx, rel_x, rel_y, render_width, layout)
    end
    return layout_horizontal(ctx, rel_x, rel_y, render_width, layout)
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local metro, p_rect, r_rect, speed_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)
    if coords:pointInRelativeRect(mx, my, metro.x, metro.y, metro.w, metro.h) then
        return SUB_METRO
    end
    if coords:pointInRelativeRect(mx, my, p_rect.x, p_rect.y, p_rect.w, p_rect.h) then
        return SUB_P
    end
    if coords:pointInRelativeRect(mx, my, r_rect.x, r_rect.y, r_rect.w, r_rect.h) then
        return SUB_R
    end
    for _, c in ipairs(speed_chips) do
        if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
            return SPD_PREFIX .. c.id
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == SUB_METRO then
        merge_low_bits(not self._en, self._play, self._rec)
        self._en = not self._en
        return true
    end
    if sub_id == SUB_P then
        merge_low_bits(self._en, not self._play, self._rec)
        self._play = not self._play
        return true
    end
    if sub_id == SUB_R then
        merge_low_bits(self._en, self._play, not self._rec)
        self._rec = not self._rec
        return true
    end
    local sid = sub_id and sub_id:match("^metro_spd_(.+)$")
    if sid then
        local s = speed_by_id(sid)
        if s.cmd then
            reaper.Main_OnCommand(s.cmd, 0)
        end
        self._rate_id = s.id
        return true
    end
    return false
end

function widget.onRightClick(self)
    reaper.Main_OnCommand(40363, 0)
end

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
    self._en = true
    self._play = true
    self._rec = true
    self._rate_id = "two"
    local mx, my = coords:getRelativeMouse()
    local vert = layout and layout.is_vertical
    local metro, p_rect, r_rect, speed_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)

    draw_chip(ctx, coords, draw_list, metro, "M", self._en, false, btn_txt, btn_bg, false)
    draw_chip(ctx, coords, draw_list, p_rect, "P", self._play, false, btn_txt, btn_bg, false)
    draw_chip(ctx, coords, draw_list, r_rect, "R", self._rec, false, btn_txt, btn_bg, false)
    CHIP_MULTISWITCH.draw(ctx, self, speed_chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        vertical = vert,
        slide_namespace = "spd",
        is_selected_segment = function(c)
            return c.mode.id == self._rate_id
        end,
    })
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF

    if self._preview_mode then
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
        return
    end

    local mx, my = coords:getRelativeMouse()
    local metro, p_rect, r_rect, speed_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)
    local vert = layout and layout.is_vertical

    draw_chip(ctx, coords, draw_list, metro, "M", self._en, coords:pointInRelativeRect(mx, my, metro.x, metro.y, metro.w, metro.h), btn_txt, btn_bg, false)
    draw_chip(ctx, coords, draw_list, p_rect, "P", self._play, coords:pointInRelativeRect(mx, my, p_rect.x, p_rect.y, p_rect.w, p_rect.h), btn_txt, btn_bg, false)
    draw_chip(ctx, coords, draw_list, r_rect, "R", self._rec, coords:pointInRelativeRect(mx, my, r_rect.x, r_rect.y, r_rect.w, r_rect.h), btn_txt, btn_bg, false)

    local function label_for_chip(c)
        return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
    end

    CHIP_MULTISWITCH.draw(ctx, self, speed_chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        vertical = vert,
        slide_namespace = "spd",
        label_for = label_for_chip,
        is_selected_segment = function(c)
            return c.mode.id == self._rate_id
        end,
    })
end

return widget
