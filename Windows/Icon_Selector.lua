-- Windows/Icon_Selector.lua

local ICON_FONTS_LIB = require("Utils.icon_fonts")

local IconSelector = {}
IconSelector.__index = IconSelector

local ICON_CHAR = string.char(ICON_FONTS_LIB.ICON_CODEPOINT)

local function sortedCategories(font_maps)
    local seen = {}
    for _, fm in ipairs(font_maps) do
        seen[fm.category or "Other"] = true
    end
    local cats = {}
    for c in pairs(seen) do
        table.insert(cats, c)
    end
    table.sort(
        cats,
        function(a, b)
            return a:lower() < b:lower()
        end
    )
    return cats
end

local function categoryLabel(c)
    return (c:gsub("_", " "))
end

function IconSelector.new()
    local self = setmetatable({}, IconSelector)

    self.is_open = false
    self.current_button = nil
    self.owner_ctx = nil
    self.font_maps = {}
    self.close_requested = false
    self.icon_filter = ""
    self.icon_category_index = 1

    self:scanIconFonts()

    return self
end

function IconSelector:scanIconFonts()
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
    self.close_requested = false

    local cats = sortedCategories(self.font_maps)
    self.icon_category_index = 1
    if button.icon_font then
        local norm = UTILS.normalizeSlashes(button.icon_font)
        local cat_from_path = norm:match("IconFonts/icons/([^/]+)/")
        if cat_from_path then
            for i, c in ipairs(cats) do
                if c == cat_from_path then
                    self.icon_category_index = i
                    break
                end
            end
        end
    end
end

function IconSelector:renderGrid(ctx)
    if C.PopupContext then
        if not C.PopupContext.shouldRender(self, ctx) or not self.current_button then
            return false
        end
    elseif (not self.is_open or not self.current_button) then
        return false
    end

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    reaper.ImGui_SetNextWindowPos(ctx, 100, 100, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSize(ctx, 720, 620, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 520, 400, 4000, 4000)

    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    local visible, should_continue = reaper.ImGui_Begin(ctx, "Select Icon", true, window_flags)
    UTILS.snapWindowToMinimum(ctx, 0, 0, true)

    if not should_continue or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
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

        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        reaper.ImGui_End(ctx)

        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            UTILS.focusArrangeWindow(true)
        end
        return false
    end

    if visible then
        local needle = (self.icon_filter or ""):lower()
        local cats = sortedCategories(self.font_maps)
        if self.icon_category_index > #cats then
            self.icon_category_index = math.max(1, #cats)
        end

        if #self.font_maps == 0 then
            reaper.ImGui_TextWrapped(
                ctx,
                "No icon fonts found. Add .ttf files under IconFonts/ (see IconFonts/icons/ after running tools/icon_fonts/split_all_sources.py)."
            )
        else
            reaper.ImGui_SetNextItemWidth(ctx, (needle == "" and #cats > 0) and 360 or 520)
            local changed, new_filter =
                reaper.ImGui_InputTextWithHint(
                    ctx,
                    "##iconsearch",
                    "Type to search all folders; leave empty to browse by category…",
                    self.icon_filter or ""
                )
            if changed then
                self.icon_filter = new_filter or ""
            end

            needle = (self.icon_filter or ""):lower()
            local active_category = cats[self.icon_category_index]

            local filtered = {}
            for i, font_map in ipairs(self.font_maps) do
                local show = true
                if needle ~= "" then
                    local dn = (font_map.display_name or ""):lower()
                    local nm = (font_map.name or ""):lower()
                    local cat = (font_map.category or ""):lower()
                    show = dn:find(needle, 1, true) or nm:find(needle, 1, true) or cat:find(needle, 1, true)
                elseif active_category then
                    show = (font_map.category or "Other") == active_category
                end
                if show then
                    table.insert(filtered, {index = i, font_map = font_map})
                end
            end

            local cell_size, cols, pad = 44, 7, 6
            local cat_list_w = 168
            local grid_w = pad + cols * (cell_size + pad)
            local _, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
            avail_h = tonumber(avail_h) or 400
            -- Fill remaining window height; minimum taller than the old 200px cap (window is resizable).
            local grid_view_h = math.max(340, avail_h)

            local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0

            if needle == "" and #cats > 0 then
                reaper.ImGui_BeginChild(ctx, "IconCategories", cat_list_w, grid_view_h, child_flags)
                reaper.ImGui_TextDisabled(ctx, "Categories")
                for i, cat in ipairs(cats) do
                    local is_sel = (i == self.icon_category_index)
                    if reaper.ImGui_Selectable(ctx, categoryLabel(cat), is_sel) then
                        self.icon_category_index = i
                    end
                end
                reaper.ImGui_EndChild(ctx)
                reaper.ImGui_SameLine(ctx, 0, 10)
            end

            local grid_child_w = grid_w
            reaper.ImGui_BeginChild(ctx, "IconGrid", grid_child_w, grid_view_h, child_flags)

            if needle ~= "" and #filtered > 0 then
                reaper.ImGui_TextDisabled(ctx, "All categories — " .. #filtered .. " match(es)")
                reaper.ImGui_Spacing(ctx)
            end

            local grid_origin_y = reaper.ImGui_GetCursorPosY(ctx)

            for idx, entry in ipairs(filtered) do
                local col = (idx - 1) % cols
                local row = math.floor((idx - 1) / cols)
                local x = pad + col * (cell_size + pad)
                local y = grid_origin_y + pad + row * (cell_size + pad)
                reaper.ImGui_SetCursorPos(ctx, x, y)

                local font_map = entry.font_map
                local path_key = UTILS.normalizeSlashes(font_map.path)
                local icon_font = nil
                for _, f in ipairs(ICON_FONTS) do
                    if UTILS.normalizeSlashes(f.path) == path_key then
                        icon_font = f.font
                        break
                    end
                end

                reaper.ImGui_PushID(ctx, entry.index)

                if icon_font then
                    reaper.ImGui_PushFont(ctx, icon_font, CONFIG.ICON_FONT.SIZE)
                    local char_width = reaper.ImGui_CalcTextSize(ctx, ICON_CHAR)
                    local text_x = (cell_size - char_width) / 2
                    local text_y = (cell_size - reaper.ImGui_GetTextLineHeight(ctx)) / 2
                    if reaper.ImGui_Button(ctx, "##pick", cell_size, cell_size) then
                        self.current_button.icon_char = ICON_CHAR
                        self.current_button.icon_path = nil
                        self.current_button.icon_font = font_map.path
                        self.current_button.cached_width = nil
                        self.current_button:saveChanges()
                        self.close_requested = true
                        if C.PopupContext then
                            C.PopupContext.close(self)
                        else
                            self.is_open = false
                        end
                    end
                    local tip = font_map.display_name or ""
                    if needle ~= "" and font_map.category then
                        tip = categoryLabel(font_map.category) .. "\n" .. tip
                    end
                    if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_None()) then
                        reaper.ImGui_SetTooltip(ctx, tip)
                    end
                    reaper.ImGui_SetCursorPos(ctx, x + text_x, y + text_y)
                    reaper.ImGui_Text(ctx, ICON_CHAR)
                    reaper.ImGui_PopFont(ctx)
                else
                    reaper.ImGui_Button(ctx, "?", cell_size, cell_size)
                    if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_None()) then
                        reaper.ImGui_SetTooltip(ctx, (font_map.display_name or "") .. " (not loaded)")
                    end
                end

                reaper.ImGui_PopID(ctx)

                if self.close_requested then
                    break
                end
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
end

return IconSelector.new()
