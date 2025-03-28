-- Windows/Global_Color_Editor.lua

local GlobalColorEditor = {}
GlobalColorEditor.__index = GlobalColorEditor

function GlobalColorEditor.new()
    local self = setmetatable({}, GlobalColorEditor)

    self.is_open = false
    self.selected_color_path = nil
    self.current_color = 0
    return self
end

function GlobalColorEditor:renderColorButton(ctx, color_hex, label)
    local color = COLOR_UTILS.hexToImGuiColor(color_hex)
    reaper.ImGui_ColorButton(ctx, "##" .. label, color, reaper.ImGui_ColorEditFlags_None(), 20, 20)
end

function GlobalColorEditor:renderColorInColumn(ctx, key, value, current_path)
    local display_name = key:gsub("_", " "):gsub("^%l", string.upper)

    reaper.ImGui_PushID(ctx, current_path)
    self:renderColorButton(ctx, value, current_path)
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Selectable(ctx, display_name, self.selected_color_path == current_path) then
        self.selected_color_path = current_path
        self.current_color = COLOR_UTILS.hexToImGuiColor(value)
    end
    reaper.ImGui_PopID(ctx)
end

function GlobalColorEditor:renderColorCategory(ctx, category_name, colors)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)

    local child_flags = reaper.ImGui_ChildFlags_Border() | reaper.ImGui_ChildFlags_AutoResizeY()

    if reaper.ImGui_BeginChild(ctx, "category_" .. category_name, -1, 0, child_flags) then
        local display_name = category_name:gsub("_", " "):gsub("^%l", string.upper)
        reaper.ImGui_TextDisabled(ctx, display_name)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)

        for key, value in pairs(colors) do
            if type(value) == "table" then
                self:renderNestedGroup(ctx, category_name, key, value)
            else
                self:renderColorInColumn(ctx, key, value, category_name .. "." .. key)
            end
            reaper.ImGui_Spacing(ctx)
        end

        reaper.ImGui_EndChild(ctx)
    end

    reaper.ImGui_PopStyleVar(ctx, 2)
end

function GlobalColorEditor:renderNestedGroup(ctx, category_name, group_key, group_value)
    local group_name = group_key:gsub("_", " "):gsub("^%l", string.upper)
    reaper.ImGui_TextDisabled(ctx, group_name)
    reaper.ImGui_Indent(ctx, 10)

    for subkey, subvalue in pairs(group_value) do
        local display_subkey = subkey == "BG" and "Background" or subkey
        local nested_path = category_name .. "." .. group_key .. "." .. subkey
        self:renderColorInColumn(ctx, display_subkey, subvalue, nested_path)
        reaper.ImGui_Spacing(ctx)
    end

    reaper.ImGui_Unindent(ctx, 10)
end

function GlobalColorEditor:collectTopLevelColors(colors)
    local top_level = {}
    for key, value in pairs(colors) do
        if type(value) ~= "table" then
            top_level[key] = value
        end
    end
    return top_level
end

function GlobalColorEditor:render(ctx, saveCallback)
    if not self.is_open then
        return
    end

    local window_flags =
        reaper.ImGui_WindowFlags_NoDocking() | reaper.ImGui_WindowFlags_NoScrollbar() |
        reaper.ImGui_WindowFlags_NoResize() |
        reaper.ImGui_WindowFlags_NoCollapse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    local visible, open = reaper.ImGui_Begin(ctx, "Color Editor", true, window_flags)
    self.is_open = open

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
        self.is_open = false
    end

    if visible then
        local total_width = 800
        local column_width = total_width / 2 - 10

        reaper.ImGui_BeginChild(ctx, "colors_list", column_width, 400)

        local top_level_colors = self:collectTopLevelColors(CONFIG.COLORS)
        if next(top_level_colors) then
            self:renderColorCategory(ctx, "General", top_level_colors)
            reaper.ImGui_Spacing(ctx)
        end

        for key, value in pairs(CONFIG.COLORS) do
            if type(value) == "table" then
                self:renderColorCategory(ctx, key, value)
                reaper.ImGui_Spacing(ctx)
            end
        end

        reaper.ImGui_EndChild(ctx)

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_BeginChild(ctx, "color_picker", column_width, 400)

        if self.selected_color_path then
            local flags =
                reaper.ImGui_ColorEditFlags_AlphaBar() | reaper.ImGui_ColorEditFlags_PickerHueBar() |
                reaper.ImGui_ColorEditFlags_DisplayRGB() |
                reaper.ImGui_ColorEditFlags_NoSidePreview() |
                reaper.ImGui_ColorEditFlags_DisplayHex()

            local changed, new_color = reaper.ImGui_ColorPicker4(ctx, "##picker", self.current_color, flags)
            if changed then
                self:updateColorConfig(new_color, saveCallback)
            end
        else
            reaper.ImGui_SetCursorPos(ctx, column_width / 2 - 50, 180)
            reaper.ImGui_TextDisabled(ctx, "Select a color to edit")
        end

        reaper.ImGui_EndChild(ctx)
    end

    reaper.ImGui_End(ctx)

    -- Reset the global style
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
end

function GlobalColorEditor:updateColorConfig(new_color, saveCallback)
    -- Update the state
    self.current_color = new_color

    -- Extract RGBA components and format as hex color
    local hex_color = COLOR_UTILS.toHex(new_color)

    -- Update the config
    local path_parts = {}
    for part in self.selected_color_path:gmatch("[^.]+") do
        table.insert(path_parts, part)
    end

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

return GlobalColorEditor.new()
