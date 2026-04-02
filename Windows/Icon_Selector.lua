-- Windows/Icon_Selector.lua

local ICON_FONTS_LIB = require("Utils.icon_fonts")

local IconSelector = {}
IconSelector.__index = IconSelector

function IconSelector.new()
    local self = setmetatable({}, IconSelector)

    self.is_open = false
    self.current_button = nil
    -- ImGui context that opened the selector (only render there; avoids duplicate windows when multiple toolbars run)
    self.owner_ctx = nil
    self.font_maps = {}
    self.selected_font_index = 1
    self.close_requested = false
    self.icon_filter = ""

    -- Font management - fonts will be loaded in main context
    self.pending_font = nil

    self:scanIconFonts()

    return self
end

function IconSelector:scanIconFonts()
    -- Same table as _G.ICON_FONTS (filled before modules load)
    self.font_maps = ICON_FONTS
end

function IconSelector:show(button, owner_ctx)
    self.current_button = button
    if C.PopupContext then
        C.PopupContext.open(self, owner_ctx)
    else
        self.owner_ctx = owner_ctx
        self.is_open = true
    end
    self.previous_icon = {
        icon_char = button.icon_char,
        icon_path = button.icon_path,
        icon_font = button.icon_font
    }

    self.icon_filter = ""

    if button.icon_font then
        local saved_norm = UTILS.normalizeSlashes(button.icon_font)
        local found = false
        for i, font_map in ipairs(self.font_maps) do
            if UTILS.normalizeSlashes(font_map.path) == saved_norm then
                self.selected_font_index = i
                self.pending_font = i
                found = true
                break
            end
        end
        if not found then
            local saved_base_name = UTILS.getBaseFontName(button.icon_font)
            for i, font_map in ipairs(self.font_maps) do
                if UTILS.getBaseFontName(font_map.path) == saved_base_name then
                    self.selected_font_index = i
                    self.pending_font = i
                    break
                end
            end
        end
    else
        self.pending_font = 1
    end

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
    if C.PopupContext then
        if not C.PopupContext.shouldRender(self, ctx) or not self.current_button then
            return false
        end
    elseif (not self.is_open or not self.current_button) then
        return false
    end

    -- Apply pending font selection
    if self.pending_font then
        self.selected_font_index = self.pending_font
        self.pending_font = nil
    end

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_AlwaysAutoResize() |
        reaper.ImGui_WindowFlags_NoResize() |
        reaper.ImGui_WindowFlags_NoScrollbar() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    -- Use the passed context directly
    reaper.ImGui_SetNextWindowPos(ctx, 100, 100, reaper.ImGui_Cond_FirstUseEver())
    
    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    local visible, should_continue = reaper.ImGui_Begin(ctx, "Select Icon", true, window_flags)
    UTILS.snapWindowToMinimum(ctx, 0, 0, true)

    if not should_continue or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
        -- Restore previous icon on cancel
        if self.previous_icon then
            self.current_button.icon_char = self.previous_icon.icon_char
            self.current_button.icon_path = self.previous_icon.icon_path
            self.current_button.icon_font = self.previous_icon.icon_font
        end
        
        self.close_requested = true
        if C.PopupContext then
            C.PopupContext.close(self)
        else
            self.is_open = false
        end

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
        local current_font_map = self.font_maps[self.selected_font_index]

        local cell_size, grid_cols, padding = 40, 5, 4
        local grid_width, grid_height = 0, 0
        if current_font_map then
            local total_chars = 0
            for _, range in ipairs(current_font_map.icon_range) do
                total_chars = total_chars + (range.laFin - range.start + 1)
            end

            grid_width = (cell_size + padding) * grid_cols + 16
            if current_font_map.kind == "per_icon" then
                grid_height = cell_size + padding + 24
                grid_width = math.max(grid_width, cell_size + 32)
            else
                grid_height = (cell_size + padding) * math.ceil(total_chars / grid_cols)
            end
        end

        local line_height = reaper.ImGui_GetTextLineHeight(ctx)
        local list_rows = 0
        local needle = (self.icon_filter or ""):lower()
        for _, font_map in ipairs(self.font_maps) do
            if needle == "" then
                list_rows = list_rows + 1
            else
                local dn = (font_map.display_name or ""):lower()
                local nm = (font_map.name or ""):lower()
                if dn:find(needle, 1, true) or nm:find(needle, 1, true) then
                    list_rows = list_rows + 1
                end
            end
        end
        local font_list_height = math.min(360, math.max(120, (line_height + 6) * (list_rows + 2) + 48))
        local total_height = math.max(grid_height + 8, font_list_height)

        local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
        reaper.ImGui_BeginChild(ctx, "FontList", 220, total_height, child_flags)

        if #self.font_maps == 0 then
            reaper.ImGui_TextWrapped(ctx, "No icon fonts found. Place TTF files in the IconFonts folder.")
        else
            reaper.ImGui_SetNextItemWidth(ctx, 200)
            local changed, new_filter =
                reaper.ImGui_InputTextWithHint(ctx, "##iconsearch", "Search...", self.icon_filter or "")
            if changed then
                self.icon_filter = new_filter or ""
            end
            for i, font_map in ipairs(self.font_maps) do
                local show = true
                if needle ~= "" then
                    local dn = (font_map.display_name or ""):lower()
                    local nm = (font_map.name or ""):lower()
                    show = dn:find(needle, 1, true) or nm:find(needle, 1, true)
                end
                if show then
                    local is_selected = (i == self.selected_font_index)
                    if reaper.ImGui_Selectable(ctx, font_map.display_name, is_selected) then
                        self.selected_font_index = i
                    end
                end
            end
        end

        reaper.ImGui_EndChild(ctx)

        reaper.ImGui_SameLine(ctx)

        if not current_font_map then
            reaper.ImGui_Text(ctx, "No icon font selected")
            reaper.ImGui_End(ctx)
            C.GlobalStyle.reset(ctx, colorCount, styleCount)
            return true
        end

        local grid_child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
        if reaper.ImGui_BeginChild(ctx, "IconGrid", grid_width, total_height, grid_child_flags) then
            local path_key = UTILS.normalizeSlashes(current_font_map.path)
            local current_font = nil
            for _, icon_font in ipairs(ICON_FONTS) do
                if UTILS.normalizeSlashes(icon_font.path) == path_key then
                    current_font = icon_font.font
                    break
                end
            end

            if current_font then
                reaper.ImGui_PushFont(ctx, current_font, CONFIG.ICON_FONT.SIZE)

                if current_font_map.kind == "per_icon" then
                    local code = ICON_FONTS_LIB.PER_ICON_CODEPOINT
                    local char = self:codePointToUTF8(code)
                    local x, y = 0, 0
                    reaper.ImGui_SetCursorPos(ctx, x, y)
                    local char_width = reaper.ImGui_CalcTextSize(ctx, char)
                    local text_x = (cell_size - char_width) / 2
                    local text_y = (cell_size - reaper.ImGui_GetTextLineHeight(ctx)) / 2
                    if reaper.ImGui_Button(ctx, "##pericon_pick", cell_size, cell_size) then
                        self.current_button.icon_char = char
                        self.current_button.icon_path = nil
                        self.current_button.icon_font = current_font_map.path
                        self.current_button.cached_width = nil
                        self.current_button:saveChanges()
                        self.close_requested = true
                        if C.PopupContext then
                            C.PopupContext.close(self)
                        else
                            self.is_open = false
                        end
                    end
                    reaper.ImGui_SetCursorPos(ctx, x + text_x, y + text_y)
                    reaper.ImGui_Text(ctx, char)
                    reaper.ImGui_SetCursorPos(ctx, 0, cell_size + padding)
                    reaper.ImGui_TextWrapped(ctx, "One glyph per font (U+0041). Click to use.")
                else
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
                                if C.PopupContext then
                                    C.PopupContext.close(self)
                                else
                                    self.is_open = false
                                end
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
    if C.PopupContext then
        C.PopupContext.close(self)
    else
        self.is_open = false
        self.owner_ctx = nil
    end
    self.current_button = nil
    self.close_requested = false
    self.pending_font = nil
end

return IconSelector.new()