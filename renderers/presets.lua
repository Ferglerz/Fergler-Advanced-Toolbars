-- renderers/presets.lua
local ColorUtils = require "color_utils"

local PresetRenderer = {}
PresetRenderer.__index = PresetRenderer

function PresetRenderer.new(reaper, helpers)
    local self = setmetatable({}, PresetRenderer)
    self.r = reaper
    self.helpers = helpers
    self.ColorUtils = ColorUtils
    return self
end

function PresetRenderer:renderPreset(ctx, button, pos_x, pos_y, width, window_pos, draw_list)
    if not button.preset then
        return false -- Not handled
    end

    local preset = button.preset

    -- Update preset value
    local current_time = self.r.time_precise()
    local should_update = (current_time - (preset.last_update_time or 0) >= (preset.update_interval or 0.5))

    if should_update and preset.getValue then
        local success, value = pcall(preset.getValue, self.r)
        if success then
            preset.value = value
        end
        preset.last_update_time = current_time
    end

    -- Get text color
    local text_color = self.ColorUtils.toImGuiColor(CONFIG.COLORS.NORMAL.TEXT.NORMAL)
    if button.is_hovered then
        text_color = self.ColorUtils.toImGuiColor(CONFIG.COLORS.NORMAL.TEXT.HOVER)
    end

    -- Render based on type
    if preset.type == "display" then
        local height = CONFIG.SIZES.HEIGHT
        local x1 = window_pos.x + pos_x
        local y1 = window_pos.y + pos_y
        local render_width = width

        -- Format the value
        local text = string.format(preset.format or "%.2f", preset.value or 0)

        -- Draw the value text
        local text_width = self.r.ImGui_CalcTextSize(ctx, text)
        local text_x = x1 + (render_width - text_width) / 2
        local text_y = y1 + (height - self.r.ImGui_GetTextLineHeight(ctx)) / 2

        self.r.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, text)

        -- Draw label if exists
        if preset.label and preset.label ~= "" then
            local label_color = self.ColorUtils.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
            local label_width = self.r.ImGui_CalcTextSize(ctx, preset.label)
            local label_x = x1 + (render_width - label_width) / 2
           local label_y = y1 + 4

           self.r.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, preset.label)
       end

       return true, render_width
   elseif preset.type == "slider" then
       local height = CONFIG.SIZES.HEIGHT
       local x1 = window_pos.x + pos_x
       local y1 = window_pos.y + pos_y
       local render_width = width
       local x2 = x1 + render_width

       -- Slider track
       local slider_bg = 0x222222FF -- Slider background

       -- Get slider fill color directly
       local slider_fill
       if type(preset.col_primary) == "function" then
           -- Call the function to get the color value
           local nativeColor = preset.col_primary(self.r)
           slider_fill = self.ColorUtils.toImGuiColor(nativeColor)
       else
           -- Use as direct color if it's not a function
           slider_fill = self.ColorUtils.toImGuiColor(preset.col_primary or "#888888FF")
       end

       local slider_handle = text_color & 0xFFFFFF00 | 0xFF -- Use text color for handle

       -- Render track
       local track_height = 8
       local track_y = y1 + (height - track_height) / 2 + 5 -- Moved down 5 pixels
       local track_x1 = x1 + 10
       local track_x2 = x2 - 10

       self.r.ImGui_DrawList_AddRectFilled(
           draw_list,
           track_x1,
           track_y,
           track_x2,
           track_y + track_height,
           slider_bg,
           track_height / 2
       )

       -- Calculate normalized value
       local range = (preset.max_value or 1) - (preset.min_value or 0)
       local normalized = range ~= 0 and ((preset.value or 0) - (preset.min_value or 0)) / range or 0
       normalized = math.max(0, math.min(1, normalized))

       -- Slider fill
       local fill_width = (track_x2 - track_x1) * normalized
       self.r.ImGui_DrawList_AddRectFilled(
           draw_list,
           track_x1,
           track_y,
           track_x1 + fill_width,
           track_y + track_height,
           slider_fill,
           track_height / 2
       )

       -- Slider handle
       local handle_radius = track_height - 1
       local handle_x = track_x1 + fill_width
       local handle_y = track_y + track_height / 2

       self.r.ImGui_DrawList_AddCircleFilled(draw_list, handle_x, handle_y, handle_radius, slider_handle)

       -- Format value and draw at top left
       local text = string.format(preset.format or "%.2f", preset.value or 0)
       local text_color_half = text_color & 0xFFFFFF00 | 0x80

       self.r.ImGui_DrawList_AddText(draw_list, x1 + 4, y1 + 4, text_color_half, text)

       -- Draw label at top right if exists
       if preset.label and preset.label ~= "" then
           local label_width = self.r.ImGui_CalcTextSize(ctx, preset.label)
           self.r.ImGui_DrawList_AddText(draw_list, x2 - label_width - 4, y1 + 4, text_color_half, preset.label)
       end

       -- Handle slider interaction
       local is_active = self.r.ImGui_IsItemActive(ctx)

       if is_active and preset.setValue then
           local mouse_x = self.r.ImGui_GetMousePos(ctx)
           local new_normalized = (mouse_x - track_x1) / (track_x2 - track_x1)
           new_normalized = math.max(0, math.min(1, new_normalized))

           local new_value = (preset.min_value or 0) + new_normalized * range

           -- Only update if value changed
           if math.abs(new_value - (preset.value or 0)) > 0.0001 then
               preset.value = new_value
               -- Call setValue
               pcall(preset.setValue, self.r, new_value)
           end
       end

       if self.r.ImGui_IsItemHovered(ctx) and self.r.ImGui_IsMouseDoubleClicked(ctx, 0) then
           -- Check if preset has a default_value defined
           if preset.default_value ~= nil then
               -- Set to default value
               preset.value = preset.default_value
               -- Call setValue with default value
               pcall(preset.setValue, self.r, preset.default_value)
           end
       end

       return true, render_width
   end

   return false -- Not handled
end

return {
   new = function(reaper, helpers)
       return PresetRenderer.new(reaper, helpers)
   end
}