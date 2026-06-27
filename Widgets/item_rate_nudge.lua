-- Widgets/item_rate_nudge.lua
-- Item playrate: five separate button chips (semitone / 10 cents / reset).
-- Layout and draw match discrete transport-style chips (not grouped multiswitch track).

local CHIP_MS = require("Utils.chip_multiswitch")
local ROW = require("Renderers.Widgets.chip_row")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local FLEX_LAYOUT = require("Utils.flex_layout")
local DRAWING = require("Utils.drawing")
local PREVIEW_FB = require("Utils.widget_preview_fallback")

local PREFIX = "item_rate_"
local PREVIEW_CHIP_IDS = { "d10", "rst", "u10" }

local CHIP_GAP = ROW.CHIP_GAP
local CHIP_H_PAD = 5
local CHIP_ROUND = ROW.CHIP_ROUND
local ROW_PAD_X = 3

-- Order: coarse down, fine down (~0.6%), reset, fine up, coarse up.
local ENTRIES = {
    {
        id = "d100",
        command_id = 40798,
        short_label = "-100",
        label = "Decrease item rate by ~6% (one semitone), clear 'preserve pitch'",
    },
    {
        id = "d10",
        command_id = 40520,
        short_label = "-10",
        label = "Decrease item rate by ~0.6% (10 cents)",
    },
    {
        id = "rst",
        action_id = "_SWS_RESETRATE",
        short_label = "Reset",
        label = "Reset item rate, preserving length, clear 'preserve pitch'",
    },
    {
        id = "u10",
        command_id = 40799,
        short_label = "+10",
        label = "Increase item rate by ~0.6% (10 cents), clear 'preserve pitch'",
    },
    {
        id = "u100",
        command_id = 40797,
        short_label = "+100",
        label = "Increase item rate by ~6% (one semitone), clear 'preserve pitch'",
    },
}

CHIP_MS.normalize_chip_entries(ENTRIES)

local function entry_by_id(id)
    return UTILS.findById(ENTRIES, id)
end

local function preview_entries()
    local list = {}
    for _, pid in ipairs(PREVIEW_CHIP_IDS) do
        local e = entry_by_id(pid)
        if e then
            list[#list + 1] = e
        end
    end
    return list
end

local function layout_entry_list(self)
    if self._preview_mode or self._preview_width_cap then
        return preview_entries()
    end
    return ENTRIES
end

local function run_chip_action(entry)
    if not entry then
        return
    end
    if entry.command_id then
        reaper.Main_OnCommand(entry.command_id, 0)
        return
    end
    local action_id = entry.action_id
    if not action_id or action_id == "" then
        return
    end
    local cmd = reaper.NamedCommandLookup(action_id)
    if cmd and cmd ~= 0 then
        reaper.Main_OnCommand(cmd, 0)
    end
end

local function chip_line_h(ctx)
    return ROW.chip_line_height(ctx) + 2
end

local function chip_natural_w(ctx, e)
    local text = CHIP_MS.chip_caption(e)
    return reaper.ImGui_CalcTextSize(ctx, text) + CHIP_H_PAD * 2
end

local function layout_chips(ctx, rel_x, rel_y, render_width, layout, entries)
    local is_vertical = layout and layout.is_vertical
    local h = layout and layout.height or CONFIG.SIZES.HEIGHT
    local chip_h = chip_line_h(ctx)
    local inset = ROW.button_rounding_content_pad()
    local pad_x = ROW_PAD_X + inset
    local inner_w = math.max(10, render_width - pad_x * 2)
    local max_w = is_vertical and inner_w or 99999

    local groups = {}
    for _, e in ipairs(entries) do
        table.insert(groups, { { id = e.id, entry = e, w = chip_natural_w(ctx, e), h = chip_h } })
    end

    local lines = FLEX_LAYOUT.wrap_groups(groups, max_w, CHIP_GAP, CHIP_GAP)
    
    local chips = {}
    local total_h = #lines * chip_h + (#lines - 1) * CHIP_GAP
    local start_y = is_vertical and (rel_y + 4 + inset) or (rel_y + (h - total_h) / 2)

    local y = start_y
    for _, line in ipairs(lines) do
        local x = rel_x + pad_x
        if is_vertical and #line.items == 1 then
            line.items[1].w = inner_w
        end

        for _, it in ipairs(line.items) do
            it.x = x
            it.y = y
            table.insert(chips, it)
            x = x + it.w + CHIP_GAP
        end
        y = y + chip_h + CHIP_GAP
    end
    
    return chips
end

local function draw_discrete_chip(ctx, coords, draw_list, chip, is_hover, btn_txt, btn_bg)
    local text = CHIP_MS.chip_caption(chip.entry)
    DRAWING.drawWidgetPillChip(ctx, coords, draw_list, chip, text, btn_txt, btn_bg, {
        active = false,
        filled = true,
        hover = is_hover,
        rounding = CHIP_ROUND,
    })
end

local function render_preview(ctx, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = chip_line_h(ctx)
    local inset = ROW.button_rounding_content_pad()
    local pad_x = ROW_PAD_X + inset
    local inner_w = math.max(10, render_width - pad_x * 2)
    local row_y = rel_y + (h - chip_h) / 2
    local subset = preview_entries()
    if #subset == 0 then
        PREVIEW_FB.draw_centered_title(ctx, "-10 · Reset · +10", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end
    local chips = ROW.layout_chip_strip(ctx, rel_x + pad_x, row_y, inner_w, subset, {
        chip_gap = CHIP_GAP,
        min_chip_w = 16,
        sizing = "fill",
        chip_pad_h = CHIP_H_PAD,
    })
    for _, c in ipairs(chips) do
        draw_discrete_chip(ctx, coords, draw_list, c, false, btn_txt, btn_bg)
    end
end

local widget = {
    name = "Item Rate Nudge",
    category = "Items & selection",
    type = "display",
    update_interval = 1.0,
    description = "Five buttons to nudge item playrate by semitone or ~0.6% (10¢), or reset. Reset requires SWS.",
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
    local entries = layout_entry_list(self)
    for i, e in ipairs(entries) do
        w = w + chip_natural_w(ctx, e)
        if i < #entries then
            w = w + CHIP_GAP
        end
    end
    w = w + ROW_PAD_X + inset
    return ROW.apply_preview_width_cap(self, math.max(60, math.ceil(w)))
end

function widget.getLayoutHeight(self, ctx, inner_width, is_vertical_toolbar)
    if not is_vertical_toolbar or not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    local chip_h = chip_line_h(ctx)
    local inset = ROW.button_rounding_content_pad()
    local pad_y = 4 + inset
    local inner_w = math.max(10, (inner_width or self.width or 0) - (ROW_PAD_X + inset) * 2)
    
    local groups = {}
    for _, e in ipairs(ENTRIES) do
        table.insert(groups, { { id = e.id, entry = e, w = chip_natural_w(ctx, e), h = chip_h } })
    end
    
    local lines = FLEX_LAYOUT.wrap_groups(groups, inner_w, CHIP_GAP, CHIP_GAP)
    return pad_y * 2 + #lines * chip_h + math.max(0, #lines - 1) * CHIP_GAP
end

function widget.getValue(_self)
    return 0
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout, ENTRIES)
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
    run_chip_action(e)
    return true
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)

    if self._preview_mode then
        render_preview(ctx, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        return
    end

    local mx, my = coords:getRelativeMouse()
    local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout, ENTRIES)

    for _, c in ipairs(chips) do
        local hover = coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h)
        draw_discrete_chip(ctx, coords, draw_list, c, hover, btn_txt, btn_bg)
    end
end

return widget
