--font_icon_selector.lua

local FontIconSelector = {}
FontIconSelector.__index = FontIconSelector

function FontIconSelector.new(reaper)
    local self = setmetatable({}, FontIconSelector)
    self.r = reaper
    self.is_open = false
    self.current_button = nil
    self.ctx = nil
    self.is_font_attached = false
    self.icons = {{start = 0x0021, laFin = 0x007E}}
    return self
end

function FontIconSelector:show(button)
    self.current_button = button
    self.is_open = true
    self.previous_icon = {
        icon_char = button.icon_char,
        icon_path = button.icon_path
    }
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

function FontIconSelector:renderGrid(ctx, icon_font)
    if not self.is_open or not self.current_button then return end

    local selected_char = nil
    if ctx ~= self.ctx then self.ctx = ctx end

    local window_flags = self.r.ImGui_WindowFlags_NoCollapse() |
                         self.r.ImGui_WindowFlags_AlwaysAutoResize() |
                         self.r.ImGui_WindowFlags_NoResize() |
                         self.r.ImGui_WindowFlags_NoFocusOnAppearing()

    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), 0x2A2A2AFF)

    local visible, should_continue = self.r.ImGui_Begin(ctx, "Select Icon Character", true, window_flags)

    if not should_continue or self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
        if self.previous_icon then
            self.icon_char = self.previous_icon.icon_char
            self.icon_path = self.previous_icon.icon_path
        end
        self.is_open = false
        self.r.ImGui_PopStyleColor(ctx)
        self.r.ImGui_End(ctx)
        
        -- Call the action to focus arrange window when closing with Esc
        if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) and self.focusArrangeCallback then
            self.focusArrangeCallback()
        end
        return
    end

    if visible then
        local cell_size, grid_cols, padding = 40, 8, 4
        local window_width = (cell_size + padding) * grid_cols
        local total_chars = 0
        for _, range in ipairs(self.icons) do
            total_chars = total_chars + (range.laFin - range.start + 1)
        end
        local grid_height = (cell_size + padding) * math.ceil(total_chars / grid_cols)

        if self.r.ImGui_BeginChild(ctx, "IconGrid", window_width, grid_height) then
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x3D3D3DFF)
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x4D4D4DFF)
            self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x5D5D5DFF)
            self.r.ImGui_PushFont(ctx, icon_font)

            local grid_x, grid_y = 0, 0
            for _, range in ipairs(self.icons) do
                for code = range.start, range.laFin do
                    local success, char = pcall(function() return self:codePointToUTF8(code) end)
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
                            self.current_button.cached_width = nil
                            if self.saveConfigCallback then self.saveConfigCallback() end
                            self.is_open = false
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
                if selected_char then break end
            end

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
    new = function(reaper) return FontIconSelector.new(reaper) end
}
