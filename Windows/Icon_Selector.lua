-- Windows/Icon_Selector.lua

local IconSelector = {}
IconSelector.__index = IconSelector

function IconSelector.new()
    local self = setmetatable({}, IconSelector)

    self.is_open = false
    self.current_button = nil
    self.font_maps = {}
    self.selected_font_index = 1
    self.close_requested = false

    -- Font management
    self.font_cache = {}
    self.fonts_loaded = {}
    self.pending_font = nil
    
    -- Don't create a separate context yet - we'll do it on demand
    self.ctx = nil

    -- Load available icon fonts
    self:scanIconFonts()

    return self
end

function IconSelector:scanIconFonts()
    -- Clear any existing font maps
    self.font_maps = {}

    local icon_fonts_dir = UTILS.joinPath(SCRIPT_PATH, "IconFonts")

    UTILS.ensureDirectoryExists(icon_fonts_dir)

    -- Get files in the directory
    local files = UTILS.getFilesInDirectory(icon_fonts_dir)

    -- Process each .ttf file
    for _, file in ipairs(files) do
        if file:match("%.ttf$") then
            -- Extract count from filename (e.g., FontIcons_28.ttf)
            local count = file:match("_(%d+)%.ttf$")
            count = tonumber(count) or 10 -- Default to 10 if no match

            -- Create icon range
            local start_code = 0x00C0 -- Start from 'À' character
            local end_code = start_code + count - 1

            -- Make sure we don't exceed valid Unicode ranges
            if end_code > 0x10FFFF then
                end_code = 0x10FFFF
            end

            local icon_range = {{start = start_code, laFin = end_code}}

            -- Create font map entry with proper path separator
            local font_path = "IconFonts" .. (reaper.GetOS():match("Win") and "\\" or "/") .. file

            local font_info = {
                path = font_path,
                name = file:gsub("%.ttf$", ""),
                display_name = UTILS.formatFontName(file:gsub("%.ttf$", "")),
                icon_range = icon_range
            }

            table.insert(self.font_maps, font_info)
        end
    end

    -- Set default selected font index if fonts are available
    if #self.font_maps > 0 then
        self.selected_font_index = 1
    end
end

function IconSelector:show(button)
    self.current_button = button
    self.is_open = true
    self.previous_icon = {
        icon_char = button.icon_char,
        icon_path = button.icon_path,
        icon_font = button.icon_font
    }

    -- Try to select the font previously used
    if button.icon_font then
        local saved_base_name = UTILS.getBaseFontName(button.icon_font)
        for i, font_map in ipairs(self.font_maps) do
            if UTILS.getBaseFontName(font_map.path) == saved_base_name then
                self.selected_font_index = i
                self.pending_font = i
                break
            end
        end
    else
        -- Default to first font
        self.pending_font = 1
    end

    -- Reset states
    self.close_requested = false
    
    -- Initialize the context if it doesn't exist
    if not self.ctx then
        self.ctx = reaper.ImGui_CreateContext("IconSelector")
        
        -- Load system font first
        local font_size = CONFIG.SIZES.TEXT or 14
        local system_fonts = {"Futura", "Arial", "Helvetica", "Segoe UI", "Verdana"}
        
        for _, font_name in ipairs(system_fonts) do
            local font = reaper.ImGui_CreateFont(font_name, font_size)
            if font then
                local success = pcall(function() reaper.ImGui_Attach(self.ctx, font) end)
                if success then
                    self.system_font = font
                    break
                end
            end
        end
        
        -- Now load icon fonts for this context
        for i, font_info in ipairs(self.font_maps) do
            local font_path = SCRIPT_PATH .. font_info.path
            
            if not self.font_cache[font_path] then
                local font_size = math.floor(CONFIG.ICON_FONT.SIZE * CONFIG.ICON_FONT.SCALE)
                local new_font = reaper.ImGui_CreateFont(font_path, font_size)
                
                if new_font then
                    local success = pcall(function() reaper.ImGui_Attach(self.ctx, new_font) end)
                    if success then
                        self.font_cache[font_path] = new_font
                        self.fonts_loaded[i] = true
                    end
                end
            else
                self.fonts_loaded[i] = true
            end
        end
    end
end

-- Convert code point to UTF-8 character
function IconSelector:codePointToUTF8(code)
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

function IconSelector:renderGrid(ctx)
    if not self.is_open or not self.current_button then
        return false
    end
    
    -- Only proceed if we have our own context
    if not self.ctx then
        return false
    end
    
    -- Use our separate context
    ctx = self.ctx
    
    -- Apply pending font selection
    if self.pending_font and self.fonts_loaded[self.pending_font] then
        self.selected_font_index = self.pending_font
        self.pending_font = nil
    end

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_AlwaysAutoResize() |
        reaper.ImGui_WindowFlags_NoResize() |
        reaper.ImGui_WindowFlags_NoScrollbar() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    -- Start a new frame with our context
    reaper.ImGui_SetNextWindowPos(ctx, 100, 100, reaper.ImGui_Cond_FirstUseEver())
    
    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    local visible, should_continue = reaper.ImGui_Begin(ctx, "Select Icon", true, window_flags)

    if not should_continue or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
        -- Restore previous icon on cancel
        if self.previous_icon then
            self.current_button.icon_char = self.previous_icon.icon_char
            self.current_button.icon_path = self.previous_icon.icon_path
            self.current_button.icon_font = self.previous_icon.icon_font
        end
        self.close_requested = true
        self.is_open = false

        -- Reset the global style
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        reaper.ImGui_End(ctx)

        -- Call the action to focus arrange window when closing with Esc
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            UTILS.focusArrangeWindow(true)
        end
        return false
    end

    if visible then
        -- Get the current font map
        local current_font_map = self.font_maps[self.selected_font_index]

        -- Set up grid layout parameters
        local cell_size, grid_cols, padding = 40, 5, 4

        -- Calculate grid dimensions
        local grid_width, grid_height = 0, 0
        if current_font_map then
            local total_chars = 0
            for _, range in ipairs(current_font_map.icon_range) do
                total_chars = total_chars + (range.laFin - range.start + 1)
            end

            grid_width = (cell_size + padding) * grid_cols + 16
            grid_height = (cell_size + padding) * math.ceil(total_chars / grid_cols)
        end

        -- Calculate font list height
        local line_height = reaper.ImGui_GetTextLineHeight(ctx)
        local font_list_height
        if #self.font_maps > 0 then
            font_list_height = (line_height + 6) * #self.font_maps + 10
        else
            font_list_height = line_height * 3
        end
        local total_height = math.max(grid_height, font_list_height)

        -- Font list section
        reaper.ImGui_BeginChild(ctx, "FontList", 200, total_height, reaper.ImGui_ChildFlags_Border())

        -- Display empty state if no fonts
        if #self.font_maps == 0 then
            reaper.ImGui_TextWrapped(ctx, "No icon fonts found. Place TTF files in the IconFonts folder.")
        else
            -- Display font list
            for i, font_map in ipairs(self.font_maps) do
                local is_selected = (i == self.selected_font_index)
                if reaper.ImGui_Selectable(ctx, font_map.display_name, is_selected) then
                    if i ~= self.selected_font_index and self.fonts_loaded[i] then
                        self.selected_font_index = i
                    end
                end
            end
        end

        reaper.ImGui_EndChild(ctx)

        reaper.ImGui_SameLine(ctx)

        -- Render the grid if we have a font
        if not current_font_map then
            reaper.ImGui_Text(ctx, "No icon font selected")
            reaper.ImGui_End(ctx)
            C.GlobalStyle.reset(ctx, colorCount, styleCount)
            return true
        end

        if reaper.ImGui_BeginChild(ctx, "IconGrid", grid_width, total_height, reaper.ImGui_ChildFlags_Border()) then
            -- Get the current font
            local font_path = SCRIPT_PATH .. current_font_map.path
            local current_font = self.font_cache[font_path]

            if current_font then
                reaper.ImGui_PushFont(ctx, current_font)

                local grid_x, grid_y = 0, 0
                for _, range in ipairs(current_font_map.icon_range) do
                    for code = range.start, range.laFin do
                        local char = self:codePointToUTF8(code)

                        local x = grid_x * (cell_size + padding)
                        local y = grid_y * (cell_size + padding)
                        reaper.ImGui_SetCursorPos(ctx, x, y)

                        local char_width = reaper.ImGui_CalcTextSize(ctx, char)
                        local text_x = (cell_size - char_width) / 2
                        local text_y = (cell_size - reaper.ImGui_GetTextLineHeight(ctx)) / 2

                        if reaper.ImGui_Button(ctx, "##icon_" .. code, cell_size, cell_size) then
                            self.current_button.icon_char = char
                            self.current_button.icon_path = nil
                            self.current_button.icon_font = current_font_map.path
                            self.current_button.cached_width = nil
                            self.current_button:saveChanges() 
                            self.close_requested = true
                            self.is_open = false
                            break
                        end

                        reaper.ImGui_SetCursorPos(ctx, x + text_x, y + text_y)
                        reaper.ImGui_Text(ctx, char)

                        grid_x = grid_x + 1
                        if grid_x >= grid_cols then
                            grid_x = 0
                            grid_y = grid_y + 1
                        end
                    end
                    if self.close_requested then
                        break
                    end
                end

                reaper.ImGui_PopFont(ctx)
            else
                reaper.ImGui_TextColored(ctx, 0xFF0000FF, "Font not loaded")
                reaper.ImGui_TextWrapped(ctx, "Please select a different font.")
            end

            reaper.ImGui_EndChild(ctx)
        end
    end

    reaper.ImGui_End(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    
    return self.is_open
end

function IconSelector:cleanup()
    self.is_open = false
    self.current_button = nil
    self.close_requested = false
    self.pending_font = nil
    
    -- Clean up the context when we're completely done
    if self.ctx then
        -- Clean up any attached fonts first
        for _, font in pairs(self.font_cache) do
            pcall(function() reaper.ImGui_Detach(self.ctx, font) end)
        end
        
        if self.system_font then
            pcall(function() reaper.ImGui_Detach(self.ctx, self.system_font) end)
        end
        
        reaper.ImGui_DestroyContext(self.ctx)
        self.ctx = nil
    end
    
    self.font_cache = {}
    self.fonts_loaded = {}
end

return IconSelector.new()