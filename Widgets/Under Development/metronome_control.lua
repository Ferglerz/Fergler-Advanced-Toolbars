-- Widgets/Under Development/metronome_control.lua
-- Metronome enable, playback/recording (projmetroen via SWS); click rate via actions 43703, 42456–42458.

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local ICON_FONTS_LIB = require("Utils.icon_fonts")

local CHIP_GAP = 6
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

local PR_MODES = {
    { id = "p", short_label = "P" },
    { id = "r", short_label = "R" },
}
CHIP_MS.normalize_chip_entries(PR_MODES)

local SUB_METRO = "metro_main"
local SUB_P = "metro_p"
local SUB_R = "metro_r"
local SPD_PREFIX = "metro_spd_"

local widget = {
    name = "Metronome Control",
    category = "Under Development",
    type = "display",
    update_interval = 0.15,
    description = "Metronome on/off (music/metronome icon or M fallback), playback/recording (P|R flush multi-toggle), and click rate (0.5×–4× via actions 43703 / 42456–42458). Right-click opens metronome / pre-roll settings. M/P/R need SWS (SNM); rate uses REAPER actions.",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 220,
    _en = false,
    _play = false,
    _rec = false,
    _rate_id = "one",
}

-- Per-icon TTF (glyph U+0021); icon px from ROW.magnet_icon_size — same as FTC adaptive grid snap chip.
local METRO_ICON_PATH = UTILS.normalizeSlashes("IconFonts/icons/Music/Metronome.ttf")
local METRO_ICON_CHAR = utf8.char(ICON_FONTS_LIB.ICON_CODEPOINT)
local METRO_LABEL_FALLBACK = "M"

local _metro_icon_resolved

local function metro_icon_mode()
    if _metro_icon_resolved ~= nil then
        return _metro_icon_resolved
    end
    _metro_icon_resolved = { use_icons = false }
    if not SCRIPT_PATH or SCRIPT_PATH == "" or not C or not C.ButtonContent then
        return _metro_icon_resolved
    end
    local p = UTILS.joinPath(SCRIPT_PATH, "IconFonts", "icons", "music", "metronome.ttf")
    if not reaper.file_exists(p) then
        return _metro_icon_resolved
    end
    local f = C.ButtonContent:loadIconFont(METRO_ICON_PATH)
    if not f then
        return _metro_icon_resolved
    end
    _metro_icon_resolved = { use_icons = true, font = f }
    return _metro_icon_resolved
end

local function metro_chip_metrics(ctx)
    local mode = metro_icon_mode()
    if not mode.use_icons then
        local _, _, cw, ch = DRAWING.getTextChipMetrics(ctx, METRO_LABEL_FALLBACK, M_PAD_H, ROW.CHIP_V_PAD)
        return cw, ch
    end
    local icon_sz = ROW.magnet_icon_size(ctx)
    reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
    local w = reaper.ImGui_CalcTextSize(ctx, METRO_ICON_CHAR)
    reaper.ImGui_PopFont(ctx)
    w = math.max(w, icon_sz * 0.65)
    return w + M_PAD_H * 2, ROW.chip_line_height(ctx)
end

local function draw_metro_chip(ctx, coords, draw_list, chip, is_active, is_hover, btn_txt, btn_bg, disabled)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
        disabled = disabled,
    })
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROUND)

    local mode = metro_icon_mode()
    if not mode.use_icons then
        local tw = reaper.ImGui_CalcTextSize(ctx, METRO_LABEL_FALLBACK)
        local tx = chip.x + (chip.w - tw) / 2
        local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, METRO_LABEL_FALLBACK)
        return
    end
    local icon_sz = ROW.magnet_icon_size(ctx)
    reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
    local text_w = reaper.ImGui_CalcTextSize(ctx, METRO_ICON_CHAR)
    reaper.ImGui_PopFont(ctx)
    text_w = math.max(text_w, icon_sz * 0.65)
    local text_rel_x = chip.x + (chip.w - text_w) / 2
    local text_rel_y = chip.y + chip.h / 2 - icon_sz / 4
    reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
    local tx, ty = coords:relativeToDrawList(text_rel_x, text_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_col, METRO_ICON_CHAR)
    reaper.ImGui_PopFont(ctx)
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
    local R = ROW.button_rounding_content_pad()
    if not ctx or not reaper.ImGui_CalcTextSize then
        return 4 + R + 44 + CHIP_GAP + 30 + CHIP_GAP + 30
    end
    local mw = select(1, metro_chip_metrics(ctx))
    local _, _, pw = DRAWING.getTextChipMetrics(ctx, "P", PR_PAD_H, ROW.CHIP_V_PAD)
    local _, _, rw = DRAWING.getTextChipMetrics(ctx, "R", PR_PAD_H, ROW.CHIP_V_PAD)
    return 4 + R + mw + CHIP_GAP + pw + rw
end

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 220
    if ctx and reaper.ImGui_GetTextLineHeight then
        local R = ROW.button_rounding_content_pad()
        local spd = #SPEEDS * 20 + ROW.CHIP_GAP * (#SPEEDS - 1)
        natural = math.max(natural, left_block_width(ctx) + GROUP_GAP + spd + 4 + R)
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
    local chip_h = ROW.chip_line_height(ctx)
    local mh_m = select(2, metro_chip_metrics(ctx))
    local pad = 4 + ROW.button_rounding_content_pad()
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

--- Horizontal layout: [M][P][R] | [speed multiswitch]
local function layout_horizontal(ctx, rel_x, rel_y, render_width, layout)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = ROW.chip_line_height(ctx)
    local row_y = rel_y + (h - chip_h) / 2
    local R = ROW.button_rounding_content_pad()
    local x = rel_x + 4 + R

    local mw, mh_m = metro_chip_metrics(ctx)
    local _, _, pw, _ = DRAWING.getTextChipMetrics(ctx, "P", PR_PAD_H, ROW.CHIP_V_PAD)
    local _, _, rw, _ = DRAWING.getTextChipMetrics(ctx, "R", PR_PAD_H, ROW.CHIP_V_PAD)

    local metro = { x = x, y = rel_y + (h - mh_m) / 2, w = mw, h = mh_m }
    x = x + mw + CHIP_GAP
    local pr_chips = {
        {
            id = "p",
            x = x,
            y = row_y,
            w = pw,
            h = chip_h,
            mode = PR_MODES[1],
        },
        {
            id = "r",
            x = x + pw,
            y = row_y,
            w = rw,
            h = chip_h,
            mode = PR_MODES[2],
        },
    }
    x = x + pw + rw + GROUP_GAP

    local spd_w = math.max(40, rel_x + render_width - x - 4 - R)
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

    return metro, pr_chips, speed_chips
end

--- Vertical: M full width; P|R multi-toggle (flush); stacked speeds with multiswitch vertical.
local function layout_vertical(ctx, rel_x, rel_y, render_width, layout)
    local R = ROW.button_rounding_content_pad()
    local pad_x, pad_y = 4 + R, 4 + R
    local chip_h = ROW.chip_line_height(ctx)
    local usable = math.max(40, render_width - pad_x * 2)
    local y = rel_y + pad_y

    local _, mh_m = metro_chip_metrics(ctx)
    local metro = { x = rel_x + pad_x, y = y, w = usable, h = mh_m }
    y = y + mh_m + CHIP_GAP

    local _, _, pw, _ = DRAWING.getTextChipMetrics(ctx, "P", PR_PAD_H, ROW.CHIP_V_PAD)
    local _, _, rw, _ = DRAWING.getTextChipMetrics(ctx, "R", PR_PAD_H, ROW.CHIP_V_PAD)
    local px = rel_x + pad_x
    local pr_chips = {
        {
            id = "p",
            x = px,
            y = y,
            w = pw,
            h = chip_h,
            mode = PR_MODES[1],
        },
        {
            id = "r",
            x = px + pw,
            y = y,
            w = rw,
            h = chip_h,
            mode = PR_MODES[2],
        },
    }
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

    return metro, pr_chips, speed_chips
end

local function layout_all(ctx, rel_x, rel_y, render_width, layout)
    if layout and layout.is_vertical then
        return layout_vertical(ctx, rel_x, rel_y, render_width, layout)
    end
    return layout_horizontal(ctx, rel_x, rel_y, render_width, layout)
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local metro, pr_chips, speed_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)
    if coords:pointInRelativeRect(mx, my, metro.x, metro.y, metro.w, metro.h) then
        return SUB_METRO
    end
    for _, c in ipairs(pr_chips) do
        if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
            return c.mode.id == "p" and SUB_P or SUB_R
        end
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

local function draw_pr_multi_toggle(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg, mx, my)
    CHIP_MS.draw(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        multi_toggle = true,
        slide_namespace = "metro_pr",
        is_selected_segment = function(c)
            if c.mode.id == "p" then
                return self._play
            end
            if c.mode.id == "r" then
                return self._rec
            end
            return false
        end,
    })
end

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
    self._en = true
    self._play = true
    self._rec = true
    self._rate_id = "two"
    local mx, my = coords:getRelativeMouse()
    local vert = layout and layout.is_vertical
    local metro, pr_chips, speed_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)

    draw_metro_chip(ctx, coords, draw_list, metro, self._en, false, btn_txt, btn_bg, false)
    draw_pr_multi_toggle(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg, mx, my)
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
    local metro, pr_chips, speed_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)
    local vert = layout and layout.is_vertical

    draw_metro_chip(ctx, coords, draw_list, metro, self._en, coords:pointInRelativeRect(mx, my, metro.x, metro.y, metro.w, metro.h), btn_txt, btn_bg, false)
    draw_pr_multi_toggle(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg, mx, my)

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
