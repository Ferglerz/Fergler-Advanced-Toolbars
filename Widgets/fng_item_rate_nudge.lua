-- Widgets/fng_item_rate_nudge.lua
-- SWS FNG item playrate: five separate button chips (semitone / 10 cents / reset).
-- Layout and draw match discrete transport-style chips (not grouped multiswitch track).

local CHIP_MS = require("Utils.chip_multiswitch")
local ROW = require("Renderers._Widgets_chip_row")
local CHIP_HIT = require("Utils.chip_hit_prefix")

local PREFIX = "fng_rate_"

local CHIP_GAP = 3
local CHIP_H_PAD = 5
local CHIP_V_PAD = 3
local CHIP_ROUND = 3
local ROW_PAD_X = 3

-- Order: coarse down, fine down (~0.6%), reset, fine up, coarse up.
local ENTRIES = {
    {
        id = "d100",
        action_id = "_FNG_DECREASERATE_SWS",
        short_label = "-100",
        label = "Decrease item rate by ~6% (one semitone) preserving length, clear 'preserve pitch'",
    },
    {
        id = "d10",
        action_id = "_FNG_NUDGERATEDOWN",
        short_label = "-10",
        label = "Decrease item rate by ~0.6% (10 cents) preserving length, clear 'preserve pitch'",
    },
    {
        id = "rst",
        action_id = "_SWS_RESETRATE",
        short_label = "Reset",
        label = "Reset item rate, preserving length, clear 'preserve pitch'",
    },
    {
        id = "u10",
        action_id = "_FNG_NUDGERATEUP",
        short_label = "+10",
        label = "Increase item rate by ~0.6% (10 cents) preserving length, clear 'preserve pitch'",
    },
    {
        id = "u100",
        action_id = "_FNG_INCREASERATE_SWS",
        short_label = "+100",
        label = "Increase item rate by ~6% (one semitone) preserving length, clear 'preserve pitch'",
    },
}

CHIP_MS.normalize_chip_entries(ENTRIES)

local function entry_by_id(id)
    for _, e in ipairs(ENTRIES) do
        if e.id == id then
            return e
        end
    end
    return nil
end

local function run_named_action(action_id)
    if not action_id or action_id == "" then
        return
    end
    local cmd = reaper.NamedCommandLookup(action_id)
    if cmd and cmd ~= 0 then
        reaper.Main_OnCommand(cmd, 0)
    end
end

local function chip_line_h(ctx)
    return reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
end

local function chip_natural_w(ctx, e)
    local text = CHIP_MS.chip_caption(e)
    return reaper.ImGui_CalcTextSize(ctx, text) + CHIP_H_PAD * 2
end

local function layout_chips_horizontal(ctx, rel_x, rel_y, _render_width)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = chip_line_h(ctx)
    local row_y = rel_y + (h - chip_h) / 2
    local x = rel_x + ROW_PAD_X + ROW.button_rounding_content_pad()
    local chips = {}
    for _, e in ipairs(ENTRIES) do
        local w = chip_natural_w(ctx, e)
        chips[#chips + 1] = { id = e.id, entry = e, x = x, y = row_y, w = w, h = chip_h }
        x = x + w + CHIP_GAP
    end
    return chips
end

local function layout_chips_vertical(ctx, rel_x, rel_y, render_width)
    local chip_h = chip_line_h(ctx)
    local inset = ROW.button_rounding_content_pad()
    local pad_y = 4 + inset
    local usable = math.max(24, render_width - (ROW_PAD_X + inset) * 2)
    local x = rel_x + ROW_PAD_X + inset
    local y = rel_y + pad_y
    local chips = {}
    for _, e in ipairs(ENTRIES) do
        chips[#chips + 1] = { id = e.id, entry = e, x = x, y = y, w = usable, h = chip_h }
        y = y + chip_h + CHIP_GAP
    end
    return chips
end

local function layout_chips(ctx, rel_x, rel_y, render_width, layout)
    if layout and layout.is_vertical then
        return layout_chips_vertical(ctx, rel_x, rel_y, render_width)
    end
    return layout_chips_horizontal(ctx, rel_x, rel_y, render_width)
end

local function draw_discrete_chip(ctx, coords, draw_list, chip, is_hover, btn_txt, btn_bg)
    local text = CHIP_MS.chip_caption(chip.entry)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = false,
        hover = is_hover,
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

local widget = {
    name = "FNG Item Rate Nudge",
    category = "Items & selection",
    type = "display",
    update_interval = 1.0,
    description = "SWS: five separate buttons — nudge item playrate by semitone or ~0.6% (10¢), or reset (length preserved, preserve pitch cleared). Requires SWS extension.",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 0,
}

function widget.getLayoutWidth(self, ctx)
    if not ctx or not reaper.ImGui_CalcTextSize then
        return math.max(80, self.width or 0)
    end
    local inset = ROW.button_rounding_content_pad()
    local w = ROW_PAD_X + inset
    for i, e in ipairs(ENTRIES) do
        w = w + chip_natural_w(ctx, e)
        if i < #ENTRIES then
            w = w + CHIP_GAP
        end
    end
    w = w + ROW_PAD_X + inset
    return ROW.apply_preview_width_cap(self, math.max(60, math.ceil(w)))
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar or not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    local chip_h = chip_line_h(ctx)
    local pad_y = 4 + ROW.button_rounding_content_pad()
    return pad_y * 2 + #ENTRIES * chip_h + math.max(0, #ENTRIES - 1) * CHIP_GAP
end

function widget.getValue(_self)
    return 0
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout)
    for _, c in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
            return PREFIX .. c.id
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    local id = CHIP_HIT.strip(PREFIX, sub_id)
    if not id then
        return false
    end
    local e = entry_by_id(id)
    if not e then
        return false
    end
    run_named_action(e.action_id)
    return true
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    self._hover_tip_text = nil
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    local mx, my = coords:getRelativeMouse()
    local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout)

    for _, c in ipairs(chips) do
        local hover = coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h)
        if hover then
            local e = c.entry
            self._hover_tip_text = e.action_id .. "\n" .. (e.label or "")
        end
        draw_discrete_chip(ctx, coords, draw_list, c, hover, btn_txt, btn_bg)
    end
end

function widget.onWidgetFrame(self, ctx, _button)
    if self._preview_mode then
        return
    end
    local tip = self._hover_tip_text
    if not tip or tip == "" then
        return
    end
    reaper.ImGui_BeginTooltip(ctx)
    reaper.ImGui_Text(ctx, tip)
    reaper.ImGui_EndTooltip(ctx)
end

return widget
