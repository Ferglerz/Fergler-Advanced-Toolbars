-- widgets/colour_swatch.lua
-- Track/item colour swatches with stock + user palettes; state in CONFIG.WIDGET_SAVED_STATES.

local MIN_CELL = 15
local MAX_CELL = MIN_CELL * 2.5
local GAP = 2
local PAD_X = 4
local PAD_Y_HORIZONTAL = 4
local PAD_Y_VERTICAL_TOP = 6
local PAD_Y_VERTICAL_BOTTOM = 12
local STOCK_CATEGORIES = {
    {
        id = "stock_primary",
        name = "Primary",
        colors = {
            "#E6194BFF", "#3CB44BFF", "#FFE119FF", "#4363D8FF", "#F58231FF",
            "#911EB4FF", "#46F0F0FF", "#F032E6FF", "#BCF60CFF", "#FABEBEFF"
        }
    },
    {
        id = "stock_pastel",
        name = "Pastel",
        colors = {
            "#FFB3BAFF", "#FFDFBAFF", "#FFFFBAFF", "#BAFFC9FF", "#BAE1FFFF",
            "#E8BAFFFF", "#D4A574FF", "#C7CEEAFF", "#B5EAD7FF", "#FFDAC1FF"
        }
    },
    {
        id = "stock_muted",
        name = "Muted",
        colors = {
            "#5C4B51FF", "#8CBEB2FF", "#F2EBBFFF", "#F3B562FF", "#F06060FF",
            "#4A6FA5FF", "#6B4226FF", "#789262FF", "#C06C84FF", "#6C5B7BFF"
        }
    }
}

local function state_key(self)
    return tostring(self._button_instance_id or self.name or "default")
end

local function ensure_saved_table()
    if not CONFIG.WIDGET_SAVED_STATES then
        CONFIG.WIDGET_SAVED_STATES = {}
    end
    if type(CONFIG.WIDGET_SAVED_STATES.colour_swatch) ~= "table" then
        CONFIG.WIDGET_SAVED_STATES.colour_swatch = {}
    end
    return CONFIG.WIDGET_SAVED_STATES.colour_swatch
end

local function load_state(self)
    local key = state_key(self)
    local store = ensure_saved_table()
    local st = store[key]
    if type(st) ~= "table" then
        st = {
            active_category_id = nil,
            user_categories = {},
            swatch_scale = 1.0
        }
        store[key] = st
    end
    if st.swatch_scale == nil then
        st.swatch_scale = 1.0
    end
    if type(st.user_categories) ~= "table" then
        st.user_categories = {}
    end
    if st.swatch_scale == nil then
        st.swatch_scale = 1.0
    end
    self._state = st
    return st
end

local function stock_categories(self)
    local out = {}
    for _, c in ipairs(STOCK_CATEGORIES) do
        if type(c) == "table" and c.id and type(c.colors) == "table" then
            local colors = {}
            for _, hex in ipairs(c.colors) do
                table.insert(colors, hex)
            end
            table.insert(
                out,
                {
                    id = c.id,
                    name = c.name or c.id,
                    colors = colors
                }
            )
        end
    end
    return out
end

local function deep_copy_colors(t)
    local out = {}
    if type(t) == "table" then
        for _, c in ipairs(t) do
            table.insert(out, c)
        end
    end
    return out
end

local function all_categories(self)
    local out = {}
    for _, c in ipairs(stock_categories(self)) do
        if type(c) == "table" and c.id and type(c.colors) == "table" then
            table.insert(out, { id = c.id, name = c.name or c.id, colors = c.colors, stock = true })
        end
    end
    for _, c in ipairs(self._state.user_categories) do
        if type(c) == "table" and c.id and type(c.colors) == "table" then
            table.insert(out, { id = c.id, name = c.name or c.id, colors = c.colors, stock = false })
        end
    end
    return out
end

local function find_category(self, id)
    if not id then
        return nil
    end
    for _, c in ipairs(all_categories(self)) do
        if c.id == id then
            return c
        end
    end
    return nil
end

local function active_palette(self)
    local st = self._state
    local cat = find_category(self, st.active_category_id)
    if cat then
        return cat.colors
    end
    local stock = stock_categories(self)
    if stock[1] and type(stock[1].colors) == "table" then
        st.active_category_id = stock[1].id
        return stock[1].colors
    end
    return {}
end

local function save_config()
    if CONFIG_MANAGER and CONFIG_MANAGER.saveMainConfig then
        CONFIG_MANAGER:saveMainConfig()
    end
end

-- Scale 0.5–1.5 multiplies stock MIN/MAX cell bounds for this button instance.
local function swatch_bounds(self)
    load_state(self)
    local scale = tonumber(self._state.swatch_scale) or 1.0
    scale = math.max(0.5, math.min(1.5, scale))
    local min_c = math.max(10, MIN_CELL * scale)
    local max_c = math.max(min_c + 1, MAX_CELL * scale)
    return min_c, max_c
end

local function hex_to_reaper_native(hex)
    local rgba = COLOR_UTILS.toRGBA(hex)
    local r, g, b = rgba.r, rgba.g, rgba.b
    if reaper.ColorToNative then
        return reaper.ColorToNative(r, g, b) | 0x1000000
    end
    return ((b & 0xFF) << 16) | ((g & 0xFF) << 8) | (r & 0xFF) | 0x1000000
end

local function apply_color_to_targets(self, hex)
    local native = hex_to_reaper_native(hex)
    local cursor_ctx = reaper.GetCursorContext and reaper.GetCursorContext() or 0
    local target_items = (cursor_ctx == 1)
    if target_items then
        local n = reaper.CountSelectedMediaItems(0)
        for i = 0, n - 1 do
            local it = reaper.GetSelectedMediaItem(0, i)
            if it and reaper.SetMediaItemInfo_Value then
                reaper.SetMediaItemInfo_Value(it, "I_CUSTOMCOLOR", native)
            end
        end
    else
        local n = reaper.CountSelectedTracks(0)
        for i = 0, n - 1 do
            local tr = reaper.GetSelectedTrack(0, i)
            if tr then
                reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", native)
            end
        end
    end
    reaper.TrackList_AdjustWindows(false)
end

-- Pick a column count that prefers larger swatches (up to max_c)
-- while still respecting the minimum cell size.
local function columns_for_width_vertical(inner_w, n, min_c, max_c)
    n = math.max(1, n or 1)
    if inner_w < min_c then
        return 1
    end

    local max_cols_by_min = math.max(1, math.floor((inner_w + GAP) / (min_c + GAP)))
    local min_cols_for_max = math.max(1, math.ceil((inner_w + GAP) / (max_c + GAP)))
    local preferred_cols = math.max(1, math.min(max_cols_by_min, min_cols_for_max))

    return math.max(1, math.min(n, preferred_cols))
end

local function cell_size(inner_w, cols, min_c, max_c)
    if cols <= 0 then
        return min_c
    end
    if inner_w <= 0 then
        return 1
    end
    local size = (inner_w - (cols - 1) * GAP) / cols
    local min_cell = inner_w < min_c and math.max(1, inner_w) or min_c
    return math.max(min_cell, math.min(max_c, size))
end

local function horizontal_inner_height_budget(base_h, min_c)
    local h = (base_h or CONFIG.SIZES.HEIGHT or 0) - (PAD_Y_HORIZONTAL * 2)
    return math.max(min_c, h)
end

-- Horizontal toolbars: keep height bounded and widen widget as needed.
-- Try two rows only when they fit min_c; otherwise fall back to one row.
local function plan_horizontal_grid(n, inner_h_budget, min_c, max_c)
    if n <= 0 then
        return 1, 1, min_c
    end

    local two_row_cell = (inner_h_budget - GAP) / 2
    local rows = (n >= 2 and two_row_cell >= min_c) and 2 or 1

    local cell
    if rows == 1 then
        cell = math.max(min_c, math.min(max_c, inner_h_budget))
    else
        cell = math.max(min_c, math.min(max_c, two_row_cell))
    end

    local cols = math.ceil(n / rows)
    return rows, cols, cell
end

-- Row item counts: first (n % rows) rows get ceil(n/rows), rest get floor — e.g. 15 in 2 rows → 8,7
local function balanced_row_counts(n, rows)
    if rows <= 0 or n <= 0 then
        return {}
    end
    local q = math.floor(n / rows)
    local r = n - q * rows
    local counts = {}
    for i = 1, rows do
        counts[i] = q + (i <= r and 1 or 0)
    end
    return counts
end

-- Returns list of { x, y, w, h } in inner coordinates (origin top-left of padded area), and total height used
local function layout_rects_vertical(inner_w, n, min_c, max_c)
    if n <= 0 then
        return {}, 0
    end
    local cols = columns_for_width_vertical(inner_w, n, min_c, max_c)
    local rows = math.ceil(n / cols)
    local cw = cell_size(inner_w, cols, min_c, max_c)
    local ch = cw
    local row_counts
    if rows >= 2 then
        row_counts = balanced_row_counts(n, rows)
    else
        row_counts = { n }
    end

    local rects = {}
    local idx = 1
    local y = 0
    for row = 1, rows do
        local cnt = row_counts[row] or 0
        local row_w = cnt * cw + (cnt - 1) * GAP
        local x0 = (inner_w - row_w) / 2
        for c = 1, cnt do
            if idx <= n then
                rects[idx] = {
                    x = x0 + (c - 1) * (cw + GAP),
                    y = y,
                    w = cw,
                    h = ch
                }
                idx = idx + 1
            end
        end
        y = y + ch + (row < rows and GAP or 0)
    end
    return rects, y
end

local function layout_rects_horizontal(inner_w, n, inner_h_budget, min_c, max_c)
    if n <= 0 then
        return {}, 0
    end

    local rows, _, cell = plan_horizontal_grid(n, inner_h_budget, min_c, max_c)
    local ch = cell
    local row_counts = rows >= 2 and balanced_row_counts(n, rows) or { n }

    local rects = {}
    local idx = 1
    local y = 0
    for row = 1, rows do
        local cnt = row_counts[row] or 0
        local row_w = cnt * cell + (cnt - 1) * GAP
        local x0 = (inner_w - row_w) / 2
        for c = 1, cnt do
            if idx <= n then
                rects[idx] = {
                    x = x0 + (c - 1) * (cell + GAP),
                    y = y,
                    w = cell,
                    h = ch
                }
                idx = idx + 1
            end
        end
        y = y + ch + (row < rows and GAP or 0)
    end

    return rects, y
end

local function layout_rects_preview_single_row(inner_w, n, inner_h_budget, min_c, max_c)
    if n <= 0 then
        return {}, 0
    end

    local cell = math.max(1, math.min(max_c, math.max(min_c, inner_h_budget)))
    local max_visible = math.max(1, math.floor((inner_w + GAP) / (cell + GAP)))
    local visible = math.max(1, math.min(n, max_visible))
    local row_w = visible * cell + (visible - 1) * GAP
    local x0 = (inner_w - row_w) / 2

    local rects = {}
    for i = 1, visible do
        rects[i] = {
            x = x0 + (i - 1) * (cell + GAP),
            y = 0,
            w = cell,
            h = cell
        }
    end
    return rects, cell
end

local function layout_rects(inner_w, n, is_vertical_toolbar, inner_h_budget, min_c, max_c)
    if is_vertical_toolbar then
        return layout_rects_vertical(inner_w, n, min_c, max_c)
    end
    return layout_rects_horizontal(inner_w, n, inner_h_budget, min_c, max_c)
end

local function is_constrained_mode(self)
    return self and self._preview_mode == true
end

local function next_user_cat_id(self)
    self._cat_seq = (self._cat_seq or 0) + 1
    return string.format("user_%s_%d", state_key(self):gsub("[^%w]", "_"), self._cat_seq)
end

local widget = {
    name = "Colour Swatch",
    category = "Project & surfaces",
    type = "colour_swatch",
    width = 200,
    update_interval = 0.5,
    description = "Click a swatch to set track or item colour. Right-click for palettes and add colour.",
    _state = nil,
    _picker_color_imgui = 0xFFFFFFFF,
    _open_context = false,
    _open_picker = false,
    _pending_add_category_id = nil,
    _cat_seq = 0,
    _hit_rects = nil
}

function widget.getValue(self)
    load_state(self)
    return 0
end

function widget.getLayoutWidth(self, _ctx, layout_is_vertical_toolbar)
    load_state(self)
    local colors = active_palette(self)
    local n = #colors
    local base = self.width or 200
    local min_w = CONFIG.SIZES.MIN_WIDTH or 30
    if is_constrained_mode(self) then
        local cap = tonumber(self._preview_width_cap) or base
        return math.max(1, cap)
    end
    local ctx = _ctx
    local is_vertical_toolbar
    if layout_is_vertical_toolbar ~= nil then
        is_vertical_toolbar = layout_is_vertical_toolbar == true
    else
        is_vertical_toolbar = false
        if ctx and reaper.ImGui_GetWindowWidth and reaper.ImGui_GetWindowHeight then
            local ww = reaper.ImGui_GetWindowWidth(ctx) or 0
            local wh = reaper.ImGui_GetWindowHeight(ctx) or 0
            is_vertical_toolbar = ww > 0 and wh > 0 and ww < wh
        end
    end

    if is_vertical_toolbar and ctx and reaper.ImGui_GetWindowWidth then
        local win_w = reaper.ImGui_GetWindowWidth(ctx) or base
        local side_pad = (CONFIG.SIZES.PADDING or 0) * 2
        local capped = math.max(min_w, win_w - side_pad - 4)
        return math.min(base, capped)
    end

    if n <= 0 then
        return math.max(min_w, base)
    end

    local min_c, max_c = swatch_bounds(self)
    local inner_h_budget = horizontal_inner_height_budget(CONFIG.SIZES.HEIGHT, min_c)
    local rows, cols, cell = plan_horizontal_grid(n, inner_h_budget, min_c, max_c)

    local needed_inner_w = cols * cell + (cols - 1) * GAP
    local needed_total_w = needed_inner_w + 2 * PAD_X
    return math.max(min_w, math.max(base, needed_total_w))
end

function widget.getLayoutHeight(self, _ctx, inner_width, _is_vertical_toolbar)
    load_state(self)
    local colors = active_palette(self)
    local n = #colors
    local w = inner_width or self.width or 200
    local is_vertical_toolbar = _is_vertical_toolbar == true
    local pad_top = is_vertical_toolbar and PAD_Y_VERTICAL_TOP or PAD_Y_HORIZONTAL
    local pad_bottom = is_vertical_toolbar and PAD_Y_VERTICAL_BOTTOM or PAD_Y_HORIZONTAL
    local inner_w = math.max(1, w - 2 * PAD_X)
    local base_h = CONFIG.SIZES.HEIGHT
    if n == 0 then
        return base_h
    end
    local min_c, max_c = swatch_bounds(self)
    local inner_h_budget = horizontal_inner_height_budget(base_h, min_c)
    if is_constrained_mode(self) then
        return base_h
    end
    local _, total_h = layout_rects(inner_w, n, is_vertical_toolbar, inner_h_budget, min_c, max_c)
    if is_vertical_toolbar then
        return math.max(base_h, pad_top + pad_bottom + (total_h or 0))
    end
    return base_h
end

function widget.hitTestSubcontrols(self, _ctx, coords, rel_x, rel_y, _render_width, _layout)
    if not self._hit_rects then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    for i, r in ipairs(self._hit_rects) do
        if coords:pointInRelativeRect(mx, my, rel_x + r.x, rel_y + r.y, r.w, r.h) then
            return i
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_idx)
    local colors = active_palette(self)
    local hex = colors[sub_idx]
    if hex then
        apply_color_to_targets(self, hex)
    end
end

function widget.onRightClick(self)
    self._open_context = true
end

local function draw_menus(self, ctx)
    local key = state_key(self)
    local popup_id = "##colour_swatch_ctx_" .. key
    if self._open_context then
        reaper.ImGui_OpenPopup(ctx, popup_id)
        self._open_context = false
    end

    local ctx_cc, ctx_sc = C.GlobalStyle.apply(ctx)
    if reaper.ImGui_BeginPopup(ctx, popup_id) then
        reaper.ImGui_TextDisabled(ctx, "Palettes")
        local stock = stock_categories(self)
        for _, c in ipairs(stock) do
            local sel = self._state.active_category_id == c.id
            if reaper.ImGui_MenuItem(ctx, c.name or c.id, nil, sel) then
                self._state.active_category_id = c.id
                save_config()
            end
        end

        local user = self._state.user_categories or {}
        if #user > 0 then
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_TextDisabled(ctx, "User palettes")
            for _, c in ipairs(user) do
                local sel = self._state.active_category_id == c.id
                if reaper.ImGui_MenuItem(ctx, c.name or c.id, nil, sel) then
                    self._state.active_category_id = c.id
                    save_config()
                end
            end
        end

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_TextDisabled(ctx, "Swatch size")
        local scale = tonumber(self._state.swatch_scale) or 1.0
        scale = math.max(0.5, math.min(1.5, scale))
        reaper.ImGui_PushItemWidth(ctx, 200)
        local scale_changed, new_scale = reaper.ImGui_SliderDouble(ctx, "##colour_swatch_sz", scale, 0.5, 1.5, "%.2f")
        reaper.ImGui_PopItemWidth(ctx)
        if scale_changed then
            self._state.swatch_scale = new_scale
            save_config()
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, "Scales swatch cell size (smaller fits more per row).")
        end

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_MenuItem(ctx, "Add colour…") then
            self._pending_add_category_id = self._state.active_category_id
            local cols = active_palette(self)
            local ref = cols[1] or "#FFFFFFFF"
            self._picker_color_imgui = COLOR_UTILS.toImGuiColor(ref)
            self._open_picker = true
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        local src = find_category(self, self._state.active_category_id)
        if reaper.ImGui_MenuItem(ctx, "Duplicate palette…", nil, false, src ~= nil) then
            local default_name = ((src and src.name) or "Palette") .. " copy"
            local ok, name = reaper.GetUserInputs("Duplicate palette", 1, "Name", default_name)
            if ok and name and name ~= "" and src then
                table.insert(
                    self._state.user_categories,
                    {
                        id = next_user_cat_id(self),
                        name = name,
                        colors = deep_copy_colors(src.colors)
                    }
                )
                self._state.active_category_id = self._state.user_categories[#self._state.user_categories].id
                save_config()
            end
        end

        for i = #self._state.user_categories, 1, -1 do
            local uc = self._state.user_categories[i]
            if reaper.ImGui_MenuItem(ctx, "Delete \"" .. (uc.name or uc.id) .. "\"", nil, false) then
                table.remove(self._state.user_categories, i)
                if self._state.active_category_id == uc.id then
                    local stock = stock_categories(self)
                    self._state.active_category_id = stock[1] and stock[1].id or nil
                end
                save_config()
            end
        end

        reaper.ImGui_EndPopup(ctx)
    end
    C.GlobalStyle.reset(ctx, ctx_cc, ctx_sc)

    local picker_id = "##colour_swatch_picker_" .. key
    if self._open_picker then
        reaper.ImGui_OpenPopup(ctx, picker_id)
        self._open_picker = false
    end

    local pk_cc, pk_sc = C.GlobalStyle.apply(ctx)
    if reaper.ImGui_BeginPopup(ctx, picker_id) then
        local flags =
            reaper.ImGui_ColorEditFlags_NoAlpha() |
            reaper.ImGui_ColorEditFlags_NoInputs() |
            reaper.ImGui_ColorEditFlags_PickerHueBar() |
            reaper.ImGui_ColorEditFlags_DisplayRGB() |
            reaper.ImGui_ColorEditFlags_DisplayHex()

        local chg, new_c = reaper.ImGui_ColorPicker4(ctx, "##cp", self._picker_color_imgui, flags)
        if chg then
            self._picker_color_imgui = new_c
        end

        if reaper.ImGui_Button(ctx, "Add to palette") then
            local hex = COLOR_UTILS.toHex(new_c)
            local src_id = self._pending_add_category_id
            local src = find_category(self, src_id)

            if src and not src.stock then
                for _, uc in ipairs(self._state.user_categories) do
                    if uc.id == src.id then
                        table.insert(uc.colors, hex)
                        break
                    end
                end
                save_config()
            else
                local new_colors = src and deep_copy_colors(src.colors) or {}
                table.insert(new_colors, hex)

                local ok, name = reaper.GetUserInputs("New palette name", 1, "Name", "My colours")
                if ok and name and name ~= "" then
                    table.insert(
                        self._state.user_categories,
                        {
                            id = next_user_cat_id(self),
                            name = name,
                            colors = new_colors
                        }
                    )
                    self._state.active_category_id = self._state.user_categories[#self._state.user_categories].id
                    save_config()
                end
            end
            self._pending_add_category_id = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Cancel") then
            self._pending_add_category_id = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_EndPopup(ctx)
    end
    C.GlobalStyle.reset(ctx, pk_cc, pk_sc)
end

function widget.renderColourSwatch(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color, _layout, _bg_color)
    load_state(self)
    local colors = active_palette(self)
    local n = #colors
    local is_vertical_toolbar = _layout and _layout.is_vertical or false
    local pad_y = is_vertical_toolbar and PAD_Y_VERTICAL_TOP or PAD_Y_HORIZONTAL
    local inner_w = math.max(1, render_width - 2 * PAD_X)
    local min_c, max_c = swatch_bounds(self)
    local inner_h_budget = horizontal_inner_height_budget(CONFIG.SIZES.HEIGHT, min_c)
    local rects
    if is_constrained_mode(self) then
        rects = layout_rects_preview_single_row(inner_w, n, inner_h_budget, min_c, max_c)
    else
        rects = layout_rects(inner_w, n, is_vertical_toolbar, inner_h_budget, min_c, max_c)
    end

    self._hit_rects = {}
    for i, r in ipairs(rects) do
        self._hit_rects[i] = { x = PAD_X + r.x, y = pad_y + r.y, w = r.w, h = r.h }
    end

    for i, r in ipairs(rects) do
        local hx = rel_x + PAD_X + r.x
        local hy = rel_y + pad_y + r.y
        local x1, y1 = coords:relativeToDrawList(hx, hy)
        local x2, y2 = coords:relativeToDrawList(hx + r.w, hy + r.h)
        local hex = colors[i]
        local fill = COLOR_UTILS.toImGuiColor(hex or "#888888FF")
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, fill, 2)
        reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, 0x00000088, 2, 0, 1)
    end

    if n == 0 then
        local tx, ty = coords:relativeToDrawList(rel_x + 8, rel_y + (CONFIG.SIZES.HEIGHT / 2 - 6))
        reaper.ImGui_DrawList_AddText(draw_list, tx, ty, 0x888888FF, "No colours")
    end

    draw_menus(self, ctx)
end

return widget
