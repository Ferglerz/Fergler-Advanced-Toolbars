-- Renderers/03_Button/content.lua
-- Button content rendering (shadow, background, icon, text, widget)

local widgetTitle = require("Utils.Widget.widget_title")
local KNOB_LAYOUT = require("Utils.Widget.knob_layout")

function ButtonRenderer:getRoundingFlags(button, is_vertical)
    if not CONFIG.UI.USE_GROUPING or button.is_alone then
        return reaper.ImGui_DrawFlags_RoundCornersAll()
    end

    if button:isSeparator() then
        return reaper.ImGui_DrawFlags_RoundCornersNone()
    end

    if button.is_visual_section_start and button.is_visual_section_end then
        return reaper.ImGui_DrawFlags_RoundCornersAll()
    elseif button.is_visual_section_start then
        if is_vertical then
            return reaper.ImGui_DrawFlags_RoundCornersTop()
        end
        return reaper.ImGui_DrawFlags_RoundCornersLeft()
    elseif button.is_visual_section_end then
        if is_vertical then
            return reaper.ImGui_DrawFlags_RoundCornersBottom()
        end
        return reaper.ImGui_DrawFlags_RoundCornersRight()
    end

    return reaper.ImGui_DrawFlags_RoundCornersNone()
end

function ButtonRenderer:renderBackground(draw_list, button, rel_x, rel_y, width, bg_color, border_color, coords, is_vertical, content_height, ctx)
    local flags = self:getRoundingFlags(button, is_vertical)
    local h = content_height or CONFIG.SIZES.HEIGHT

    local x1_rel, x2_rel = rel_x, rel_x + width

    if button.widget and button.widget.slider_style == "simple_knob" then
        local edge_pad = 0
        local radius = math.max(6, (h - 2 * edge_pad) / 2)
        local direction = button.widget.knob_bg_direction or "right"
        local readout_pad = KNOB_LAYOUT.readout_outer_pad(ctx, h)
        local cx_rel
        if direction == "left" then
            cx_rel = rel_x + edge_pad + radius
            x1_rel = cx_rel
            x2_rel = rel_x + width
            flags = reaper.ImGui_DrawFlags_RoundCornersRight()
        else
            cx_rel = rel_x + width - edge_pad - radius
            x1_rel = rel_x
            x2_rel = cx_rel
            flags = reaper.ImGui_DrawFlags_RoundCornersLeft()
        end
    end

    local w = x2_rel - x1_rel
    DRAWING.drawChipBackground(coords, draw_list, x1_rel, rel_y, w, h, bg_color, {
        rounding = CONFIG.SIZES.ROUNDING,
        flags = flags,
        border_color = border_color
    })
end

function ButtonRenderer:applyDragPreviewColors(bg_color, border_color, icon_color, text_color, button)
    if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() and button.parent_group == C.DragDropManager:getDragSourceGroup() then
        return bg_color & 0xFFFFFF88, border_color & 0xFFFFFF88, icon_color & 0xFFFFFF88, text_color & 0xFFFFFF88
    end
    if C.DragDropManager:isDragging() and C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == button.instance_id then
        return bg_color & 0xFFFFFF88, border_color & 0xFFFFFF88, icon_color & 0xFFFFFF88, text_color & 0xFFFFFF88
    end
    return bg_color, border_color, icon_color, text_color
end

function ButtonRenderer:createButtonContentParams(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    local color_mouse_key = BUTTON_UTILS.colorMouseKeyForButton(button, mouse_key)
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, color_mouse_key)

    if ghost_mode then
        bg_color = COLOR_UTILS.ghostTint(bg_color)
        border_color = COLOR_UTILS.ghostTint(border_color)
        icon_color = COLOR_UTILS.ghostTint(icon_color)
        text_color = COLOR_UTILS.ghostTint(text_color)
    else
        bg_color, border_color, icon_color, text_color = self:applyDragPreviewColors(bg_color, border_color, icon_color, text_color, button)
    end

    return {
        ctx = ctx,
        button = button,
        position = {x = rel_x, y = rel_y},
        coords = coords,
        draw_list = draw_list,
        editing_mode = editing_mode,
        layout = layout,
        is_vertical = is_vertical,
        ghost_mode = ghost_mode == true,
        colors = {
            bg = bg_color,
            border = border_color,
            icon = icon_color,
            text = text_color
        },
        interaction = {
            clicked = clicked,
            hovered = is_hovered,
            clicked_state = is_clicked
        }
    }
end

function ButtonRenderer:renderButtonContent(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    local params = self:createButtonContentParams(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    return self:renderButtonContentWithParams(params)
end

function ButtonRenderer:renderButtonContentWithParams(params)
    local bg_h = params.layout.height

    local hide_chrome = params.button.hide_bg_shadow == true

    if not hide_chrome and CONFIG.SIZES.DEPTH > 0 and params.ghost_mode ~= true then
        local flags = self:getRoundingFlags(params.button, params.is_vertical)
        local shadow_x, shadow_w = params.position.x, params.layout.width

        if params.button.widget and params.button.widget.slider_style == "simple_knob" then
            local edge_pad = 0
            local readout_pad = KNOB_LAYOUT.readout_outer_pad(params.ctx, params.layout.height)
            local radius = math.max(6, (params.layout.height - 2 * edge_pad) / 2)
            local direction = params.button.widget.knob_bg_direction or "right"
            local cx_rel
            if direction == "left" then
                cx_rel = shadow_x + edge_pad + radius
                shadow_x = cx_rel
                shadow_w = params.layout.width - (cx_rel - params.position.x)
                flags = reaper.ImGui_DrawFlags_RoundCornersRight()
            else
                cx_rel = shadow_x + params.layout.width - edge_pad - radius
                shadow_x = shadow_x
                shadow_w = cx_rel - shadow_x
                flags = reaper.ImGui_DrawFlags_RoundCornersLeft()
            end
        end

        self:renderShadow(params.draw_list, shadow_x, params.position.y, shadow_w, bg_h, flags, params.coords)
    end

    if not hide_chrome then
        self:renderBackground(
            params.draw_list,
            params.button,
            params.position.x,
            params.position.y,
            params.layout.width,
            params.colors.bg,
            params.colors.border,
            params.coords,
            params.is_vertical,
            bg_h,
            params.ctx
        )
    end

    local edit_hover = params.editing_mode and params.interaction.hovered and not C.DragDropManager:isDragging()
    local is_knob_widget = BUTTON_UTILS.isKnobWidget(params.button.widget)
    local widget_handled = false
    local widget_width = params.layout.width
    if BUTTON_UTILS.hasWidget(params.button)
        and params.ghost_mode ~= true
        and (not edit_hover or is_knob_widget) then
        local title_h = params.layout.title_height or 0
        local content_y = params.position.y
        if params.is_vertical and title_h > 0 then
            content_y = params.position.y + title_h
        end
        if title_h > 0 then
            local title_y = params.position.y
            if not params.is_vertical then
                title_y = params.position.y - title_h
            end
            widgetTitle.draw(
                params.ctx,
                params.button.widget,
                params.position.x,
                title_y,
                params.layout.width,
                params.coords,
                params.draw_list,
                {
                    is_vertical = params.is_vertical,
                    lines = params.layout.title_lines,
                }
            )
        end
        local handled, width = C.WidgetRenderer:renderWidget(
            params.ctx,
            params.button,
            params.position.x,
            content_y,
            params.coords,
            params.draw_list,
            params.layout,
            params.interaction.clicked,
            params.interaction.hovered,
            params.interaction.clicked_state,
            {
                edit_bg_only = params.editing_mode and is_knob_widget,
            }
        )
        if handled then
            widget_handled = true
            widget_width = width
        end
    end

    if edit_hover and not params.button.is_empty_toolbar_placeholder and params.ghost_mode ~= true then
        self:renderEditMode(
            params.ctx,
            params.position.x,
            params.position.y,
            params.layout.width,
            bg_h,
            params.coords,
            params.draw_list,
            params.colors.bg,
            params.colors.text,
            params.button
        )
    elseif not widget_handled then
        local extra_padding = BUTTON_UTILS.getExtraPadding(params.button)
        local icon_params = C.ButtonContent:createIconParams(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            C.IconSelector,
            params.colors.icon,
            params.layout.width,
            extra_padding,
            params.coords,
            params.draw_list
        )
        local icon_width = C.ButtonContent:renderIconWithParams(icon_params)

        local text_params = C.ButtonContent:createTextParams(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            params.colors.text,
            params.layout.width,
            icon_width,
            extra_padding,
            params.editing_mode,
            params.coords,
            params.draw_list
        )
        C.ButtonContent:renderTextWithParams(text_params)
    end

    return widget_handled and widget_width or params.layout.width
end

function ButtonRenderer:renderShadow(draw_list, rel_x, rel_y, width, height, flags, coords)
    if not self.cached_shadow_color then
        self.cached_shadow_color = CONFIG_MANAGER:color("SHADOW")
    end

    DRAWING.drawRectFilledRelative(coords, draw_list, rel_x + CONFIG.SIZES.DEPTH, rel_y + CONFIG.SIZES.DEPTH, width, height, self.cached_shadow_color, CONFIG.SIZES.ROUNDING, flags)
end
