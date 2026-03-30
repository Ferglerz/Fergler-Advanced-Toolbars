-- widgets/colour_swatch.lua
-- Track/item colour swatches with stock + user palettes; state in CONFIG.WIDGET_SAVED_STATES.

local MIN_CELL = 8
local GAP = 2
local PAD = 4

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
            target = "track",
            active_category_id = nil,
            user_categories = {}
        }
        store[key] = st
    end
    if st.target ~= "track" and st.target ~= "item" then
        st.target = "track"
    end
    if type(st.user_categories) ~= "table" then
        st.user_categories = {}
    end
    self._state = st
    return st
end

local function stock_categories(self)
    local defs = CONFIG.COLOUR_SWATCH_DEFAULTS
    if type(defs) ~= "table" then
        return {}
    end
    local list = defs[self._state.target]
    return type(list) == "table" and list or {}
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
    if self._state.target == "item" then
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

-- Max columns that fit with cell >= MIN_CELL
local function columns_for_width(inner_w)
    if inner_w < MIN_CELL then
        return 1
    end
    return math.max(1, math.floor((inner_w + GAP) / (MIN_CELL + GAP)))
end

local function cell_size(inner_w, cols)
    if cols <= 0 then
        return MIN_CELL
    end
    return math.max(MIN_CELL, (inner_w - (cols - 1) * GAP) / cols)
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
local function layout_rects(inner_w, n)
    if n <= 0 then
        return {}, 0
    end
    local cols = columns_for_width(inner_w)
    local rows = math.ceil(n / cols)
    local cw = cell_size(inner_w, cols)
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

local function next_user_cat_id(self)
    self._cat_seq = (self._cat_seq or 0) + 1
    return string.format("user_%s_%d", state_key(self):gsub("[^%w]", "_"), self._cat_seq)
end

local widget = {
    name = "Colour Swatch",
    type = "colour_swatch",
    width = 200,
    update_interval = 0.5,
    description = "Click a swatch to set track or item colour. Right-click for palettes and add colour.",
    _state = nil,
    _picker_color_imgui = 0xFFFFFFFF,
    _open_context = false,
    _open_picker = false,
    _pending_add_stock_id = nil,
    _cat_seq = 0,
    _hit_rects = nil
}

function widget.getValue(self)
    load_state(self)
    return 0
end

function widget.getLayoutWidth(self, _ctx)
    load_state(self)
    return self.width or 200
end

function widget.getLayoutHeight(self, _ctx, inner_width, _is_vertical_toolbar)
    load_state(self)
    local colors = active_palette(self)
    local n = #colors
    local w = inner_width or self.width or 200
    local inner_w = w - 2 * PAD
    local base_h = CONFIG.SIZES.HEIGHT
    if n == 0 then
        return base_h
    end
    local _, total_h = layout_rects(inner_w, n)
    return math.max(base_h, PAD * 2 + (total_h or 0))
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

    if reaper.ImGui_BeginPopup(ctx, popup_id) then
        reaper.ImGui_TextDisabled(ctx, "Target")
        if reaper.ImGui_MenuItem(ctx, "Tracks", nil, self._state.target == "track") then
            self._state.target = "track"
            local stock = stock_categories(self)
            if stock[1] then
                self._state.active_category_id = stock[1].id
            end
            save_config()
        end
        if reaper.ImGui_MenuItem(ctx, "Items", nil, self._state.target == "item") then
            self._state.target = "item"
            local stock = stock_categories(self)
            if stock[1] then
                self._state.active_category_id = stock[1].id
            end
            save_config()
        end

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_TextDisabled(ctx, "Palettes")
        for _, c in ipairs(all_categories(self)) do
            local sel = self._state.active_category_id == c.id
            if reaper.ImGui_MenuItem(ctx, c.name or c.id, nil, sel) then
                self._state.active_category_id = c.id
                save_config()
            end
        end

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_MenuItem(ctx, "Add colour…") then
            self._pending_add_stock_id = self._state.active_category_id
            local cols = active_palette(self)
            local ref = cols[1] or "#FFFFFFFF"
            self._picker_color_imgui = COLOR_UTILS.toImGuiColor(ref)
            self._open_picker = true
            reaper.ImGui_CloseCurrentPopup(ctx)
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

    local picker_id = "##colour_swatch_picker_" .. key
    if self._open_picker then
        reaper.ImGui_OpenPopup(ctx, picker_id)
        self._open_picker = false
    end

    if reaper.ImGui_BeginPopup(ctx, picker_id) then
        local flags =
            reaper.ImGui_ColorEditFlags_AlphaBar() |
            reaper.ImGui_ColorEditFlags_NoInputs() |
            reaper.ImGui_ColorEditFlags_PickerHueBar() |
            reaper.ImGui_ColorEditFlags_DisplayRGB() |
            reaper.ImGui_ColorEditFlags_DisplayHex()

        local chg, new_c = reaper.ImGui_ColorPicker4(ctx, "##cp", self._picker_color_imgui, flags)
        if chg then
            self._picker_color_imgui = new_c
        end

        if reaper.ImGui_Button(ctx, "Add to palette") then
            local r = (new_c >> 24) & 0xFF
            local g = (new_c >> 16) & 0xFF
            local b = (new_c >> 8) & 0xFF
            local a = new_c & 0xFF
            local hex = string.format("#%02X%02X%02X%02X", r, g, b, a)
            local src_id = self._pending_add_stock_id
            local src = find_category(self, src_id)
            local new_colors = src and deep_copy_colors(src.colors) or {}
            table.insert(new_colors, hex)

            local ok, name = reaper.GetUserInputs("New palette name", 1, "Name", "My colours")
            if ok and name and name ~= "" then
                if src and src.stock then
                    table.insert(
                        self._state.user_categories,
                        {
                            id = next_user_cat_id(self),
                            name = name,
                            colors = new_colors
                        }
                    )
                    self._state.active_category_id = self._state.user_categories[#self._state.user_categories].id
                elseif src and not src.stock then
                    for _, uc in ipairs(self._state.user_categories) do
                        if uc.id == src.id then
                            table.insert(uc.colors, hex)
                            break
                        end
                    end
                else
                    table.insert(
                        self._state.user_categories,
                        {
                            id = next_user_cat_id(self),
                            name = name,
                            colors = new_colors
                        }
                    )
                    self._state.active_category_id = self._state.user_categories[#self._state.user_categories].id
                end
                save_config()
            end
            self._pending_add_stock_id = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Cancel") then
            self._pending_add_stock_id = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_EndPopup(ctx)
    end
end

function widget.renderColourSwatch(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color, _layout)
    load_state(self)
    local colors = active_palette(self)
    local n = #colors
    local inner_w = render_width - 2 * PAD
    local rects = layout_rects(inner_w, n)

    self._hit_rects = {}
    for i, r in ipairs(rects) do
        self._hit_rects[i] = { x = PAD + r.x, y = PAD + r.y, w = r.w, h = r.h }
    end

    for i, r in ipairs(rects) do
        local hx = rel_x + PAD + r.x
        local hy = rel_y + PAD + r.y
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
