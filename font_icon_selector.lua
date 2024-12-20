local FontIconSelector = {}
FontIconSelector.__index = FontIconSelector

function FontIconSelector.new(reaper, config)
    local self = setmetatable({}, FontIconSelector)
    self.r = reaper
    self.config = config
    self.is_open = false
    self.current_button = nil
    self.ctx = nil
    self.is_font_attached = false
    
    -- Define icon ranges
    self.icons = {
        {start = 0x0021, laFin = 0x007E}  -- Basic Latin range
    }
    
    return self
end

-- In FontIconSelector:show()
function FontIconSelector:show(button)
    --self.r.ShowConsoleMsg("Show called with button: " .. tostring(button) .. "\n")
    --self.r.ShowConsoleMsg("Button ID: " .. tostring(button.id) .. "\n")
    
    self.current_button = button
    --self.r.ShowConsoleMsg("current_button after assignment: " .. tostring(self.current_button) .. "\n")
    --self.r.ShowConsoleMsg("current_button ID: " .. tostring(self.current_button.id) .. "\n")
    
    self.is_open = true
    -- Save the previous icon state in case we need to restore it
    self.previous_icon = {
        icon_char = button.icon_char,
        icon_path = button.icon_path
    }
end


function FontIconSelector:codePointToUTF8(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40),
                         0x80 + (code % 0x40))
    elseif code < 0x10000 then
        return string.char(0xE0 + math.floor(code / 0x1000),
                         0x80 + math.floor((code % 0x1000) / 0x40),
                         0x80 + (code % 0x40))
    else
        return string.char(0xF0 + math.floor(code / 0x40000),
                         0x80 + math.floor((code % 0x40000) / 0x1000),
                         0x80 + math.floor((code % 0x1000) / 0x40),
                         0x80 + (code % 0x40))
    end
end

function FontIconSelector:renderGrid(ctx, icon_font)
    if not self.is_open or not self.current_button then return end
    
    -- Declare selected_char at function scope
    local selected_char = nil
    
    -- Update context if needed
    if ctx ~= self.ctx then
        self.ctx = ctx
    end
    
    -- Set up window styling and flags
    local window_flags = self.r.ImGui_WindowFlags_NoCollapse() | 
                        self.r.ImGui_WindowFlags_AlwaysAutoResize()
    
    -- Push gray background color
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), 0x2A2A2AFF)
    
    local open = true
    local visible, should_continue = self.r.ImGui_Begin(ctx, 'Select Icon Character', open, window_flags)
    
    -- Handle window closing
    if not should_continue then
        self.is_open = false
        self.r.ImGui_PopStyleColor(ctx)
        self.r.ImGui_End(ctx)
        return
    end
    
    -- Handle escape key
    if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
        -- Restore previous icon state
        if self.previous_icon then
                button.icon_char = self.previous_icon.icon_char
                button.icon_path = self.previous_icon.icon_path
        end
        self.is_open = false
        self.r.ImGui_PopStyleColor(ctx)
        self.r.ImGui_End(ctx)
        return
    end
    
    if visible then
        -- Set up grid layout
        local cell_size = 40
        local grid_cols = 8
        local padding = 4
        local window_width = (cell_size + padding) * grid_cols
        
        -- Calculate total characters and rows
        local total_chars = 0
        for _, range in ipairs(self.icons) do
            total_chars = total_chars + (range.laFin - range.start + 1)
        end
        local total_rows = math.ceil(total_chars / grid_cols)
        local grid_height = (cell_size + padding) * total_rows
        
        if self.r.ImGui_BeginChild(ctx, 'IconGrid', window_width, grid_height) then
            -- Set up grid styling
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x3D3D3DFF)
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x4D4D4DFF)
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x5D5D5DFF)
            
            -- Push icon font
            self.r.ImGui_PushFont(ctx, icon_font)
            
            -- Render grid
            local grid_x = 0
            local grid_y = 0
            
            for _, range in ipairs(self.icons) do
                for code = range.start, range.laFin do
                    local success, char = pcall(function()
                        return self:codePointToUTF8(code)
                    end)
                    
                    if success and char then
                        local x = grid_x * (cell_size + padding)
                        local y = grid_y * (cell_size + padding)
                        
                        -- Position and render button
                        self.r.ImGui_SetCursorPos(ctx, x, y)
                        
                        -- Center icon in button
                        local char_width = self.r.ImGui_CalcTextSize(ctx, char)
                        local text_x = (cell_size - char_width) / 2
                        local text_y = (cell_size - self.r.ImGui_GetTextLineHeight(ctx)) / 2
                        
                       if self.r.ImGui_Button(ctx, "##icon_" .. code, cell_size, cell_size) then
    selected_char = char
    
    -- Debug button details
    --self.r.ShowConsoleMsg("Button ID: " .. tostring(self.current_button.id) .. "\n")
    --self.r.ShowConsoleMsg("Button property_key: " .. tostring(self.current_button.property_key) .. "\n")
    --self.r.ShowConsoleMsg("Button original_text: " .. tostring(self.current_button.original_text) .. "\n")
    
    -- Check if property exists in config
    if self.config.BUTTON_CUSTOM_PROPERTIES[self.current_button.property_key] then
        --self.r.ShowConsoleMsg("Found properties in config\n")
    else
        --self.r.ShowConsoleMsg("No properties found in config\n")
    end
    
    -- Direct assignment 
    self.current_button.icon_char = selected_char
    --self.r.ShowConsoleMsg("After direct assignment: " .. tostring(selected_char) .. "\n")
    
    -- Check config after update
    if self.config.BUTTON_CUSTOM_PROPERTIES[self.current_button.property_key] then
        --self.r.ShowConsoleMsg("Config icon_char after: " .. 
            --tostring(self.config.BUTTON_CUSTOM_PROPERTIES[self.current_button.property_key].icon_char) .. "\n")
    end
					    
					    -- Try direct assignment first
					    self.current_button.icon_char = selected_char
					    --self.r.ShowConsoleMsg("After direct assignment: " .. tostring(self.current_button.icon_char) .. "\n")
					    
					    -- Clear cached width
					    self.current_button.cached_width = nil
					    
					        self.current_button.icon_char = selected_char
					        self.current_button.icon_path = nil
					        
					    -- Save configuration
					    if self.saveConfigCallback then
					        self.saveConfigCallback()
					    end
					    
					    -- Close selector
					    self.is_open = false
					    break
					end                        
                        -- Draw centered text over button
                        self.r.ImGui_SetCursorPos(ctx, x + text_x, y + text_y)
                        self.r.ImGui_Text(ctx, char)
                        
                        -- Update grid position
                        grid_x = grid_x + 1
                        if grid_x >= grid_cols then
                            grid_x = 0
                            grid_y = grid_y + 1
                        end
                    end
                end
                -- Break outer loop if character was selected
                if selected_char then break end
            end
            
            -- Pop styles and fonts
            self.r.ImGui_PopFont(ctx)
            self.r.ImGui_PopStyleColor(ctx, 3)
            self.r.ImGui_EndChild(ctx)
        end
    end
    
    
    self.r.ImGui_End(ctx)
    self.r.ImGui_PopStyleColor(ctx)
end

function FontIconSelector:cleanup()
    self.is_open = false
    self.current_button = nil
    self.ctx = nil
end

return {
    new = function(reaper, config)
        return FontIconSelector.new(reaper, config)
    end
}