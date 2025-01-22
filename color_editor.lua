-- color_editor.lua
local CONFIG = require "Advanced Toolbars - User Config"

local ColorEditor = {}
ColorEditor.__index = ColorEditor

function ColorEditor.new(reaper, helpers)
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

function ColorEditor:renderColorInColumn(ctx, key, value, current_path)
    local display_name = key:gsub("_", " "):gsub("^%l", string.upper)

    self.r.ImGui_PushID(ctx, current_path)
    self:renderColorButton(ctx, value, current_path)
    self.r.ImGui_SameLine(ctx)
    if self.r.ImGui_Selectable(ctx, display_name, self.selected_color_path == current_path) then
        self.selected_color_path = current_path
        self.current_color = self.helpers.hexToImGuiColor(value)
    end
    self.r.ImGui_PopID(ctx)
end

function ColorEditor:renderColorCategory(ctx, category_name, colors)
    self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_ChildRounding(), 5)
    self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_ChildBorderSize(), 1)

    local child_flags = self.r.ImGui_ChildFlags_Border() | self.r.ImGui_ChildFlags_AutoResizeY()

    if self.r.ImGui_BeginChild(ctx, "category_" .. category_name, -1, 0, child_flags) then
        local display_name = category_name:gsub("_", " "):gsub("^%l", string.upper)
        self.r.ImGui_TextDisabled(ctx, display_name)
        self.r.ImGui_Separator(ctx)
        self.r.ImGui_Spacing(ctx)

        for key, value in pairs(colors) do
            if type(value) == "table" then
                self:renderNestedGroup(ctx, category_name, key, value, 0)
            else
                self:renderColorInColumn(ctx, key, value, category_name .. "." .. key)
            end
            self.r.ImGui_Spacing(ctx)
        end

        self.r.ImGui_EndChild(ctx)
    end

    self.r.ImGui_PopStyleVar(ctx, 2)
end

function ColorEditor:renderNestedGroup(ctx, category_name, group_key, group_value, x_offset)
    local group_name = group_key:gsub("_", " "):gsub("^%l", string.upper)
    self.r.ImGui_TextDisabled(ctx, group_name)
    self.r.ImGui_Indent(ctx, 10)

    for subkey, subvalue in pairs(group_value) do
        local display_subkey = subkey == "BG" and "Background" or subkey
        local nested_path = category_name .. "." .. group_key .. "." .. subkey
        self:renderColorInColumn(ctx, display_subkey, subvalue, nested_path)
        self.r.ImGui_Spacing(ctx)
    end

    self.r.ImGui_Unindent(ctx, 10)
end

function ColorEditor:collectTopLevelColors(colors)
    local top_level = {}
    for key, value in pairs(colors) do
        if type(value) ~= "table" then
            top_level[key] = value
        end
    end
    return top_level
end

function ColorEditor:render(ctx, saveCallback)
    if not self.is_open then
        return
    end

    local window_flags =    self.r.ImGui_WindowFlags_NoDocking() | 
                            self.r.ImGui_WindowFlags_NoScrollbar() |
                            self.r.ImGui_WindowFlags_NoResize() |
                            self.r.ImGui_WindowFlags_NoCollapse()

    local visible, open = self.r.ImGui_Begin(ctx, "Color Editor", true, window_flags)
    self.is_open = open

    if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
        self.is_open = false
    end

    if visible then
        local total_width = 800
        local column_width = total_width / 2 - 10

        self.r.ImGui_BeginChild(ctx, "colors_list", column_width, 400)

        local top_level_colors = self:collectTopLevelColors(CONFIG.COLORS)
        if next(top_level_colors) then
            self:renderColorCategory(ctx, "General", top_level_colors)
            self.r.ImGui_Spacing(ctx)
        end

        for key, value in pairs(CONFIG.COLORS) do
            if type(value) == "table" then
                self:renderColorCategory(ctx, key, value)
                self.r.ImGui_Spacing(ctx)
            end
        end

        self.r.ImGui_EndChild(ctx)

        self.r.ImGui_SameLine(ctx)
        self.r.ImGui_BeginChild(ctx, "color_picker", column_width, 400)

        if self.selected_color_path then
            local flags =
                self.r.ImGui_ColorEditFlags_AlphaBar() | self.r.ImGui_ColorEditFlags_PickerHueBar() |
                self.r.ImGui_ColorEditFlags_DisplayRGB() |
                self.r.ImGui_ColorEditFlags_NoSidePreview() |
                self.r.ImGui_ColorEditFlags_DisplayHex()

            local changed, new_color = self.r.ImGui_ColorPicker4(ctx, "##picker", self.current_color, flags)
            if changed then
                self:updateColorConfig(new_color, saveCallback)
            end
        else
            self.r.ImGui_SetCursorPos(ctx, column_width / 2 - 50, 180)
            self.r.ImGui_TextDisabled(ctx, "Select a color to edit")
        end

        self.r.ImGui_EndChild(ctx)
    end

    self.r.ImGui_End(ctx)
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

    -- Handle both nested and top-level colors
    if #path_parts == 2 then
        -- For top-level colors (e.g., "General.SHADOW")
        CONFIG.COLORS[path_parts[2]] = hex_color
    else
        -- For nested colors (e.g., "NORMAL.BG.HOVER")
        local current = CONFIG.COLORS
        for i = 1, #path_parts - 1 do
            if not current[path_parts[i]] then
                current[path_parts[i]] = {}
            end
            current = current[path_parts[i]]
        end
        current[path_parts[#path_parts]] = hex_color
    end

    saveCallback()
end

return {
    new = function(reaper, helpers)
        return ColorEditor.new(reaper, helpers)
    end
}
