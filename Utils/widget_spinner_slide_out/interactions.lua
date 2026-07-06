-- Utils/widget_spinner_slide_out/interactions.lua

local ROW = require("Utils.Chips.chip_row")
local SPINNER = require("Utils.Chips.chip_spinner")
local CHIP_HIT = require("Utils.Chips.chip_hit_prefix")
local VIS = require("Utils.Widget.widget_visibility")

return function(widget, spec, env)
    local M = env.M
    local MS_PREFIX = env.MS_PREFIX
    local SP_PREFIX = env.SP_PREFIX
    local PITCH_SUB_ID = env.PITCH_SUB_ID
    local MS_GAP = env.MS_GAP
    local CMD_PITCH_TOGGLE = env.CMD_PITCH_TOGGLE
    local CMD_SPINNER_UP = env.CMD_SPINNER_UP
    local CMD_SPINNER_DOWN = env.CMD_SPINNER_DOWN
    local MODES = env.MODES
    local mode_by_id = env.mode_by_id
    local readout_width = env.readout_width
    local layout_spinner_area = env.layout_spinner_area
    local toolbar_body_h = env.toolbar_body_h
    local slide_out_layout_opts = env.slide_out_layout_opts
    local layout_multiswitch_chips = env.layout_multiswitch_chips
    local enabled_list = env.enabled_list
    local ensure_included = env.ensure_included
    local is_included = env.is_included
    local count_included = env.count_included

    function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
        if self._preview_mode then
            return nil
        end
        render_width = UTILS.asNumber(render_width, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
        ensure_included(self)
        local mx, my = coords:getRelativeMouse()
        local rw = readout_width(ctx)
        local spin_total = SPINNER.total_width(ctx, rw)

        if not is_slide_out then
            local vert = layout and layout.is_vertical
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
                    if coords:pointInRelativeRect(mx, my, minus_rect.x, minus_rect.y, minus_rect.w, minus_rect.h) then
                        return SP_PREFIX .. "minus"
                    end
                    if coords:pointInRelativeRect(mx, my, plus_rect.x, plus_rect.y, plus_rect.w, plus_rect.h) then
                        return SP_PREFIX .. "plus"
                    end

                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    local readout_rect = { x = bot_x, y = y_row2, w = rw, h = chip_h }
                    if coords:pointInRelativeRect(mx, my, readout_rect.x, readout_rect.y, readout_rect.w, readout_rect.h) then
                        return SP_PREFIX .. "readout"
                    end

                    if self._show_pitch ~= false then
                        if coords:pointInRelativeRect(mx, my, bot_x + rw + MS_GAP, y_row2, 26, chip_h) then
                            return PITCH_SUB_ID
                        end
                    end
                elseif self._show_pitch ~= false then
                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    if coords:pointInRelativeRect(mx, my, bot_x, y_row2, 26, chip_h) then
                        return PITCH_SUB_ID
                    end
                end
            else
                if self._show_spinner ~= false then
                    local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, rel_y, toolbar_body_h(layout), rw)
                    local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
                    if sp == "minus" or sp == "plus" then
                        return SP_PREFIX .. sp
                    end
                    current_x = current_x + sp_layout.spin_total + MS_GAP
                end

                if self._show_pitch ~= false then
                    local chip_h = SPINNER.chip_line_height(ctx)
                    if coords:pointInRelativeRect(mx, my, current_x, rel_y + (toolbar_body_h(layout) - chip_h) / 2, 26, chip_h) then
                        return PITCH_SUB_ID
                    end
                end
            end
            return nil
        end

        if is_slide_out then
            local list = enabled_list(self)
            local slide_opts = slide_out_layout_opts(
                self,
                ctx,
                render_width,
                self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout),
                layout
            )
            local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, list, slide_opts)
            local hit = ROW.hit_test_chips(mx, my, coords, chips, MS_PREFIX)
            if hit then
                return hit
            end
            return nil
        end

        local list = enabled_list(self)
        if #list < 1 then
            return nil
        end

        local vert = layout and layout.is_vertical

        if vert then
            local inset = ROW.button_rounding_content_pad()
            local chips, ms_outer_h = layout_multiswitch_chips(ctx, rel_x, rel_y, render_width, layout, list)
            local hit = ROW.hit_test_chips(mx, my, coords, chips, MS_PREFIX)
            if hit then
                return hit
            end
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
                local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
                if sp == "minus" or sp == "plus" then
                    return SP_PREFIX .. sp
                end
                current_x = current_x + spin_total + MS_GAP
            end

            if self._show_pitch ~= false then
                if coords:pointInRelativeRect(mx, my, current_x, extra_y, 26, SPINNER.chip_line_height(ctx)) then
                    return PITCH_SUB_ID
                end
            end
            return nil
        end

        local sp_layout = layout_spinner_area(ctx, render_width, rw, self._show_spinner, self._show_pitch, vert)
        local ms_w = render_width
        local elements_w = sp_layout.w
        if elements_w > 0 then
            ms_w = math.max(40, render_width - elements_w - MS_GAP)
        end

        local chips = layout_multiswitch_chips(ctx, rel_x, rel_y, ms_w, layout, list)
        local hit = ROW.hit_test_chips(mx, my, coords, chips, MS_PREFIX)
        if hit then
            return hit
        end

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
                    if coords:pointInRelativeRect(mx, my, minus_rect.x, minus_rect.y, minus_rect.w, minus_rect.h) then
                        return SP_PREFIX .. "minus"
                    end
                    if coords:pointInRelativeRect(mx, my, plus_rect.x, plus_rect.y, plus_rect.w, plus_rect.h) then
                        return SP_PREFIX .. "plus"
                    end

                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    local readout_rect = { x = bot_x, y = y_row2, w = rw, h = chip_h }
                    if coords:pointInRelativeRect(mx, my, readout_rect.x, readout_rect.y, readout_rect.w, readout_rect.h) then
                        return SP_PREFIX .. "readout"
                    end

                    if self._show_pitch ~= false then
                        if coords:pointInRelativeRect(mx, my, bot_x + rw + MS_GAP, y_row2, 26, chip_h) then
                            return PITCH_SUB_ID
                        end
                    end
                elseif self._show_pitch ~= false then
                    local bot_x = current_x + (elements_w - sp_layout.bot_w) / 2
                    if coords:pointInRelativeRect(mx, my, bot_x, y_row2, 26, chip_h) then
                        return PITCH_SUB_ID
                    end
                end
            else
                if self._show_spinner ~= false then
                    local minus, readout, plus = SPINNER.layout_horizontal(ctx, current_x, rel_y, toolbar_body_h(layout), rw)
                    local sp = SPINNER.hit_test(mx, my, coords, minus, readout, plus)
                    if sp == "minus" or sp == "plus" then
                        return SP_PREFIX .. sp
                    end
                    current_x = current_x + sp_layout.spin_total + MS_GAP
                end

                if self._show_pitch ~= false then
                    local chip_h = SPINNER.chip_line_height(ctx)
                    if coords:pointInRelativeRect(mx, my, current_x, rel_y + (toolbar_body_h(layout) - chip_h) / 2, 26, chip_h) then
                        return PITCH_SUB_ID
                    end
                end
            end
        end
        return nil
    end

    function widget.onSubcontrolClick(self, sub_id)
        if not sub_id then
            return false
        end
        if sub_id == PITCH_SUB_ID then
            reaper.Main_OnCommand(CMD_PITCH_TOGGLE, 0)
            return true
        end
        local ms = CHIP_HIT.strip(MS_PREFIX, sub_id)
        if ms then
            local e = mode_by_id(ms)
            if e then
                if spec.on_mode_select then
                    spec.on_mode_select(self, e)
                else
                    reaper.CSurf_OnPlayRateChange(e.rate)
                    self._play_rate = e.rate
                    self._active_ms_id = e.id
                end
                return true
            end
            return false
        end
        local sp = CHIP_HIT.strip(SP_PREFIX, sub_id)
        if sp == "minus" then
            reaper.Main_OnCommand(CMD_SPINNER_DOWN, 0)
            return true
        end
        if sp == "plus" then
            reaper.Main_OnCommand(CMD_SPINNER_UP, 0)
            return true
        end
        if sp == "readout" and SPINNER_OVERLAY then
            local live = SPINNER_OVERLAY.get_live_rate and SPINNER_OVERLAY.get_live_rate()
                or UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
            if SPINNER_OVERLAY.rate_to_display then
                self._st_buf = SPINNER_OVERLAY.rate_to_display(live)
            end
            self._st_overlay_focused = true
            return true
        end
        return false
    end

    function widget.onSettingsMenu(self, ctx, button)
        ensure_included(self)
        local rows = {}
        rows[#rows + 1] = {
            label = "Show Semitone Spinner",
            get = function(h)
                if h._show_spinner == nil then
                    return true
                end
                return h._show_spinner
            end,
            set = function(h, v)
                h._show_spinner = v
            end,
        }
        rows[#rows + 1] = {
            label = "Show Preserve Pitch",
            get = function(h)
                if h._show_pitch == nil then
                    return true
                end
                return h._show_pitch
            end,
            set = function(h, v)
                h._show_pitch = v
            end,
        }
        for _, entry in ipairs(MODES) do
            local e = entry
            rows[#rows + 1] = {
                label = UTILS.formatWidgetValue(self, e.rate),
                get = function(h)
                    return is_included(h, e)
                end,
                set = function(h, v)
                    h._included[e.id] = v
                end,
            }
        end
        VIS.draw_checkbox_list(ctx, button, self, {
            title = spec.settings_title or (spec.name .. " Options"),
            rows = rows,
            total_visible = count_included,
        })
    end
end
