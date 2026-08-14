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

local function preview_list_key(list)
    local parts = {}
    for _, e in ipairs(list or {}) do
        parts[#parts + 1] = tostring(e.id)
    end
    return table.concat(parts, ",")
end

local function preview_state_key(self)
    return string.format("%s|%s", self._show_spinner ~= false and "1" or "0", self._show_pitch ~= false and "1" or "0")
end

function M.compute_spinner_layout_at(ctx, self, start_x, rel_y, layout, rw, ms_gap, sp_layout)
    ms_gap = ms_gap or 6
    local chip_h = SPINNER.chip_line_height(ctx)
    local body_h = M._toolbar_body_h(layout)
    local elements_w = sp_layout.w

    local result = {
        sp_layout = sp_layout,
        start_x = start_x,
        elements_w = elements_w,
        rw = rw,
        ms_gap = ms_gap,
        chip_h = chip_h,
        body_h = body_h,
    }

    if sp_layout.stacked then
        result.y_start, result.y_row2 = M.stacked_spinner_rows(rel_y, chip_h, layout)
        if self._show_spinner ~= false then
            local top_x = start_x + (elements_w - sp_layout.top_w) / 2
            result.minus_rect = { x = top_x, y = result.y_start, w = sp_layout.w_minus, h = chip_h }
            result.plus_rect = { x = top_x + sp_layout.w_minus + ms_gap, y = result.y_start, w = sp_layout.w_plus, h = chip_h }
            local bot_x = start_x + (elements_w - sp_layout.bot_w) / 2
            result.readout_rect = { x = bot_x, y = result.y_row2, w = rw, h = chip_h }
            if self._show_pitch ~= false then
                result.pitch_rect = { x = bot_x + rw + ms_gap, y = result.y_row2, w = 26, h = chip_h }
            end
        elseif self._show_pitch ~= false then
            local bot_x = start_x + (elements_w - sp_layout.bot_w) / 2
            result.pitch_rect = { x = bot_x, y = result.y_row2, w = 26, h = chip_h }
        end
    else
        if self._show_spinner ~= false then
            result.minus, result.readout, result.plus = SPINNER.layout_horizontal(ctx, start_x, rel_y, body_h, rw)
            result.spin_end_x = start_x + sp_layout.spin_total + ms_gap
        end
        if self._show_pitch ~= false then
            local pitch_x = self._show_spinner ~= false and (start_x + sp_layout.spin_total + ms_gap) or start_x
            result.pitch_rect = { x = pitch_x, y = rel_y + (body_h - chip_h) / 2, w = 26, h = chip_h }
        end
    end

    return result
end

function M.apply_sp_readout_screen(self, tb)
    if not tb then
        self._sp_readout_screen = nil
        return
    end
    if tb.readout_rect then
        self._sp_readout_screen = {
            rel_x = tb.readout_rect.x,
            rel_y = tb.readout_rect.y,
            w = tb.readout_rect.w,
            h = tb.readout_rect.h,
        }
    elseif tb.readout then
        self._sp_readout_screen = {
            rel_x = tb.readout.x,
            rel_y = tb.readout.y,
            w = tb.readout.w,
            h = tb.readout.h,
        }
    else
        self._sp_readout_screen = nil
    end
end

function M.compute_toolbar_spinner_layout(ctx, self, rel_x, rel_y, render_width, layout, rw, ms_gap)
    ms_gap = ms_gap or 6
    local vert = layout and layout.is_vertical
    local cache_key = string.format("%s|%s|%s|%s|%s", rel_x, rel_y, render_width, rw, vert and "v" or "h")
    local frame = _G.FRAME_TIME
    if frame and self._spin_tb_layout_frame == frame and self._spin_tb_layout_key == cache_key and self._spin_tb_layout_cache then
        return self._spin_tb_layout_cache
    end

    local sp_layout = M.layout_spinner_area(ctx, render_width, rw, self._show_spinner, self._show_pitch, vert, ms_gap)
    local inset = ROW.button_rounding_content_pad()
    local start_x = rel_x + inset + math.max(0, (render_width - 2 * inset - sp_layout.w) / 2)
    local result = M.compute_spinner_layout_at(ctx, self, start_x, rel_y, layout, rw, ms_gap, sp_layout)
    result.current_x = start_x

    if frame then
        self._spin_tb_layout_frame = frame
        self._spin_tb_layout_key = cache_key
        self._spin_tb_layout_cache = result
    end
    return result
end

function M.compute_preview_vertical_layout(ctx, self, rel_x, rel_y, render_width, layout, rw, ms_gap, list, layout_ms_fn)
    ms_gap = ms_gap or 6
    local cache_key = string.format(
        "pv|%s|%s|%s|%s|%s|%s",
        rel_x,
        rel_y,
        render_width,
        rw,
        preview_state_key(self),
        preview_list_key(list)
    )
    local frame = _G.FRAME_TIME
    if frame and self._spin_pv_layout_frame == frame and self._spin_pv_layout_key == cache_key and self._spin_pv_layout_cache then
        return self._spin_pv_layout_cache
    end

    local chips, ms_outer_h = layout_ms_fn(ctx, rel_x, rel_y, render_width, layout, list)
    local extra_y = rel_y + ms_outer_h + ROW.CHIP_GAP
    local tb = M.compute_toolbar_spinner_layout(ctx, self, rel_x, extra_y, render_width, layout, rw, ms_gap)
    local result = {
        chips = chips,
        ms_outer_h = ms_outer_h,
        extra_y = extra_y,
        tb = tb,
    }

    if frame then
        self._spin_pv_layout_frame = frame
        self._spin_pv_layout_key = cache_key
        self._spin_pv_layout_cache = result
    end
    return result
end

function M.compute_preview_horizontal_layout(ctx, self, rel_x, rel_y, render_width, layout, rw, ms_gap, list, layout_ms_fn)
    ms_gap = ms_gap or 6
    local vert = layout and layout.is_vertical
    local cache_key = string.format(
        "ph|%s|%s|%s|%s|%s|%s|%s",
        rel_x,
        rel_y,
        render_width,
        rw,
        vert and "v" or "h",
        preview_state_key(self),
        preview_list_key(list)
    )
    local frame = _G.FRAME_TIME
    if frame and self._spin_ph_layout_frame == frame and self._spin_ph_layout_key == cache_key and self._spin_ph_layout_cache then
        return self._spin_ph_layout_cache
    end

    local sp_layout = M.layout_spinner_area(ctx, render_width, rw, self._show_spinner, self._show_pitch, vert, ms_gap)
    local ms_w = render_width
    local elements_w = sp_layout.w
    if elements_w > 0 then
        ms_w = math.max(40, render_width - elements_w - ms_gap)
    end

    local chips = layout_ms_fn(ctx, rel_x, rel_y, ms_w, layout, list)
    local tb = nil
    if elements_w > 0 and chips and #chips > 0 then
        local last = chips[#chips]
        local start_x = last.x + last.w + ms_gap
        tb = M.compute_spinner_layout_at(ctx, self, start_x, rel_y, layout, rw, ms_gap, sp_layout)
    end

    local result = {
        chips = chips,
        ms_w = ms_w,
        elements_w = elements_w,
        sp_layout = sp_layout,
        tb = tb,
    }

    if frame then
        self._spin_ph_layout_frame = frame
        self._spin_ph_layout_key = cache_key
        self._spin_ph_layout_cache = result
    end
    return result
end

function M.hover_toolbar_spinner_segment(coords, mx, my, tb)
    if tb.sp_layout.stacked then
        if tb.minus_rect and coords:pointInRelativeRect(mx, my, tb.minus_rect.x, tb.minus_rect.y, tb.minus_rect.w, tb.minus_rect.h) then
            return "minus"
        end
        if tb.plus_rect and coords:pointInRelativeRect(mx, my, tb.plus_rect.x, tb.plus_rect.y, tb.plus_rect.w, tb.plus_rect.h) then
            return "plus"
        end
        if tb.readout_rect and coords:pointInRelativeRect(mx, my, tb.readout_rect.x, tb.readout_rect.y, tb.readout_rect.w, tb.readout_rect.h) then
            return "readout"
        end
        return "none"
    end
    if tb.minus then
        return SPINNER.hit_test(mx, my, coords, tb.minus, tb.readout, tb.plus) or "none"
    end
    return "none"
end

function M.hit_toolbar_spinner_layout(coords, mx, my, tb, sp_prefix, pitch_sub_id)
    if tb.sp_layout.stacked then
        if tb.minus_rect and coords:pointInRelativeRect(mx, my, tb.minus_rect.x, tb.minus_rect.y, tb.minus_rect.w, tb.minus_rect.h) then
            return sp_prefix .. "minus"
        end
        if tb.plus_rect and coords:pointInRelativeRect(mx, my, tb.plus_rect.x, tb.plus_rect.y, tb.plus_rect.w, tb.plus_rect.h) then
            return sp_prefix .. "plus"
        end
        if tb.readout_rect and coords:pointInRelativeRect(mx, my, tb.readout_rect.x, tb.readout_rect.y, tb.readout_rect.w, tb.readout_rect.h) then
            return sp_prefix .. "readout"
        end
        if tb.pitch_rect and coords:pointInRelativeRect(mx, my, tb.pitch_rect.x, tb.pitch_rect.y, tb.pitch_rect.w, tb.pitch_rect.h) then
            return pitch_sub_id
        end
    else
        if tb.minus then
            local sp = SPINNER.hit_test(mx, my, coords, tb.minus, tb.readout, tb.plus)
            if sp == "minus" or sp == "plus" then
                return sp_prefix .. sp
            end
        end
        if tb.pitch_rect and coords:pointInRelativeRect(mx, my, tb.pitch_rect.x, tb.pitch_rect.y, tb.pitch_rect.w, tb.pitch_rect.h) then
            return pitch_sub_id
        end
    end
    return nil
end

function M.new(spec)
    return HOST.new(spec, M)
end

return M
