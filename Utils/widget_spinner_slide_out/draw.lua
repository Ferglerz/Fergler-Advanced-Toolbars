-- Utils/widget_spinner_slide_out/draw.lua

local ROW = require("Utils.Chips.chip_row")
local SPINNER = require("Utils.Chips.chip_spinner")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local DRAWING = require("Utils.Draw.drawing")
local ICON_FONTS = require("Utils.Core.icon_fonts")

return function(widget, spec, env)
    local M = env.M
    local WID = env.WID
    local MS_GAP = env.MS_GAP
    local CMD_PITCH_TOGGLE = env.CMD_PITCH_TOGGLE
    local SLIDE_NAMESPACE = env.SLIDE_NAMESPACE
    local PITCH_ICON = env.PITCH_ICON
    local SPINNER_OVERLAY = env.SPINNER_OVERLAY
    local layout_spinner_area = env.layout_spinner_area
    local toolbar_body_h = env.toolbar_body_h
    local slide_out_layout_opts = env.slide_out_layout_opts
    local layout_multiswitch_chips = env.layout_multiswitch_chips
    local enabled_list = env.enabled_list
    local ensure_included = env.ensure_included
    local readout_width = env.readout_width
    local resolve_active_preset_id = env.resolve_active_preset_id
    local render_preview = env.render_preview

    local function draw_pitch_icon_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg, chip_h)
        local mx, my = coords:getRelativeMouse()
        local st_pitch = reaper.GetToggleCommandState(CMD_PITCH_TOGGLE) == 1
        local pt_hit = coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h)
        local icon_mode = ICON_FONTS.resolveToolbarIcon(PITCH_ICON)
        DRAWING.drawWidgetPillIconChip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg, {
            active = st_pitch,
            hover = pt_hit,
            filled = true,
            icon_mode = icon_mode,
            icon_char = utf8.char(ICON_FONTS.ICON_CODEPOINT),
            icon_sz = chip_h * 0.8,
            text = "P",
            rounding = ROW.CHIP_ROUND,
        })
    end

    local function draw_pitch_text_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg)
        local mx, my = coords:getRelativeMouse()
        local st_pitch = reaper.GetToggleCommandState(CMD_PITCH_TOGGLE) == 1
        local pt_hit = coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h)
        SPINNER.draw_segment(ctx, coords, draw_list, pt_rect, "P", btn_txt, btn_bg, pt_hit, st_pitch)
    end

    local function spinner_readout_text(self)
        if not self._st_overlay_focused then
            local live = SPINNER_OVERLAY and SPINNER_OVERLAY.get_live_rate and SPINNER_OVERLAY.get_live_rate()
                or UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
            if SPINNER_OVERLAY and SPINNER_OVERLAY.rate_to_display then
                return SPINNER_OVERLAY.rate_to_display(live)
            end
        end
        return self._st_buf or "0st"
    end

    local function draw_spinner_overlay(self, ctx, _button)
        if not SPINNER_OVERLAY or self._preview_mode then
            return
        end
        if not self._st_overlay_focused then
            return
        end
        local geom = self._sp_readout_screen
        if not geom then
            return
        end

        self._st_buf = self._st_buf or spinner_readout_text(self)

        local overlay_id = (SPINNER_OVERLAY and SPINNER_OVERLAY.overlay_id) or (WID .. "_st_")
        reaper.ImGui_PushID(ctx, overlay_id .. tostring(self._button_instance_id or "x"))
        reaper.ImGui_SetCursorPos(ctx, geom.rel_x, geom.rel_y)
        reaper.ImGui_SetNextItemWidth(ctx, geom.w)
        local hint = SPINNER_OVERLAY.hint or ""
        local ch, tx = reaper.ImGui_InputTextWithHint(ctx, "##st", hint, self._st_buf)
        if ch and tx then
            self._st_buf = tx
            local trimmed = (self._st_buf:gsub("%s", ""))
            local st = SPINNER_OVERLAY.parse_input and SPINNER_OVERLAY.parse_input(trimmed)
            if st ~= nil then
                local nr
                if SPINNER_OVERLAY.apply_semitones then
                    nr = SPINNER_OVERLAY.apply_semitones(st)
                end
                if nr ~= nil then
                    if SPINNER_OVERLAY.on_rate_applied then
                        SPINNER_OVERLAY.on_rate_applied(self, nr)
                    elseif spec.on_mode_select then
                        spec.on_mode_select(self, { rate = nr })
                    else
                        reaper.CSurf_OnPlayRateChange(nr)
                    end
                end
            end
        end
        self._st_overlay_focused = reaper.ImGui_IsItemFocused(ctx) or reaper.ImGui_IsItemActive(ctx)
        reaper.ImGui_PopID(ctx)
    end

    function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        render_width = UTILS.asNumber(render_width, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
        local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)

        local mx, my = coords:getRelativeMouse()
        local vert = layout and layout.is_vertical
        local rw = readout_width(ctx)
        local play_r = UTILS.asNumber(self._play_rate, nil) or UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
        local active_id = self._active_ms_id or resolve_active_preset_id(self, play_r, enabled_list(self))

        local function label_for_chip(c)
            if not c.mode then
                return ""
            end
            return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
        end

        if not self._is_rendering_slide_out and not self._preview_mode then
            local sp_layout = layout_spinner_area(ctx, render_width, rw, self._show_spinner, self._show_pitch, vert)
            local elements_w = sp_layout.w

            local inset = ROW.button_rounding_content_pad()
            local current_x = rel_x + inset + math.max(0, (render_width - 2 * inset - elements_w) / 2)

            if sp_layout.stacked then
                local chip_h = SPINNER.chip_line_height(ctx)
                local y_start, y_row2 = M.stacked_spinner_rows(rel_y, chip_h, layout)

                if self._show_spinner ~= false then
                    local top_x = current_x + (elements_w - sp_layout.top_w) / 2
                    local minus_rect = { x = top_x, y = y_start, w = sp_layout.w_minus, h = chip_h }
                    local plus_rect = { x = top_x + minus_rect.w + MS_GAP, y = y_start, w = sp_layout.w_plus, h = chip_h }
                    local sm = "none"
                    if coords:pointInRelativeRect(mx, my, minus_rect.x, minus_rect.y, minus_rect.w, minus_rect.h) then
                        sm = "minus"
                    end
                    if coords:pointInRelativeRect(mx, my, plus_rect.x, plus_rect.y, plus_rect.w, plus_rect.h) then
                        sm = "plus"
                    end

                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    local readout_rect = { x = bot_x, y = y_row2, w = rw, h = chip_h }
                    if coords:pointInRelativeRect(mx, my, readout_rect.x, readout_rect.y, readout_rect.w, readout_rect.h) then
                        sm = "readout"
                    end

                    self._sp_readout_screen = { rel_x = readout_rect.x, rel_y = readout_rect.y, w = readout_rect.w, h = readout_rect.h }

                    SPINNER.draw_segment(ctx, coords, draw_list, minus_rect, "-", btn_txt, btn_bg, sm == "minus")
                    SPINNER.draw_segment(ctx, coords, draw_list, readout_rect, spinner_readout_text(self), btn_txt, btn_bg, sm == "readout")
                    SPINNER.draw_segment(ctx, coords, draw_list, plus_rect, "+", btn_txt, btn_bg, sm == "plus")

                    if self._show_pitch ~= false then
                        local pt_rect = { x = bot_x + rw + MS_GAP, y = y_row2, w = 26, h = chip_h }
                        draw_pitch_icon_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg, chip_h)
                    end
                elseif self._show_pitch ~= false then
                    self._sp_readout_screen = nil
                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    local pt_rect = { x = bot_x, y = y_row2, w = 26, h = chip_h }
                    draw_pitch_icon_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg, chip_h)
                end
            else
                if self._show_spinner ~= false then
                    local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, rel_y, toolbar_body_h(layout), rw)

                    self._sp_readout_screen = {
                        rel_x = readout.x,
                        rel_y = readout.y,
                        w = readout.w,
                        h = readout.h,
                    }

                    local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
                    SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
                    SPINNER.draw_segment(ctx, coords, draw_list, readout, spinner_readout_text(self), btn_txt, btn_bg, sm == "readout")
                    SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
                    current_x = current_x + sp_layout.spin_total + MS_GAP
                else
                    self._sp_readout_screen = nil
                end

                if self._show_pitch ~= false then
                    local chip_h = SPINNER.chip_line_height(ctx)
                    local pt_rect = { x = current_x, y = rel_y + (toolbar_body_h(layout) - chip_h) / 2, w = 26, h = chip_h }
                    draw_pitch_icon_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg, chip_h)
                end
            end
            return
        end

        if self._is_rendering_slide_out and not self._preview_mode then
            ensure_included(self)
            local list = enabled_list(self)

            local slide_opts = slide_out_layout_opts(
                self,
                ctx,
                render_width,
                self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout),
                layout
            )
            local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, list, slide_opts)

            CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
                mx = mx,
                my = my,
                enabled = true,
                mixed = false,
                chip_round = ROW.CHIP_ROUND,
                slide_namespace = SLIDE_NAMESPACE,
                grid_layout = true,
                label_for = label_for_chip,
                rel_x = rel_x,
                rel_y = rel_y,
                alpha_factor = self._slide_alpha_factor,
                is_selected_segment = function(c)
                    return not c.blank and active_id ~= nil and c.mode ~= nil and c.mode.id == active_id
                end,
            })
            return
        end

        if self._preview_mode then
            self._sp_readout_screen = nil
            render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
            return
        end

        self._sp_readout_screen = nil
        ensure_included(self)
        local list = enabled_list(self)
        if #list < 1 then
            self._included["1"] = true
            list = enabled_list(self)
        end

        if vert then
            local inset = ROW.button_rounding_content_pad()
            local chips, ms_outer_h = layout_multiswitch_chips(ctx, rel_x, rel_y, render_width, layout, list)
            CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
                mx = mx,
                my = my,
                enabled = true,
                mixed = false,
                chip_round = ROW.CHIP_ROUND,
                slide_namespace = SLIDE_NAMESPACE,
                grid_layout = true,
                label_for = label_for_chip,
                is_selected_segment = function(c)
                    return not c.blank and active_id ~= nil and c.mode ~= nil and c.mode.id == active_id
                end,
            })

            local extra_y = rel_y + ms_outer_h + ROW.CHIP_GAP
            local spin_total = SPINNER.total_width(ctx, rw)
            local elements_w = 0
            if self._show_spinner ~= false then
                elements_w = elements_w + spin_total
            end
            if self._show_pitch ~= false then
                elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26
            end

            local current_x = rel_x + inset + math.max(0, (render_width - 2 * inset - elements_w) / 2)

            if self._show_spinner ~= false then
                local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, extra_y, SPINNER.chip_line_height(ctx), rw)
                self._sp_readout_screen = {
                    rel_x = readout.x,
                    rel_y = readout.y,
                    w = readout.w,
                    h = readout.h,
                }
                local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
                SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
                SPINNER.draw_segment(ctx, coords, draw_list, readout, spinner_readout_text(self), btn_txt, btn_bg, sm == "readout")
                SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
                current_x = current_x + spin_total + MS_GAP
            end
            if self._show_pitch ~= false then
                local pt_rect = { x = current_x, y = extra_y, w = 26, h = SPINNER.chip_line_height(ctx) }
                draw_pitch_text_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg)
            end
            return
        end

        local sp_layout = layout_spinner_area(ctx, render_width, rw, self._show_spinner, self._show_pitch, vert)
        local ms_w = render_width
        local elements_w = sp_layout.w
        if elements_w > 0 then
            ms_w = math.max(40, render_width - elements_w - MS_GAP)
        end

        local chips = layout_multiswitch_chips(ctx, rel_x, rel_y, ms_w, layout, list)
        CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
            mx = mx,
            my = my,
            enabled = true,
            mixed = false,
            chip_round = ROW.CHIP_ROUND,
            slide_namespace = SLIDE_NAMESPACE,
            grid_layout = true,
            label_for = label_for_chip,
            is_selected_segment = function(c)
                return not c.blank and active_id ~= nil and c.mode ~= nil and c.mode.id == active_id
            end,
        })

        if elements_w > 0 and #chips > 0 then
            local last = chips[#chips]
            local current_x = last.x + last.w + MS_GAP

            if sp_layout.stacked then
                local chip_h = SPINNER.chip_line_height(ctx)
                local y_start, y_row2 = M.stacked_spinner_rows(rel_y, chip_h, layout)

                if self._show_spinner ~= false then
                    local top_x = current_x + (elements_w - sp_layout.top_w) / 2
                    local minus_rect = { x = top_x, y = y_start, w = sp_layout.w_minus, h = chip_h }
                    local plus_rect = { x = top_x + minus_rect.w + MS_GAP, y = y_start, w = sp_layout.w_plus, h = chip_h }
                    local sm = "none"
                    if coords:pointInRelativeRect(mx, my, minus_rect.x, minus_rect.y, minus_rect.w, minus_rect.h) then
                        sm = "minus"
                    end
                    if coords:pointInRelativeRect(mx, my, plus_rect.x, plus_rect.y, plus_rect.w, plus_rect.h) then
                        sm = "plus"
                    end

                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    local readout_rect = { x = bot_x, y = y_row2, w = rw, h = chip_h }
                    if coords:pointInRelativeRect(mx, my, readout_rect.x, readout_rect.y, readout_rect.w, readout_rect.h) then
                        sm = "readout"
                    end

                    self._sp_readout_screen = { rel_x = readout_rect.x, rel_y = readout_rect.y, w = readout_rect.w, h = readout_rect.h }

                    SPINNER.draw_segment(ctx, coords, draw_list, minus_rect, "-", btn_txt, btn_bg, sm == "minus")
                    SPINNER.draw_segment(ctx, coords, draw_list, readout_rect, spinner_readout_text(self), btn_txt, btn_bg, sm == "readout")
                    SPINNER.draw_segment(ctx, coords, draw_list, plus_rect, "+", btn_txt, btn_bg, sm == "plus")

                    if self._show_pitch ~= false then
                        local pt_rect = { x = bot_x + rw + MS_GAP, y = y_row2, w = 26, h = chip_h }
                        draw_pitch_text_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg)
                    end
                elseif self._show_pitch ~= false then
                    self._sp_readout_screen = nil
                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    local pt_rect = { x = bot_x, y = y_row2, w = 26, h = chip_h }
                    draw_pitch_text_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg)
                end
            else
                if self._show_spinner ~= false then
                    local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, rel_y, toolbar_body_h(layout), rw)

                    self._sp_readout_screen = {
                        rel_x = readout.x,
                        rel_y = readout.y,
                        w = readout.w,
                        h = readout.h,
                    }

                    local sm = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
                    SPINNER.draw_segment(ctx, coords, draw_list, minus, "-", btn_txt, btn_bg, sm == "minus")
                    SPINNER.draw_segment(ctx, coords, draw_list, readout, spinner_readout_text(self), btn_txt, btn_bg, sm == "readout")
                    SPINNER.draw_segment(ctx, coords, draw_list, plus, "+", btn_txt, btn_bg, sm == "plus")
                    current_x = current_x + sp_layout.spin_total + MS_GAP
                else
                    self._sp_readout_screen = nil
                end

                if self._show_pitch ~= false then
                    local chip_h = SPINNER.chip_line_height(ctx)
                    local pt_rect = { x = current_x, y = rel_y + (toolbar_body_h(layout) - chip_h) / 2, w = 26, h = chip_h }
                    draw_pitch_text_chip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg)
                end
            end
        end
    end

    function widget.onWidgetFrame(self, ctx, button)
        draw_spinner_overlay(self, ctx, button)
    end
end
