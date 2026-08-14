-- Utils/Widget/spinner_slide_out_render.lua

local ROW = require("Utils.Chips.chip_row")
local SPINNER = require("Utils.Chips.chip_spinner")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local DRAWING = require("Utils.Draw.drawing")
local ICON_FONTS = require("Utils.Core.icon_fonts")
local SLIDE_HOST = require("Utils.Widget.slide_out_chip_host")

local function draw_preset_ms(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, mx, my, slide_ns, label_for_chip, active_id, extra)
    local spec = { slide_namespace = slide_ns, chip_round = ROW.CHIP_ROUND }
    SLIDE_HOST.draw_ms(ctx, self, chips, coords, draw_list, btn_txt, btn_bg,
        SLIDE_HOST.slide_draw_opts(ctx, spec, self, slide_ns .. "_", mx, my,
            function()
                return false
            end,
            { enabled = true, mixed = false },
            {
                grid_layout = true,
                alpha_factor = self._slide_alpha_factor,
                label_for = label_for_chip,
                rel_x = extra and extra.rel_x,
                rel_y = extra and extra.rel_y,
                is_selected_segment = function(c)
                    return not c.blank and active_id ~= nil and c.mode ~= nil and c.mode.id == active_id
                end,
            }))
end

return function(widget, spec, env)
    local WID = env.WID
    local MS_GAP = env.MS_GAP
    local CMD_PITCH_TOGGLE = env.CMD_PITCH_TOGGLE
    local SLIDE_NAMESPACE = env.SLIDE_NAMESPACE
    local PITCH_ICON = env.PITCH_ICON
    local SPINNER_OVERLAY = env.SPINNER_OVERLAY
    local compute_toolbar_spinner_layout = env.compute_toolbar_spinner_layout
    local compute_preview_vertical_layout = env.compute_preview_vertical_layout
    local compute_preview_horizontal_layout = env.compute_preview_horizontal_layout
    local apply_sp_readout_screen = env.apply_sp_readout_screen
    local hover_toolbar_spinner_segment = env.hover_toolbar_spinner_segment
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
        DRAWING.drawToolbarIconPillChip(ctx, coords, draw_list, pt_rect, btn_txt, btn_bg, {
            active = st_pitch,
            hover = pt_hit,
            icon_path = PITCH_ICON,
            icon_char = utf8.char(ICON_FONTS.ICON_CODEPOINT),
            icon_sz = chip_h * 0.8,
            fallback_text = "P",
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

    local function draw_tb_spinner(ctx, self, coords, draw_list, tb, btn_txt, btn_bg, mx, my, draw_pitch_fn)
        if not tb then
            apply_sp_readout_screen(self, nil)
            return
        end
        apply_sp_readout_screen(self, tb)
        local sm = hover_toolbar_spinner_segment(coords, mx, my, tb)
        local readout = spinner_readout_text(self)
        if tb.sp_layout.stacked then
            if tb.minus_rect then
                SPINNER.draw_segment(ctx, coords, draw_list, tb.minus_rect, "-", btn_txt, btn_bg, sm == "minus")
                SPINNER.draw_segment(ctx, coords, draw_list, tb.readout_rect, readout, btn_txt, btn_bg, sm == "readout")
                SPINNER.draw_segment(ctx, coords, draw_list, tb.plus_rect, "+", btn_txt, btn_bg, sm == "plus")
            end
        elseif tb.minus then
            SPINNER.draw_segment(ctx, coords, draw_list, tb.minus, "-", btn_txt, btn_bg, sm == "minus")
            SPINNER.draw_segment(ctx, coords, draw_list, tb.readout, readout, btn_txt, btn_bg, sm == "readout")
            SPINNER.draw_segment(ctx, coords, draw_list, tb.plus, "+", btn_txt, btn_bg, sm == "plus")
        end
        if tb.pitch_rect and draw_pitch_fn then
            draw_pitch_fn(ctx, coords, draw_list, tb.pitch_rect, btn_txt, btn_bg, tb.chip_h)
        end
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
            local tb = compute_toolbar_spinner_layout(ctx, self, rel_x, rel_y, render_width, layout, rw, MS_GAP)
            draw_tb_spinner(ctx, self, coords, draw_list, tb, btn_txt, btn_bg, mx, my, draw_pitch_icon_chip)
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

            draw_preset_ms(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, mx, my, SLIDE_NAMESPACE, label_for_chip, active_id, {
                rel_x = rel_x,
                rel_y = rel_y,
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
            local combined = compute_preview_vertical_layout(ctx, self, rel_x, rel_y, render_width, layout, rw, MS_GAP, list, layout_multiswitch_chips)
            draw_preset_ms(ctx, self, combined.chips, coords, draw_list, btn_txt, btn_bg, mx, my, SLIDE_NAMESPACE, label_for_chip, active_id)
            draw_tb_spinner(ctx, self, coords, draw_list, combined.tb, btn_txt, btn_bg, mx, my, function(c, co, dl, pt_rect, bt, bb, _chip_h)
                draw_pitch_text_chip(c, co, dl, pt_rect, bt, bb)
            end)
            return
        end

        local combined = compute_preview_horizontal_layout(ctx, self, rel_x, rel_y, render_width, layout, rw, MS_GAP, list, layout_multiswitch_chips)
        draw_preset_ms(ctx, self, combined.chips, coords, draw_list, btn_txt, btn_bg, mx, my, SLIDE_NAMESPACE, label_for_chip, active_id)
        draw_tb_spinner(ctx, self, coords, draw_list, combined.tb, btn_txt, btn_bg, mx, my, function(c, co, dl, pt_rect, bt, bb, _chip_h)
            draw_pitch_text_chip(c, co, dl, pt_rect, bt, bb)
        end)
    end

    function widget.onWidgetFrame(self, ctx, button)
        draw_spinner_overlay(self, ctx, button)
    end
end
