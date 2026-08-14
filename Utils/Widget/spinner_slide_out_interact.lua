-- Utils/Widget/spinner_slide_out_interact.lua

local ROW = require("Utils.Chips.chip_row")
local BASE = require("Utils.Widget.chip_widget_base")
local VIS = require("Utils.Widget.widget_visibility")

return function(widget, spec, env)
    local MS_PREFIX = env.MS_PREFIX
    local SP_PREFIX = env.SP_PREFIX
    local PITCH_SUB_ID = env.PITCH_SUB_ID
    local MS_GAP = env.MS_GAP
    local CMD_PITCH_TOGGLE = env.CMD_PITCH_TOGGLE
    local CMD_SPINNER_UP = env.CMD_SPINNER_UP
    local CMD_SPINNER_DOWN = env.CMD_SPINNER_DOWN
    local SPINNER_OVERLAY = env.SPINNER_OVERLAY
    local MODES = env.MODES
    local mode_by_id = env.mode_by_id
    local readout_width = env.readout_width
    local slide_out_layout_opts = env.slide_out_layout_opts
    local enabled_list = env.enabled_list
    local ensure_included = env.ensure_included
    local is_included = env.is_included
    local count_included = env.count_included

    local compute_toolbar_spinner_layout = env.compute_toolbar_spinner_layout
    local hit_toolbar_spinner_layout = env.hit_toolbar_spinner_layout

    function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
        if self._preview_mode then
            return nil
        end
        render_width = UTILS.asNumber(render_width, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
        ensure_included(self)
        local mx, my = coords:getRelativeMouse()
        local rw = readout_width(ctx)

        if not is_slide_out then
            local vert = layout and layout.is_vertical
            local tb = compute_toolbar_spinner_layout(ctx, self, rel_x, rel_y, render_width, layout, rw, MS_GAP)
            return hit_toolbar_spinner_layout(coords, mx, my, tb, SP_PREFIX, PITCH_SUB_ID)
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
        local ms = BASE.strip_click_id(MS_PREFIX, sub_id)
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
        local sp = BASE.strip_click_id(SP_PREFIX, sub_id)
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
