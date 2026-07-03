-- Widgets/playback_rate_knob.lua
local WIDGET = require("Utils.widget_factory")

local snap_decimals = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0}
local snap_semitones = {}
for i = -24, 24 do
    table.insert(snap_semitones, math.max(0.25, math.min(4.0, 2^(i/12))))
end

local CHIP_W = 26
local CHIP_GAP = 6

local widget = {
    name = "Playback Rate (Knob)",
    category = "Time, grid & tempo",
    type = "slider",
    slider_style = "simple_knob",
    knob_bg_direction = "left",
    width = 84,
    fixed_width = true,
    min_value = 0.25,
    max_value = 4.0,
    default_value = 1.0,
    title = "Rate",
    description = "Master play rate knob. Right-click to toggle Semitone snapping.",
    snap_points = snap_decimals,
    fine_scale = 0.1,
    update_interval = 0.05,
    _use_semitones = false,
    _show_pitch = true,
    _open_context = false,

    applyPersistedOptions = function(self, opts)
        if type(opts) == "table" then
            if type(opts.use_semitones) == "boolean" then
                self._use_semitones = opts.use_semitones
            end
            if type(opts.show_pitch) == "boolean" then
                self._show_pitch = opts.show_pitch
            end
        end
        self.snap_points = self._use_semitones and snap_semitones or snap_decimals
    end,

    exportPersistedOptions = function(self)
        return { use_semitones = self._use_semitones, show_pitch = self._show_pitch }
    end,

    format = function(value)
        return string.format("%.0f%%", value * 100)
    end,

    getLayoutWidth = function(self, ctx, is_vertical_toolbar)
        local w = self.width or 84
        local chips = {}
        if self._show_pitch ~= false then
            table.insert(chips, { id = "pr_pitch", w = CHIP_W, h = WIDGET.SPINNER.chip_line_height(ctx) })
        end
        return WIDGET.KNOB_LAYOUT.get_width(w, chips)
    end,

    getLayoutHeight = function(self, ctx, inner_w, is_vertical_toolbar)
        local h = CONFIG.SIZES.HEIGHT
        if self._show_pitch ~= false and is_vertical_toolbar then
            h = h + CHIP_GAP + WIDGET.SPINNER.chip_line_height(ctx)
        end
        return h
    end,

    hitTestSubcontrols = function(self, ctx, coords, rel_x, rel_y, render_width, layout)
        if self._show_pitch == false then return nil end
        local mx, my = coords:getRelativeMouse()
        local chips_info = {}
        local chip_line_h = WIDGET.SPINNER.chip_line_height(ctx)
        
        if layout and layout.is_vertical then
            local pt_rect = {
                x = rel_x + (render_width - CHIP_W) / 2,
                y = rel_y + CONFIG.SIZES.HEIGHT + CHIP_GAP,
                w = CHIP_W,
                h = chip_line_h
            }
            if coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h) then
                return "pr_pitch"
            end
            return nil
        else
            table.insert(chips_info, { id = "pr_pitch", w = CHIP_W, h = chip_line_h })
            local _, chips = WIDGET.KNOB_LAYOUT.layout(rel_x, rel_y, render_width, self.knob_bg_direction, chips_info)
            for _, c in ipairs(chips) do
                if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
                    return c.id
                end
            end
        end
        return nil
    end,

    onSubcontrolClick = function(self, sub_id)
        if sub_id == "pr_pitch" then
            reaper.Main_OnCommand(40671, 0)
            return true
        end
        return false
    end,

    renderCustom = function(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local bg_only = self._edit_bg_only == true
        local preview = self._preview_mode == true
        local chips_info = {}
        local chip_line_h = WIDGET.SPINNER.chip_line_height(ctx)
        
        if layout and layout.is_vertical then
            WIDGET_ELEMENTS.knob(ctx, self, coords, draw_list, rel_x, rel_y, render_width, CONFIG.SIZES.HEIGHT, text_color, bg_color, false, preview, "simple_knob", bg_only)
            
            if not bg_only and self._show_pitch ~= false then
                local st_pitch = reaper.GetToggleCommandState(40671) == 1
                local pt_rect = {
                    x = rel_x + (render_width - CHIP_W) / 2,
                    y = rel_y + CONFIG.SIZES.HEIGHT + CHIP_GAP,
                    w = CHIP_W,
                    h = chip_line_h
                }
                local mx, my = coords:getRelativeMouse()
                local pt_hit = coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h)
                local icon_mode = WIDGET.ICON_FONTS.resolveToolbarIcon("icons/Music/Tuning Fork.ttf")
                WIDGET.DRAWING.drawWidgetPillIconChip(ctx, coords, draw_list, pt_rect, text_color, bg_color, {
                    active = st_pitch,
                    hover = pt_hit,
                    filled = true,
                    icon_mode = icon_mode,
                    icon_char = utf8.char(WIDGET.ICON_FONTS.ICON_CODEPOINT),
                    icon_sz = pt_rect.h * 0.8,
                    text = "P",
                    rounding = WIDGET.CHIP_ROW.CHIP_ROUND
                })
            end
        else
            if not bg_only and self._show_pitch ~= false then
                table.insert(chips_info, { id = "pr_pitch", w = CHIP_W, h = chip_line_h })
            end
            local knob_rect, chips = WIDGET.KNOB_LAYOUT.layout(rel_x, rel_y, render_width, self.knob_bg_direction, chips_info)
            
            WIDGET_ELEMENTS.knob(ctx, self, coords, draw_list, knob_rect.x, knob_rect.y, knob_rect.w, CONFIG.SIZES.HEIGHT, text_color, bg_color, false, preview, "simple_knob", bg_only)
            
            if not bg_only and self._show_pitch ~= false then
                local st_pitch = reaper.GetToggleCommandState(40671) == 1
                local mx, my = coords:getRelativeMouse()
                for _, c in ipairs(chips) do
                    if c.id == "pr_pitch" then
                        local pt_hit = coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h)
                        local icon_mode = WIDGET.ICON_FONTS.resolveToolbarIcon("icons/Music/Tuning Fork.ttf")
                        WIDGET.DRAWING.drawWidgetPillIconChip(ctx, coords, draw_list, c, text_color, bg_color, {
                            active = st_pitch,
                            hover = pt_hit,
                            filled = true,
                            icon_mode = icon_mode,
                            icon_char = utf8.char(WIDGET.ICON_FONTS.ICON_CODEPOINT),
                            icon_sz = c.h * 0.8,
                            text = "P",
                            rounding = WIDGET.CHIP_ROW.CHIP_ROUND
                        })
                    end
                end
            end
        end
    end,

    onSettingsMenu = function(self, ctx, button)
        reaper.ImGui_TextDisabled(ctx, "Playback Rate Options")
        reaper.ImGui_Spacing(ctx)
        
        local changed = false
        local ch, new_semitones = reaper.ImGui_Checkbox(ctx, "Snap to Semitones", self._use_semitones)
        if ch then
            self._use_semitones = new_semitones
            self.snap_points = self._use_semitones and snap_semitones or snap_decimals
            changed = true
        end

        local ch2, new_pitch = reaper.ImGui_Checkbox(ctx, "Show Pitch Chip", self._show_pitch ~= false)
        if ch2 then
            self._show_pitch = new_pitch
            changed = true
        end

        if changed then
            WIDGET.OPT_POPUP.commit_dynamic_widget_layout(button, ctx)
        end
    end,
    
    col_primary = function()
        local rate = UTILS.asNumber(reaper.Master_GetPlayRate(0), nil)
        if rate and math.abs(rate - 1.0) > 0.0001 then
            return reaper.GetThemeColor("playrate_edited", 0)
        end
        return nil
    end,

    getValue = function()
        return UTILS.asNumber(reaper.Master_GetPlayRate(0), 1.0)
    end,

    setValue = function(value)
        reaper.CSurf_OnPlayRateChange(value)
    end
}

return widget
