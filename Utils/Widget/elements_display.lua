-- Utils/Widget/elements_display.lua
-- Text display readouts and dropdown selector rendering.

local DRAWING = require("Utils.Draw.drawing")
local PEAK_METERS = require("Utils.Widget.widget_draw_peak_meters")

local M = {}

local function resolve_display_opts(widget)
    local opts = {}
    local value_color = widget.display_value_color
    if type(value_color) == "function" then
        value_color = value_color(widget)
    end
    if value_color then
        opts.value_color = value_color
    end
    if widget.display_truncate then
        opts.truncate = true
        opts.truncate_pad = widget.display_truncate_pad
    end
    if widget.display_vertical_offset ~= nil then
        opts.vertical_offset = widget.display_vertical_offset
    end
    if widget.display_label_rel_y ~= nil then
        opts.label_rel_y = widget.display_label_rel_y
    end
    if widget.display_ellipsis ~= nil then
        opts.ellipsis = widget.display_ellipsis
    end
    return opts
end

local function draw_meter_strip(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, height, text_color, text)
    local meter = widget.display_meter
    if type(meter) == "function" then
        meter = meter(widget)
    end
    meter = meter or {}

    local meter_w = meter.meter_w or 8
    local gap = meter.gap or 2
    local meter_total = meter_w * 2 + gap
    local meter_height = meter.height or math.max(12, height - 8)
    local inner_gap = meter.inner_gap or 6
    local readout_w = reaper.ImGui_CalcTextSize(ctx, text or "")
    local group_w = readout_w + inner_gap + meter_total
    local group_x = rel_x + math.max(0, (render_width - group_w) / 2)
    local meter_y = rel_y + (height - meter_height) / 2
    local meter_x = group_x + readout_w + inner_gap

    PEAK_METERS.draw_stereo_vertical(draw_list, coords, {
        x_left = meter_x,
        y = meter_y,
        meter_w = meter_w,
        gap = gap,
        height = meter_height,
        left_db = meter.left_db,
        right_db = meter.right_db,
        peak_db = meter.peak_db,
        clip_indicator = meter.clip_indicator,
        corner_round = meter.corner_round or 2,
    })

    local opts = resolve_display_opts(widget)
    local value_color = opts.value_color or text_color
    local text_rel_y = DRAWING.centeredTextRelY(ctx, rel_y, height, opts.vertical_offset or 0)
    local text_rel_x = group_x + (readout_w - reaper.ImGui_CalcTextSize(ctx, text or "")) / 2
    DRAWING.drawTextRelative(coords, draw_list, text_rel_x, text_rel_y, value_color, text or "")
end

-- Text Display readout (standard path; use widget.renderCustom for full manual override)
-- display_style: "value_label" (default), "centered", "meter_strip"
function M.display(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, _layout)
    local height = render_height or CONFIG.SIZES.HEIGHT or 24
    local text = UTILS.formatWidgetValue(widget)
    local style = widget.display_style or "value_label"
    local opts = resolve_display_opts(widget)

    if style == "meter_strip" then
        draw_meter_strip(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, height, text_color, text)
        return
    end

    if style == "centered" then
        if widget.display_show_title ~= false and DRAWING.widgetDisplayLabel(widget) ~= "" then
            DRAWING.drawWidgetCenteredLabel(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, opts.label_rel_y)
        end
        local y_off = opts.vertical_offset or 0
        DRAWING.drawWidgetCenteredValueText(ctx, text, rel_x, rel_y, render_width, height, coords, draw_list, opts.value_color or text_color, y_off)
        return
    end

    DRAWING.drawWidgetValueWithLabel(ctx, widget, rel_x, rel_y, render_width, height, coords, draw_list, text_color, text, opts)
end

-- Dropdown Selector element
function M.dropdown(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color)
    local height = render_height or CONFIG.SIZES.HEIGHT or 24
    local display_text = widget.selected_text or widget.placeholder or "Select..."

    local text_rel_x = rel_x + 8
    local text_rel_y = DRAWING.centeredTextRelY(ctx, rel_y, height, 0)

    DRAWING.drawTextRelative(coords, draw_list, text_rel_x, text_rel_y, text_color, display_text)

    local arrow_size = 8
    local arrow_rel_x = rel_x + render_width - arrow_size - 8
    local arrow_rel_y = rel_y + height / 2

    local arrow_x, arrow_y = coords:relativeToDrawList(arrow_rel_x, arrow_rel_y)

    DRAWING.triangle(draw_list, arrow_x, arrow_y, arrow_size, arrow_size, text_color, DRAWING.ANGLE_DOWN)

    DRAWING.drawWidgetLeadingLabel(ctx, widget, rel_x, rel_y, coords, draw_list, 4)
end

return M
