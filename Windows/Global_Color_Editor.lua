-- Windows/Global_Color_Editor.lua

local GlobalColorEditor = {}
GlobalColorEditor.__index = GlobalColorEditor

function GlobalColorEditor.new()
    local self = setmetatable({}, GlobalColorEditor)

    self.is_open = false
    self.selected_color_path = nil
    self.current_color = 0
    self.window_width = 750
    self.window_height = 450  -- Increased height to accommodate checkboxes
    
    -- Link options
    self.link_icon_text = true
    self.link_bg_border = true
    
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

    if reaper.ImGui_Selectable(ctx, display_name, self.selected_color_path == current_path, 0, 80  ) then
        self.selected_color_path = current_path
        self.current_color = COLOR_UTILS.hexToImGuiColor(value)
    end
    reaper.ImGui_PopID(ctx)
end

function GlobalColorEditor:renderColorCategory(ctx, category_name, colors)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 10, 8)

    local child_flags = reaper.ImGui_ChildFlags_Border() | reaper.ImGui_ChildFlags_AutoResizeY()


    if reaper.ImGui_BeginChild(ctx, "category_" .. category_name, -8, 0, child_flags) then
        local display_name = category_name:gsub("_", " "):gsub("^%l", string.upper)
        reaper.ImGui_TextDisabled(ctx, display_name)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)

        -- Check if this category has subcategories like BG, TEXT, ICON, BORDER
        local hasSubcategories = false
        local subcategories = {}
        for key, value in pairs(colors) do
            if type(value) == "table" and (key == "BG" or key == "TEXT" or key == "ICON" or key == "BORDER") then
                table.insert(subcategories, {key = key, value = value})
                hasSubcategories = true
            end
        end

        if hasSubcategories then
            -- Sort subcategories for consistent ordering
            table.sort(subcategories, function(a, b) return a.key < b.key end)
            
            -- Create a 2x2 grid layout using SameLine and NewLine
            self:render2x2Grid(ctx, category_name, subcategories, colors)
        else
            -- Render simple key-value pairs
            for key, value in pairs(colors) do
                if type(value) == "table" then
                    self:renderNestedGroup(ctx, category_name, key, value)
                else
                    self:renderColorInColumn(ctx, key, value, category_name .. "." .. key)
                end
                reaper.ImGui_Spacing(ctx)
            end
        end

        reaper.ImGui_EndChild(ctx)
    end

    reaper.ImGui_PopStyleVar(ctx, 3)
end

function GlobalColorEditor:render2x2Grid(ctx, category_name, subcategories, colors)
    local content_width = reaper.ImGui_GetContentRegionAvail(ctx)
    local cell_width = content_width / 2 - 5
    
    -- First row
    if #subcategories > 0 then
        self:renderNestedGroup(ctx, category_name, subcategories[1].key, subcategories[1].value)
        
        if #subcategories > 1 then
            -- Position second item on the same row
            reaper.ImGui_SameLine(ctx, cell_width + 10) -- Add some padding between items
            self:renderNestedGroup(ctx, category_name, subcategories[2].key, subcategories[2].value)
        end
    end
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- Second row
    if #subcategories > 2 then
        self:renderNestedGroup(ctx, category_name, subcategories[3].key, subcategories[3].value)
        
        if #subcategories > 3 then
            -- Position fourth item on the same row
            reaper.ImGui_SameLine(ctx, cell_width + 10) -- Add some padding between items
            self:renderNestedGroup(ctx, category_name, subcategories[4].key, subcategories[4].value)
        end
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Render other non-subcategory entries if they exist
    for key, value in pairs(colors) do
        local isStandardSubcategory = false
        for _, subcat in ipairs(subcategories) do
            if key == subcat.key then
                isStandardSubcategory = true
                break
            end
        end
        
        if not isStandardSubcategory then
            if type(value) == "table" then
                self:renderNestedGroup(ctx, category_name, key, value)
            else
                self:renderColorInColumn(ctx, key, value, category_name .. "." .. key)
            end
            reaper.ImGui_Spacing(ctx)
        end
    end
end

function GlobalColorEditor:renderNestedGroup(ctx, category_name, group_key, group_value)
    local group_name = group_key:gsub("_", " "):gsub("^%l", string.upper)
    
    -- Create a group with title
    reaper.ImGui_BeginGroup(ctx)
    reaper.ImGui_TextDisabled(ctx, group_name)
    reaper.ImGui_Indent(ctx, 10)

    for subkey, subvalue in pairs(group_value) do
        if type(subvalue) ~= "table" then
            local display_subkey = subkey == "BG" and "Background" or subkey
            local nested_path = category_name .. "." .. group_key .. "." .. subkey
            self:renderColorInColumn(ctx, display_subkey, subvalue, nested_path)
            reaper.ImGui_Spacing(ctx)
        end
    end

    reaper.ImGui_Unindent(ctx, 10)
    reaper.ImGui_EndGroup(ctx)
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

-- In Windows/Global_Color_Editor.lua
function GlobalColorEditor:render(ctx, saveCallback)
    if not self.is_open then
        _G.POPUP_OPEN = false
        return false
    end
    
    _G.POPUP_OPEN = true

    local window_flags =
        reaper.ImGui_WindowFlags_NoDocking() | reaper.ImGui_WindowFlags_NoScrollbar() |
        reaper.ImGui_WindowFlags_NoScrollWithMouse() |
        reaper.ImGui_WindowFlags_NoResize() |
        reaper.ImGui_WindowFlags_NoCollapse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    reaper.ImGui_SetNextWindowSize(ctx, self.window_width, self.window_height)

    local visible, open = reaper.ImGui_Begin(ctx, "Color Editor", true, window_flags)
    self.is_open = open

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
        self.is_open = false
    end

    if visible then
        -- Add checkboxes for linking options
        local changed1, new_value1 = reaper.ImGui_Checkbox(ctx, "Link icon/text changes", self.link_icon_text)
        if changed1 then self.link_icon_text = new_value1 end
        
        reaper.ImGui_SameLine(ctx, 300)
        
        local changed2, new_value2 = reaper.ImGui_Checkbox(ctx, "Link bg/border changes", self.link_bg_border)
        if changed2 then self.link_bg_border = new_value2 end
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)

        local arbitrary_fix_lol = 60
        local column_width = self.window_width / 3 + arbitrary_fix_lol

        reaper.ImGui_BeginChild(ctx, "colors_list", column_width, self.window_height - 80)  -- Adjusted height

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
        
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 8, 8)
        reaper.ImGui_BeginChild(ctx, "color_picker", column_width * 2, column_width * 2)

        if self.selected_color_path then
            local flags =
                reaper.ImGui_ColorEditFlags_AlphaBar() | reaper.ImGui_ColorEditFlags_PickerHueBar() |
                reaper.ImGui_ColorEditFlags_DisplayRGB() |
                reaper.ImGui_ColorEditFlags_NoSidePreview() |
                reaper.ImGui_ColorEditFlags_DisplayHex()

            local changed, new_color = reaper.ImGui_ColorPicker4(ctx, "##picker", self.current_color, flags)
            if changed then
                -- Make sure saveCallback exists before trying to update
                if saveCallback and type(saveCallback) == "function" then
                    self:updateColorConfig(new_color, saveCallback)
                else
                    -- Fallback if saveCallback is missing
                    self.current_color = new_color
                    reaper.ShowConsoleMsg("Warning: Cannot save color, saveCallback is not provided\n")
                end
            end
        else
            reaper.ImGui_SetCursorPos(ctx, column_width / 2 - 50, 180)
            reaper.ImGui_TextDisabled(ctx, "Select a color to edit")
        end

        reaper.ImGui_EndChild(ctx)
        reaper.ImGui_PopStyleVar(ctx)
    end

    reaper.ImGui_End(ctx)

    -- Reset the global style
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    
    if not open then
        _G.POPUP_OPEN = false
    end
    self.is_open = open
    
    return self.is_open
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
        
        -- Apply linked changes if needed
        if #path_parts >= 3 then
            -- Handle icon/text linking
            if self.link_icon_text and (path_parts[#path_parts-1] == "ICON" or path_parts[#path_parts-1] == "TEXT") then
                local linked_key = path_parts[#path_parts-1] == "ICON" and "TEXT" or "ICON"
                local linked_current = CONFIG.COLORS
                
                -- Navigate to the parent of the ICON/TEXT
                for i = 1, #path_parts - 2 do
                    linked_current = linked_current[path_parts[i]]
                end
                
                -- Update the linked value if it exists
                if linked_current[linked_key] and linked_current[linked_key][path_parts[#path_parts]] then
                    linked_current[linked_key][path_parts[#path_parts]] = hex_color
                end
            end
            
            -- Handle bg/border linking
            if self.link_bg_border and (path_parts[#path_parts-1] == "BG" or path_parts[#path_parts-1] == "BORDER") then
                local linked_key = path_parts[#path_parts-1] == "BG" and "BORDER" or "BG"
                local linked_current = CONFIG.COLORS
                
                -- Navigate to the parent of the BG/BORDER
                for i = 1, #path_parts - 2 do
                    linked_current = linked_current[path_parts[i]]
                end
                
                -- Update the linked value if it exists
                if linked_current[linked_key] and linked_current[linked_key][path_parts[#path_parts]] then
                    linked_current[linked_key][path_parts[#path_parts]] = hex_color
                end
            end
        end
    end

    -- Call saveCallback to save the changes
    if saveCallback and type(saveCallback) == "function" then
        saveCallback()
    end
end

return GlobalColorEditor.new()