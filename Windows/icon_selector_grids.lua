-- Windows/icon_selector_grids.lua
local ICON_FONTS_LIB = require("Utils.Core.icon_fonts")
local REAPER_ICONS = require("Utils.Core.reaper_toolbar_icons")
local REAPER_TRACK_ICONS = require("Utils.Core.reaper_track_icons")
local DRAWING = require("Utils.Draw.drawing")

local ICON_CHAR = string.char(ICON_FONTS_LIB.ICON_CODEPOINT)

local IconSelectorGrids = {}

function IconSelectorGrids.sortedCategories(font_maps)
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

local function filterPathIcons(entries, needle)
    local filtered = {}
    for i, entry in ipairs(entries or {}) do
        local show = true
        if needle ~= "" then
            local dn = (entry.display_name or ""):lower()
            local nm = (entry.name or ""):lower()
            local path = (entry.path or ""):lower()
            show = dn:find(needle, 1, true) or nm:find(needle, 1, true) or path:find(needle, 1, true)
        end
        if show then
            table.insert(filtered, {index = i, entry = entry})
        end
    end
    return filtered
end

local function renderPathIconFlow(ctx, opts)
    local pad = 6
    local grid_origin_y = reaper.ImGui_GetCursorPosY(ctx)
    local row_x = pad
    local row_y = grid_origin_y + pad
    local row_h = 0
    local max_x = math.max(120, (select(1, reaper.ImGui_GetContentRegionAvail(ctx)) or 0) - pad)
    local u0, v0, u1, v1
    if opts.frame_uv then
        u0, v0, u1, v1 = opts.frame_uv()
    end

    for _, row in ipairs(opts.filtered) do
        local entry = row.entry
        local abs_path = opts.resolve_absolute(entry.path)
        local texture = abs_path and C.IconManager:loadTexture(abs_path) or nil
        local native_w, native_h = opts.native_size(texture)
        local can_draw = texture and native_w and native_h
        local layout_w = native_w or opts.fallback_size
        local layout_h = native_h or opts.fallback_size

        if row_x > pad and row_x + layout_w + pad > max_x then
            row_x = pad
            row_y = row_y + row_h + pad
            row_h = 0
        end
        reaper.ImGui_SetCursorPos(ctx, row_x, row_y)

        reaper.ImGui_PushID(ctx, row.index)

        if can_draw then
            if u0 then
                reaper.ImGui_Image(ctx, texture, native_w, native_h, u0, v0, u1, v1)
            else
                reaper.ImGui_Image(ctx, texture, native_w, native_h)
            end
            reaper.ImGui_SetCursorPos(ctx, row_x, row_y)
            if reaper.ImGui_InvisibleButton(ctx, opts.pick_id, native_w, native_h) then
                opts.on_pick(entry)
            end
            if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_None()) then
                reaper.ImGui_SetTooltip(ctx, entry.display_name or entry.path or "")
            end
            row_x = row_x + native_w + pad
            row_h = math.max(row_h, native_h)
        else
            reaper.ImGui_Button(ctx, "?", layout_w, layout_h)
            if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_None()) then
                reaper.ImGui_SetTooltip(ctx, (entry.display_name or entry.path or "") .. " (not found)")
            end
            row_x = row_x + layout_w + pad
            row_h = math.max(row_h, layout_h)
        end

        reaper.ImGui_PopID(ctx)

        if opts.close_requested then
            break
        end
    end
end

local function renderPathIconGrid(ctx, opts)
    reaper.ImGui_SetNextItemWidth(ctx, opts.content_w())
    local filter_changed, filter_value =
        reaper.ImGui_InputTextWithHint(ctx, opts.search_id, opts.search_hint, opts.filter or "")
    if filter_changed then
        opts.set_filter(filter_value or "")
    end

    local needle = (opts.filter or ""):lower()
    local filtered = filterPathIcons(opts.entries, needle)

    if #opts.entries == 0 then
        reaper.ImGui_TextWrapped(ctx, opts.empty_message)
        return
    end

    if needle ~= "" then
        reaper.ImGui_TextDisabled(ctx, #filtered .. " match(es)")
        reaper.ImGui_Spacing(ctx)
    end

    reaper.ImGui_BeginChild(ctx, opts.child_id, 0, opts.grid_view_h - 36, opts.child_flags)
    renderPathIconFlow(ctx, {
        filtered = filtered,
        resolve_absolute = opts.resolve_absolute,
        native_size = opts.native_size,
        frame_uv = opts.frame_uv,
        fallback_size = opts.fallback_size,
        pick_id = opts.pick_id,
        on_pick = opts.on_pick,
        close_requested = opts.close_requested,
    })
    reaper.ImGui_EndChild(ctx)
end

local function renderFontIconGrid(ctx, opts)
    local needle = (opts.selector.icon_filter or ""):lower()
    local cats = IconSelectorGrids.sortedCategories(opts.selector.font_maps)
    if opts.selector.icon_category_index > #cats then
        opts.selector.icon_category_index = math.max(1, #cats)
    end

    if #opts.selector.font_maps == 0 then
        reaper.ImGui_TextWrapped(
            ctx,
            "No icon fonts found. Add .ttf files under IconFonts/ (see IconFonts/icons/ after running tools/icon_fonts/split_all_sources.py)."
        )
        return
    end

    reaper.ImGui_SetNextItemWidth(ctx, opts.content_w())
    local changed, new_filter =
        reaper.ImGui_InputTextWithHint(
            ctx,
            "##iconsearch",
            "Type to search all folders; leave empty to browse by category…",
            opts.selector.icon_filter or ""
        )
    if changed then
        opts.selector.icon_filter = new_filter or ""
    end

    needle = (opts.selector.icon_filter or ""):lower()
    local active_category = cats[opts.selector.icon_category_index]

    local filtered = {}
    for i, font_map in ipairs(opts.selector.font_maps) do
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

    local cell_size, cols, pad = 44, 6, 6
    local cat_list_w = 168
    local grid_inner_h = opts.grid_view_h - 36

    if needle == "" and #cats > 0 then
        reaper.ImGui_BeginChild(ctx, "IconCategories", cat_list_w, grid_inner_h, opts.child_flags)
        reaper.ImGui_TextDisabled(ctx, "Categories")
        for i, cat in ipairs(cats) do
            local is_sel = (i == opts.selector.icon_category_index)
            if reaper.ImGui_Selectable(ctx, categoryLabel(cat), is_sel) then
                opts.selector.icon_category_index = i
            end
        end
        reaper.ImGui_EndChild(ctx)
        reaper.ImGui_SameLine(ctx, 0, 10)
    end

    reaper.ImGui_BeginChild(ctx, "IconGrid", 0, grid_inner_h, opts.child_flags)

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
        local idx = ICON_FONTS_LIB.path_index and ICON_FONTS_LIB.path_index[path_key]
        if idx and _G.ICON_FONTS and _G.ICON_FONTS[idx] then
            icon_font = resolveIconFontEntryFont(_G.ICON_FONTS[idx])
        end

        reaper.ImGui_PushID(ctx, entry.index)

        if icon_font and ensureIconFontAttachedToContext(ctx, icon_font) then
            reaper.ImGui_PushFont(ctx, icon_font, CONFIG.ICON_FONT.SIZE)
            local line_h = reaper.ImGui_GetTextLineHeight(ctx)
            local char_width = select(1, reaper.ImGui_CalcTextSize(ctx, ICON_CHAR)) or line_h
            local text_x = (cell_size - char_width) / 2
            local text_y = DRAWING.centeredIconRelY(0, cell_size, CONFIG.ICON_FONT.SIZE, 0)
            if reaper.ImGui_Button(ctx, "##pick", cell_size, cell_size) then
                opts.on_font_pick(font_map)
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

        if opts.close_requested then
            break
        end
    end

    reaper.ImGui_EndChild(ctx)
end

function IconSelectorGrids.renderIconGrid(ctx, opts)
    if opts.mode == "reaper" then
        IconSelectorGrids.renderReaperIconGrid(ctx, opts)
    elseif opts.mode == "track" then
        IconSelectorGrids.renderTrackIconGrid(ctx, opts)
    elseif opts.mode == "fonts" then
        IconSelectorGrids.renderFontIconGrid(ctx, opts)
    end
end

function IconSelectorGrids.renderReaperIconGrid(ctx, opts)
    local selector = opts.selector
    local button = opts.button
    renderPathIconGrid(ctx, {
        content_w = opts.content_w,
        search_id = "##reapericonsearch",
        search_hint = "Search REAPER toolbar icons…",
        filter = selector.reaper_icon_filter,
        set_filter = function(value)
            selector.reaper_icon_filter = value
        end,
        entries = selector.reaper_icons,
        empty_message =
            "No REAPER toolbar icons found. Expected PNG files under your REAPER resource path in Data/toolbar_icons.",
        child_id = "ReaperIconGrid",
        grid_view_h = opts.grid_view_h,
        child_flags = opts.child_flags,
        resolve_absolute = REAPER_ICONS.resolveAbsolutePath,
        native_size = REAPER_ICONS.nativeFrameSizeFromTexture,
        frame_uv = REAPER_ICONS.frameUv,
        fallback_size = 30,
        pick_id = "##reaper_pick",
        close_requested = selector.close_requested,
        on_pick = function(entry)
            opts.applyDisplayText(selector)
            opts.clearButtonIcons(button)
            button.reaper_icon_path = entry.path
            button.cached_width = nil
            opts.refreshButtonIconLayout(button)
            button:saveChanges()
        end,
    })
end

function IconSelectorGrids.renderTrackIconGrid(ctx, opts)
    local selector = opts.selector
    local button = opts.button
    renderPathIconGrid(ctx, {
        content_w = opts.content_w,
        search_id = "##trackiconsearch",
        search_hint = "Search REAPER track icons…",
        filter = selector.track_icon_filter,
        set_filter = function(value)
            selector.track_icon_filter = value
        end,
        entries = selector.track_icons,
        empty_message =
            "No REAPER track icons found. Expected PNG files under your REAPER resource path in Data/track_icons.",
        child_id = "TrackIconGrid",
        grid_view_h = opts.grid_view_h,
        child_flags = opts.child_flags,
        resolve_absolute = REAPER_TRACK_ICONS.resolveAbsolutePath,
        native_size = REAPER_TRACK_ICONS.nativeSizeFromTexture,
        fallback_size = 32,
        pick_id = "##track_pick",
        close_requested = selector.close_requested,
        on_pick = function(entry)
            opts.applyDisplayText(selector)
            opts.clearButtonIcons(button)
            button.reaper_track_icon_path = entry.path
            button.cached_width = nil
            opts.refreshButtonIconLayout(button)
            button:saveChanges()
        end,
    })
end

function IconSelectorGrids.renderFontIconGrid(ctx, opts)
    renderFontIconGrid(ctx, {
        selector = opts.selector,
        content_w = opts.content_w,
        grid_view_h = opts.grid_view_h,
        child_flags = opts.child_flags,
        close_requested = opts.selector.close_requested,
        on_font_pick = function(font_map)
            local selector = opts.selector
            local button = opts.button
            opts.applyDisplayText(selector)
            opts.clearButtonIcons(button)
            button.icon_char = ICON_CHAR
            button.icon_font = font_map.path
            button.cached_width = nil
            opts.refreshButtonIconLayout(button)
            button:saveChanges()
        end,
    })
end

function IconSelectorGrids.renderIconPickerTabs(ctx, selector, grid_opts)
    if not reaper.ImGui_BeginTabBar(ctx, "##icon_picker_tabs", 0) then
        return
    end

    local first = selector.icon_picker_tab or "reaper"
    local tab_fns = {
        reaper = function()
            if reaper.ImGui_BeginTabItem(ctx, "Toolbar Icons##icon_tab_reaper") then
                selector.icon_picker_tab = "reaper"
                IconSelectorGrids.renderReaperIconGrid(ctx, grid_opts)
                reaper.ImGui_EndTabItem(ctx)
            end
        end,
        track = function()
            if reaper.ImGui_BeginTabItem(ctx, "Track Icons##icon_tab_track") then
                selector.icon_picker_tab = "track"
                IconSelectorGrids.renderTrackIconGrid(ctx, grid_opts)
                reaper.ImGui_EndTabItem(ctx)
            end
        end,
        fonts = function()
            if reaper.ImGui_BeginTabItem(ctx, "Icon Fonts##icon_tab_fonts") then
                selector.icon_picker_tab = "fonts"
                IconSelectorGrids.renderFontIconGrid(ctx, grid_opts)
                reaper.ImGui_EndTabItem(ctx)
            end
        end,
    }
    local order = {"reaper", "track", "fonts"}
    tab_fns[first]()
    for _, id in ipairs(order) do
        if id ~= first then
            tab_fns[id]()
        end
    end
    reaper.ImGui_EndTabBar(ctx)
end

return IconSelectorGrids
