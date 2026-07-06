-- widgets/colour_swatch.lua
-- Track/item colour swatches with stock + user palettes; state in CONFIG.WIDGET_SAVED_STATES.

local WIDGET = require("Utils.Widget.widget_factory")
local LAYOUT = require("Widgets.colour_swatch_layout")
local STATE = require("Widgets.colour_swatch_state")
local PICKER = require("Widgets.colour_swatch_picker")

local PAD_X = LAYOUT.PAD_X
local PAD_Y_HORIZONTAL = LAYOUT.PAD_Y_HORIZONTAL
local PAD_Y_VERTICAL_TOP = LAYOUT.PAD_Y_VERTICAL_TOP
local PAD_Y_VERTICAL_BOTTOM = LAYOUT.PAD_Y_VERTICAL_BOTTOM
local GAP = LAYOUT.GAP

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

local function is_constrained_mode(self)
    return self and self._preview_mode == true
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
    STATE.load_state(self)
    return 0
end

function widget.getLayoutWidth(self, _ctx, layout_is_vertical_toolbar)
    STATE.load_state(self)
    local colors = STATE.active_palette(self)
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

    local min_c, max_c = STATE.swatch_bounds(self)
    local inner_h_budget = LAYOUT.horizontal_inner_height_budget(CONFIG.SIZES.HEIGHT, min_c)
    local rows, cols, cell = LAYOUT.plan_horizontal_grid(n, inner_h_budget, min_c, max_c)

    local needed_inner_w = cols * cell + (cols - 1) * GAP
    local needed_total_w = needed_inner_w + 2 * PAD_X
    return math.max(min_w, math.max(base, needed_total_w))
end

function widget.getLayoutHeight(self, _ctx, inner_width, _is_vertical_toolbar)
    STATE.load_state(self)
    local colors = STATE.active_palette(self)
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
    local min_c, max_c = STATE.swatch_bounds(self)
    local inner_h_budget = LAYOUT.horizontal_inner_height_budget(base_h, min_c)
    if is_constrained_mode(self) then
        return base_h
    end
    local _, total_h = LAYOUT.layout_rects(inner_w, n, is_vertical_toolbar, inner_h_budget, min_c, max_c)
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
    local colors = STATE.active_palette(self)
    local hex = colors[sub_idx]
    if hex then
        apply_color_to_targets(self, hex)
    end
end

function widget.onSettingsMenu(self, ctx, button)
    local pending_separator = false
    local core = STATE.stock_categories(self)
    local user = self._state.user_categories or {}

    -- CORE PALETTES
    if #core > 0 then
        reaper.ImGui_TextDisabled(ctx, "Core palettes")
        for _, c in ipairs(core) do
            local sel = self._state.active_category_id == c.id
            if reaper.ImGui_MenuItem(ctx, c.name or c.id, nil, sel) then
                self._state.active_category_id = c.id
                STATE.save_config()
            end
        end
        pending_separator = true
    end

    -- USER PALETTES
    if #user > 0 then
        if pending_separator then
            reaper.ImGui_Separator(ctx)
            pending_separator = false
        end
        reaper.ImGui_TextDisabled(ctx, "User palettes")
        for _, c in ipairs(user) do
            local sel = self._state.active_category_id == c.id
            if reaper.ImGui_MenuItem(ctx, c.name or c.id, nil, sel) then
                self._state.active_category_id = c.id
                STATE.save_config()
            end
        end
        pending_separator = true
    end

    if pending_separator then
        reaper.ImGui_Separator(ctx)
        pending_separator = false
    end
    reaper.ImGui_TextDisabled(ctx, "Swatch size")
    local scale = tonumber(self._state.swatch_scale) or 1.0
    scale = math.max(0.5, math.min(1.5, scale))

    local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
    local slider_w = math.min(math.max(10, avail_w - 16), 200)
    local cur_x = reaper.ImGui_GetCursorPosX(ctx)
    reaper.ImGui_SetCursorPosX(ctx, cur_x + (avail_w - slider_w) * 0.5)

    reaper.ImGui_PushItemWidth(ctx, slider_w)
    local scale_changed, new_scale = reaper.ImGui_SliderDouble(ctx, "##colour_swatch_sz", scale, 0.5, 1.5, "%.2f")
    reaper.ImGui_PopItemWidth(ctx)
    if scale_changed then
        self._state.swatch_scale = new_scale
        STATE.save_config()
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Scales swatch cell size (smaller fits more per row).")
    end

    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Add colour…") then
        self._pending_add_category_id = self._state.active_category_id
        local cols = STATE.active_palette(self)
        local ref = cols[1] or "#FFFFFFFF"
        self._picker_color_imgui = COLOR_UTILS.toImGuiColor(ref)
        self._open_picker = true
    end
    local src = STATE.find_category(self, self._state.active_category_id)
    if reaper.ImGui_MenuItem(ctx, "Duplicate palette…", nil, false, src ~= nil) then
        local default_name = ((src and src.name) or "Palette") .. " copy"
        local ok, name = reaper.GetUserInputs("Duplicate palette", 1, "Name", default_name)
        if ok and name and name ~= "" and src then
            table.insert(
                self._state.user_categories,
                {
                    id = STATE.next_user_cat_id(self),
                    name = name,
                    colors = STATE.deep_copy_colors(src.colors)
                }
            )
            self._state.active_category_id = self._state.user_categories[#self._state.user_categories].id
            STATE.save_config()
        end
    end

    for i = #self._state.user_categories, 1, -1 do
        local uc = self._state.user_categories[i]
        if reaper.ImGui_MenuItem(ctx, "Delete \"" .. (uc.name or uc.id) .. "\"", nil, false) then
            table.remove(self._state.user_categories, i)
            if self._state.active_category_id == uc.id then
                local stock = STATE.stock_categories(self)
                self._state.active_category_id = stock[1] and stock[1].id or nil
            end
            STATE.save_config()
        end
    end
end

function widget.renderColourSwatch(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color, _layout, _bg_color, render_height)
    STATE.load_state(self)
    local colors = STATE.active_palette(self)
    local n = #colors
    local is_vertical_toolbar = _layout and _layout.is_vertical or false
    local body_h = render_height or (_layout and _layout.height) or CONFIG.SIZES.HEIGHT
    if is_vertical_toolbar and _layout and (_layout.title_height or 0) > 0 then
        body_h = body_h - _layout.title_height
    end
    local pad_y = is_vertical_toolbar and PAD_Y_VERTICAL_TOP or PAD_Y_HORIZONTAL
    local pad_bottom = is_vertical_toolbar and PAD_Y_VERTICAL_BOTTOM or PAD_Y_HORIZONTAL
    local inner_w = math.max(1, render_width - 2 * PAD_X)
    local min_c, max_c = STATE.swatch_bounds(self)
    local inner_h_budget = LAYOUT.horizontal_inner_height_budget(body_h, min_c)
    local rects, grid_h
    if is_constrained_mode(self) then
        rects, grid_h = LAYOUT.layout_rects_preview_single_row(inner_w, n, inner_h_budget, min_c, max_c)
    else
        rects, grid_h = LAYOUT.layout_rects(inner_w, n, is_vertical_toolbar, inner_h_budget, min_c, max_c)
    end
    grid_h = grid_h or 0
    local content_h = pad_y + grid_h + pad_bottom
    local offset_y = math.max(0, (body_h - content_h) / 2)

    self._hit_rects = {}
    for i, r in ipairs(rects) do
        self._hit_rects[i] = { x = PAD_X + r.x, y = offset_y + pad_y + r.y, w = r.w, h = r.h }
    end

    for i, r in ipairs(rects) do
        local hx = rel_x + PAD_X + r.x
        local hy = rel_y + offset_y + pad_y + r.y
        local hex = colors[i]
        local fill = COLOR_UTILS.toImGuiColor(hex or "#888888FF")
        WIDGET.DRAWING.drawChipBackground(coords, draw_list, hx, hy, r.w, r.h, fill, { rounding = 2, border_color = 0x00000088 })
    end

    if n == 0 then
        WIDGET.DRAWING.drawTextRelative(coords, draw_list, rel_x + 8, rel_y + (body_h / 2 - 6), 0x888888FF, "No colours")
    end

    PICKER.draw(self, ctx)
end

return widget
