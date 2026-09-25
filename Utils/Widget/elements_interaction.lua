-- Utils/Widget/elements_interaction.lua
-- Shared slider/knob drag interaction, snapping, and tooltips.

local M = {}
local CALLBACKS = require("Utils.Widget.widget_callbacks")

function M.applySnapping(new_value, widget, min_v, max_v)
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

function M.sliderTooltipFineMode(ctx, widget)
    if widget.last_shift_state then
        return true
    end
    local key_mods = reaper.ImGui_GetKeyMods(ctx)
    return (key_mods & reaper.ImGui_Mod_Shift()) ~= 0
end

function M.showSliderDragTooltip(ctx, widget)
    if not widget.slider_drag_tooltip or not reaper.ImGui_IsItemActive(ctx) then
        return
    end
    reaper.ImGui_BeginTooltip(ctx)
    reaper.ImGui_Text(ctx, UTILS.formatWidgetValue(widget, nil, {
        tooltip = true,
        fine_mode = M.sliderTooltipFineMode(ctx, widget),
    }))
    reaper.ImGui_EndTooltip(ctx)
end

function M.handleDragInteraction(ctx, widget, coords, is_disabled, range, min_v, max_v, interaction_type, param1, param2)
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
            new_value = M.applySnapping(new_value, widget, min_v, max_v)
        end

        if math.abs(new_value - (widget.value or 0)) > 0.0001 then
            widget.value = new_value
            CALLBACKS.setValue(widget, new_value)
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
            CALLBACKS.setValue(widget, widget.default_value)

            -- Clear drag state so holding after double-click drags from the default value
            widget.last_slider_value = nil
            widget.drag_start_pos = nil
            widget.last_shift_state = nil
            widget.slider_drag_start_x = nil
            widget.knob_drag_start_y = nil
        end
    end
end

return M
