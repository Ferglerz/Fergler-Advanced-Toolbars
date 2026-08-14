-- Menus/Button_Settings/widget_selector_preview.lua
-- Live widget preview tiles for the widget selector grid.

local widgetTitle = require("Utils.Widget.widget_title")

local M = {}

function M.compute_grid_layout(ctx, avail_w)
    avail_w = math.max(0, avail_w or 0)
    local grid_inner_pad = 16
    local usable_grid_w = math.max(0, avail_w - (grid_inner_pad * 2))
    local sp_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())) or 0
    local min_cell_w = 120
    local columns = math.max(1, math.floor((usable_grid_w + sp_x) / (min_cell_w + sp_x)))
    local cell_w = math.max(min_cell_w, math.floor((usable_grid_w - sp_x * (columns - 1)) / columns))
    local pad = 8
    local button_h = CONFIG.SIZES.HEIGHT or 38
    local cell_h = pad * 2 + button_h
    local tile_rounding = math.max(6, math.floor((CONFIG.SIZES.ROUNDING or 6) * 0.75))
    return {
        grid_inner_pad = grid_inner_pad,
        sp_x = sp_x,
        columns = columns,
        cell_w = cell_w,
        cell_h = cell_h,
        button_h = button_h,
        pad = pad,
        tile_rounding = tile_rounding,
    }
end

local function sync_preview_shell(sel, shell)
    shell.custom_color = sel.preview_style_custom
    shell.user_colors = sel.preview_style_user
    shell.border_offset = sel.preview_style_border
    if shell.cache.colors then
        shell.cache.colors = nil
    end
end

local function draw_tile_chrome(ctx, tile_screen_x, tile_screen_y, cell_w, cell_h, tile_hovered, is_selected, tile_rounding)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local base_tile_bg = tile_hovered and 0x383838FF or 0x2D2D2DFF
    local tile_border = is_selected and 0xE8E5DCFF or (tile_hovered and 0x7D7D7DFF or 0x4F4F4FFF)
    local dummy_coords = {
        relativeRectToDrawList = function(self, cx, cy, cw, ch)
            return cx, cy, cx + cw, cy + ch
        end,
    }
    DRAWING.drawChipBackground(dummy_coords, draw_list, tile_screen_x, tile_screen_y, cell_w, cell_h, base_tile_bg, {
        rounding = tile_rounding,
        border_color = tile_border,
        thickness = is_selected and 2 or 1,
    })
    return draw_list
end

local function render_tile_preview(ctx, sel, shell, widget_entry, layout, tile_x, tile_y, tile_screen_x, tile_screen_y)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

    local preview_ok, preview_err = pcall(function()
        if not sel.preview_cache[widget_entry.name] then
            sel.preview_cache[widget_entry.name] = C.WidgetsManager:cloneWidgetInstance(widget_entry.name)
        end
        shell.widget = sel.preview_cache[widget_entry.name]
        shell.widget._preview_mode = true
        shell.is_alone = true
        shell:clearLayoutCache()
        local max_inner = layout.cell_w - layout.pad * 2
        shell.widget._preview_width_cap = max_inner
        C.LayoutManager:calculateWidgetButtonWidth(ctx, shell)
        local button_layout = shell.cache.layout or {}
        local draw_w = max_inner
        local preview_h = layout.button_h or CONFIG.SIZES.HEIGHT or 38

        local coords = COORDINATES.new(ctx)
        local state_key = C.Interactions:determineStateKey(shell)
        local bg_color, border_color = COLOR_UTILS.getButtonColors(shell, state_key, "NORMAL")
        local draw_layout = {
            width = draw_w,
            height = preview_h,
            extra_padding = button_layout.extra_padding or 0,
        }
        local preview_x = tile_x + layout.pad
        local preview_y = tile_y + layout.pad
        C.ButtonRenderer:renderBackground(draw_list, shell, preview_x, preview_y, draw_w, bg_color, border_color, coords, false, preview_h, ctx)
        C.WidgetRenderer:renderWidgetPreview(ctx, shell, preview_x, preview_y, coords, draw_list, draw_layout)
        shell.widget._preview_mode = nil
        shell.widget._preview_width_cap = nil
    end)

    if preview_ok then
        return
    end

    reaper.ShowConsoleMsg(
        "Advanced Toolbars: widget preview failed ("
            .. tostring(widget_entry.name)
            .. "): "
            .. tostring(preview_err)
            .. "\n"
    )
    local err_x, err_y = tile_screen_x + layout.pad, tile_screen_y + layout.pad + 8
    reaper.ImGui_DrawList_AddText(draw_list, err_x, err_y, 0xFF8888FF, "Preview error")
end

function M.render_grid(ctx, sel, shell, layout, scroll_h, apply_selected_fn)
    sync_preview_shell(sel, shell)

    local grid_child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
    local hovered_widget = nil
    local selected_widget = (sel.selected_index and sel.widget_list[sel.selected_index]) or nil

    reaper.ImGui_BeginChild(ctx, "WidgetPreviewGrid", 0, scroll_h, grid_child_flags)
    reaper.ImGui_SetCursorPos(ctx, layout.grid_inner_pad, layout.grid_inner_pad)

    local grid_col = 0
    local prev_category
    local prev_subcategory

    for i, widget_entry in ipairs(sel.widget_list) do
        local cat = widget_entry.category or ""
        local sub = widget_entry.subcategory or ""

        if (prev_category or "") ~= cat then
            if grid_col > 0 then
                reaper.ImGui_NewLine(ctx)
                grid_col = 0
            end
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, cat ~= "" and cat or "General")
            reaper.ImGui_Dummy(ctx, 0, 6)
            prev_category = cat
            prev_subcategory = nil
        end

        if sub ~= "" and sub ~= prev_subcategory then
            if grid_col > 0 then
                reaper.ImGui_NewLine(ctx)
                grid_col = 0
            end
            reaper.ImGui_TextDisabled(ctx, sub)
            reaper.ImGui_Dummy(ctx, 0, 4)
            prev_subcategory = sub
        elseif sub == "" then
            prev_subcategory = nil
        end

        if grid_col == 0 then
            reaper.ImGui_SetCursorPosX(ctx, layout.grid_inner_pad)
        else
            reaper.ImGui_SameLine(ctx, 0, layout.sp_x)
        end

        local tile_x = reaper.ImGui_GetCursorPosX(ctx)
        local tile_y = reaper.ImGui_GetCursorPosY(ctx)
        local tile_screen_x, tile_screen_y = reaper.ImGui_GetCursorScreenPos(ctx)

        reaper.ImGui_InvisibleButton(ctx, "##tile_pick_" .. widget_entry.name, layout.cell_w, layout.cell_h)
        local tile_hovered = reaper.ImGui_IsItemHovered(ctx)
        local tile_clicked = reaper.ImGui_IsItemClicked(ctx, 0)
        local tile_double_clicked = tile_hovered and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)
        local is_selected = i == sel.selected_index

        if tile_clicked then
            sel.selected_index = i
            is_selected = true
            selected_widget = widget_entry
        end
        if tile_double_clicked then
            sel.selected_index = i
            selected_widget = widget_entry
            apply_selected_fn()
        end
        if tile_hovered then
            hovered_widget = widget_entry
        end

        draw_tile_chrome(ctx, tile_screen_x, tile_screen_y, layout.cell_w, layout.cell_h, tile_hovered, is_selected, layout.tile_rounding)
        if tile_hovered or is_selected then
            render_tile_preview(ctx, sel, shell, widget_entry, layout, tile_x, tile_y, tile_screen_x, tile_screen_y)
        end

        grid_col = grid_col + 1
        if grid_col >= layout.columns then
            grid_col = 0
        end
    end

    reaper.ImGui_EndChild(ctx)
    shell.widget = nil

    return hovered_widget, selected_widget
end

return M
