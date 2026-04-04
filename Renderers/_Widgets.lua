-- Renderers/_Widgets.lua

local renderSliderWidget = require("Renderers._Widgets_slider")
local renderKnobWidget = require("Renderers._Widgets_knob")

local widgetChipRow = require("Renderers._Widgets_chip_row")

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

local function renderDisplayWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local height = CONFIG.SIZES.HEIGHT

    -- Check for custom rendering first
    if widget.renderCustom then
        widget.renderCustom(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        return
    end

    local value = widget.value
    local default_fmt = type(value) == "number" and "%.2f" or "%s"
    local text = UTILS.safeFormat(widget.format or default_fmt, value or 0)

    local text_width = reaper.ImGui_CalcTextSize(ctx, text)
    local text_rel_x = rel_x + (render_width - text_width) / 2
    local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2 + 7
    
    local text_x, text_y = coords:relativeToDrawList(text_rel_x, text_rel_y)
    
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, text)

    if widget.label and widget.label ~= "" then
        local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
        local label_rel_x = rel_x + (render_width - label_width) / 2
        local label_rel_y = rel_y + 1
        
        local label_x, label_y = coords:relativeToDrawList(label_rel_x, label_rel_y)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
    end
end

local function renderDropdownWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT

    local display_text = widget.selected_text or widget.placeholder or "Select..."
    
    local text_rel_x = rel_x + 8
    local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    
    local text_x, text_y = coords:relativeToDrawList(text_rel_x, text_rel_y)
    
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, display_text)

    local arrow_size = 8
    local arrow_rel_x = rel_x + render_width - arrow_size - 8
    local arrow_rel_y = rel_y + height / 2
    
    local arrow_x, arrow_y = coords:relativeToDrawList(arrow_rel_x, arrow_rel_y)
    
    DRAWING.triangle(draw_list, arrow_x, arrow_y, arrow_size, arrow_size, text_color, DRAWING.ANGLE_DOWN)

    if widget.label and widget.label ~= "" then
        local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        local label_rel_x = rel_x + 4
        local label_rel_y = rel_y + 1
        
        local label_x, label_y = coords:relativeToDrawList(label_rel_x, label_rel_y)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
    end
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

local function updateWidgetValue(widget)
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

    local widget = button.widget

    if button.atb_controller_id then
        widget._atb_controller_id = button.atb_controller_id
    end
    widget._button_instance_id = button.instance_id

    updateWidgetValue(widget)

    local render_width = layout and layout.width or widget.width

    local sub_hit = nil
    if not preview_mode and widget.hitTestSubcontrols then
        sub_hit = widget.hitTestSubcontrols(widget, ctx, coords, rel_x, rel_y, render_width, layout)
    end

    -- Get text color from the parent button's color settings (chip widgets: no hover/click tint — chips handle feedback)
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = BUTTON_UTILS.colorMouseKeyForButton(button, C.Interactions:determineMouseKey(is_hovered, is_clicked))
    local bg_color, _, _, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    if not preview_mode then
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
                local ok, handled = pcall(widget.onSubcontrolClick, widget, sub_hit)
                subcontrol_handled = ok and handled ~= false
                if subcontrol_handled then
                    refreshWidgetValueFromReaper(widget)
                end
            end

            if widget.onClick and (not sub_hit or not subcontrol_handled) then
                pcall(widget.onClick, widget, sub_hit)
            end
        end

        if reaper.ImGui_IsMouseClicked(ctx, 1) and is_hovered then
            if sub_hit and widget.onRightClickSubcontrol then
                pcall(widget.onRightClickSubcontrol, widget, sub_hit, button)
            elseif widget.onRightClick and (not sub_hit or not widget.onRightClickSubcontrol) then
                pcall(widget.onRightClick, widget, button)
            end
        end

        if not preview_mode and widget.onMouseWheel and is_hovered then
            local wheel = reaper.ImGui_GetMouseWheel(ctx)
            if wheel ~= 0 then
                pcall(widget.onMouseWheel, widget, wheel)
            end
        end
    end

    if widget.type == "display" then
        renderDisplayWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        if not preview_mode and widget.onWidgetFrame then
            pcall(widget.onWidgetFrame, widget, ctx, button)
        end
        return true, render_width

    elseif widget.type == "colour_swatch" then
        if widget.renderColourSwatch then
            widget.renderColourSwatch(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        end
        return true, render_width
        
    elseif widget.type == "slider" then
        if widget.slider_style == "knob" then
            renderKnobWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color, preview_mode)
        else
            renderSliderWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, preview_mode, layout, bg_color)
        end
        if not preview_mode and widget.onWidgetFrame then
            pcall(widget.onWidgetFrame, widget, ctx, button)
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