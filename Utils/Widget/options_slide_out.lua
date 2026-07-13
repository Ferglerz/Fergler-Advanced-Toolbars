-- Utils/Widget/options_slide_out.lua
-- Helpers for host chip / readout + slide-out option rows (toggle grids, multiswitch).

local ROW = require("Utils.Chips.chip_row")
local DRAWING = require("Utils.Draw.drawing")
local ICON_FONTS = require("Utils.Core.icon_fonts")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")

local M = {}

M.TOGGLE_PAD_H = 10
M.TOGGLE_MIN_WIDTH = 44 + M.TOGGLE_PAD_H * 2
local DEFAULT_ICON_GAP = 4

function M.with_slide_out(spec)
    spec.slide_out = true
    return spec
end

function M.toggle_command_state(cmd)
    local ok, st = pcall(reaper.GetToggleCommandState, cmd)
    return ok and st == 1
end

function M.click_entry_by_id(entries, chip_id)
    for _, e in ipairs(entries) do
        if e.id == chip_id and e.cmd then
            reaper.Main_OnCommand(e.cmd, 0)
            return true
        end
    end
    return false
end

function M.shrink_label(ctx, candidates, max_text_w)
    if not ctx or not reaper.ImGui_CalcTextSize or max_text_w <= 0 then
        return candidates[1]
    end
    for i = 1, #candidates do
        local label = candidates[i]
        if (reaper.ImGui_CalcTextSize(ctx, label) or 0) <= max_text_w then
            return label
        end
    end
    return candidates[#candidates]
end

function M.host_labeled_toggle(label, get_state, on_click, opts)
    opts = opts or {}
    return M.host_toggle_row({
        type = "toggle",
        label = label,
        min_width = opts.min_width or M.TOGGLE_MIN_WIDTH,
        get_label = opts.get_label,
        get_width = opts.get_width,
        get_state = get_state,
        on_click = on_click,
        render_custom_chip = opts.render_custom_chip,
    })
end

function M.single_checkbox_menu(ctx, button, label, get_value, set_value)
    local ch, new_val = reaper.ImGui_Checkbox(ctx, label, get_value())
    if ch then
        set_value(new_val)
        require("Utils.Widget.widget_options_popup").commit_dynamic_widget_layout(button, ctx)
    end
end

function M.chip_label_settings(self, ctx, button, opts)
    opts = opts or {}
    local hint = opts.hint or "Chip name"
    local field = opts.edit_field or "_chip_label_edit"
    local store = opts.store_field or "_chip_label"
    local default_label = opts.default_label or "Chip"
    local show_icon_field = opts.show_icon_field
    local icon_bundle_fn = opts.icon_bundle_fn

    if self[field] == nil or self[field] == "" then
        self[field] = self.chip_display_text and self:chip_display_text() or default_label
    end

    if show_icon_field and icon_bundle_fn then
        local bundle = icon_bundle_fn()
        if bundle and bundle.use_icons then
            if reaper.ImGui_MenuItem(ctx, opts.show_icon_label or "Show icon", nil, self[show_icon_field] == true) then
                self[show_icon_field] = not self[show_icon_field]
                require("Utils.Widget.widget_options_popup").commit_dynamic_widget_layout(button, ctx)
            end
            reaper.ImGui_Separator(ctx)
        end
    end

    reaper.ImGui_Text(ctx, opts.section_label or "Chip label")
    reaper.ImGui_SetNextItemWidth(ctx, opts.input_width or 220)
    local ch, buf = reaper.ImGui_InputTextWithHint(ctx, opts.input_id or "##chip_lbl", hint, self[field])
    if ch and buf ~= nil then
        self[field] = buf
        self[store] = (buf:gsub("^%s+", ""):gsub("%s+$", ""))
        require("Utils.Widget.widget_options_popup").commit_dynamic_widget_layout(button, ctx)
    end
end

function M.resolve_icon(icon_path)
    return ICON_FONTS.resolveToolbarIcon(icon_path)
end

function M.icon_column_width(ctx, bundle, gap)
    gap = gap or DEFAULT_ICON_GAP
    if not bundle or not bundle.use_icons or not ctx then
        return 0
    end
    local icon_sz = ROW.magnet_icon_size(ctx)
    return math.max(icon_sz * 0.65, icon_sz) + gap
end

function M.draw_icon_leading_toggle(ctx, coords, draw_list, rect, label, hover, btn_txt, btn_bg, opts)
    opts = opts or {}
    local bundle = opts.icon_bundle
    local show_icon = opts.show_icon
    if show_icon == nil then
        show_icon = bundle and bundle.use_icons
    end
    local icon_font = opts.icon_font
    local icon_sz = 0
    if show_icon and bundle and bundle.use_icons then
        icon_sz = opts.icon_sz or ROW.magnet_icon_size(ctx)
        icon_font = icon_font or bundle.font
    end
    DRAWING.drawWidgetPillChipLeadingIcon(ctx, coords, draw_list, rect, label, btn_txt, btn_bg, {
        active = opts.active == true,
        filled = opts.filled ~= false,
        hover = hover and not opts.active,
        disabled = opts.disabled,
        rounding = opts.rounding or ROW.CHIP_ROUND,
        text_y_offset = opts.text_y_offset or 0,
        icon_font = icon_font,
        icon_char = opts.icon_char,
        icon_sz = icon_sz,
        icon_gap = opts.icon_gap or DEFAULT_ICON_GAP,
        alpha_factor = opts.alpha_factor,
    })
end

function M.host_readout_row(get_label, opts)
    opts = opts or {}
    return {
        toolbar_only = true,
        segments = {
            {
                type = "readout",
                get_label = get_label,
                min_width = opts.min_width,
                pad_x = opts.pad_x,
            },
        },
    }
end

function M.host_toggle_row(toggle_seg)
    return {
        toolbar_only = true,
        segments = { toggle_seg },
    }
end

function M.slide_multiswitch(modes, get_active, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    return {
        slide_only = true,
        segments = {
            {
                type = "multiswitch",
                modes = modes,
                min_chip_w = opts.min_chip_w,
                rows = opts.rows,
                get_active = get_active,
                on_click = on_click,
            },
        },
    }
end

function M.slide_multi_toggle(modes, is_on, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    return {
        slide_only = true,
        segments = {
            {
                type = "multiswitch",
                modes = modes,
                multi_toggle = true,
                min_chip_w = opts.min_chip_w,
                rows = opts.rows,
                is_on = is_on,
                on_click = on_click,
            },
        },
    }
end

--- Independent pill toggles (no shared multiswitch track, no merged selection).
function M.slide_toggle_chips(modes, is_on, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    local segments = {}
    for _, mode in ipairs(modes) do
        local id = mode.id
        local caption = mode.short_label or mode.label or id
        segments[#segments + 1] = {
            type = "toggle",
            label = caption,
            min_width = opts.min_chip_w or 40,
            get_label = function()
                return caption
            end,
            get_state = function(self)
                return is_on(self, id)
            end,
            on_click = function(self)
                on_click(self, id)
            end,
        }
    end
    return {
        slide_only = true,
        segments = segments,
    }
end

function M.slide_action_row(modes, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    return {
        slide_only = true,
        segments = {
            {
                type = "multiswitch",
                modes = modes,
                multi_toggle = true,
                min_chip_w = opts.min_chip_w,
                rows = opts.rows,
                is_on = function()
                    return false
                end,
                on_click = on_click,
            },
        },
    }
end

return M
