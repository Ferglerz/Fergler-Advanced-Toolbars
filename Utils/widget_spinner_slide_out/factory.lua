-- Utils/widget_spinner_slide_out/factory.lua

local ROW = require("Utils.Chips.chip_row")
local SPINNER = require("Utils.Chips.chip_spinner")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local BASE = require("Utils.Widget.chip_widget_base")

local defaults_mod = require("Utils.widget_spinner_slide_out.defaults")
local attach_state = require("Utils.widget_spinner_slide_out.state")
local attach_slide_out = require("Utils.widget_spinner_slide_out.slide_out")
local attach_preview = require("Utils.widget_spinner_slide_out.preview")
local attach_interactions = require("Utils.widget_spinner_slide_out.interactions")
local attach_draw = require("Utils.widget_spinner_slide_out.draw")

return function(M)
    local defaults = defaults_mod()

    function M.new(spec)
        local MODES = spec.modes or {}
        CHIP_MS.normalize_chip_entries(MODES)

        local WID = defaults.default_widget_id(spec)
        local MS_PREFIX = spec.ms_prefix or (WID .. "_ms_")
        local SP_PREFIX = spec.sp_prefix or (WID .. "_sp_")
        local PITCH_SUB_ID = spec.pitch_sub_id or (WID .. "_pitch")
        local MS_GAP = spec.ms_gap or 6
        local MIN_CHIP = spec.min_chip_w or 22
        local PREVIEW_IDS = spec.preview_ids or defaults.default_preview_ids(MODES)
        local CMD_SPINNER_UP = spec.cmd_spinner_up
        local CMD_SPINNER_DOWN = spec.cmd_spinner_down
        local CMD_PITCH_TOGGLE = spec.cmd_pitch_toggle
        local SLIDE_NAMESPACE = spec.slide_namespace or (WID .. "_ms")
        local PREVIEW_NAMESPACE = spec.preview_namespace or (WID .. "_prev")
        local PREVIEW_SELECTED_ID = spec.preview_selected_id or defaults.default_preview_selected_id(MODES)
        local PREVIEW_TITLE = spec.preview_title or (spec.name or "Presets")
        local PITCH_ICON = spec.pitch_icon or "icons/Music/Tuning Fork.ttf"
        local SPINNER_OVERLAY = spec.spinner_overlay

        local function mode_by_id(id)
            return BASE.mode_by_id(MODES, id)
        end

        local readout_width = spec.readout_width or defaults.default_readout_width

        local function resolve_active_preset_id(self, play_rate, list)
            if spec.active_preset_id then
                return spec.active_preset_id(self, play_rate, list)
            end
            play_rate = UTILS.asNumber(play_rate, nil)
            if not play_rate or not list or #list < 1 then
                return nil
            end
            local best_e, best_d
            for _, e in ipairs(list) do
                local er = UTILS.asNumber(e.rate, nil)
                if er then
                    local d = math.abs(play_rate - er)
                    if best_d == nil or d < best_d or (best_e and math.abs(d - best_d) < 1e-9 and er < best_e.rate) then
                        best_d = d
                        best_e = e
                    end
                end
            end
            if best_e and type(best_d) == "number" and best_d < 0.11 then
                return best_e.id
            end
            return nil
        end

        local function layout_spinner_area(ctx, render_width, rw, show_spinner, show_pitch, is_vertical)
            return M.layout_spinner_area(ctx, render_width, rw, show_spinner, show_pitch, is_vertical, MS_GAP)
        end

        local env = {
            M = M,
            MODES = MODES,
            WID = WID,
            MS_PREFIX = MS_PREFIX,
            SP_PREFIX = SP_PREFIX,
            PITCH_SUB_ID = PITCH_SUB_ID,
            MS_GAP = MS_GAP,
            MIN_CHIP = MIN_CHIP,
            PREVIEW_IDS = PREVIEW_IDS,
            CMD_SPINNER_UP = CMD_SPINNER_UP,
            CMD_SPINNER_DOWN = CMD_SPINNER_DOWN,
            CMD_PITCH_TOGGLE = CMD_PITCH_TOGGLE,
            SLIDE_NAMESPACE = SLIDE_NAMESPACE,
            PREVIEW_NAMESPACE = PREVIEW_NAMESPACE,
            PREVIEW_SELECTED_ID = PREVIEW_SELECTED_ID,
            PREVIEW_TITLE = PREVIEW_TITLE,
            PITCH_ICON = PITCH_ICON,
            SPINNER_OVERLAY = SPINNER_OVERLAY,
            mode_by_id = mode_by_id,
            readout_width = readout_width,
            resolve_active_preset_id = resolve_active_preset_id,
            layout_spinner_area = layout_spinner_area,
            toolbar_body_h = M._toolbar_body_h,
        }

        local widget = BASE.apply_base_widget(spec, {
            update_interval = 0.05,
            default_width = 280,
            extra = {
                _included = nil,
                _show_spinner = true,
                _show_pitch = true,
                _slide_out_mode = true,
                _play_rate = 1.0,
                _active_ms_id = nil,
                _open_rates_context = false,
                _st_buf = nil,
                _st_overlay_focused = false,
                _sp_readout_rel = nil,
                _pitch_rel = nil,
                _sp_readout_screen = nil,
            },
        })

        if spec.format then
            widget.format = spec.format
        end
        if spec.col_primary then
            widget.col_primary = spec.col_primary
        end

        for k, v in pairs(spec.state or {}) do
            widget[k] = v
        end

        attach_state(widget, spec, env)
        attach_slide_out(widget, spec, env)
        attach_preview(widget, spec, env)
        attach_interactions(widget, spec, env)
        attach_draw(widget, spec, env)

        local enabled_list = env.enabled_list
        local ensure_included = env.ensure_included
        local count_included = env.count_included
        local horizontal_multiswitch_cols = env.horizontal_multiswitch_cols
        local multiswitch_block_height = env.multiswitch_block_height

        function widget.getLayoutWidth(self, ctx)
            if not ctx or not reaper.ImGui_CalcTextSize then
                return math.max(120, self.width or 280)
            end
            ensure_included(self)
            if not self._preview_mode then
                local rw = readout_width(ctx)
                local elements_w = 0
                if self._show_spinner ~= false then
                    elements_w = elements_w + SPINNER.total_width(ctx, rw)
                end
                if self._show_pitch ~= false then
                    elements_w = elements_w + (elements_w > 0 and MS_GAP or 0) + 26
                end
                local inset = ROW.button_rounding_content_pad()
                local pad = (4 * 2) + inset * 2
                return ROW.apply_preview_width_cap(self, math.max(40, math.ceil(elements_w + pad)))
            end
            local n = count_included(self)
            if n < 1 then
                n = 1
            end
            local cols = horizontal_multiswitch_cols(ctx, n)
            local preview_list = enabled_list(self)
            if #preview_list < 1 then
                preview_list = MODES
            end
            local ms_w = ROW.uniform_multiswitch_width(ctx, preview_list, cols, env.multiswitch_layout_opts())
            local total = ms_w
            if self._show_spinner ~= false then
                local rw = readout_width(ctx)
                local spin_w = SPINNER.total_width(ctx, rw)
                total = total + MS_GAP + spin_w
            end
            if self._show_pitch ~= false then
                total = total + MS_GAP + 26
            end
            return ROW.apply_preview_width_cap(self, math.max(100, math.ceil(total)))
        end

        function widget.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar)
            if not is_vertical_toolbar or not ctx then
                return CONFIG.SIZES.HEIGHT
            end
            if not self._preview_mode then
                local iw = UTILS.asNumber(inner_w, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
                local rw = readout_width(ctx)
                local sp_layout = layout_spinner_area(ctx, iw, rw, self._show_spinner, self._show_pitch, true)
                if sp_layout.stacked then
                    local chip_h = SPINNER.chip_line_height(ctx)
                    local inset = ROW.button_rounding_content_pad()
                    return math.max(CONFIG.SIZES.HEIGHT or 28, chip_h * 2 + 2 + inset * 2)
                end
                return CONFIG.SIZES.HEIGHT
            end
            ensure_included(self)
            local n = count_included(self)
            if n < 1 then
                n = 1
            end
            local iw = UTILS.asNumber(inner_w, nil) or UTILS.asNumber(self.width, nil) or CONFIG.SIZES.MIN_WIDTH or 100
            local ms_h = multiswitch_block_height(ctx, n, true, iw)
            local inset = ROW.button_rounding_content_pad()
            if self._show_spinner ~= false or self._show_pitch ~= false then
                local rw = readout_width(ctx)
                local sp_layout = layout_spinner_area(ctx, iw, rw, self._show_spinner, self._show_pitch, true)
                if sp_layout.stacked then
                    local chip_h = SPINNER.chip_line_height(ctx)
                    local total_h = chip_h * 2 + 2
                    return math.max(CONFIG.SIZES.HEIGHT or 28, ms_h + ROW.CHIP_GAP + total_h + 4 + inset)
                else
                    local sh = SPINNER.chip_line_height(ctx)
                    return math.max(CONFIG.SIZES.HEIGHT or 28, ms_h + ROW.CHIP_GAP + sh + 4 + inset)
                end
            end
            return math.max(CONFIG.SIZES.HEIGHT or 28, ms_h + 4 + inset)
        end

        BASE.apply_spec_overrides(widget, spec, {
            "renderCustom",
            "hitTestSubcontrols",
            "onSubcontrolClick",
            "getLayoutWidth",
            "getLayoutHeight",
            "getValue",
            "onSettingsMenu",
            "applyPersistedOptions",
            "exportPersistedOptions",
            "onWidgetFrame",
        })

        return widget
    end
end
