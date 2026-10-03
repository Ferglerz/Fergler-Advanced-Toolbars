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

local function gridCache(selector, key)
    selector._grid_cache = selector._grid_cache or {}
    selector._grid_cache[key] = selector._grid_cache[key] or {}
    return selector._grid_cache[key]
end

-- PNG width/height are in the IHDR. Reading 24 bytes avoids creating every
-- texture just to lay out a grid of differently sized images.
local function pngSize(path)
    if not path then return nil, nil end
    local file = io.open(path, "rb")
    if not file then return nil, nil end
    local head = file:read(24)
    file:close()
    if not head or #head < 24 or head:sub(1, 8) ~= "\137PNG\r\n\26\n" or head:sub(13, 16) ~= "IHDR" then
        return nil, nil
    end
    local function uint32(at)
        local a, b, c, d = head:byte(at, at + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    local w, h = uint32(17), uint32(21)
    if w <= 0 or h <= 0 then return nil, nil end
    return w, h
end

local function pathItems(cache, filtered, opts)
    cache.paths = cache.paths or {}
    cache.sizes = cache.sizes or {}
    local items = {}
    for _, row in ipairs(filtered) do
        local key = row.entry.path or ""
        local path = cache.paths[key]
        if path == nil then
            path = opts.resolve_absolute(key) or false
            cache.paths[key] = path
        end
        if path == false then path = nil end
        local size = path and cache.sizes[path]
        if not size then
            local w, h = pngSize(path)
            size = {w = w and math.max(1, math.floor(w / opts.frame_count)) or opts.fallback_size,
                h = h or opts.fallback_size}
            if path then cache.sizes[path] = size end
        end
        items[#items + 1] = {index = row.index, entry = row.entry, path = path, w = size.w, h = size.h}
    end
    return items
end

-- Exposed for the focused layout regression test.
function IconSelectorGrids.layoutPathRows(items, width)
    local pad = 6
    local rows = {}
    local row = {y = pad, h = 0, items = {}}
    local x = pad
    local max_x = math.max(120, width - pad)
    for _, item in ipairs(items) do
        if x > pad and x + item.w + pad > max_x then
            rows[#rows + 1] = row
            row = {y = row.y + row.h + pad, h = 0, items = {}}
            x = pad
        end
        row.items[#row.items + 1] = {item = item, x = x}
        row.h = math.max(row.h, item.h)
        x = x + item.w + pad
    end
    if #row.items > 0 then rows[#rows + 1] = row end
    local last = rows[#rows]
    return rows, last and (last.y + last.h + pad) or 0
end

local function renderPathIconFlow(ctx, opts)
    local origin_y = reaper.ImGui_GetCursorPosY(ctx)
    local width = select(1, reaper.ImGui_GetContentRegionAvail(ctx)) or 0
    local cache = opts.cache
    if cache.layout_items ~= opts.items or cache.layout_width ~= width then
        cache.rows, cache.total_h = IconSelectorGrids.layoutPathRows(opts.items, width)
        cache.layout_items, cache.layout_width = opts.items, width
    end
    local scroll_y = reaper.ImGui_GetScrollY(ctx)
    local visible_bottom = scroll_y + reaper.ImGui_GetWindowHeight(ctx)
    local u0, v0, u1, v1
    if opts.frame_uv then
        u0, v0, u1, v1 = opts.frame_uv()
    end

    -- Rows are ordered by y; skip directly to the first row touching the viewport.
    local lo, hi = 1, #cache.rows
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local row = cache.rows[mid]
        if origin_y + row.y + row.h < scroll_y then lo = mid + 1 else hi = mid - 1 end
    end
    for row_index = lo, #cache.rows do
        local row = cache.rows[row_index]
        local y = origin_y + row.y
        if y > visible_bottom then break end
        for _, placed in ipairs(row.items) do
            local item = placed.item
            local entry = item.entry
            local texture = item.path and C.IconManager:loadTexture(item.path) or nil
            local can_draw = texture ~= nil
            reaper.ImGui_SetCursorPos(ctx, placed.x, y)
            reaper.ImGui_PushID(ctx, item.index)
            if can_draw then
                if u0 then
                    reaper.ImGui_Image(ctx, texture, item.w, item.h, u0, v0, u1, v1)
                else
                    reaper.ImGui_Image(ctx, texture, item.w, item.h)
                end
                reaper.ImGui_SetCursorPos(ctx, placed.x, y)
                if reaper.ImGui_InvisibleButton(ctx, opts.pick_id, item.w, item.h) then
                    opts.on_pick(entry)
                end
                if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_None()) then
                    reaper.ImGui_SetTooltip(ctx, entry.display_name or entry.path or "")
                end
            else
                reaper.ImGui_Button(ctx, "?", item.w, item.h)
                if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_None()) then
                    reaper.ImGui_SetTooltip(ctx, (entry.display_name or entry.path or "") .. " (not found)")
                end
            end
            reaper.ImGui_PopID(ctx)
        end
    end
    reaper.ImGui_SetCursorPos(ctx, 0, origin_y + cache.total_h)
    reaper.ImGui_Dummy(ctx, 1, 1)
end

local function renderPathIconGrid(ctx, opts)
    reaper.ImGui_SetNextItemWidth(ctx, opts.content_w())
    local filter_changed, filter_value =
        reaper.ImGui_InputTextWithHint(ctx, opts.search_id, opts.search_hint, opts.filter or "")
    if filter_changed then
        opts.filter = filter_value or ""
        opts.set_filter(opts.filter)
    end

    local needle = (opts.filter or ""):lower()
    local cache = gridCache(opts.selector, opts.child_id)
    if cache.entries ~= opts.entries then
        cache.paths, cache.sizes = nil, nil
    end
    if cache.entries ~= opts.entries or cache.needle ~= needle then
        cache.filtered = filterPathIcons(opts.entries, needle)
        cache.items = pathItems(cache, cache.filtered, opts)
        cache.entries, cache.needle = opts.entries, needle
    end
    local filtered = cache.filtered

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
        cache = cache,
        items = cache.items,
        frame_uv = opts.frame_uv,
        pick_id = opts.pick_id,
        on_pick = opts.on_pick,
    })
    reaper.ImGui_EndChild(ctx)
end

local function renderFontIconGrid(ctx, opts)
    local needle = (opts.selector.icon_filter or ""):lower()
    local cache = gridCache(opts.selector, "fonts")
    if cache.maps ~= opts.selector.font_maps then
        cache.cats = IconSelectorGrids.sortedCategories(opts.selector.font_maps)
        cache.maps = opts.selector.font_maps
    end
    local cats = cache.cats
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
    if cache.needle ~= needle or cache.category ~= active_category or cache.filtered_maps ~= opts.selector.font_maps then
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
                filtered[#filtered + 1] = {index = i, font_map = font_map}
            end
        end
        cache.filtered, cache.needle, cache.category, cache.filtered_maps = filtered, needle, active_category, opts.selector.font_maps
    end
    local filtered = cache.filtered

    local cell_size, pad = 44, 6
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
    local grid_w = select(1, reaper.ImGui_GetContentRegionAvail(ctx)) or 0
    local cols = math.max(1, math.floor((grid_w - pad) / (cell_size + pad)))

    if needle ~= "" and #filtered > 0 then
        reaper.ImGui_TextDisabled(ctx, "All categories — " .. #filtered .. " match(es)")
        reaper.ImGui_Spacing(ctx)
    end

    local grid_origin_y = reaper.ImGui_GetCursorPosY(ctx) + pad
    local row_step = cell_size + pad
    local row_count = math.ceil(#filtered / cols)
    reaper.ImGui_SetCursorPos(ctx, 0, grid_origin_y)
    if not cache.clipper or cache.clipper_ctx ~= ctx or
        not reaper.ImGui_ValidatePtr(cache.clipper, "ImGui_ListClipper*") then
        cache.clipper = reaper.ImGui_CreateListClipper(ctx)
        cache.clipper_ctx = ctx
    end
    reaper.ImGui_ListClipper_Begin(cache.clipper, row_count, row_step)
    while reaper.ImGui_ListClipper_Step(cache.clipper) do
        local first_row, last_row = reaper.ImGui_ListClipper_GetDisplayRange(cache.clipper)
        for row = first_row, last_row - 1 do
            for col = 0, cols - 1 do
                local item_index = row * cols + col + 1
                if item_index > #filtered then break end
                local entry = filtered[item_index]
                local x = pad + col * row_step
                local y = grid_origin_y + row * row_step
                reaper.ImGui_SetCursorPos(ctx, x, y)

                local font_map = entry.font_map
                local path_key = UTILS.normalizeSlashes(font_map.path)
                local icon_font = nil
                local font_index = ICON_FONTS_LIB.path_index and ICON_FONTS_LIB.path_index[path_key]
                if font_index and _G.ICON_FONTS and _G.ICON_FONTS[font_index] then
                    icon_font = resolveIconFontEntryFont(_G.ICON_FONTS[font_index])
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
            end
        end
    end

    reaper.ImGui_SetCursorPos(ctx, 0, grid_origin_y + row_count * row_step)
    reaper.ImGui_Dummy(ctx, 1, 1)
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
        selector = selector,
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
        frame_count = REAPER_ICONS.FRAME_COUNT,
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
        end,
    })
end

function IconSelectorGrids.renderTrackIconGrid(ctx, opts)
    local selector = opts.selector
    local button = opts.button
    renderPathIconGrid(ctx, {
        selector = selector,
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
        frame_count = 1,
        fallback_size = 32,
        pick_id = "##track_pick",
        close_requested = selector.close_requested,
        on_pick = function(entry)
            opts.applyDisplayText(selector)
            opts.clearButtonIcons(button)
            button.reaper_track_icon_path = entry.path
            button.cached_width = nil
            opts.refreshButtonIconLayout(button)
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
