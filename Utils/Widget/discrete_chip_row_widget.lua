-- Utils/Widget/discrete_chip_row_widget.lua
-- Discrete command chips (variable width, no selection state). Flex-wrap on vertical toolbars.
-- Override: spec.renderCustom, spec.draw_chip, spec.chip_width, spec.on_entry_click.

local ROW = require("Utils.Chips.chip_row")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local PREVIEW_FB = require("Utils.Widget.widget_preview_fallback")
local DRAWING = require("Utils.Draw.drawing")
local FLEX = require("Utils.Core.flex_layout")
local ICON_FONTS = require("Utils.Core.icon_fonts")
local BASE = require("Utils.Widget.chip_widget_base")

local M = {}

local SPEC_OVERRIDE_METHODS = {
    "renderCustom",
    "hitTestSubcontrols",
    "onSubcontrolClick",
    "getLayoutWidth",
    "getLayoutHeight",
    "getValue",
    "onSettingsMenu",
}

local function default_run_action(entry)
    if not entry then
        return
    end
    if entry.command_id then
        UTILS.runAction(entry.command_id)
        return
    end
    UTILS.runNamedAction(entry.action_id)
end

function M.new(spec)
    local ENTRIES = spec.entries or {}
    CHIP_MS.normalize_chip_entries(ENTRIES)

    local PREFIX = spec.prefix or "dcr_"
    local PREVIEW_IDS = spec.preview_ids or {}
    local CHIP_GAP = spec.chip_gap or ROW.CHIP_GAP
    local CHIP_H_PAD = spec.chip_h_pad or 5
    local CHIP_ROUND = spec.chip_round or ROW.CHIP_ROUND
    local ROW_PAD_X = spec.row_pad_x or 3

    local function entry_by_id(id)
        return BASE.mode_by_id(ENTRIES, id)
    end

    local function preview_entries()
        return BASE.preview_entries_by_ids(PREVIEW_IDS, ENTRIES)
    end

    local function layout_entry_list(self)
        if self._preview_mode or self._preview_width_cap then
            return preview_entries()
        end
        return ENTRIES
    end

    local function chip_line_h(ctx)
        if spec.chip_line_h then
            return spec.chip_line_h(ctx)
        end
        return ROW.chip_line_height(ctx) + 2
    end

    local function chip_natural_w(ctx, e)
        if spec.chip_width then
            return spec.chip_width(ctx, e)
        end
        local text = CHIP_MS.chip_caption(e)
        return reaper.ImGui_CalcTextSize(ctx, text) + CHIP_H_PAD * 2
    end

    local function layout_chips(ctx, rel_x, rel_y, render_width, layout, entries)
        local chip_h = chip_line_h(ctx)
        local groups = {}
        for _, e in ipairs(entries) do
            groups[#groups + 1] = { { id = e.id, entry = e, w = chip_natural_w(ctx, e), h = chip_h } }
        end
        return ROW.layout_flex_wrap_groups(ctx, rel_x, rel_y, render_width, layout, groups, {
            row_pad_x = ROW_PAD_X,
            chip_gap = CHIP_GAP,
            chip_h = chip_h,
            stretch_single_on_vertical = true,
        })
    end

    local function draw_default_chip(ctx, coords, draw_list, chip, is_hover, btn_txt, btn_bg)
        local text = CHIP_MS.chip_caption(chip.entry)
        DRAWING.drawWidgetPillChip(ctx, coords, draw_list, chip, text, btn_txt, btn_bg, {
            active = false,
            filled = true,
            hover = is_hover,
            rounding = CHIP_ROUND,
            alpha_factor = chip.alpha_factor,
        })
    end

    local function draw_chip(ctx, coords, draw_list, chip, is_hover, btn_txt, btn_bg)
        if spec.draw_chip then
            spec.draw_chip(ctx, coords, draw_list, chip, is_hover, btn_txt, btn_bg, spec)
            return
        end
        draw_default_chip(ctx, coords, draw_list, chip, is_hover, btn_txt, btn_bg)
    end

    local function render_preview(ctx, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
        local h = ROW.widget_body_height(layout)
        local chip_h = chip_line_h(ctx)
        local inset = ROW.button_rounding_content_pad()
        local pad_x = ROW_PAD_X + inset
        local inner_w = math.max(10, render_width - pad_x * 2)
        local row_y = rel_y + (h - chip_h) / 2
        local subset = preview_entries()
        local preview_title = spec.preview_title or "-10 · Reset · +10"
        if #subset == 0 then
            PREVIEW_FB.draw_centered_title(ctx, preview_title, rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
            return
        end
        local chips = ROW.layout_chip_strip(ctx, rel_x + pad_x, row_y, inner_w, subset, {
            chip_gap = CHIP_GAP,
            min_chip_w = 16,
            sizing = "fill",
            chip_pad_h = CHIP_H_PAD,
        })
        for _, c in ipairs(chips) do
            draw_chip(ctx, coords, draw_list, c, false, btn_txt, btn_bg)
        end
    end

    local widget = BASE.apply_base_widget(spec, {
        update_interval = 0.2,
        default_width = 0,
    })

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
        local groups = {}
        for _, e in ipairs(ENTRIES) do
            groups[#groups + 1] = { { id = e.id, entry = e, w = chip_natural_w(ctx, e), h = chip_h } }
        end
        local inset = ROW.button_rounding_content_pad()
        local inner_w = math.max(10, (inner_width or self.width or 0) - (ROW_PAD_X + inset) * 2)
        local lines = FLEX.wrap_groups(groups, inner_w, CHIP_GAP, CHIP_GAP)
        local pad_y = 4 + inset
        return math.max(CONFIG.SIZES.HEIGHT or 28, pad_y * 2 + #lines * chip_h + math.max(0, #lines - 1) * CHIP_GAP)
    end

    function widget.getValue(_self)
        if spec.getValue then
            return spec.getValue(_self)
        end
        return 0
    end

    function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
        local mx, my = coords:getRelativeMouse()
        local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout, ENTRIES)
        return BASE.hit_test_chips(mx, my, coords, chips, PREFIX)
    end

    function widget.onSubcontrolClick(self, sub_id)
        local id = BASE.strip_click_id(PREFIX, sub_id)
        if not id then
            return false
        end
        local e = entry_by_id(id)
        if not e then
            return false
        end
        if spec.on_entry_click then
            spec.on_entry_click(self, e)
        else
            default_run_action(e)
        end
        return true
    end

    function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)

        if self._preview_mode then
            render_preview(ctx, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
            return
        end

        local mx, my = coords:getRelativeMouse()
        local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout, ENTRIES)

        for _, c in ipairs(chips) do
            local hover = coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h)
            draw_chip(ctx, coords, draw_list, c, hover, btn_txt, btn_bg)
        end
    end

    BASE.apply_spec_overrides(widget, spec, SPEC_OVERRIDE_METHODS)

    return widget
end

M.ICON_FONTS = ICON_FONTS

return M
