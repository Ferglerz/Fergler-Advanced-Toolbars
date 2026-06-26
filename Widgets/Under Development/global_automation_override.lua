-- Widgets/Under Development/global_automation_override.lua
-- Global automation override: On/Off chip plus mode chip with popup (REAPER Options → Global automation override).

local TOGGLE_PAD_H = 10
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_ROW = require("Renderers.Widgets.chip_row")
local FLEX_LAYOUT = require("Utils.flex_layout")
local DRAWING = require("Utils.drawing")

local PREFIX_MS = "gao_ms_"
local MIN_CHIP = 28

local MODES = {
    { id = "trim", short_label = "Trim", label = "Trim/Read", api = 0 },
    { id = "read", label = "Read", api = 1 },
    { id = "touch", label = "Touch", api = 2 },
    { id = "latch", label = "Latch", api = 4 },
    { id = "latch_preview", short_label = "L.Prev", label = "Latch preview", api = nil },
    { id = "write", label = "Write", api = 3 },
}

CHIP_MS.normalize_chip_entries(MODES)

local widget = {
    name = "Global Automation Override",
    category = "Under Development",
    update_interval = 0.12,
    type = "display",
    width = 128,
    label = "",
    description = "Toggle global automation override (per-track vs project-wide). Off = no override. On = apply the mode chosen in the slide-out multiswitch (right-click for settings).",
    chip_widget = true,
    _slide_out_mode = true,
    _preferred_mode_id = "read",
    _api_mode = -1,
}

local function mode_by_id(id)
    return UTILS.findById(MODES, id)
end

-- Same timing as Managers.Button armed flash (CONFIG.UI.FLASH_INTERVAL).
local function override_flash_toolbar_mimic_phase()
    local interval = (CONFIG and CONFIG.UI and CONFIG.UI.FLASH_INTERVAL) or 0.5
    return math.floor(reaper.time_precise() / (interval / 2)) % 2 == 0
end

-- Dispatch matches REAPER Get/SetGlobalAutomationOverride (latch preview uses main action).
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
        reaper.Main_OnCommand(42022, 0)
    end,
}

local function apply_global_mode(mode_id)
    local fn = APPLY_BY_MODE_ID[mode_id]
    if fn then
        fn()
    end
end

local function sync_preferred_from_api(self, api)
    if api == nil or api == -1 or api == 5 then
        return
    end
    if api == 6 then
        self._preferred_mode_id = "latch_preview"
        return
    end
    for _, m in ipairs(MODES) do
        if m.api == api then
            self._preferred_mode_id = m.id
            return
        end
    end
end

function widget.getValue(self)
    local api = reaper.GetGlobalAutomationOverride()
    self._api_mode = api
    sync_preferred_from_api(self, api)
    return api
end

local function active_mode_id(self)
    local api = self._api_mode
    if api == 5 then
        return self._preferred_mode_id
    end
    if api == 6 then
        return "latch_preview"
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

local function toggle_chip_label(self)
    if self._api_mode == -1 then
        return "Off"
    end
    local mode = mode_by_id(active_mode_id(self))
    local name = mode and CHIP_MS.chip_caption(mode) or "Read"
    return "On - " .. name
end

local function toggle_chip_width(ctx)
    local max_tw = 0
    local function measure(text)
        local tw = reaper.ImGui_CalcTextSize(ctx, text) or 0
        if tw > max_tw then
            max_tw = tw
        end
    end
    measure("Off")
    for _, m in ipairs(MODES) do
        measure("On - " .. CHIP_MS.chip_caption(m))
    end
    return math.max(44, max_tw + TOGGLE_PAD_H * 2)
end

local function layout_toolbar_toggle(ctx, rel_x, rel_y, render_width, layout)
    local h = CHIP_ROW.widget_body_height(layout)
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_ROW.CHIP_V_PAD * 2
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    local toggle_w = toggle_chip_width(ctx)
    local inner_w = math.max(10, render_width - pad_x * 2)
    local x = rel_x + pad_x + math.max(0, (inner_w - toggle_w) / 2)
    local y = rel_y + (h - chip_h) / 2
    return { id = "toggle_override", x = x, y = y, w = toggle_w, h = chip_h }, chip_h
end

local function layout_mode_multiswitch(self, ctx, rel_x, rel_y, render_width, slide_height, layout)
    local rows = (self._slide_out_plan and self._slide_out_plan.rows) or 2
    return CHIP_ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, MODES, {
        pad_x = 4,
        rows = rows,
        height = slide_height,
    })
end

local function layout_chips(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out then
        local h = self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout)
        local chips = layout_mode_multiswitch(self, ctx, rel_x, rel_y, render_width, h, layout)
        return nil, chips, CHIP_ROW.chip_line_height(ctx)
    end

    local is_vertical = layout and layout.is_vertical
    if self._slide_out_mode and not is_vertical then
        local toggle, chip_h = layout_toolbar_toggle(ctx, rel_x, rel_y, render_width, layout)
        return toggle, nil, chip_h
    end

    local h = CHIP_ROW.widget_body_height(layout)
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_ROW.CHIP_V_PAD * 2
    local R = CHIP_ROW.button_rounding_content_pad()
    local toggle_w = toggle_chip_width(ctx)
    local pad_x = 4 + R
    local inner_w = math.max(10, render_width - pad_x * 2)
    local max_w = is_vertical and inner_w or 99999

    local groups = {
        { { id = "toggle_override", w = toggle_w, h = chip_h } },
    }

    local lines = FLEX_LAYOUT.wrap_groups(groups, max_w, CHIP_ROW.CHIP_GAP, CHIP_ROW.CHIP_GAP)
    local total_h = #lines * chip_h + (#lines - 1) * CHIP_ROW.CHIP_GAP
    local start_y = rel_y + (h - total_h) / 2

    local toggle
    local y = start_y
    for _, line in ipairs(lines) do
        local x = rel_x + pad_x
        local remaining_w = inner_w
        for _, it in ipairs(line.items) do
            remaining_w = remaining_w - it.w - CHIP_ROW.CHIP_GAP
        end
        remaining_w = remaining_w + CHIP_ROW.CHIP_GAP
        for _, it in ipairs(line.items) do
            local w = it.w
            if remaining_w > 0 then
                w = w + remaining_w
                remaining_w = 0
            end
            it.x = x
            it.y = y
            it.w = w
            toggle = it
            x = x + w + CHIP_ROW.CHIP_GAP
        end
        y = y + chip_h + CHIP_ROW.CHIP_GAP
    end

    return toggle, nil, chip_h
end

function widget.getLayoutWidth(self, ctx, is_vertical_toolbar)
    if not ctx or not reaper.ImGui_CalcTextSize then
        return math.max(96, self.width or 128)
    end
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad = (4 + R) * 2
    if self._slide_out_mode and not is_vertical_toolbar then
        return math.max(56, math.ceil(toggle_chip_width(ctx) + pad))
    end
    local toggle_w = toggle_chip_width(ctx)
    local mode_min = 60
    return math.max(self.width or 128, math.ceil(pad + toggle_w + CHIP_ROW.CHIP_GAP + mode_min))
end

function widget.getLayoutHeight(self, ctx, inner_width, is_vertical_toolbar)
    if not is_vertical_toolbar or not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    if self._slide_out_mode then
        return CONFIG.SIZES.HEIGHT
    end
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_ROW.CHIP_V_PAD * 2
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    local inner_w = math.max(10, (inner_width or self.width or 0) - pad_x * 2)
    local toggle_w = toggle_chip_width(ctx)
    local groups = {
        { { id = "toggle_override", w = toggle_w, h = chip_h } },
    }
    local lines = FLEX_LAYOUT.wrap_groups(groups, inner_w, CHIP_ROW.CHIP_GAP, CHIP_ROW.CHIP_GAP)
    local pad_y = 4 + R
    return pad_y * 2 + #lines * chip_h + math.max(0, #lines - 1) * CHIP_ROW.CHIP_GAP
end

local function draw_chip_override_on(
    ctx,
    coords,
    draw_list,
    chip,
    text,
    is_hover,
    btn_txt,
    btn_bg,
    toolbar_txt,
    toolbar_bg,
    flash_mimic
)
    if flash_mimic then
        DRAWING.drawChipBackground(coords, draw_list, chip.x, chip.y, chip.w, chip.h, toolbar_bg, { rounding = CHIP_ROW.CHIP_ROUND, border_color = toolbar_txt })
        DRAWING.drawCenteredText(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, text, toolbar_txt, 0)
    else
        DRAWING.drawWidgetPillChip(ctx, coords, draw_list, chip, text, btn_txt, btn_bg, {
            active = true,
            hover = is_hover,
            disabled = false,
            rounding = CHIP_ROW.CHIP_ROUND,
            text_y_offset = 0,
        })
    end
end

local function draw_mode_multiswitch(self, ctx, coords, draw_list, chips, btn_txt, btn_bg, mx, my, alpha_factor)
    local sel_id = active_mode_id(self)
    local override_on = self._api_mode ~= -1
    CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROW.CHIP_ROUND,
        slide_namespace = "gao_ms",
        grid_layout = true,
        alpha_factor = alpha_factor,
        is_selected_segment = function(c)
            if c.blank or not c.mode then
                return false
            end
            return override_on and c.mode.id == sel_id
        end,
    })
end

function widget.onSettingsMenu(self, ctx, _button)
    reaper.ImGui_TextDisabled(ctx, "Global mode")
    local sel_id = active_mode_id(self)
    for _, m in ipairs(MODES) do
        if reaper.ImGui_MenuItem(ctx, m.label, nil, sel_id == m.id) then
            self._preferred_mode_id = m.id
            if self._api_mode ~= -1 then
                apply_global_mode(m.id)
            end
        end
    end
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    local mx, my = coords:getRelativeMouse()
    local toggle, mode_chips = layout_chips(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out and mode_chips then
        local hit = CHIP_ROW.hit_test_chips(mx, my, coords, mode_chips, PREFIX_MS)
        if hit then
            return hit
        end
        return nil
    end
    if toggle and coords:pointInRelativeRect(mx, my, toggle.x, toggle.y, toggle.w, toggle.h) then
        return toggle.id
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "toggle_override" then
        if self._api_mode ~= -1 then
            reaper.SetGlobalAutomationOverride(-1)
            self._api_mode = -1
        else
            apply_global_mode(self._preferred_mode_id or "read")
            self._api_mode = reaper.GetGlobalAutomationOverride()
        end
        return true
    end
    local mode_id = sub_id and sub_id:match("^" .. PREFIX_MS .. "(.+)$")
    if mode_id then
        self._preferred_mode_id = mode_id
        if self._api_mode ~= -1 then
            apply_global_mode(mode_id)
            self._api_mode = reaper.GetGlobalAutomationOverride()
        end
        return true
    end
    return false
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    local mx, my = coords:getRelativeMouse()
    local is_slide_out = self._is_rendering_slide_out == true

    if is_slide_out then
        local _, mode_chips = layout_chips(self, ctx, rel_x, rel_y, render_width, layout, true)
        if mode_chips and #mode_chips > 0 then
            draw_mode_multiswitch(self, ctx, coords, draw_list, mode_chips, btn_txt, btn_bg, mx, my, self._slide_alpha_factor)
        end
        return
    end

    local toggle = layout_chips(self, ctx, rel_x, rel_y, render_width, layout, false)
    if not toggle then
        return
    end

    local override_on = self._api_mode ~= -1
    local flash_mimic = override_on and override_flash_toolbar_mimic_phase()
    local toggle_text = toggle_chip_label(self)
    local toggle_hover = coords:pointInRelativeRect(mx, my, toggle.x, toggle.y, toggle.w, toggle.h)

    if override_on then
        draw_chip_override_on(
            ctx,
            coords,
            draw_list,
            toggle,
            toggle_text,
            toggle_hover,
            btn_txt,
            btn_bg,
            btn_txt,
            btn_bg,
            flash_mimic
        )
    else
        DRAWING.drawWidgetPillChip(ctx, coords, draw_list, toggle, toggle_text, btn_txt, btn_bg, {
            active = false,
            filled = true,
            hover = toggle_hover,
            disabled = false,
            rounding = CHIP_ROW.CHIP_ROUND,
        })
    end
end

function widget.slide_height(self, ctx, host_w, host_h, layout)
    local constraints = {}
    if layout and layout.is_vertical then
        constraints.panel_h = host_h
    else
        constraints.panel_w = host_w
    end
    local w, h, rows, cols = CHIP_ROW.plan_slide_out_panel(ctx, MODES, {
        pad_x = 4,
        chip_pad_h = 6,
        min_chip_w = MIN_CHIP,
    }, constraints)
    self._slide_out_plan = { w = w, h = h, rows = rows, cols = cols }
    return h
end

function widget.slide_width(self, ctx, host_w, host_h, layout)
    if not self._slide_out_plan then
        self:slide_height(ctx, host_w, host_h, layout)
    end
    return self._slide_out_plan.w
end

return widget
