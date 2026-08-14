-- Segmented widget factory: toggle / multiswitch / readout rows across toolbar and slide-out.

local CHIP_ROW = require("Utils.Chips.chip_row")
local DRAWING = require("Utils.Draw.drawing")
local OPT_POPUP = require("Utils.Widget.widget_options_popup")
local LAYOUT = require("Utils.Widget.segmented_layout")
local MEASURE = require("Utils.Widget.segmented_measure")
local SLIDE_HOST = require("Utils.Widget.slide_out_chip_host")

local M = {}

local OVERRIDE_METHODS = {
    "getLayoutWidth", "getLayoutHeight", "slide_height", "slide_width",
    "hitTestSubcontrols", "onSubcontrolClick", "renderCustom", "onSettingsMenu",
    "onRightClick", "onClick", "applyPersistedOptions", "exportPersistedOptions",
}

function M.new(spec, make_widget)
    local widget = make_widget()
    local GAP = spec.gap or 6
    local INNER_GAP = spec.inner_gap or 3

    function widget:getValue()
        if spec.on_update then spec.on_update(self) end
        return 0
    end

    local rows_config = spec.rows
    if not rows_config and spec.segments then
        rows_config = { { segments = spec.segments } }
    end

    local function layout_all_rows(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)
        local frame_time = _G.FRAME_TIME
        local cache_key = string.format(
            "%s|%s|%s|%s|%s",
            rel_x,
            rel_y,
            render_width,
            layout and layout.is_vertical and "v" or "h",
            is_slide_out and "1" or "0"
        )
        if frame_time and self._seg_layout_frame == frame_time and self._seg_layout_key == cache_key and self._seg_layout_cache then
            return self._seg_layout_cache
        end
        local layouts = LAYOUT.layout_all_rows(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out, rows_config, GAP, INNER_GAP)
        if frame_time then
            self._seg_layout_frame = frame_time
            self._seg_layout_key = cache_key
            self._seg_layout_cache = layouts
        end
        return layouts
    end

    function widget:getLayoutWidth(ctx, is_vertical_toolbar)
        if not ctx then return self.width end
        if spec.slide_out and not is_vertical_toolbar then
            return CHIP_ROW.apply_preview_width_cap(self, MEASURE.measure_host_toolbar_width(self, ctx, rows_config, GAP, INNER_GAP))
        end
        return CHIP_ROW.apply_preview_width_cap(self, math.max(self.width or 0, MEASURE.measure_toolbar_width(self, ctx, rows_config, GAP, INNER_GAP)))
    end

    function widget:getLayoutHeight(ctx, inner_w, is_vertical_toolbar)
        if not is_vertical_toolbar then return CONFIG.SIZES.HEIGHT end
        if not ctx then return CONFIG.SIZES.HEIGHT end
        local _, _, total_h = layout_all_rows(self, ctx, 0, 0, inner_w or 9999, { is_vertical = true }, false)
        return math.max(CONFIG.SIZES.HEIGHT or 28, total_h or 0)
    end

    if spec.slide_out then
        function widget:slide_width(ctx, host_w, host_h, layout)
            if spec.slide_width then
                return spec.slide_width(self, ctx, host_w, host_h, layout)
            end
            return MEASURE.compute_slide_panel_dims(self, ctx, host_w, rows_config, GAP, INNER_GAP)
        end
        function widget:slide_height(ctx, host_w, host_h, layout)
            if spec.slide_height then
                return spec.slide_height(self, ctx, host_w, host_h, layout)
            end
            local _, h = MEASURE.compute_slide_panel_dims(self, ctx, host_w, rows_config, GAP, INNER_GAP)
            return h
        end
    end

    function widget:hitTestSubcontrols(ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
        local mx, my = coords:getRelativeMouse()
        local eff_slide_out = is_slide_out or self._is_rendering_slide_out or false
        local layouts = layout_all_rows(self, ctx, rel_x, rel_y, render_width, layout, eff_slide_out)
        local ordered = {}
        for id, l in pairs(layouts) do
            ordered[#ordered + 1] = { id = id, l = l }
        end
        table.sort(ordered, function(a, b)
            local ra = a.l.seg_row or 0
            local rb = b.l.seg_row or 0
            if ra ~= rb then
                return ra < rb
            end
            return a.id < b.id
        end)

        for _, entry in ipairs(ordered) do
            local id, l = entry.id, entry.l
            if l.type == "toggle" or l.type == "readout" then
                if coords:pointInRelativeRect(mx, my, l.rect.x, l.rect.y, l.rect.w, l.rect.h) then
                    return id
                end
            elseif l.type == "multiswitch" then
                for _, c in ipairs(l.chips) do
                    if not c.blank and coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
                        return id .. "_" .. c.id
                    end
                end
            end
        end
        return nil
    end

    function widget:onSubcontrolClick(sub_id)
        local r_idx, s_idx = sub_id:match("^r(%d+)_s(%d+)")
        if not r_idx then return false end
        r_idx = tonumber(r_idx)
        s_idx = tonumber(s_idx)
        local row = rows_config[r_idx]
        if not row then return false end
        local seg = row.segments[s_idx]
        if not seg then return false end

        if seg.type == "toggle" or seg.type == "readout" then
            if seg.on_click then seg.on_click(self) end
            return seg.type == "toggle"
        elseif seg.type == "multiswitch" then
            local chip_id = sub_id:match("^r%d+_s%d+_(.+)")
            if chip_id and not chip_id:match("^__ms_blank") and seg.on_click then
                seg.on_click(self, chip_id)
                return true
            end
        end
        return false
    end

    function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
        local mx, my = coords:getRelativeMouse()
        local is_slide_out = self._is_rendering_slide_out == true
        local layouts = layout_all_rows(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)

        for id, l in pairs(layouts) do
            local seg = l.seg
            if l.type == "readout" then
                local body_h = CHIP_ROW.widget_body_height(layout)
                if l.lines and l.font_size and (#l.lines > 1 or l.font_size < (CONFIG.SIZES.TEXT or 12)) then
                    DRAWING.drawCompactReadout(ctx, coords, draw_list, l.rect.x, rel_y, l.rect.w, body_h, l.lines, l.font_size, text_color)
                else
                    DRAWING.drawWidgetCenteredValueText(ctx, l.label, l.rect.x, rel_y, l.rect.w, body_h, coords, draw_list, text_color, 0)
                end
            elseif l.type == "toggle" then
                local is_on = seg.get_state and seg.get_state(self) or false
                local hover = coords:pointInRelativeRect(mx, my, l.rect.x, l.rect.y, l.rect.w, l.rect.h)

                if seg.render_custom_chip then
                    seg.render_custom_chip(self, ctx, coords, draw_list, l.rect, l.label, hover, btn_txt, btn_bg, text_color, bg_color)
                else
                    DRAWING.drawWidgetPillChip(ctx, coords, draw_list, l.rect, l.label, btn_txt, btn_bg, {
                        active = is_on,
                        filled = true,
                        hover = hover and not is_on,
                        rounding = CHIP_ROW.CHIP_ROUND,
                        alpha_factor = self._slide_alpha_factor,
                    })
                end
            elseif l.type == "multiswitch" then
                local active_id = seg.get_active and seg.get_active(self) or nil
                local multi_toggle = seg.multi_toggle == true
                local row_ns = is_slide_out and ("seg_r" .. tostring(l.seg_row or 0)) or nil
                SLIDE_HOST.draw_ms(ctx, self, l.chips, coords, draw_list, btn_txt, btn_bg, {
                    mx = mx,
                    my = my,
                    enabled = true,
                    mixed = false,
                    chip_round = CHIP_ROW.CHIP_ROUND,
                    alpha_factor = self._slide_alpha_factor,
                    multi_toggle = multi_toggle,
                    grid_layout = not multi_toggle and (is_slide_out or (seg.rows and seg.rows > 1)),
                    slide_namespace = row_ns,
                    is_selected_segment = function(c)
                        if c.blank then
                            return false
                        end
                        local cid = c.id or (c.mode and c.mode.id)
                        if multi_toggle and seg.is_on then
                            return seg.is_on(self, cid)
                        end
                        return cid == active_id
                    end,
                })
            end
        end
    end

    if spec.settings_menu then
        function widget:onSettingsMenu(ctx, button)
            if type(spec.settings_menu) == "function" then
                spec.settings_menu(self, ctx, button)
            elseif type(spec.settings_menu) == "table" then
                if spec.settings_menu_title then
                    reaper.ImGui_TextDisabled(ctx, spec.settings_menu_title)
                    reaper.ImGui_Spacing(ctx)
                end
                for _, item in ipairs(spec.settings_menu) do
                    local on = item.get_state and item.get_state(self) or false
                    if reaper.ImGui_MenuItem(ctx, item.label, nil, on) then
                        if item.on_click then item.on_click(self) end
                    end
                end
                if spec.settings_menu_on_commit then
                    OPT_POPUP.commit_dynamic_widget_layout(button, ctx)
                end
            end
        end
    end

    for _, method_name in ipairs(OVERRIDE_METHODS) do
        if spec[method_name] then
            widget[method_name] = spec[method_name]
        end
    end

    return widget
end

return M
