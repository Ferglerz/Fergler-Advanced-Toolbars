-- color_editor.lua
local CONFIG = require "Advanced Toolbars - User Config"

local ColorEditor = {}
ColorEditor.__index = ColorEditor

function ColorEditor.new(reaper, helpers)
    local self = setmetatable({}, ColorEditor)
    local self = setmetatable({}, ColorEditor)
    self.r = reaper
    self.helpers = helpers
    self.is_open = false
    self.selected_color_path = nil
    self.current_color = 0
    return self
end

function ColorEditor:renderColorButton(ctx, color_hex, label)
    local color = self.helpers.hexToImGuiColor(color_hex)
    self.r.ImGui_ColorButton(ctx, "##" .. label, color, self.r.ImGui_ColorEditFlags_None(), 20, 20)
end

function ColorEditor:renderColorSection(ctx, colors, path, indent)
    for key, value in pairs(colors) do
        local display_name = key:gsub("_", " "):gsub("^%l", string.upper)
        local current_path = path and (path .. "." .. key) or key

        if type(value) == "table" then
            -- For nested color groups
            if indent > 0 then
                self.r.ImGui_Separator(ctx)
            end
            self.r.ImGui_TextDisabled(ctx, display_name)
            self:renderColorSection(ctx, value, current_path, indent + 1)
        else
            -- For individual colors
            self.r.ImGui_PushID(ctx, current_path)

            if indent > 0 then
                self.r.ImGui_Indent(ctx, 20)
            end

            -- Display color button and label
            self:renderColorButton(ctx, value, current_path)
            self.r.ImGui_SameLine(ctx)
            if self.r.ImGui_Selectable(ctx, display_name, self.selected_color_path == current_path) then
                self.selected_color_path = current_path
                self.current_color = self.helpers.hexToImGuiColor(value)
            end

            if indent > 0 then
                self.r.ImGui_Unindent(ctx, 20)
            end

            self.r.ImGui_PopID(ctx)
        end
    end
end

function ColorEditor:updateColorConfig(new_color, saveCallback)
    -- Update the state
    self.current_color = new_color

    -- Extract RGBA components
    local r = (new_color >> 24) & 0xFF
    local g = (new_color >> 16) & 0xFF
    local b = (new_color >> 8) & 0xFF
    local a = new_color & 0xFF

    -- Format as hex color
    local hex_color = string.format("#%02X%02X%02X%02X", r, g, b, a)

    -- Update the config
    local path_parts = {}
    for part in self.selected_color_path:gmatch("[^.]+") do
        table.insert(path_parts, part)
    end

    local current = CONFIG.COLORS
    for i = 1, #path_parts - 1 do
        current = current[path_parts[i]]
    end
    current[path_parts[#path_parts]] = hex_color

    saveCallback()
end

function ColorEditor:render(ctx, saveCallback)
    if not self.is_open then
        return
    end

    -- Set up window flags
    local window_flags = self.r.ImGui_WindowFlags_NoDocking() | self.r.ImGui_WindowFlags_AlwaysAutoResize()

    -- Begin color editor window
    local visible, open = self.r.ImGui_Begin(ctx, "Color Editor", true, window_flags)
    self.is_open = open

    -- Handle Escape key
    if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
        self.is_open = false
    end

    if not visible then
        self.r.ImGui_End(ctx)
        return
    end

    -- Set content width for both columns
    local total_width = 800
    local column_width = total_width / 2 - 10

    -- Left column - Color list
    self.r.ImGui_BeginChild(ctx, "colors_list", column_width, 400)
    self:renderColorSection(ctx, CONFIG.COLORS, nil, 0)
    self.r.ImGui_EndChild(ctx)

    -- Right column - Color picker
    self.r.ImGui_SameLine(ctx)
    self.r.ImGui_BeginChild(ctx, "color_picker", column_width, 400)

    if self.selected_color_path then
        local flags =
            self.r.ImGui_ColorEditFlags_AlphaBar() | self.r.ImGui_ColorEditFlags_PickerHueBar() |
            self.r.ImGui_ColorEditFlags_DisplayRGB() |
            self.r.ImGui_ColorEditFlags_NoSidePreview() |
            self.r.ImGui_ColorEditFlags_DisplayHex()

        -- Convert color to proper format for ImGui picker
        local changed, new_color = self.r.ImGui_ColorPicker4(ctx, "##picker", self.current_color, flags)

        if changed then
            self:updateColorConfig(new_color, saveCallback)
        end
    else
        -- Show placeholder text when no color is selected
        self.r.ImGui_SetCursorPos(ctx, column_width / 2 - 50, 180)
        self.r.ImGui_TextDisabled(ctx, "Select a color to edit")
    end

    self.r.ImGui_EndChild(ctx)
    self.r.ImGui_End(ctx)
end

return {
    new = function(reaper, helpers)
        return ColorEditor.new(reaper, helpers)
    end
}
