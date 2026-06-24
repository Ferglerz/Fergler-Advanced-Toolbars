-- Widgets/playback_rate_knob.lua
local OPT = require("Utils.widget_options_popup")
local SPINNER = require("Utils.chip_spinner")
local KNOB_LAYOUT = require("Utils.knob_layout")

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
    width = 54,
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
        local w = self.width or 54
        local chips = {}
        if self._show_pitch ~= false then
            table.insert(chips, { id = "pr_pitch", w = CHIP_W, h = SPINNER.chip_line_height(ctx) })
        end
        return KNOB_LAYOUT.get_width(w, chips)
    end,

    getLayoutHeight = function(self, ctx, inner_w, is_vertical_toolbar)
        local h = CONFIG.SIZES.HEIGHT
        if self._show_pitch ~= false and is_vertical_toolbar then
            h = h + CHIP_GAP + SPINNER.chip_line_height(ctx)
        end
        return h
    end,

    hitTestSubcontrols = function(self, ctx, coords, rel_x, rel_y, render_width, layout)
        if self._show_pitch == false then return nil end
        local mx, my = coords:getRelativeMouse()
        local chips_info = {}
        local chip_line_h = SPINNER.chip_line_height(ctx)
        
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
            local _, chips = KNOB_LAYOUT.layout(rel_x, rel_y, render_width, self.knob_bg_direction, chips_info)
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
        local simple_knob_renderer = require("Renderers._Widgets_simple_knob")
        
        local chips_info = {}
        local chip_line_h = SPINNER.chip_line_height(ctx)
        
        if layout and layout.is_vertical then
            simple_knob_renderer(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color, false)
            
            if self._show_pitch ~= false then
                local st_pitch = reaper.GetToggleCommandState(40671) == 1
                local pt_rect = {
                    x = rel_x + (render_width - CHIP_W) / 2,
                    y = rel_y + CONFIG.SIZES.HEIGHT + CHIP_GAP,
                    w = CHIP_W,
                    h = chip_line_h
                }
                local mx, my = coords:getRelativeMouse()
                local pt_hit = coords:pointInRelativeRect(mx, my, pt_rect.x, pt_rect.y, pt_rect.w, pt_rect.h)
                SPINNER.draw_segment(ctx, coords, draw_list, pt_rect, "P", text_color, bg_color, pt_hit, st_pitch)
            end
        else
            if self._show_pitch ~= false then
                table.insert(chips_info, { id = "pr_pitch", w = CHIP_W, h = chip_line_h })
            end
            local knob_rect, chips = KNOB_LAYOUT.layout(rel_x, rel_y, render_width, self.knob_bg_direction, chips_info)
            
            simple_knob_renderer(ctx, self, knob_rect.x, knob_rect.y, knob_rect.w, coords, draw_list, text_color, bg_color, false)
            
            if self._show_pitch ~= false then
                local st_pitch = reaper.GetToggleCommandState(40671) == 1
                local mx, my = coords:getRelativeMouse()
                for _, c in ipairs(chips) do
                    if c.id == "pr_pitch" then
                        local pt_hit = coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h)
                        SPINNER.draw_segment(ctx, coords, draw_list, c, "P", text_color, bg_color, pt_hit, st_pitch)
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
            OPT.commit_dynamic_widget_layout(button, ctx)
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
