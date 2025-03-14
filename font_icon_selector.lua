-- font_icon_selector.lua

local GeneralUtils = require "general_utils"

local FontIconSelector = {}
FontIconSelector.__index = FontIconSelector

function FontIconSelector.new(reaper, helpers)
    local self = setmetatable({}, FontIconSelector)
    self.r = reaper
    self.helpers = helpers
    self.is_open = false
    self.current_button = nil
    self.font_maps = {}
    self.selected_font_index = 1
    self.close_requested = false

    -- Font management - simplified
    self.font_cache = {}
    self.main_ctx = nil
    self.fonts_to_load = {}
    self.pending_font = nil

    -- Load available icon fonts
    self:scanIconFonts()

    return self
end

function FontIconSelector:scanIconFonts()
    -- Clear any existing font maps
    self.font_maps = {}

    -- Get the script path and the IconFonts folder path
    local icon_fonts_dir = SCRIPT_PATH .. "IconFonts/"

    -- Create directory if it doesn't exist
    if not self.r.file_exists(icon_fonts_dir) then
        self.r.RecursiveCreateDirectory(icon_fonts_dir, 0)
    end

    -- Get files in the directory
    local files = GeneralUtils.getFilesInDirectory(icon_fonts_dir, self.r)

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

            local icons = {{start = start_code, laFin = end_code}}

            -- Create font map entry
            local font_info = {
                path = "IconFonts/" .. file,
                name = file:gsub("%.ttf$", ""),
                display_name = self.helpers.formatFontName(file:gsub("%.ttf$", "")),
                icons = icons
            }

            table.insert(self.font_maps, font_info)
        end
    end

    -- Set default selected font index if fonts are available
    if #self.font_maps > 0 then
        self.selected_font_index = 1
    end
end

function FontIconSelector:loadFont(ctx, font_path_or_index)
    -- Unified function to get a font by path or index
    local font_info

    if type(font_path_or_index) == "number" then
        font_info = self.font_maps[font_path_or_index]
    else
        for _, info in ipairs(self.font_maps) do
            if self.helpers.getBaseFontName(info.path) == self.helpers.getBaseFontName(font_path_or_index) then
                font_info = info
                break
            end
        end
    end

    if not font_info then
        return nil
    end

    -- Get full font path
    local font_path = SCRIPT_PATH .. font_info.path

    -- Check cache first
    if self.font_cache[font_path] then
        return self.font_cache[font_path]
    end

    -- Schedule loading
    if type(font_path_or_index) == "number" then
        table.insert(self.fonts_to_load, font_path_or_index)
    else
        for i, info in ipairs(self.font_maps) do
            if self.helpers.getBaseFontName(info.path) == self.helpers.getBaseFontName(font_path_or_index) then
                table.insert(self.fonts_to_load, i)
                break
            end
        end
    end

    return nil -- Font will be loaded on next frame
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
        for i, font_map in ipairs(self.font_maps) do
            if self.helpers.getBaseFontName(font_map.path) == saved_base_name then
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
end

-- This function handles all font loading in one place
function FontIconSelector:prepareNextFrame(ctx)
    -- Process pending font changes first
    if self.pending_font then
        local font_info = self.font_maps[self.pending_font]
        if font_info then
            local font_path = SCRIPT_PATH .. font_info.path

            if not self.font_cache[font_path] then
                local font_size = math.floor(CONFIG.ICON_FONT.SIZE * CONFIG.ICON_FONT.SCALE)
                local new_font = self.r.ImGui_CreateFont(font_path, font_size)

                if new_font then
                    self.r.ImGui_Attach(ctx, new_font)
                    self.font_cache[font_path] = new_font
                end
            end

            self.selected_font_index = self.pending_font
            self.current_font = self.font_cache[font_path]
        end

        self.pending_font = nil
    end

    -- Process queued fonts (limit to one per frame to prevent stuttering)
    if #self.fonts_to_load > 0 then
        local font_index = table.remove(self.fonts_to_load, 1)
        local font_info = self.font_maps[font_index]

        if font_info then
            local font_path = SCRIPT_PATH .. font_info.path

            if not self.font_cache[font_path] then
                local font_size = math.floor(CONFIG.ICON_FONT.SIZE * CONFIG.ICON_FONT.SCALE)
                local new_font = self.r.ImGui_CreateFont(font_path, font_size)

                if new_font then
                    self.r.ImGui_Attach(ctx, new_font)
                    self.font_cache[font_path] = new_font
                end
            end
        end
    end

    -- Handle close requests
    if self.close_requested then
        self.is_open = false
        self.close_requested = false
    end

    return self.is_open
end

-- Convert code point to UTF-8 character
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

function FontIconSelector:renderGrid(ctx)
    if not self.is_open or not self.current_button then
        return false
    end

    -- Remember the context
    self.main_ctx = ctx

    local window_flags =
        self.r.ImGui_WindowFlags_NoCollapse() | self.r.ImGui_WindowFlags_AlwaysAutoResize() |
        self.r.ImGui_WindowFlags_NoResize() |
        self.r.ImGui_WindowFlags_NoScrollbar() |
        self.r.ImGui_WindowFlags_NoFocusOnAppearing()

    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), 0x2A2A2AFF)

    local visible, should_continue = self.r.ImGui_Begin(ctx, "Select Icon", true, window_flags)

    if not should_continue or self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
        -- Restore previous icon on cancel
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

        -- Set up grid layout parameters
        local cell_size, grid_cols, padding = 40, 5, 4

        -- Calculate grid dimensions
        local grid_width, grid_height = 0, 0
        if current_font_map then
            local total_chars = 0
            for _, range in ipairs(current_font_map.icons) do
                total_chars = total_chars + (range.laFin - range.start + 1)
            end

            grid_width = (cell_size + padding) * grid_cols + 16
            grid_height = (cell_size + padding) * math.ceil(total_chars / grid_cols)
        end

        -- Calculate font list height
        local line_height = self.r.ImGui_GetTextLineHeight(ctx)
        local font_list_height
        if #self.font_maps > 0 then
            font_list_height = (line_height + 6) * #self.font_maps + 10
        else
            font_list_height = line_height * 3
        end
        local total_height = math.max(grid_height, font_list_height)

        -- Font list section
        self.r.ImGui_BeginChild(ctx, "FontList", 200, total_height, self.r.ImGui_ChildFlags_Border())

        -- Display empty state if no fonts
        if #self.font_maps == 0 then
            self.r.ImGui_TextWrapped(ctx, "No icon fonts found. Place TTF files in the IconFonts folder.")
        else
            -- Display font list
            for i, font_map in ipairs(self.font_maps) do
                local is_selected = (i == self.selected_font_index)
                if self.r.ImGui_Selectable(ctx, font_map.display_name, is_selected) then
                    if i ~= self.selected_font_index then
                        self.pending_font = i
                        -- Display a message to user
                        self.r.ImGui_Text(ctx, "Loading font...")
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
            local font_path = SCRIPT_PATH .. current_font_map.path
            local current_font = self.font_cache[font_path]

            if current_font then
                self.r.ImGui_PushFont(ctx, current_font)

                local grid_x, grid_y = 0, 0
                for _, range in ipairs(current_font_map.icons) do
                    for code = range.start, range.laFin do
                        local char = self:codePointToUTF8(code)

                        local x = grid_x * (cell_size + padding)
                        local y = grid_y * (cell_size + padding)
                        self.r.ImGui_SetCursorPos(ctx, x, y)

                        local char_width = self.r.ImGui_CalcTextSize(ctx, char)
                        local text_x = (cell_size - char_width) / 2
                        local text_y = (cell_size - self.r.ImGui_GetTextLineHeight(ctx)) / 2

                        if self.r.ImGui_Button(ctx, "##icon_" .. code, cell_size, cell_size) then
                            self.current_button.icon_char = char
                            self.current_button.icon_path = nil
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
                    if self.close_requested then
                        break
                    end
                end

                self.r.ImGui_PopFont(ctx)
            else
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
    self.pending_font = nil
    self.current_font = nil
    self.fonts_to_load = {}
    -- We don't clear font_cache as we want to reuse loaded fonts
end

return {
    new = function(reaper, helpers)
        return FontIconSelector.new(reaper, helpers)
    end
}
