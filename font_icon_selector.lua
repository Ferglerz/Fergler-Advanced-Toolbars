-- font_icon_selector.lua

local FontIconSelector = {}
FontIconSelector.__index = FontIconSelector

function FontIconSelector:updateIconRangeFromFilename(font_path)
    -- Extract count from filename (e.g., FontIcons_28.ttf)
    local count = font_path:match("_(%d+)%.ttf$")
    count = tonumber(count) or 10 -- Default to 10 if no match

    -- Create icon range
    local start_code = 0x00C0 -- Start from 'À' character
    local end_code = start_code + count - 1

    -- Make sure we don't exceed valid Unicode ranges
    if end_code > 0x10FFFF then
        end_code = 0x10FFFF
    end

    return {{start = start_code, laFin = end_code}}
end

function FontIconSelector:getFilesInDirectory(directory)
    local files = {}

    -- Platform specific directory listing
    if self.r.GetOS():match("Win") then
        -- Windows
        local cmd = 'dir /b "' .. directory:gsub("/", "\\") .. '"'
        local handle = io.popen(cmd)
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    else
        -- macOS/Linux
        local cmd = 'ls -1 "' .. directory .. '"'
        local handle = io.popen(cmd)
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    end

    return files
end

function FontIconSelector.new(reaper, helpers)
    local self = setmetatable({}, FontIconSelector)
    self.r = reaper
    self.helpers = helpers
    self.is_open = false
    self.current_button = nil
    self.font_maps = {}
    self.selected_font_index = 1
    self.close_requested = false

    -- Font management
    self.requesting_font_change = false
    self.pending_font_index = nil
    self.font_cache = {}
    self.current_font = nil
    self.font_loaded = false
    self.main_ctx = nil
    self.fonts_to_load = {}

    -- Load available icon fonts
    self:scanIconFonts()

    return self
end

-- Use helpers for font name handling instead of local methods

function FontIconSelector:scanIconFonts()
    -- Clear any existing font maps
    self.font_maps = {}

    -- Get the script path and the IconFonts folder path
    local icon_fonts_dir = SCRIPT_PATH .. "IconFonts/"

    -- Check if the directory exists
    local dir_exists = self.r.file_exists(icon_fonts_dir)
    if not dir_exists then
        -- Create the IconFonts directory if it doesn't exist
        if self.r.RecursiveCreateDirectory(icon_fonts_dir, 0) == 0 then
            self.r.ShowMessageBox("Failed to create IconFonts directory", "Error", 0)
            return
        end
    end

    -- Get files in the directory
    local files = self:getFilesInDirectory(icon_fonts_dir)

    -- Process each .ttf file
    for _, file in ipairs(files) do
        if file:match("%.ttf$") then
            local font_info = {}
            font_info.path = "IconFonts/" .. file
            font_info.name = file:gsub("%.ttf$", "")
            font_info.display_name = self.helpers.formatFontName(font_info.name)
            font_info.icons = self:updateIconRangeFromFilename(font_info.path)
            table.insert(self.font_maps, font_info)
        end
    end

    -- Set default selected font index if fonts are available
    if #self.font_maps > 0 then
        self.selected_font_index = 1
    end
end

function FontIconSelector:loadFont(ctx, font_path_or_index)
    local font_index
    
    -- Handle both index and path inputs
    if type(font_path_or_index) == "number" then
        font_index = font_path_or_index
    else
        -- Get font index from path, ignoring numeric suffix
        local path_base_name = self.helpers.getBaseFontName(font_path_or_index)
        font_index = self.helpers.matchFontByBaseName(path_base_name, self.font_maps)
    end
    
    if not font_index or not self.font_maps[font_index] then
        return nil
    end
    
    -- Get full font path
    local font_path = SCRIPT_PATH .. self.font_maps[font_index].path
    
    -- Check cache first
    if self.font_cache[font_path] then
        return self.font_cache[font_path]
    end
    
    -- If we're in the middle of a frame, we can't attach a new font
    -- Schedule the font to be loaded on the next frame
    if not table.contains(self.fonts_to_load, font_index) then
        table.insert(self.fonts_to_load, font_index)
    end
    
    -- Return nil for now, the font will be available next frame
    return nil
end

function FontIconSelector:show(button)
    self.current_button = button
    self.is_open = true
    self.previous_icon = {
        icon_char = button.icon_char,
        icon_path = button.icon_path,
        icon_font = button.icon_font
    }

    -- Try to select the font previously used
    if button.icon_font then
        local saved_base_name = self.helpers.getBaseFontName(button.icon_font)
        local matched_index = self.helpers.matchFontByBaseName(saved_base_name, self.font_maps)
        if matched_index then
            self.selected_font_index = matched_index
            self.pending_font_index = matched_index
        else
            -- Default to first font if not found
            self.pending_font_index = 1
        end
    else
        -- Default to first font
        self.pending_font_index = 1
    end

    -- Reset states
    self.requesting_font_change = false
    self.close_requested = false
    self.font_loaded = false
end

function FontIconSelector:codePointToUTF8(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
    elseif code < 0x10000 then
        return string.char(
            0xE0 + math.floor(code / 0x1000),
            0x80 + math.floor((code % 0x1000) / 0x40),
            0x80 + (code % 0x40)
        )
    end
    return string.char(
        0xF0 + math.floor(code / 0x40000),
        0x80 + math.floor((code % 0x40000) / 0x1000),
        0x80 + math.floor((code % 0x1000) / 0x40),
        0x80 + (code % 0x40)
    )
end

-- Calculate window sizes for the icon grid
function FontIconSelector:calculateGridSize(ctx, current_font_map, cell_size, grid_cols, padding)
    local total_chars = 0
    for _, range in ipairs(current_font_map.icons) do
        total_chars = total_chars + (range.laFin - range.start + 1)
    end
    
    local grid_width = (cell_size + padding) * grid_cols + 16
    local grid_height = (cell_size + padding) * math.ceil(total_chars / grid_cols)
    
    return grid_width, grid_height
end

-- Calculate font list height
function FontIconSelector:calculateFontListHeight(ctx)
    local line_height = self.r.ImGui_GetTextLineHeight(ctx)
    local font_count = #self.font_maps
    
    if font_count == 0 then
        return line_height * 3 -- Just enough for the "No icon fonts found" message
    else
        -- Use a simple approximation with fixed padding
        return (line_height + 6) * font_count + 10
    end
end

-- This function is called before any frames begin to prepare fonts
function FontIconSelector:prepareNextFrame(ctx)
    -- Handle pending font loads
    if #self.fonts_to_load > 0 or self.pending_font_index then
        -- Process pending font index first (from UI interactions)
        if self.pending_font_index then
            local font_path = SCRIPT_PATH .. self.font_maps[self.pending_font_index].path
            
            -- Create new font if not in cache
            if not self.font_cache[font_path] then
                local font_size = math.floor(CONFIG.ICON_FONT.SIZE * CONFIG.ICON_FONT.SCALE)
                local new_font = self.r.ImGui_CreateFont(font_path, font_size)
                
                if new_font then
                    -- Attach to ImGui context
                    self.r.ImGui_Attach(ctx, new_font)
                    self.font_cache[font_path] = new_font
                else
                    self.r.ShowConsoleMsg("Failed to load font: " .. font_path .. "\n")
                end
            end
            
            -- Update selected index
            self.selected_font_index = self.pending_font_index
            self.current_font = self.font_cache[font_path]
            self.font_loaded = true
            self.pending_font_index = nil
        end
        
        -- Process one additional font from the queue each frame
        if #self.fonts_to_load > 0 then
            local font_index = table.remove(self.fonts_to_load, 1)
            local font_path = SCRIPT_PATH .. self.font_maps[font_index].path
            
            -- Create new font if not in cache
            if not self.font_cache[font_path] then
                local font_size = math.floor(CONFIG.ICON_FONT.SIZE * CONFIG.ICON_FONT.SCALE)
                local new_font = self.r.ImGui_CreateFont(font_path, font_size)
                
                if new_font then
                    -- Attach to ImGui context
                    self.r.ImGui_Attach(ctx, new_font)
                    self.font_cache[font_path] = new_font
                else
                    self.r.ShowConsoleMsg("Failed to load font from queue: " .. font_path .. "\n")
                end
            end
        end
    end
    
    -- Handle close requests
    if self.close_requested then
        self.is_open = false
        self.close_requested = false
        return false
    end
    
    return self.is_open
end

function FontIconSelector:renderGrid(ctx)
    if not self.is_open or not self.current_button then
        return false
    end

    -- Remember the context
    self.main_ctx = ctx

    local window_flags =
        self.r.ImGui_WindowFlags_NoCollapse() | 
        self.r.ImGui_WindowFlags_AlwaysAutoResize() |
        self.r.ImGui_WindowFlags_NoResize() |
        self.r.ImGui_WindowFlags_NoScrollbar() |
        self.r.ImGui_WindowFlags_NoFocusOnAppearing()

    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), 0x2A2A2AFF)

    local visible, should_continue = self.r.ImGui_Begin(ctx, "Select Icon", true, window_flags)

    if not should_continue or self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
        if self.previous_icon then
            self.current_button.icon_char = self.previous_icon.icon_char
            self.current_button.icon_path = self.previous_icon.icon_path
            self.current_button.icon_font = self.previous_icon.icon_font
        end
        self.close_requested = true
        self.r.ImGui_PopStyleColor(ctx)
        self.r.ImGui_End(ctx)

        -- Call the action to focus arrange window when closing with Esc
        if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) and self.focusArrangeCallback then
            self.focusArrangeCallback()
        end
        return true
    end

    if visible then
        -- Get the current font map
        local current_font_map = self.font_maps[self.selected_font_index]
        
        -- Calculate sizes
        local cell_size, grid_cols, padding = 40, 5, 4
        local grid_width, grid_height = 0, 0
        if current_font_map then
            grid_width, grid_height = self:calculateGridSize(ctx, current_font_map, cell_size, grid_cols, padding)
        end
        
        local font_list_height = self:calculateFontListHeight(ctx)
        local total_height = math.max(grid_height, font_list_height)
        
        -- Font list section - with no scrollbar, auto-sized
        self.r.ImGui_BeginChild(ctx, "FontList", 200, total_height, self.r.ImGui_ChildFlags_Border())

        -- Display empty state if no fonts
        if #self.font_maps == 0 then
            self.r.ImGui_TextWrapped(ctx, "No icon fonts found. Place TTF files in the IconFonts folder.")
        else
            -- Display font list without headers/counts
            for i, font_map in ipairs(self.font_maps) do
                local is_selected = (i == self.selected_font_index)
                if self.r.ImGui_Selectable(ctx, font_map.display_name, is_selected) then
                    if i ~= self.selected_font_index then
                        -- Schedule font change for next frame
                        self.pending_font_index = i
                        self.requesting_font_change = true

                        -- Display a message to user
                        self.r.ImGui_Text(ctx, "Loading font...")
                        self.r.ImGui_EndChild(ctx)
                        self.r.ImGui_End(ctx)
                        self.r.ImGui_PopStyleColor(ctx)
                        return true
                    end
                end
            end
        end

        self.r.ImGui_EndChild(ctx)

        self.r.ImGui_SameLine(ctx)

        -- Render the grid if we have a font
        if not current_font_map then
            self.r.ImGui_Text(ctx, "No icon font selected")
            self.r.ImGui_End(ctx)
            self.r.ImGui_PopStyleColor(ctx)
            return true
        end

        if self.r.ImGui_BeginChild(ctx, "IconGrid", grid_width, total_height, self.r.ImGui_ChildFlags_Border()) then
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x3D3D3DFF)
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x4D4D4DFF)
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x5D5D5DFF)

            -- Get the current font
            if not self.current_font then
                local font_path = SCRIPT_PATH .. current_font_map.path
                self.current_font = self.font_cache[font_path]
            end

            if self.current_font and self.font_loaded then
                self.r.ImGui_PushFont(ctx, self.current_font)

                local grid_x, grid_y = 0, 0
                for _, range in ipairs(current_font_map.icons) do
                    for code = range.start, range.laFin do
                        local success, char =
                            pcall(
                            function()
                                return self:codePointToUTF8(code)
                            end
                        )
                        if success and char then
                            local x = grid_x * (cell_size + padding)
                            local y = grid_y * (cell_size + padding)
                            self.r.ImGui_SetCursorPos(ctx, x, y)

                            local char_width = self.r.ImGui_CalcTextSize(ctx, char)
                            local text_x = (cell_size - char_width) / 2
                            local text_y = (cell_size - self.r.ImGui_GetTextLineHeight(ctx)) / 2

                            if self.r.ImGui_Button(ctx, "##icon_" .. code, cell_size, cell_size) then
                                self.current_button.icon_char = char
                                self.current_button.icon_path = nil
                                -- Store the base font name to be resilient to version changes
                                self.current_button.icon_font = current_font_map.path
                                self.current_button.cached_width = nil
                                if self.saveConfigCallback then
                                    self.saveConfigCallback()
                                end
                                self.close_requested = true
                                break
                            end

                            self.r.ImGui_SetCursorPos(ctx, x + text_x, y + text_y)
                            self.r.ImGui_Text(ctx, char)

                            grid_x = grid_x + 1
                            if grid_x >= grid_cols then
                                grid_x = 0
                                grid_y = grid_y + 1
                            end
                        end
                    end
                    if self.close_requested then
                        break
                    end
                end

                self.r.ImGui_PopFont(ctx)
            else
                -- If font is not available, show message
                self.r.ImGui_TextColored(ctx, 0xFF0000FF, "Font not loaded")
                self.r.ImGui_TextWrapped(ctx, "Please select a different font.")
            end

            self.r.ImGui_PopStyleColor(ctx, 3)
            self.r.ImGui_EndChild(ctx)
        end
    end

    self.r.ImGui_End(ctx)
    self.r.ImGui_PopStyleColor(ctx)
    return true
end

function FontIconSelector:cleanup()
    self.is_open = false
    self.current_button = nil
    self.close_requested = false
    self.requesting_font_change = false
    self.pending_font_index = nil
    self.current_font = nil
    self.font_loaded = false
    self.fonts_to_load = {}

    -- We don't clear font_cache as we want to reuse loaded fonts
end

return {
    new = function(reaper, helpers)
        return FontIconSelector.new(reaper, helpers)
    end
}