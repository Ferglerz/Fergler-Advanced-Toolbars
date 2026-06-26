-- Renderers/Widgets.lua


local widgetChipRow = require("Renderers.Widgets.chip_row")
local widgetCommonDraw = require("Renderers.Widgets.common_draw")

local WidgetRenderer = {}
WidgetRenderer.__index = WidgetRenderer
WidgetRenderer.chipRow = widgetChipRow

function WidgetRenderer.new()
    local self = setmetatable({}, WidgetRenderer)
    return self
end

-- Call a widget function once with pcall, then cache whether it is safe to call directly.
-- This keeps protection for the first invocation while avoiding pcall overhead on every frame.
local function callWidgetFunction(widget, fn_name, ...)
    local fn = widget and widget[fn_name]
    if not fn then
        return false
    end

    local guard_key = "__guard_" .. fn_name
    local guard_state = widget[guard_key]

    if guard_state == false then
        return false
    end

    if guard_state == true then
        return true, fn(widget, ...)
    end

    local ok, result = pcall(fn, widget, ...)
    widget[guard_key] = ok

    if ok then
        return true, result
    end

    return false
end



local function postRenderWidget(ctx, widget, button, rel_x, rel_y, render_width, layout, coords, draw_list, text_color, bg_color, border_color, is_hovered, custom_slide_render)
    if widget.onWidgetFrame then
        pcall(widget.onWidgetFrame, widget, ctx, button, is_hovered)
    end
    if widget._slide_out_mode then
        local SLIDE_MGR = require("Utils.slide_out_manager")
        local render_height = layout and layout.height or CONFIG.SIZES.HEIGHT or 28
        local ok, err = pcall(SLIDE_MGR.render, ctx, widget, button, rel_x, rel_y, render_width, render_height, coords, draw_list, text_color, bg_color, border_color, layout, custom_slide_render)
        if not ok then
            reaper.ShowConsoleMsg("Advanced Toolbars: slide-out failed ("
                .. tostring(widget.name or widget.display_name)
                .. "): "
                .. tostring(err)
                .. "\n")
        end
    end
end

local function renderDisplayWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local height = CONFIG.SIZES.HEIGHT

    -- Check for custom rendering first
    if widget.renderCustom then
        local ok, err = pcall(
            widget.renderCustom,
            ctx,
            widget,
            rel_x,
            rel_y,
            render_width,
            coords,
            draw_list,
            text_color,
            layout,
            bg_color
        )
        if not ok then
            reaper.ShowConsoleMsg("Advanced Toolbars: widget render failed ("
                .. tostring(widget.name or widget.display_name)
                .. "): "
                .. tostring(err)
                .. "\n")
        end
        return
    end

    WIDGET_ELEMENTS.display(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, height, text_color)
end

local function renderDropdownWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT
    WIDGET_ELEMENTS.dropdown(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, height, text_color)
end

-- Repopulate dropdown items immediately on open (getValue uses throttleScan for scans,
-- which can leave dropdown_menu empty or stale on first frames or rapid clicks).
local function refreshWidgetDropdownMenu(widget)
    if not widget then
        return
    end
    local scan = widget.scanRegions or widget.scanTemplates or widget.scanToolbars or widget.scanMenuItems
    if scan then
        pcall(scan, widget)
    end
end

local function refreshWidgetValueFromReaper(widget)
    if not widget or not widget.getValue then
        return
    end
    local ok, value = callWidgetFunction(widget, "getValue")
    if ok then
        widget.value = value
    end
end

local function shouldPollWidget(ctx, coords, rel_x, rel_y, render_width, layout)
    if not ctx or not coords then
        return true
    end
    -- We removed the hover/focus check here so widgets update globally as long as they are visible
    coords:refreshScroll()
    local sx, sy = coords.scroll_x, coords.scroll_y
    local ww = reaper.ImGui_GetWindowWidth(ctx)
    local wh = reaper.ImGui_GetWindowHeight(ctx)
    local w = render_width or (layout and layout.width) or 0
    local h = widgetChipRow.widget_body_height(layout)
    return rel_x + w > sx and rel_x < sx + ww and rel_y + h > sy and rel_y < sy + wh
end

local function updateWidgetValue(widget, ctx, coords, rel_x, rel_y, render_width, layout)
    if not shouldPollWidget(ctx, coords, rel_x, rel_y, render_width, layout) then
        return
    end
    local current_time = _G.FRAME_TIME or reaper.time_precise()
    local interval = widget.update_interval
    if interval == nil then
        interval = 0.5
    end
    -- First frame: last_update_time is nil — must run getValue immediately so dropdowns
    -- (e.g. region list) populate before the user can click; using 0 here delayed the
    -- first refresh until `interval` seconds had passed.
    local should_update = widget.last_update_time == nil
        or (current_time - widget.last_update_time >= interval)

    if should_update and widget.getValue then
        refreshWidgetValueFromReaper(widget)
        widget.last_update_time = current_time
    end
end

function WidgetRenderer:renderWidget(ctx, button, rel_x, rel_y, coords, draw_list, layout, clicked, is_hovered, is_clicked, opts)
    if not button.widget then
        return false
    end

    opts = opts or {}
    local preview_mode = opts.preview_mode == true
    local edit_bg_only = opts.edit_bg_only == true

    local widget = button.widget

    if button.atb_controller_id then
        widget._atb_controller_id = button.atb_controller_id
    end
    widget._atb_row_index = button.atb_row_index or 0
    widget._button_instance_id = button.instance_id
    if not preview_mode then
        widget._host_button = button
    end

    local render_width = layout and layout.width or widget.width
    updateWidgetValue(widget, ctx, coords, rel_x, rel_y, render_width, layout)

    local sub_hit = nil
    if not preview_mode and widget.hitTestSubcontrols then
        local ok, hit = pcall(widget.hitTestSubcontrols, widget, ctx, coords, rel_x, rel_y, render_width, layout)
        if ok then
            sub_hit = hit
        else
            reaper.ShowConsoleMsg("Advanced Toolbars: widget hitTest failed ("
                .. tostring(widget.name or widget.display_name)
                .. "): "
                .. tostring(hit)
                .. "\n")
        end
    end

    -- Get text color from the parent button's color settings (chip widgets: no hover/click tint — chips handle feedback)
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = BUTTON_UTILS.colorMouseKeyForButton(button, C.Interactions:determineMouseKey(is_hovered, is_clicked))
    local bg_color, border_color, _, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    if not preview_mode then
        if widget._slide_out_mode then
            local SLIDE_MGR = require("Utils.slide_out_manager")
            SLIDE_MGR.update_animation(widget, button, is_hovered)
        end

        -- Handle hover callbacks
        if is_hovered and widget.onHover then
            pcall(widget.onHover, widget)
        elseif not is_hovered and widget.is_hovering then
            widget.is_hovering = false
        end

        -- Handle click callbacks: renderer stays subcontrol-agnostic.
        if clicked then
            local subcontrol_handled = false
            if sub_hit and widget.onSubcontrolClick then
                local ok, handled = pcall(widget.onSubcontrolClick, widget, sub_hit, ctx)
                subcontrol_handled = ok and handled ~= false
                if subcontrol_handled then
                    refreshWidgetValueFromReaper(widget)
                end
            end

            if widget.onClick and (not sub_hit or not subcontrol_handled) then
                pcall(widget.onClick, widget, sub_hit)
            end
        end

        -- Right-click now passes through to the standard Button Settings Menu,
        -- which checks for and renders widget.onSettingsMenu internally.

        if not preview_mode and widget.onMouseWheel and is_hovered then
            local wheel = reaper.ImGui_GetMouseWheel(ctx)
            if wheel ~= 0 then
                pcall(widget.onMouseWheel, widget, wheel)
            end
        end
    end

    if widget.type == "display" then
        renderDisplayWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        if not preview_mode then
            postRenderWidget(ctx, widget, button, rel_x, rel_y, render_width, layout, coords, draw_list, text_color, bg_color, border_color, is_hovered, function(ctx, w, sx, sy, w_slide, sc, dl, tc, l, bc, alpha_factor)
                w._is_rendering_slide_out = true
                w._slide_alpha_factor = alpha_factor
                local rok, rerr = pcall(w.renderCustom, ctx, w, sx, sy, w_slide, sc, dl, tc, l, bc)
                if not rok then
                    reaper.ShowConsoleMsg("Advanced Toolbars: widget slide-out render failed (" .. tostring(w.name or w.display_name) .. "): " .. tostring(rerr) .. "\n")
                end
                w._is_rendering_slide_out = nil
                w._slide_alpha_factor = nil
            end)
        end
        return true, render_width

    elseif widget.type == "colour_swatch" then
        local swatch_h = widgetChipRow.widget_body_height(layout)
        WIDGET_ELEMENTS.colour_swatch(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, swatch_h, text_color, bg_color, layout)
        return true, render_width
        
    elseif widget.type == "slider" then
        local render_height = layout and layout.height or CONFIG.SIZES.HEIGHT or 28
        if widget.renderCustom then
            widget._edit_bg_only = edit_bg_only
            widget.renderCustom(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
            widget._edit_bg_only = nil
        elseif widget.slider_style == "knob" then
            WIDGET_ELEMENTS.knob(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, false, preview_mode, "knob", edit_bg_only)
        elseif widget.slider_style == "simple_knob" then
            WIDGET_ELEMENTS.knob(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, false, preview_mode, "simple_knob", edit_bg_only)
        else
            WIDGET_ELEMENTS.slider(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, false, preview_mode, layout)
        end
        if not preview_mode then
            postRenderWidget(ctx, widget, button, rel_x, rel_y, render_width, layout, coords, draw_list, text_color, bg_color, border_color, is_hovered, function(ctx, w, sx, sy, w_slide, sc, dl, tc, slide_layout, bc, alpha_factor)
                local SLIDER_QC = require("Renderers.Widgets.slider_quick_chips")
                SLIDER_QC.draw_slide_out(ctx, w, sx, sy, w_slide, sc, dl, tc, bc, alpha_factor, slide_layout)
            end)
        end
        return true, render_width
        
    elseif widget.type == "dropdown" then
        if clicked and not preview_mode then
            refreshWidgetDropdownMenu(widget)
            local temp_button = {
                -- Use toolbar button id (stable, no spaces); tostring(widget) breaks ImGui ids ("table: 0x...")
                instance_id = "widget_dropdown_" .. (button.instance_id or "widget"),
                dropdown_menu = widget.dropdown_menu or {},
                display_text = (widget.label and widget.label ~= "") and widget.label
                    or (widget.selected_text or widget.name or "Dropdown Widget"),
                widget_ref = widget,
                dynamic_items = widget.dropdown_menu
            }
            
            local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
            C.Interactions:showDropdownMenu(ctx, temp_button, {x = mouse_x, y = mouse_y})
        end
        
        renderDropdownWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
        return true, render_width
    end

    return false
end

-- Non-interactive draw for widget picker previews (same graphics as the toolbar).
function WidgetRenderer:renderWidgetPreview(ctx, preview_button, rel_x, rel_y, coords, draw_list, layout)
    local fake_layout = {
        width = layout.width,
        height = layout.height or CONFIG.SIZES.HEIGHT,
        extra_padding = layout.extra_padding or 0
    }
    return self:renderWidget(
        ctx,
        preview_button,
        rel_x,
        rel_y,
        coords,
        draw_list,
        fake_layout,
        false,
        false,
        false,
        { preview_mode = true }
    )
end

return WidgetRenderer