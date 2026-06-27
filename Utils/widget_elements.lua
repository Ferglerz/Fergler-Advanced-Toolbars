-- Utils/widget_elements.lua
-- A unified library of widget component tools (like HTML elements).
-- Contains both rendering and interaction logic for sliders, knobs, buttons, and displays.

local M = {}

local WIDGET_DRAW = require("Renderers.Widgets.common_draw")
local CHIP_MS = require("Utils.chip_multiswitch")
local DRAWING = require("Utils.drawing")
local KNOB_LAYOUT = require("Utils.knob_layout")

-- 1. Text Display readout
function M.display(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color)
    local height = render_height or CONFIG.SIZES.HEIGHT or 24
    local text = UTILS.formatWidgetValue(widget)
    DRAWING.drawWidgetValueWithLabel(ctx, widget, rel_x, rel_y, render_width, height, coords, draw_list, text_color, text)
end

-- 2. Dropdown Selector element
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

-- Helper to apply snapping to slider values
local function applySnapping(new_value, widget, min_v, max_v)
    if widget.snap_points then
        local best = new_value
        local dist = math.huge
        for _, pt in ipairs(widget.snap_points) do
            local d = math.abs(new_value - pt)
            if d < dist then
                dist = d
                best = pt
            end
        end
        new_value = best
    elseif widget.snap_increment then
        new_value = math.floor(new_value / widget.snap_increment + 0.5) * widget.snap_increment
        new_value = math.max(min_v, math.min(max_v, new_value))
    end
    return new_value
end

local function handleDragInteraction(ctx, widget, coords, is_disabled, range, min_v, max_v, interaction_type, param1, param2)
    if is_disabled then return end
    
    local is_active = reaper.ImGui_IsItemActive(ctx)
    if is_active and widget.setValue then
        local mouse_x, mouse_y = coords:getRelativeMouse()
        local key_mods = reaper.ImGui_GetKeyMods(ctx)
        local is_shift_down = (key_mods & reaper.ImGui_Mod_Shift()) ~= 0
        local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0
        if not is_cmd_down then
            if reaper.ImGui_Mod_Shortcut then
                is_cmd_down = (key_mods & reaper.ImGui_Mod_Shortcut()) ~= 0
            end
            if not is_cmd_down and reaper.ImGui_Mod_Super then
                is_cmd_down = (key_mods & reaper.ImGui_Mod_Super()) ~= 0
            end
        end

        if not widget.last_slider_value or widget.last_shift_state ~= is_shift_down then
            widget.last_slider_value = widget.value
            if interaction_type == "slider" then
                widget.drag_start_pos = mouse_x
            else
                widget.drag_start_pos = mouse_y
            end
            widget.last_shift_state = is_shift_down
        end

        local new_value
        if interaction_type == "slider" then
            local track_width = param1
            local track_rel_x1 = param2
            local new_normalized
            if is_shift_down then
                local fine_scale = widget.fine_scale or 0.1
                local delta_x = (mouse_x - widget.drag_start_pos) * fine_scale
                new_normalized = ((widget.last_slider_value - min_v) / range) + (delta_x / track_width)
            else
                new_normalized = (mouse_x - track_rel_x1) / track_width
            end
            new_normalized = math.max(0, math.min(1, new_normalized))
            new_value = min_v + new_normalized * range
        else
            local pixels_full = param1
            local delta_y = widget.drag_start_pos - mouse_y
            local fine = widget.fine_scale or 0.1
            local delta_normalized = delta_y / pixels_full
            if is_shift_down then
                delta_normalized = delta_normalized * fine
            end
            new_value = (widget.last_slider_value or 0) + delta_normalized * range
            new_value = math.max(min_v, math.min(max_v, new_value))
        end

        local should_snap = not widget.default_snap_disabled
        if is_cmd_down then should_snap = not should_snap end
        if is_shift_down then should_snap = false end

        if should_snap then
            new_value = applySnapping(new_value, widget, min_v, max_v)
        end

        if math.abs(new_value - (widget.value or 0)) > 0.0001 then
            widget.value = new_value
            pcall(widget.setValue, new_value)
        end
    else
        if widget.last_slider_value then
            widget.last_slider_value = nil
            widget.drag_start_pos = nil
            widget.last_shift_state = nil
            widget.slider_drag_start_x = nil
            widget.knob_drag_start_y = nil
        end
    end

    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
        if widget.default_value ~= nil then
            widget.value = widget.default_value
            pcall(widget.setValue, widget.default_value)
        end
    end
end

-- 3. Horizontal Slider element
function M.slider(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, is_disabled, preview_mode, layout)
    local height = render_height or CONFIG.SIZES.HEIGHT or 24

    local sx, sy, sw = rel_x, rel_y, render_width

    local slider_bg = 0x222222FF
    local slider_fill
    if type(widget.col_primary) == "function" then
        local nativeColor = widget.col_primary()
        if nativeColor == nil then
            slider_fill = 0x888888FF
        else
            slider_fill = COLOR_UTILS.reaperColorToImGui(nativeColor)
        end
    else
        if widget.col_primary then
            slider_fill = COLOR_UTILS.reaperColorToImGui(widget.col_primary)
        else
            slider_fill = 0x888888FF
        end
    end

    if is_disabled then
        slider_bg = 0x1A1A1AFF
        slider_fill = 0x444444FF
        text_color = COLOR_UTILS.setAlpha(text_color, 0x60)
    end

    local slider_handle = COLOR_UTILS.setAlpha(text_color, 0xFF)

    local track_height = 8
    local track_rel_y = sy + (height - track_height) / 2 + 5
    local track_rel_x1 = sx + 10
    local track_rel_x2 = sx + sw - 10
    local track_width = track_rel_x2 - track_rel_x1

    DRAWING.drawRectFilledRelative(coords, draw_list, track_rel_x1, track_rel_y, track_width, track_height, slider_bg, track_height / 2)

    local normalized, range, min_v, max_v = UTILS.widgetSliderNormalized(widget)

    local fill_width = track_width * normalized
    DRAWING.drawRectFilledRelative(coords, draw_list, track_rel_x1, track_rel_y, fill_width, track_height, slider_fill, track_height / 2)

    local handle_radius = track_height - 1
    local handle_rel_x = track_rel_x1 + fill_width
    local handle_rel_y = track_rel_y + track_height / 2

    local handle_x, handle_y = coords:relativeToDrawList(handle_rel_x, handle_rel_y)
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, handle_x, handle_y, handle_radius, slider_handle, 20)

    local show_value_on_toolbar = not (widget._slide_out_mode and widget.slider_quick_chips)
    if show_value_on_toolbar then
        WIDGET_DRAW.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, sx, sy, sw, text_color)
    end

    if not preview_mode then
        local track_width = track_rel_x2 - track_rel_x1
        handleDragInteraction(ctx, widget, coords, is_disabled, range, min_v, max_v, "slider", track_width, track_rel_x1)
    end
end

-- 4. Rotary Knob element (supports both "knob" and "simple_knob" styles)
function M.knob(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, is_disabled, preview_mode, style, bg_only)
    local height = render_height or CONFIG.SIZES.HEIGHT or 24
    style = style or widget.slider_style or "knob"

    local track_bg = 0x222222FF
    local arc_value_color = bg_color or 0x888888FF
    arc_value_color = COLOR_UTILS.setAlpha(arc_value_color, 0xFF)

    if is_disabled then
        track_bg = 0x1A1A1AFF
        arc_value_color = COLOR_UTILS.setAlpha(arc_value_color, 0x55)
        text_color = COLOR_UTILS.setAlpha(text_color, 0x60)
    end

    local normalized, range, min_v, max_v = UTILS.widgetSliderNormalized(widget)

    local is_merged = false
    if not preview_mode and widget._host_button then
        is_merged = CONFIG.UI.USE_GROUPING and not widget._host_button.is_alone
    end
    if preview_mode then
        is_merged = true
    end

    local pad_y = 4
    local edge_pad = (style == "simple_knob" and is_merged) and pad_y or (style == "simple_knob" and 0 or 3)
    
    local radius
    if style == "simple_knob" then
        radius = math.max(6, (height - 2 * edge_pad) / 2)
    else
        local max_r = math.min((render_width - 2 * edge_pad) / 2, (height - 2 * edge_pad) / 2)
        radius = math.max(6, max_r)
    end

    local cx_rel, cy_rel
    local direction = widget.knob_bg_direction or "right"

    if style == "simple_knob" then
        if direction == "left" then
            cx_rel = rel_x + edge_pad + radius
        else
            cx_rel = rel_x + render_width - edge_pad - radius
        end
    else
        cx_rel = rel_x + render_width / 2
    end
    cy_rel = rel_y + height / 2

    local text_area_x, text_area_w = KNOB_LAYOUT.text_area(rel_x, render_width, style, direction, is_merged, height)
    local bg_x1, bg_x2
    if style == "simple_knob" then
        if direction == "left" then
            bg_x1 = cx_rel
            bg_x2 = rel_x + render_width
        else
            bg_x1 = rel_x
            bg_x2 = cx_rel
        end
    end

    local cx, cy = coords:relativeToDrawList(cx_rel, cy_rel)

    -- Draw background flag for simple_knob
    if style == "simple_knob" and is_merged then
        local flag_bg = COLOR_UTILS.setAlpha(track_bg, 0x50)
        local flags = direction == "left" and reaper.ImGui_DrawFlags_RoundCornersRight() or reaper.ImGui_DrawFlags_RoundCornersLeft()
        DRAWING.drawRectFilledRelative(coords, draw_list, bg_x1, rel_y + pad_y, bg_x2 - bg_x1, height - 2 * pad_y, flag_bg, pad_y, flags)
    end

    -- Draw knob body
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, radius, track_bg, 24)
    reaper.ImGui_DrawList_AddCircle(draw_list, cx, cy, radius, COLOR_UTILS.setAlpha(track_bg, 0x55), 0, 1.0)

    if not bg_only then
        -- Lit arc
        local a0 = math.rad(135) + math.rad(90)
        local span = math.rad(270)
        local arc_r = radius - 2
        local dim_arc = COLOR_UTILS.setAlpha(track_bg, 0x35)
        local N = 100
        for j = 0, N - 1 do
            local ang1 = a0 + (j / N) * span
            local ang2 = a0 + ((j + 1) / N) * span
            local x1 = cx + math.sin(ang1) * arc_r
            local y1 = cy - math.cos(ang1) * arc_r
            local x2 = cx + math.sin(ang2) * arc_r
            local y2 = cy - math.cos(ang2) * arc_r
            local lit = (j + 0.5) / N < normalized
            reaper.ImGui_DrawList_AddLine(draw_list, x1, y1, x2, y2, lit and arc_value_color or dim_arc, 3.0)
        end

        -- Pointer
        local pointer_a = a0 + normalized * span
        local pr = radius * 0.72
        local px = cx + math.sin(pointer_a) * pr
        local py = cy - math.cos(pointer_a) * pr
        reaper.ImGui_DrawList_AddLine(draw_list, cx, cy, px, py, arc_value_color, 2.0)

        -- Text value
        WIDGET_DRAW.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, text_area_x, rel_y, text_area_w, text_color)

        if not preview_mode then
            local pixels_full = widget.knob_vertical_pixels or 100
            handleDragInteraction(ctx, widget, coords, is_disabled, range, min_v, max_v, "knob", pixels_full)
        end
    end
end

-- 5. Interactive Chip Button element
function M.button(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, label, text_color, bg_color, is_hovered, is_active, flags)
    local rounding = flags and flags.rounding or 4
    local draw_flags = flags and flags.draw_flags or 0
    
    local fill_color = bg_color or 0x222222FF
    if is_hovered then
        fill_color = COLOR_UTILS.lighten(fill_color, 0.15)
    end
    if is_active then
        fill_color = COLOR_UTILS.lighten(fill_color, 0.3)
    end
    
    DRAWING.drawChipBackground(coords, draw_list, rel_x, rel_y, render_width, render_height, fill_color, {
        rounding = rounding,
        flags = draw_flags,
        border_color = COLOR_UTILS.setAlpha(text_color, 0x25)
    })
    
    if label and label ~= "" then
        DRAWING.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y, render_width, render_height, label, text_color, 0)
    end
end

-- 6. Multiswitch element
function M.multiswitch(ctx, widget, coords, draw_list, text_color, bg_color, chips, opts)
    CHIP_MS.draw(ctx, widget, chips, coords, draw_list, text_color, bg_color, opts)
end

-- 7. Color Swatch element
function M.colour_swatch(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, layout)
    if widget.renderColourSwatch then
        widget.renderColourSwatch(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color, render_height)
    end
end

return M
