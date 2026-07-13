-- Widgets/metronome_control.lua
-- Metronome enable, playback/recording (projmetroen via SWS); click rate via actions 43703, 42456–42458.

local WIDGET = require("Utils.Widget.widget_factory")
local SLIDE_HOST = require("Utils.Widget.slide_out_chip_host")

local ROW = WIDGET.CHIP_ROW
local CHIP_GAP = ROW.TOOLBAR_STACK_GAP
local CHIP_ROUND = 3
local GROUP_GAP = 8

local PR_LAYOUT_OPTS = { chip_pad_h = 6, sizing = "fill" }
local SPEED_LAYOUT_OPTS = { pad_x = 4, chip_pad_h = 6, sizing = "fill" }
local SPD_PREFIX = "metro_spd_"

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

WIDGET.CHIP_MS.normalize_chip_entries(SPEEDS)

local speed_slide = WIDGET.CHIP_MODE.bind_slide_out({
    modes = SPEEDS,
    prefix = SPD_PREFIX,
    layout_opts = SPEED_LAYOUT_OPTS,
    chip_round = CHIP_ROUND,
    slide_namespace = "spd",
    set_active_on_apply = false,
    is_selected = function(self, mode)
        return mode.id == self._rate_id
    end,
    on_click_id = function(self, id, mode)
        if mode.cmd then
            reaper.Main_OnCommand(mode.cmd, 0)
        end
        self._rate_id = id
    end,
})

local PR_MODES = {
    { id = "p", short_label = "P" },
    { id = "r", short_label = "R" },
}
WIDGET.CHIP_MS.normalize_chip_entries(PR_MODES)

local SUB_METRO = "metro_main"
local SUB_P = "metro_p"
local SUB_R = "metro_r"

local widget = {
    name = "Metronome",
    category = "Time, grid & tempo",
    type = "display",
    update_interval = 0.15,
    description = "Metronome on/off (music/metronome icon or M fallback), playback/recording (P|R flush multi-toggle), and click rate (0.5×–4× via actions 43703 / 42456–42458). Right-click opens metronome / pre-roll settings. M/P/R need SWS (SNM); rate uses REAPER actions.",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 220,
    _slide_out_mode = true,
    _en = false,
    _play = false,
    _rec = false,
    _rate_id = "one",
}

local METRO_ICON_PATH = "icons/Music/Metronome.ttf"
local METRO_ICON_CHAR = utf8.char(WIDGET.ICON_FONTS.ICON_CODEPOINT)
local METRO_LABEL_FALLBACK = "M"

local function metro_chip_metrics(ctx)
    return WIDGET.DRAWING.toolbar_icon_chip_size(ctx, METRO_ICON_PATH, METRO_ICON_CHAR, METRO_LABEL_FALLBACK, PR_LAYOUT_OPTS.chip_pad_h)
end

local function pr_cell_width(ctx)
    return WIDGET.CHIP_ROW.uniform_chip_cell_width(ctx, PR_MODES, PR_LAYOUT_OPTS)
end

local function pr_block_width(ctx)
    return pr_cell_width(ctx) * #PR_MODES
end

local function speed_row_natural_w(ctx)
    local cell = WIDGET.CHIP_ROW.uniform_chip_cell_width(ctx, SPEEDS, SPEED_LAYOUT_OPTS)
    local gap = SPEED_LAYOUT_OPTS.chip_gap or WIDGET.CHIP_ROW.CHIP_GAP
    return #SPEEDS * cell + gap * math.max(0, #SPEEDS - 1)
end

local function fits_one_row(inner_w, mw, pr_w, include_speeds, speed_w)
    local need = mw + CHIP_GAP + pr_w
    if include_speeds then
        need = need + GROUP_GAP + speed_w
    end
    return inner_w >= need
end

local function make_pr_chips(x, y, total_w, chip_h)
    local cell_w = total_w / #PR_MODES
    return {
        {
            id = "p",
            x = x,
            y = y,
            w = cell_w,
            h = chip_h,
            mode = PR_MODES[1],
        },
        {
            id = "r",
            x = x + cell_w,
            y = y,
            w = cell_w,
            h = chip_h,
            mode = PR_MODES[2],
        },
    }
end

local function layout_speed_chips(ctx, x, row_y, strip_w)
    if strip_w < 40 then
        return {}
    end
    return WIDGET.CHIP_ROW.layout_chip_strip(ctx, x, row_y, strip_w, SPEEDS, SPEED_LAYOUT_OPTS)
end

local function draw_metro_chip(ctx, coords, draw_list, chip, is_active, is_hover, btn_txt, btn_bg, disabled)
    WIDGET.DRAWING.drawToolbarIconPillChip(ctx, coords, draw_list, chip, btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
        disabled = disabled,
        rounding = CHIP_ROUND,
        icon_path = METRO_ICON_PATH,
        icon_char = METRO_ICON_CHAR,
        fallback_text = METRO_LABEL_FALLBACK,
    })
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

local function left_block_width(ctx)
    local R = WIDGET.CHIP_ROW.button_rounding_content_pad()
    if not ctx or not reaper.ImGui_CalcTextSize then
        return 4 + R + 44 + CHIP_GAP + 30 + CHIP_GAP + 30
    end
    local mw = select(1, metro_chip_metrics(ctx))
    return 4 + R + mw + CHIP_GAP + pr_block_width(ctx)
end

function widget.getLayoutWidth(self, ctx, is_vertical_toolbar)
    local natural = self.width or 220
    if ctx and reaper.ImGui_GetTextLineHeight then
        natural = math.max(natural, left_block_width(ctx) + 4 + WIDGET.CHIP_ROW.button_rounding_content_pad())
        if not self._slide_out_mode or is_vertical_toolbar then
            local R = WIDGET.CHIP_ROW.button_rounding_content_pad()
            local spd = WIDGET.CHIP_ROW.uniform_chip_row_width(ctx, SPEEDS, SPEED_LAYOUT_OPTS)
            natural = math.max(natural, left_block_width(ctx) + GROUP_GAP + spd + 4 + R)
        end
    end
    return WIDGET.CHIP_ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    local chip_h = WIDGET.CHIP_ROW.chip_line_height(ctx)
    local mw, mh_m = metro_chip_metrics(ctx)
    local pad = 4 + WIDGET.CHIP_ROW.button_rounding_content_pad()
    if self._slide_out_mode then
        local usable = math.max(40, (_inner_w or self.width or 220) - pad * 2)
        if fits_one_row(usable, mw, pr_block_width(ctx), false, 0) then
            return math.max(CONFIG.SIZES.HEIGHT or 28, pad * 2 + math.max(mh_m, chip_h))
        end
        return math.max(CONFIG.SIZES.HEIGHT or 28, pad * 2 + mh_m + CHIP_GAP + chip_h)
    end
    local usable = math.max(40, (_inner_w or self.width or 220) - pad * 2)
    local speeds_h = #SPEEDS * chip_h + math.max(0, #SPEEDS - 1) * WIDGET.CHIP_ROW.CHIP_GAP
    if fits_one_row(usable, mw, pr_block_width(ctx), false, 0) then
        return math.max(CONFIG.SIZES.HEIGHT or 28, pad * 2 + math.max(mh_m, chip_h) + CHIP_GAP + speeds_h)
    end
    return math.max(CONFIG.SIZES.HEIGHT or 28, pad * 2 + mh_m + CHIP_GAP + chip_h + CHIP_GAP + speeds_h)
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

--- Horizontal: one row [M][P|R][speeds] when room; else M over P|R (multi width = metro width), speeds on the right.
local function layout_horizontal(ctx, rel_x, rel_y, render_width, layout, include_speeds)
    local h = WIDGET.CHIP_ROW.widget_body_height(layout)
    local chip_h = WIDGET.CHIP_ROW.chip_line_height(ctx)
    local R = WIDGET.CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    local inner_w = math.max(40, render_width - pad_x * 2)

    local mw, mh_m = metro_chip_metrics(ctx)
    local pr_natural = pr_block_width(ctx)
    local speed_natural = include_speeds and speed_row_natural_w(ctx) or 0

    if fits_one_row(inner_w, mw, pr_natural, include_speeds, speed_natural) then
        local block_w = mw + CHIP_GAP + pr_natural
        if include_speeds then
            block_w = block_w + GROUP_GAP + speed_natural
        end
        local inner_x = rel_x + pad_x
        local x0 = ROW.center_block_x(rel_x, render_width, block_w, pad_x)
        local row_y = rel_y + (h - chip_h) / 2
        local x = x0
        local metro = { x = x, y = rel_y + (h - mh_m) / 2, w = mw, h = mh_m }
        x = x + mw + CHIP_GAP
        local pr_chips = make_pr_chips(x, row_y, pr_natural, chip_h)
        local speed_chips = {}
        if include_speeds then
            x = x + pr_natural + GROUP_GAP
            speed_chips = layout_speed_chips(ctx, x, row_y, inner_x + inner_w - x)
        end
        return metro, pr_chips, speed_chips
    end

    local stack_w = mw
    local stack_h = mh_m + CHIP_GAP + chip_h
    local block_w = stack_w
    if include_speeds then
        local strip_w = inner_w - stack_w - GROUP_GAP
        if strip_w >= speed_natural then
            block_w = stack_w + GROUP_GAP + speed_natural
        end
    end
    local inner_x = rel_x + pad_x
    local x0 = ROW.center_block_x(rel_x, render_width, block_w, pad_x)
    local stack_y0 = rel_y + (h - stack_h) / 2
    local metro = { x = x0, y = stack_y0, w = stack_w, h = mh_m }
    local pr_chips = make_pr_chips(x0, stack_y0 + mh_m + CHIP_GAP, stack_w, chip_h)
    local speed_chips = {}
    if include_speeds then
        local sx = x0 + stack_w + GROUP_GAP
        local strip_w = inner_x + inner_w - sx
        if strip_w >= speed_natural then
            local row_y = rel_y + (h - chip_h) / 2
            speed_chips = layout_speed_chips(ctx, sx, row_y, strip_w)
        end
    end
    return metro, pr_chips, speed_chips
end

--- Vertical: one row [M][P|R] when room; else stacked M / P|R (same width); speeds below when not slide-out.
local function layout_vertical(self, ctx, rel_x, rel_y, render_width, layout)
    local R = WIDGET.CHIP_ROW.button_rounding_content_pad()
    local pad_x, pad_y = 4 + R, 4 + R
    local chip_h = WIDGET.CHIP_ROW.chip_line_height(ctx)
    local usable = math.max(40, render_width - pad_x * 2)
    local y = rel_y + pad_y

    local mw, mh_m = metro_chip_metrics(ctx)
    local pr_natural = pr_block_width(ctx)
    local include_speeds = not self._slide_out_mode

    if fits_one_row(usable, mw, pr_natural, false, 0) then
        local band_h = math.max(mh_m, chip_h)
        local block_w = mw + CHIP_GAP + pr_natural
        local x = WIDGET.CHIP_ROW.center_block_x(rel_x, render_width, block_w, pad_x)
        local metro = {
            x = x,
            y = y + (band_h - mh_m) / 2,
            w = mw,
            h = mh_m,
        }
        local pr_chips = make_pr_chips(x + mw + CHIP_GAP, y + (band_h - chip_h) / 2, pr_natural, chip_h)
        y = y + band_h + CHIP_GAP
        local speed_chips = {}
        if include_speeds then
            for _, s in ipairs(SPEEDS) do
                speed_chips[#speed_chips + 1] = {
                    id = s.id,
                    x = rel_x + pad_x,
                    y = y,
                    w = usable,
                    h = chip_h,
                    mode = s,
                }
                y = y + chip_h + WIDGET.CHIP_ROW.CHIP_GAP
            end
        end
        return metro, pr_chips, speed_chips
    end

    local stack_w = usable
    local metro = { x = rel_x + pad_x, y = y, w = stack_w, h = mh_m }
    y = y + mh_m + CHIP_GAP
    local pr_chips = make_pr_chips(rel_x + pad_x, y, stack_w, chip_h)
    y = y + chip_h + CHIP_GAP

    local speed_chips = {}
    if include_speeds then
        for _, s in ipairs(SPEEDS) do
            speed_chips[#speed_chips + 1] = {
                id = s.id,
                x = rel_x + pad_x,
                y = y,
                w = usable,
                h = chip_h,
                mode = s,
            }
            y = y + chip_h + WIDGET.CHIP_ROW.CHIP_GAP
        end
    end

    return metro, pr_chips, speed_chips
end

local function layout_all(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out then
        local panel_h = self._slide_panel_h or speed_slide.slide_height(self, ctx, render_width, self._slide_host_h, layout)
        return nil, nil, speed_slide.layout_chips(self, ctx, rel_x, rel_y, render_width, panel_h, layout)
    end
    if layout and layout.is_vertical then
        return layout_vertical(self, ctx, rel_x, rel_y, render_width, layout)
    end
    local include_speeds = not self._slide_out_mode
    return layout_horizontal(ctx, rel_x, rel_y, render_width, layout, include_speeds)
end

local SPEED_DRAW_SPEC = { slide_namespace = "spd", chip_round = CHIP_ROUND }
local PR_DRAW_SPEC = { slide_namespace = "metro_pr", chip_round = CHIP_ROUND, slide_multi_toggle = true }

local function draw_speed_multiswitch(ctx, self, speed_chips, coords, draw_list, btn_txt, btn_bg, mx, my, vert, alpha_factor, draw_opts)
    if not speed_chips or #speed_chips == 0 then
        return
    end
    draw_opts = draw_opts or {}
    SLIDE_HOST.draw_ms(ctx, self, speed_chips, coords, draw_list, btn_txt, btn_bg,
        SLIDE_HOST.slide_draw_opts(ctx, SPEED_DRAW_SPEC, self, "spd_", mx, my,
            function(s, mode) return mode and mode.id == s._rate_id end,
            { enabled = true, mixed = false },
            {
                vertical = draw_opts.grid_layout and false or vert,
                grid_layout = draw_opts.grid_layout,
                rel_x = draw_opts.rel_x,
                rel_y = draw_opts.rel_y,
                alpha_factor = alpha_factor,
                label_for = function(c)
                    return WIDGET.CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
                end,
            }))
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    local mx, my = coords:getRelativeMouse()
    local metro, pr_chips, speed_chips = layout_all(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out then
        return speed_slide.hit_test(mx, my, coords, speed_chips)
    end
    if metro and coords:pointInRelativeRect(mx, my, metro.x, metro.y, metro.w, metro.h) then
        return SUB_METRO
    end
    for _, c in ipairs(pr_chips or {}) do
        if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
            return c.mode.id == "p" and SUB_P or SUB_R
        end
    end
    for _, c in ipairs(speed_chips or {}) do
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
    if speed_slide.on_sub_id(self, sub_id) then
        return true
    end
    return false
end

function widget.onRightClick(self)
    reaper.Main_OnCommand(40363, 0)
end

local function draw_pr_multi_toggle(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg, mx, my)
    SLIDE_HOST.draw_ms(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg,
        SLIDE_HOST.slide_draw_opts(ctx, PR_DRAW_SPEC, self, "pr_", mx, my,
            function(s, mode)
                if mode.id == "p" then
                    return s._play
                end
                if mode.id == "r" then
                    return s._rec
                end
                return false
            end,
            { enabled = true, mixed = false }))
end

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
    self._en = true
    self._play = true
    self._rec = true
    self._rate_id = "two"
    local mx, my = coords:getRelativeMouse()
    local vert = layout and layout.is_vertical
    local metro, pr_chips, speed_chips = layout_all(self, ctx, rel_x, rel_y, render_width, layout, false)

    draw_metro_chip(ctx, coords, draw_list, metro, self._en, false, btn_txt, btn_bg, false)
    draw_pr_multi_toggle(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg, mx, my)
    draw_speed_multiswitch(ctx, self, speed_chips, coords, draw_list, btn_txt, btn_bg, mx, my, vert, nil)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)

    if self._preview_mode then
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
        return
    end

    local mx, my = coords:getRelativeMouse()
    local is_slide_out = self._is_rendering_slide_out == true
    local metro, pr_chips, speed_chips = layout_all(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)
    local vert = layout and layout.is_vertical

    if is_slide_out then
        speed_slide.draw_chips(ctx, self, speed_chips, coords, draw_list, btn_txt, btn_bg, mx, my)
        return
    end

    draw_metro_chip(ctx, coords, draw_list, metro, self._en, coords:pointInRelativeRect(mx, my, metro.x, metro.y, metro.w, metro.h), btn_txt, btn_bg, false)
    draw_pr_multi_toggle(ctx, self, pr_chips, coords, draw_list, btn_txt, btn_bg, mx, my)
    draw_speed_multiswitch(ctx, self, speed_chips, coords, draw_list, btn_txt, btn_bg, mx, my, vert, nil)
end

widget.slide_width = speed_slide.slide_width
widget.slide_height = speed_slide.slide_height

return widget
