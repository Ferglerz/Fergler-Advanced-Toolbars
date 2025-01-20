local CONFIG = require "Advanced Toolbars - User Config"

-- window_manager.lua
local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new(reaper, script_path, button_system, button_group, helpers)
    local self = setmetatable({}, WindowManager)
    self.r = reaper
    self.script_path = script_path
    self.ButtonSystem = button_system
    self.ButtonGroup = button_group
    self.createPropertyKey = button_system.createPropertyKey
    self.helpers = helpers
    
    -- Initialize state
    self.currentToolbarIndex = tonumber(self.r.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
    self.is_open = true
    self.last_dock_state = nil
    self.toolbars = nil
    self.button_manager = nil
    self.button_renderer = nil
    self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    
    -- Initialize font icon selector
    self.fontIconSelector = require('font_icon_selector').new(reaper)
    self.fontIconSelector.saveConfigCallback = function()
        self:saveConfig()
    end
    
    -- Add color picker state
    self.color_picker_state = {
        active_button = nil,
        current_color = 0,
        apply_to_group = false
    }
    
    self.drag_state = {
        active_separator = nil,
        initial_x = 0,
        initial_width = 0
    }
    
    -- Add group management state
    self.active_group = nil
    
    -- Initialize docking state
    if self.r.GetExtState("AdvancedToolbars", "dock_id") == "" then
        local dock_id = CONFIG.UI.DOCK_ID or 0
        if dock_id and (dock_id == 0 or (dock_id >= -16 and dock_id <= -1)) then
            self.r.SetExtState("AdvancedToolbars", "dock_id", tostring(dock_id), true)
        else
            self.r.SetExtState("AdvancedToolbars", "dock_id", "0", true)
        end
    end
    
    return self
end

function WindowManager:initialize(toolbars, button_manager, button_renderer, menu_path)
    self.toolbars = toolbars
    self.button_manager = button_manager
    self.button_renderer = button_renderer
    self.menu_path = menu_path
end

function WindowManager:isOpen()
    return self.is_open
end

function WindowManager:render(ctx, font, icon_font)
    if not self.toolbars then return end
    
    self.r.ImGui_PushFont(ctx, font)
    
    -- Set up window styling
    local windowBg = self.helpers.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), windowBg)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_PopupBg(), windowBg)
    
    -- Set up window flags and size
    self.r.ImGui_SetNextWindowSize(ctx, 800, 60, self.r.ImGui_Cond_FirstUseEver())
    local window_flags = self.r.ImGui_WindowFlags_NoScrollbar() |
                        self.r.ImGui_WindowFlags_NoDecoration() |
                        self.r.ImGui_WindowFlags_NoScrollWithMouse()
    
    -- Begin main window
    local visible, open = self.r.ImGui_Begin(ctx, 'Dynamic Toolbar', true, window_flags)
    self.is_open = open
    
    if visible then
        -- Handle docking state
        self:handleDockingState(ctx)
        
        if #self.toolbars > 0 then
            -- Handle right-click menu
            if self.r.ImGui_IsWindowHovered(ctx) and 
               not self.r.ImGui_IsAnyItemHovered(ctx) and 
               self.r.ImGui_IsMouseClicked(ctx, 1) then
                self.r.ImGui_OpenPopup(ctx, "toolbar_selector_menu")
            end
            
            -- Render toolbar selector and content
            self:renderToolbarSelector(ctx)
            self:renderToolbarContent(ctx, icon_font)
            
        else
            self.r.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        end
        
        -- Render font icon selector if open
        self.fontIconSelector:renderGrid(ctx, icon_font)
    end
    
    self.r.ImGui_End(ctx)
    self.r.ImGui_PopStyleColor(ctx, 2)
    self.r.ImGui_PopFont(ctx)
end

function WindowManager:handleDockingState(ctx)
    local current_dock = self.r.ImGui_GetWindowDockID(ctx)
    if current_dock ~= self.last_dock_state then
        self.r.SetExtState("AdvancedToolbars", "dock_id", tostring(current_dock), true)
        self.last_dock_state = current_dock
    end
end

function WindowManager:renderToolbarSelector(ctx)
    if not self.r.ImGui_BeginPopup(ctx, "toolbar_selector_menu") then return end
    
    self:renderSettingsSection(ctx)
    self:renderToolbarList(ctx)
    
    self.r.ImGui_EndPopup(ctx)
end

function WindowManager:renderSettingsSection(ctx)
    self.r.ImGui_TextDisabled(ctx, "Settings:")
    self.r.ImGui_Separator(ctx)
    
CONFIG.UI.HIDE_ALL_LABELS = CONFIG.UI.HIDE_ALL_LABELS or false    

    if self.r.ImGui_MenuItem(ctx, "Hide All Button Labels", nil, CONFIG.UI.HIDE_ALL_LABELS) then
        CONFIG.UI.HIDE_ALL_LABELS = not CONFIG.UI.HIDE_ALL_LABELS
        -- Clear all button caches when toggling global setting
        if self.toolbars and self.toolbars[self.currentToolbarIndex] then
            for _, button in ipairs(self.toolbars[self.currentToolbarIndex].buttons) do
                button.cached_width = nil
            end
        end
        self:saveConfig()
    end
    
    -- Button Height
    local height_changed, new_height = self.r.ImGui_SliderInt(ctx, "Button Height", 
        CONFIG.SIZES.HEIGHT, 20, 60)
    if height_changed then
        CONFIG.SIZES.HEIGHT = new_height
        self:saveConfig()
    end
    
    -- Button Rounding
    local rounding_changed, new_rounding = self.r.ImGui_SliderInt(ctx, "Button Rounding",
        CONFIG.SIZES.ROUNDING, 0, 30)
    if rounding_changed then
        CONFIG.SIZES.ROUNDING = new_rounding
        self:saveConfig()
    end
    
    -- Minimum Button Width
    local width_changed, new_width = self.r.ImGui_SliderInt(ctx, "Minimum Button Width",
        CONFIG.SIZES.MIN_WIDTH, 20, 200)
    if width_changed then
        CONFIG.SIZES.MIN_WIDTH = new_width
        if self.toolbars and self.toolbars[self.currentToolbarIndex] then
            for _, button in ipairs(self.toolbars[self.currentToolbarIndex].buttons) do
                button.cached_width = nil
            end
        end
        self:saveConfig()
    end
    
    -- 3D Depth
    local depth_changed, new_depth = self.r.ImGui_SliderInt(ctx, "3D Depth",
        CONFIG.SIZES.DEPTH, 0, 6)
    if depth_changed then
        CONFIG.SIZES.DEPTH = new_depth
        self:saveConfig()
    end
    
    -- Button Spacing (conditionally hidden)
if not CONFIG.SIZES.GROUPING then
    local spacing_changed, new_spacing = self.r.ImGui_SliderInt(ctx, "Button Spacing",
        CONFIG.SIZES.SPACING, 0, 30)
    if spacing_changed then
        CONFIG.SIZES.SPACING = new_spacing
        self:saveConfig()
    end
end

-- Separator Width
local separator_changed, new_separator_width = self.r.ImGui_SliderInt(ctx, "Separator Width",
    CONFIG.SIZES.EPARATOR_WIDTH, 4, 50)
if separator_changed then
    CONFIG.SIZES.SEPARATOR_WIDTH = new_separator_width
    self:saveConfig()
end
    
    -- Icon Scale
    local scale_changed, new_scale = self.r.ImGui_SliderDouble(ctx, 
        "Icon Scale (requires restart)", CONFIG.SIZES.ICON_SCALE, 0.1, 2.0, "%.2f")
    if scale_changed then
        CONFIG.SIZES.ICON_SCALE = new_scale
        self:saveConfig()
        self.button_manager:clearAllButtonCaches()
    end
    
    -- Icon Size
    local size_changed, new_size = self.r.ImGui_SliderInt(ctx, 
        "Built-in Icon Size (requires restart)", CONFIG.FONTS.FONT_ICON_SIZE, 4, 18)
    if size_changed then
        CONFIG.FONTS.FONT_ICON_SIZE = math.floor(new_size)
        self:saveConfig()
    end
    
    -- Button Grouping
    if self.r.ImGui_MenuItem(ctx, "Button Grouping", nil, CONFIG.UI.USE_GROUPING) then
        CONFIG.UI.USE_GROUPING = not CONFIG.UI.USE_GROUPING
        self:saveConfig()
    end
    

if self.r.ImGui_MenuItem(ctx, "Group Labels", nil, CONFIG.UI.USE_GROUP_LABELS) then
    CONFIG.UI.USE_GROUP_LABELS = not CONFIG.UI.USE_GROUP_LABELS
    self:saveConfig()
end
    
    -- Docking
    local current_dock = self.r.ImGui_GetWindowDockID(ctx)
    local is_docked = current_dock ~= 0
    if self.r.ImGui_MenuItem(ctx, "Docked", nil, is_docked) then
        self:toggleDocking(ctx, current_dock, is_docked)
    end
end

function WindowManager:renderToolbarList(ctx)
    self.r.ImGui_Separator(ctx)
    self.r.ImGui_TextDisabled(ctx, "Toolbar:")
    self.r.ImGui_Separator(ctx)
    
    for i, toolbar in ipairs(self.toolbars) do
        if self.r.ImGui_MenuItem(ctx, toolbar.name, nil, self.currentToolbarIndex == i) then
            self.currentToolbarIndex = i
            self.r.SetExtState("AdvancedToolbars", "last_toolbar_index", tostring(i), true)
        end
    end
end

-- Helper function to initialize rendering state
function WindowManager:initializeRenderState(ctx)
    self.r.ImGui_Spacing(ctx)
    local window_x, window_y = self.r.ImGui_GetWindowPos(ctx)
    local window_pos = { x = window_x, y = window_y }
    local draw_list = self.r.ImGui_GetWindowDrawList(ctx)
    local start_pos = { 
        x = self.r.ImGui_GetCursorPosX(ctx),
        y = self.r.ImGui_GetCursorPosY(ctx)
    }
    
    return window_pos, draw_list, start_pos
end

-- Helper function to handle button width caching
function WindowManager:updateButtonWidthCache()
    if self.last_min_width ~= CONFIG.SIZES.MIN_WIDTH then
        for _, button in ipairs(self.toolbars[self.currentToolbarIndex].buttons) do
            button.cached_width = nil
        end
        self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    end
end

-- Helper function to handle Alt+Right click
function WindowManager:handleAltRightClick(ctx, button, group)
    if button.is_hovered and self.r.ImGui_IsMouseClicked(ctx, 1) then
        if self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_LeftAlt()) or
           self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_RightAlt()) then
            self.active_button = button
            self.active_group = group
            self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
        else
            self.button_manager:handleRightClick(button)
        end
    end
end

-- Helper function to update button states within a group
function WindowManager:updateGroupButtonStates(ctx, group, flash_state)
    for _, button in ipairs(group.buttons) do
        self.button_manager:updateButtonState(button, self.r.GetArmedCommand(), flash_state)
        self:setupButtonCallbacks(ctx, button, group)
        self:handleAltRightClick(ctx, button, group)
    end
end

-- Helper function to render a group and return new x position
function WindowManager:renderGroupButtons(ctx, group, current_x, start_pos, window_pos, draw_list, icon_font)
    local group_width = self.button_renderer:renderGroup(
        ctx, group, current_x, start_pos.y, window_pos, draw_list, icon_font
    )
    
    -- Handle context menus for all buttons in the group
    for _, button in ipairs(group.buttons) do
        self:handleButtonContextMenu(ctx, button, group)
    end
    
    return current_x + group_width
end

-- Helper function to render individual buttons
function WindowManager:renderIndividualButton(ctx, button, current_x, start_pos, window_pos, draw_list, icon_font)
    self.button_manager:updateButtonState(button, self.r.GetArmedCommand(), flash_state)
    self:setupButtonCallbacks(ctx, button, nil)
    
    local button_width = self.button_renderer:renderButton(
        ctx, button, current_x, start_pos.y, icon_font, window_pos, draw_list
    )
    
    self:handleAltRightClick(ctx, button, nil)
    self:handleButtonContextMenu(ctx, button)
    
    return current_x + button_width
end

function WindowManager:renderToolbarContent(ctx, icon_font)
    local currentToolbar = self.toolbars[self.currentToolbarIndex]
    if not currentToolbar then return end
    
    local window_pos, draw_list, start_pos = self:initializeRenderState(ctx)
    local current_x = start_pos.x
    local flash_state = self:updateFlashState(ctx)
    self:updateButtonWidthCache()
    
    -- Handle active separator drag
    if self.drag_state.active_separator then
        if self.r.ImGui_IsMouseDown(ctx, 0) then
            local delta_x = self.r.ImGui_GetMousePos(ctx) - self.drag_state.initial_x
            self.drag_state.active_separator.width = math.max(
                4, -- minimum width
                self.drag_state.initial_width + delta_x
            )
        else
            self:saveConfig() -- Save new separator width
            self.drag_state.active_separator = nil
        end
    end
    
    -- Use existing groups from Parser
    for i, group in ipairs(currentToolbar.groups) do
        if i > 1 then
            current_x = current_x + CONFIG.SIZES.SEPARATOR_WIDTH
        end
        
        -- Update button states
        for _, button in ipairs(group.buttons) do
            self.button_manager:updateButtonState(button, self.r.GetArmedCommand(), flash_state)
            self:setupButtonCallbacks(ctx, button, group)
        end
        
        -- Render group
        current_x = current_x + self.button_renderer:renderGroup(
            ctx, group, current_x, start_pos.y, window_pos, draw_list, icon_font
        )
        
        -- Handle interactions
        for _, button in ipairs(group.buttons) do
            self:handleAltRightClick(ctx, button, group)
            self:handleButtonContextMenu(ctx, button)
        end
    end
end

function WindowManager:updateFlashState(ctx)
    local flash_interval = CONFIG.FLASH_INTERVAL or 0.5
    local current_time = self.r.time_precise()
    return math.floor(current_time / (flash_interval/2)) % 2 == 0
end

function WindowManager:setupButtonCallbacks(ctx, button, group)
    -- Set up context menu callback
    button.on_context_menu = function()
        self.active_button = button
        self.active_group = group  -- Store the group reference
        self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
    end
end

function WindowManager:handleButtonContextMenu(ctx, button)
    if not self.r.ImGui_BeginPopup(ctx, "context_menu_" .. button.id) then return end
    
    -- Add hide label option to button context menu
    if self.r.ImGui_MenuItem(ctx, "Hide Label", nil, button.hide_label) then
        button.hide_label = not button.hide_label
        button:clearCache()
        self:saveConfig()
    end
    
    -- Group management options
    if self.active_group and CONFIG.USE_GROUP_LABELS then
    	local menu_text = "Name Group"
    	if #self.active_group.label.text > 0 then
    		menu_text = "Rename Group"
    	end
    
        if self.r.ImGui_MenuItem(ctx, menu_text) then
            local retval, new_name = self.r.GetUserInputs(menu_text, 1, 
                "Group Name:,extrawidth=100", self.active_group.label.text or "")
            if retval then
                self.active_group.label.text = new_name
                self:saveConfig()
            end
        end
        
        self.r.ImGui_Separator(ctx)
    end
    
    if self.r.ImGui_MenuItem(ctx, "Rename") then
        self:handleButtonRename(button)
    end
    
    if self.r.ImGui_BeginMenu(ctx, "Text Alignment") then
        self:handleAlignmentMenu(ctx, button)
        self.r.ImGui_EndMenu(ctx)
    end
    
    -- Color picker section
    if self.r.ImGui_BeginMenu(ctx, "Button Color") then
        -- Initialize color state when menu is opened
        if self.color_picker_state.active_button ~= button then
            self.color_picker_state.active_button = button
            self.color_picker_state.current_color = self.helpers.hexToImGuiColor(
                button.custom_color and button.custom_color.normal or CONFIG.BUTTON_COLOR
            )
            self.color_picker_state.apply_to_group = false
        end
        
        local flags = self.r.ImGui_ColorEditFlags_AlphaBar() |
                     self.r.ImGui_ColorEditFlags_AlphaPreview() |
                     self.r.ImGui_ColorEditFlags_NoInputs() |
                     self.r.ImGui_ColorEditFlags_PickerHueBar() |
                     self.r.ImGui_ColorEditFlags_DisplayRGB() |
                     self.r.ImGui_ColorEditFlags_DisplayHex()
        
        -- Add apply to group checkbox
        local apply_changed, apply_value = self.r.ImGui_Checkbox(ctx, "Apply to group", 
            self.color_picker_state.apply_to_group)
        if apply_changed then
            self.color_picker_state.apply_to_group = apply_value
        end
        
        -- Show color picker with persistent state
        local changed, new_color = self.r.ImGui_ColorPicker4(ctx, 
            "##colorpicker" .. button.id,
            self.color_picker_state.current_color,
            flags
        )
        
        if changed then
            -- Update the state
            self.color_picker_state.current_color = new_color
            
            -- Extract RGBA components
            local r = (new_color >> 24) & 0xFF
            local g = (new_color >> 16) & 0xFF
            local b = (new_color >> 8) & 0xFF
            local a = new_color & 0xFF
            
            -- Format as hex color
            local baseColor = string.format("#%02X%02X%02X%02X", r, g, b, a)
            
            -- Calculate derived colors
            local hoverColor, activeColor = self.helpers.getDerivedColors(baseColor, CONFIG)
            
            -- Create color settings
            local colorSettings = {
                normal = baseColor,
                hover = hoverColor,
                active = activeColor
            }
            
            -- Apply to button(s)
            if self.color_picker_state.apply_to_group then
                local currentGroup = self:getCurrentButtonGroup(button)
                for _, groupButton in ipairs(currentGroup) do
                    groupButton.custom_color = colorSettings
                end
            else
                button.custom_color = colorSettings
            end
            
            self:saveConfig()
        end
        
        -- Add remove option if custom color exists
        if button.custom_color then
            self.r.ImGui_Separator(ctx)
            if self.r.ImGui_MenuItem(ctx, "Remove Custom Color") then
                if self.color_picker_state.apply_to_group then
                    local currentGroup = self:getCurrentButtonGroup(button)
                    for _, groupButton in ipairs(currentGroup) do
                        groupButton.custom_color = nil
                    end
                else
                    button.custom_color = nil
                end
                self.color_picker_state.active_button = nil
                self:saveConfig()
            end
        end
        
        self.r.ImGui_EndMenu(ctx)
    else
        -- Reset state when menu is closed
        if self.color_picker_state.active_button == button then
            self.color_picker_state.active_button = nil
        end
    end
    
    if self.r.ImGui_MenuItem(ctx, "Choose Built-in Icon") then
        self.fontIconSelector:show(button)
    end
    
    if self.r.ImGui_MenuItem(ctx, "Choose Image Icon") then
        self:handleIconPathChange(button)
    end
    
    if button.icon_path or button.icon_char then
        if self.r.ImGui_MenuItem(ctx, "Remove Icon") then
            self:handleRemoveIcon(button)
        end
    end
    
    if self.r.ImGui_MenuItem(ctx, "Change Action") then
        self:handleChangeAction(ctx, button)
    end
    
    self.r.ImGui_EndPopup(ctx)
end

-- Add helper function to get current button group
function WindowManager:getCurrentButtonGroup(button)
    local group = {}
    local currentToolbar = self.toolbars[self.currentToolbarIndex]
    if not currentToolbar then return group end
    
    -- Find the boundaries of the current group
    local start_idx, end_idx
    for i, btn in ipairs(currentToolbar.buttons) do
        if btn == button then
            -- Search backwards for group start
            start_idx = i
            while start_idx > 1 and not currentToolbar.buttons[start_idx-1].is_separator do
                start_idx = start_idx - 1
            end
            
            -- Search forwards for group end
            end_idx = i
            while end_idx < #currentToolbar.buttons and not currentToolbar.buttons[end_idx+1].is_separator do
                end_idx = end_idx + 1
            end
            break
        end
    end
    
    -- Collect all buttons in the group
    if start_idx and end_idx then
        for i = start_idx, end_idx do
            table.insert(group, currentToolbar.buttons[i])
        end
    end
    
    return group
end

function WindowManager:handleButtonRename(button)
    local retval, new_name = self.r.GetUserInputs("Rename Toolbar Item", 1, 
        "New Name:,extrawidth=100", button.display_text)
    
    if retval then
        button.display_text = new_name
        button:clearCache()
        self:saveConfig()
    end
end

function WindowManager:handleAlignmentMenu(ctx, button)
    local alignments = {
        { name = "Left", value = "left" },
        { name = "Center", value = "center" },
        { name = "Right", value = "right" }
    }
    
    for _, align in ipairs(alignments) do
        if self.r.ImGui_MenuItem(ctx, align.name, nil, button.alignment == align.value) then
            button.alignment = align.value
            button:clearCache()
            self:saveConfig()
        end
    end
end

function WindowManager:handleChangeAction(ctx, button)
    -- Get new action ID from user
    local retval, action_id = self.r.GetUserInputs("Change Action", 1, "Action ID:,extrawidth=100", button.id)
    if not retval then return end

    -- Validate the new action ID and get its name
    local cmdID = self.button_manager:getCommandID(action_id)
    if not cmdID then
        self.r.ShowMessageBox("Invalid action ID", "Error", 0)
        return
    end
    
    -- Get action name and verify it exists
    local action_name = self.r.CF_GetCommandText(0, cmdID)
    if not action_name or action_name == "" then
        self.r.ShowMessageBox("Action not found", "Error", 0)
        return
    end

    -- Get the current toolbar
    local toolbar = self.toolbars[self.currentToolbarIndex]
    if not toolbar then return end

    -- Read reaper-menu.ini
    local file = io.open(self.menu_path, "r")
    if not file then
        self.r.ShowMessageBox("Failed to read reaper-menu.ini", "Error", 0)
        return
    end

    local content = file:read("*all")
    file:close()

    -- Find and replace the action in the correct section
    local escaped_section = toolbar.section:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    local section_pattern = "%[" .. escaped_section .. "%]"
    
    local section_start = content:find(section_pattern)
    if not section_start then
        self.r.ShowMessageBox("Could not find toolbar section in reaper-menu.ini", "Error", 0)
        return
    end
    
    local section_end = content:find("%[", section_start + 1) or #content
    local section = content:sub(section_start, section_end - 1)
    
    -- Replace the specific button line
    local button_line_pattern = "(item_[0-9]+)=" .. button.id .. "[^\n]*"
    local new_line = "%1=" .. action_id .. " " .. button.original_text
    
    local new_section, replacements = section:gsub(button_line_pattern, new_line)
    if replacements == 0 then
        self.r.ShowMessageBox("Could not find button in toolbar section", "Error", 0)
        return
    end

    -- Update the content and write back to file
    content = content:sub(1, section_start - 1) .. new_section .. content:sub(section_end)
    file = io.open(self.menu_path, "w")
    if not file then
        self.r.ShowMessageBox("Failed to write to reaper-menu.ini", "Error", 0)
        return
    end

    file:write(content)
    file:close()

    -- Update button properties
    button.id = action_id
    button.property_key = self.createPropertyKey(action_id, button.original_text)
    button:clearCache()

    -- Inform user of the successful change
    self.r.ShowMessageBox(
        string.format('Action changed to: "%s"', action_name),
        "Success", 
        0
    )
end

function WindowManager:handleRemoveIcon(button)
    button.icon_path = nil
    button.icon_char = nil
    button:clearCache()
    self.button_manager:clearIconCache()
    self:saveConfig()
end

function WindowManager:handleIconPathChange(button)
    local retval, icon_path = self.r.GetUserFileNameForRead("", "Select Icon File", "")
    
    if retval then
        -- Try to load the icon first to verify it
        local test_texture = self.r.ImGui_CreateImage(icon_path)
        if not test_texture then
            self.r.ShowMessageBox(
                "Failed to load icon: " .. icon_path .. 
                "\nPlease ensure the file exists and is a valid image format.", 
                "Error", 0
            )
            return
        end
        
        -- Clear existing icon cache first
        self.button_manager:clearIconCache()
        
        -- Update button properties directly
        button.icon_path = icon_path
        button.icon_char = nil  -- Clear character icon when setting image icon
        button:clearCache()
        
        self:saveConfig()
    end
end

function WindowManager:toggleDocking(ctx, current_dock, is_docked)
    if is_docked then
        self.last_dock_state = current_dock
        self.r.SetExtState("AdvancedToolbars", "dock_id", "0", true)
        local mouse_x, mouse_y = self.r.ImGui_GetMousePos(ctx)
        self.r.ImGui_SetNextWindowPos(ctx, mouse_x, mouse_y)
    else
        local target_dock = self.last_dock_state
        if not target_dock or target_dock == 0 then
            target_dock = -1
        end
        self.r.SetExtState("AdvancedToolbars", "dock_id", tostring(target_dock), true)
    end
end

function WindowManager:serializeValue(value, indent)
    if type(value) == "table" then
        return self:serializeTable(value, indent)
    elseif type(value) == "string" then
        return string.format('"%s"', value:gsub('"', '\\"'):gsub("\n", "\\n"))
    else
        return tostring(value)
    end
end

function WindowManager:serializeTable(tbl, indent)
    indent = indent or "    "
    local parts = {}
    
    for key, value in pairs(tbl) do
        -- Use simple key format if possible
        local key_str
        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            key_str = key
        else
            key_str = string.format('["%s"]', key)
        end
        
        local value_str = self:serializeValue(value, indent .. "    ")
        table.insert(parts, indent .. key_str .. " = " .. value_str)
    end
    
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent:sub(1, -5) .. "}"
end

function WindowManager:saveConfig()
    local file = io.open(self.script_path .. "Advanced Toolbars - User Config.lua", "w")
    if not file then 
        self.r.ShowConsoleMsg("Failed to open config file for writing\n")
        return 
    end

    -- Start with an empty config table
    local config_to_save = {
        UI = CONFIG.UI,
        ICON_FONT = CONFIG.ICON_FONT,
        FONTS = CONFIG.FONTS,
        COLORS = CONFIG.COLORS,
        SIZES = CONFIG.SIZES,
        BUTTON_CUSTOM_PROPERTIES = {},
        TOOLBAR_GROUPS = {}
    }

    -- Add button properties
    if self.toolbars[self.currentToolbarIndex] then
        for _, button in ipairs(self.toolbars[self.currentToolbarIndex].buttons) do
            local props = {}
            if button.display_text ~= button.original_text then
                props.name = button.display_text
            end
            props.hide_label = button.hide_label
            if button.alignment ~= "center" then
                props.justification = button.alignment
            end
            if button.icon_path then props.icon_path = button.icon_path end
            if button.icon_char then props.icon_char = button.icon_char end
            if button.custom_color then props.custom_color = button.custom_color end
            
            if next(props) then -- Only add if there are properties
                config_to_save.BUTTON_CUSTOM_PROPERTIES[button.property_key] = props
            end
        end
    end

    -- Add toolbar groups
    for _, toolbar in ipairs(self.toolbars) do
        if toolbar.groups and #toolbar.groups > 0 then
            config_to_save.TOOLBAR_GROUPS[toolbar.section] = {}
            for _, group in ipairs(toolbar.groups) do
                table.insert(config_to_save.TOOLBAR_GROUPS[toolbar.section], {
                    label = { text = group.label.text or "" }
                })
            end
        end
    end

    -- Write the entire config at once
    file:write("local config = " .. self:serializeTable(config_to_save) .. "\n\nreturn config")
    file:close()
end

function WindowManager:cleanup()
    if self.button_manager then
        self.button_manager:cleanup()
    end
end

return {
    new = function(reaper, config, script_path, button_system, button_group, helpers)
        return WindowManager.new(reaper, config, script_path, button_system, button_group, helpers)
    end
}