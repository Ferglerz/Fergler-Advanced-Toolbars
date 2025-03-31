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

    return self
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
        for i = 1, #ICON_FONTS do
            if ICON_FONTS[i].path == button.icon_font then
                self.selected_font_index = i
                break
            end
        end
    else

        self.selected_font_index = 1
    end
    -- Reset states
    self.close_requested = false
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

    -- Remember the context
    self.main_ctx = ctx

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_AlwaysAutoResize() |
        reaper.ImGui_WindowFlags_NoResize() |
        reaper.ImGui_WindowFlags_NoScrollbar() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

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

        -- Reset the global style
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        reaper.ImGui_End(ctx)

        -- Call the action to focus arrange window when closing with Esc
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            UTILS.focusArrangeWindow(true)
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
                    if i ~= self.selected_font_index then
                        -- Display a message to user
                        reaper.ImGui_Text(ctx, "Loading font...")
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
    return true
end

function IconSelector:cleanup()
    self.is_open = false
    self.current_button = nil
    self.close_requested = false
    self.current_font = nil
end

return IconSelector.new()