-- Utils/Widget/spinner_slide_out.lua
-- Spinner toolbar (+ optional pitch chip) with preset multiswitch in slide-out.

local HOST = require("Utils.Widget.spinner_slide_out_host")
local ROW = require("Utils.Chips.chip_row")
local SPINNER = require("Utils.Chips.chip_spinner")

local M = {}

function M.layout_spinner_area(ctx, render_width, readout_w, show_spinner, show_pitch, is_vertical, ms_gap)
    ms_gap = ms_gap or 6
    local w_minus = show_spinner ~= false and SPINNER.side_button_width(ctx, "-") or 0
    local w_plus = show_spinner ~= false and SPINNER.side_button_width(ctx, "+") or 0
    local spin_total = show_spinner ~= false and (w_minus + ms_gap + readout_w + ms_gap + w_plus) or 0

    local linear_w = 0
    if show_spinner ~= false then
        linear_w = linear_w + spin_total
    end
    if show_pitch ~= false then
        linear_w = linear_w + (linear_w > 0 and ms_gap or 0) + 26
    end

    local should_stack = false
    local inset = ROW.button_rounding_content_pad()
    if is_vertical and linear_w > 0 and render_width < (linear_w + 2 * inset) then
        should_stack = true
    end

    if should_stack then
        local top_w = 0
        if show_spinner ~= false then
            top_w = w_minus + ms_gap + w_plus
        end

        local bot_w = 0
        if show_spinner ~= false then
            bot_w = bot_w + readout_w
        end
        if show_pitch ~= false then
            bot_w = bot_w + (bot_w > 0 and ms_gap or 0) + 26
        end

        return {
            stacked = true,
            w = math.max(top_w, bot_w),
            top_w = top_w,
            bot_w = bot_w,
            w_minus = w_minus,
            w_plus = w_plus,
            spin_total = spin_total,
            rw = readout_w,
            ms_gap = ms_gap,
        }
    end

    return {
        stacked = false,
        w = linear_w,
        spin_total = spin_total,
        w_minus = w_minus,
        w_plus = w_plus,
        rw = readout_w,
        ms_gap = ms_gap,
    }
end

function M.stacked_spinner_rows(rel_y, chip_h, layout)
    return ROW.toolbar_two_row_stack(rel_y, ROW.widget_body_height(layout), chip_h)
end

M._toolbar_body_h = function(layout)
    return ROW.widget_body_height(layout)
end

function M.new(spec)
    return HOST.new(spec, M)
end

return M
