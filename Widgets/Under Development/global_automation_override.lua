local WIDGET = require("Utils.Widget.widget_factory")
local OPT = WIDGET.OPTIONS_SLIDE_OUT

local TOGGLE_PAD_H = 10
local TOGGLE_CHIP_SIDE_PAD = 8
local ICON_NAME_GAP = 4
local AUTOMATION_ICON_PATH = "icons/Automation/Automation.ttf"
local AUTOMATION_ICON_CHAR = utf8.char(WIDGET.ICON_FONTS.ICON_CODEPOINT)

local function automation_icon_bundle()
    return OPT.resolve_icon(AUTOMATION_ICON_PATH)
end

-- Toolbar toggle chip labels (longest → shortest). Slide-out multiswitch uses MODES as-is.
local TOGGLE_NAMES = {
    trim = { full = "Trim", short = "Trim", glyph = "Tr" },
    read = { full = "Read", short = "Read", glyph = "R" },
    touch = { full = "Touch", short = "Touch", glyph = "T" },
    latch = { full = "Latch", short = "Latch", glyph = "L" },
    latch_preview = { full = "Preview", short = "L.Prev", glyph = "LP" },
    write = { full = "Write", short = "Write", glyph = "W" },
}

local MODES = {
    { id = "trim", short_label = "Trim", label = "Trim/Read", api = 0 },
    { id = "read", label = "Read", api = 1 },
    { id = "touch", label = "Touch", api = 2 },
    { id = "latch", label = "Latch", api = 4 },
    { id = "latch_preview", short_label = "L.Prev", label = "Latch preview", api = 6 },
    { id = "write", label = "Write", api = 3 },
}
WIDGET.CHIP_MS.normalize_chip_entries(MODES)

local function toggle_label_candidates(mode_id, is_on)
    if not is_on then
        return { "Off" }
    end
    local names = TOGGLE_NAMES[mode_id] or TOGGLE_NAMES.read
    return {
        "On - " .. names.full,
        names.full,
        names.short,
        names.glyph,
    }
end

local function pick_label_for_width(ctx, candidates, max_text_w)
    if not ctx or not reaper.ImGui_CalcTextSize or max_text_w <= 0 then
        return candidates[1]
    end
    for i = 1, #candidates do
        local label = candidates[i]
        if (reaper.ImGui_CalcTextSize(ctx, label) or 0) <= max_text_w then
            return label
        end
    end
    return candidates[#candidates]
end

local function get_active_mode_id(self)
    local api = self._api_mode
    if api == 5 then
        return self._preferred_mode_id
    end
    if api ~= nil and api ~= -1 then
        for _, m in ipairs(MODES) do
            if m.api == api then
                return m.id
            end
        end
    end
    return self._preferred_mode_id
end

local function toggle_chip_layout(self, ctx, render_width)
    local R = WIDGET.CHIP_ROW.button_rounding_content_pad()
    local side_pad = TOGGLE_CHIP_SIDE_PAD + R * 2
    local avail_w = math.max(44 + TOGGLE_PAD_H * 2, (render_width or self.width or 128) - side_pad)
    local is_on = self._api_mode ~= -1
    local mode_id = get_active_mode_id(self)
    local candidates = toggle_label_candidates(mode_id, is_on)
    local extra_icon = (not is_on) and OPT.icon_column_width(ctx, automation_icon_bundle(), ICON_NAME_GAP) or 0
    local text_w = avail_w - TOGGLE_PAD_H * 2 - extra_icon
    local label = pick_label_for_width(ctx, candidates, text_w)
    local natural = WIDGET.CHIP_ROW.toolbar_chip_width(ctx, label, { pad_h = TOGGLE_PAD_H, min_w = 44 })
    if extra_icon > 0 then
        natural = natural + extra_icon
    end
    local chip_w = math.min(natural, avail_w)
    return label, chip_w, side_pad
end

local APPLY_BY_MODE_ID = {
    trim = function()
        reaper.SetGlobalAutomationOverride(0)
    end,
    read = function()
        reaper.SetGlobalAutomationOverride(1)
    end,
    touch = function()
        reaper.SetGlobalAutomationOverride(2)
    end,
    write = function()
        reaper.SetGlobalAutomationOverride(3)
    end,
    latch = function()
        reaper.SetGlobalAutomationOverride(4)
    end,
    latch_preview = function()
        reaper.SetGlobalAutomationOverride(6)
    end,
}

return WIDGET.Segmented(OPT.with_slide_out({
    name = "Global Automation",
    category = "Under Development",
    update_interval = 0.12,
    description = "Toggle global automation override (per-track vs project-wide). Off = no override. On = apply the mode chosen in the slide-out multiswitch.",
    width = 128,
    getLayoutWidth = function(self, ctx, is_vertical_toolbar)
        if not ctx or is_vertical_toolbar then
            return self.width or 128
        end
        local _, chip_w, side_pad = toggle_chip_layout(self, ctx, 9999)
        return WIDGET.CHIP_ROW.apply_preview_width_cap(self, math.max(self.width or 0, chip_w + side_pad))
    end,
    state = {
        _preferred_mode_id = "read",
        _api_mode = -1,
    },
    on_update = function(self)
        local api = reaper.GetGlobalAutomationOverride()
        self._api_mode = api
        if api == nil or api == -1 or api == 5 then
            return
        end
        for _, m in ipairs(MODES) do
            if m.api == api then
                self._preferred_mode_id = m.id
                return
            end
        end
    end,
    rows = {
        OPT.host_toggle_row({
            type = "toggle",
            get_label = function(self, ctx, chip_w)
                if self._ga_toggle_label then
                    return self._ga_toggle_label
                end
                local label = toggle_chip_layout(self, ctx, (chip_w or 0) + TOGGLE_CHIP_SIDE_PAD * 2)
                return label
            end,
            get_width = function(self, ctx, render_width)
                self._ga_toggle_label = nil
                local label, chip_w = toggle_chip_layout(self, ctx, render_width)
                self._ga_toggle_label = label
                return chip_w
            end,
            min_width = 44 + TOGGLE_PAD_H * 2,
            get_state = function(self)
                return self._api_mode ~= -1
            end,
            on_click = function(self)
                if self._api_mode == -1 then
                    local fn = APPLY_BY_MODE_ID[get_active_mode_id(self)]
                    if fn then
                        fn()
                    end
                else
                    reaper.SetGlobalAutomationOverride(-1)
                end
            end,
            render_custom_chip = function(self, ctx, coords, draw_list, rect, label, hover, btn_txt, btn_bg, toolbar_txt, toolbar_bg)
                local is_on = self._api_mode ~= -1
                local interval = (CONFIG and CONFIG.UI and CONFIG.UI.FLASH_INTERVAL) or 0.5
                local flash = is_on and (math.floor(reaper.time_precise() / (interval / 2)) % 2 == 0)

                if flash then
                    WIDGET.DRAWING.drawChipBackground(coords, draw_list, rect.x, rect.y, rect.w, rect.h, toolbar_bg, {
                        rounding = WIDGET.CHIP_ROW.CHIP_ROUND,
                        border_color = toolbar_txt,
                    })
                    WIDGET.DRAWING.drawCenteredText(ctx, coords, draw_list, rect.x, rect.y, rect.w, rect.h, label, toolbar_txt, 0)
                    return
                end

                OPT.draw_icon_leading_toggle(ctx, coords, draw_list, rect, label, hover, btn_txt, btn_bg, {
                    active = is_on,
                    hover = hover,
                    icon_bundle = automation_icon_bundle(),
                    icon_char = AUTOMATION_ICON_CHAR,
                    show_icon = not is_on,
                    icon_gap = ICON_NAME_GAP,
                    alpha_factor = self._slide_alpha_factor,
                })
            end,
        }),
        OPT.slide_multiswitch(MODES, get_active_mode_id, function(_self, chip_id)
            local fn = APPLY_BY_MODE_ID[chip_id]
            if fn then
                fn()
            end
        end, { rows = 2 }),
    },
}))
