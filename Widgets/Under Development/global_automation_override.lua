-- Widgets/Under Development/global_automation_override.lua
-- Global automation override: On/Off chip plus mode chip with popup (REAPER Options → Global automation override).

local TOGGLE_PAD_H = 10
local CHIP_MODE = require("Utils.chip_mode_widget")
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_ROW = require("Renderers._Widgets_chip_row")

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
    description = "Toggle global automation override (per-track vs project-wide). Off = no override. On = apply the mode chosen in the second chip (popup).",
    chip_widget = true,
    _preferred_mode_id = "read",
    _api_mode = -1,
    _open_mode_popup = false,
}

local function mode_by_id(id)
    return CHIP_MODE.mode_by_id(MODES, id)
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

local function mode_chip_label(self)
    local api = self._api_mode
    if api ~= -1 and api ~= 5 then
        if api == 6 then
            local m = mode_by_id("latch_preview")
            return m and CHIP_MS.chip_caption(m) or "L.Prev"
        end
        for _, m in ipairs(MODES) do
            if m.api == api then
                return CHIP_MS.chip_caption(m)
            end
        end
    end
    local m = mode_by_id(self._preferred_mode_id or "read")
    return m and CHIP_MS.chip_caption(m) or "Read"
end

local function layout_chips(ctx, rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_ROW.CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2

    local R = CHIP_ROW.button_rounding_content_pad()
    local off_w = reaper.ImGui_CalcTextSize(ctx, "Off") + TOGGLE_PAD_H * 2
    local on_w = reaper.ImGui_CalcTextSize(ctx, "On") + TOGGLE_PAD_H * 2
    local toggle_w = math.max(off_w, on_w, 44)

    local toggle = {
        id = "toggle_override",
        x = rel_x + 4 + R,
        y = row_y,
        w = toggle_w,
        h = chip_h,
    }

    local mode_x = toggle.x + toggle.w + CHIP_ROW.CHIP_GAP
    local mode_w = math.max(34, rel_x + render_width - mode_x - 4 - R)

    local mode_chip = {
        id = "mode_menu",
        x = mode_x,
        y = row_y,
        w = mode_w,
        h = chip_h,
    }

    return toggle, mode_chip, chip_h
end

local function draw_chip(ctx, coords, draw_list, chip, text, is_active, is_hover, btn_txt, btn_bg, disabled)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
        disabled = disabled,
    })
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROW.CHIP_ROUND)

    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, text)
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
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)

    if flash_mimic then
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, toolbar_bg, CHIP_ROW.CHIP_ROUND)
        reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, toolbar_txt, CHIP_ROW.CHIP_ROUND, 0, 1.0)
    else
        local bg_col, _ = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
            active = true,
            hover = is_hover,
            disabled = false,
        })
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROW.CHIP_ROUND)
    end

    local _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = true,
        hover = is_hover,
        disabled = false,
    })
    local text_col_out = flash_mimic and toolbar_txt or text_col
    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col_out, text)
end

local function draw_mode_chip_with_arrow(
    ctx,
    coords,
    draw_list,
    chip,
    text,
    override_on,
    is_hover,
    btn_txt,
    btn_bg,
    toolbar_txt,
    toolbar_bg,
    flash_mimic
)
    local arrow_reserve = 14
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)

    if override_on then
        if flash_mimic then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, toolbar_bg, CHIP_ROW.CHIP_ROUND)
            reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, toolbar_txt, CHIP_ROW.CHIP_ROUND, 0, 1.0)
        else
            local bg_col, _ = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
                active = true,
                hover = is_hover,
                disabled = false,
            })
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROW.CHIP_ROUND)
        end
    else
        local bg_col, _ = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
            active = false,
            hover = is_hover,
            disabled = false,
        })
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROW.CHIP_ROUND)
    end

    local text_max_w = chip.w - arrow_reserve - 8
    local display = text
    local tw_full = reaper.ImGui_CalcTextSize(ctx, display)
    if tw_full > text_max_w and #display > 6 then
        display = string.sub(display, 1, 6) .. "…"
    end

    local _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = override_on,
        hover = is_hover and not override_on,
        disabled = false,
    })
    local text_col_out = (override_on and flash_mimic) and toolbar_txt or text_col

    local tw = reaper.ImGui_CalcTextSize(ctx, display)
    local tx = chip.x + 8
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col_out, display)

    local ax = chip.x + chip.w - arrow_reserve / 2 - 2
    local ay = chip.y + chip.h / 2
    local ax_dl, ay_dl = coords:relativeToDrawList(ax, ay)
    DRAWING.triangle(draw_list, ax_dl, ay_dl, 6, 6, text_col_out, DRAWING.ANGLE_DOWN)
end

local function draw_mode_popup(self, ctx)
    local key = tostring(self._button_instance_id or "global_automation_override")
    local popup_id = "##global_automation_mode_" .. key

    if self._open_mode_popup then
        reaper.ImGui_OpenPopup(ctx, popup_id)
        self._open_mode_popup = false
    end

    if reaper.ImGui_BeginPopup(ctx, popup_id) then
        reaper.ImGui_TextDisabled(ctx, "Global mode")
        local sel_id
        local api = self._api_mode
        if api == 5 then
            sel_id = self._preferred_mode_id
        elseif api == 6 then
            sel_id = "latch_preview"
        elseif api ~= nil and api ~= -1 then
            for _, m in ipairs(MODES) do
                if m.api == api then
                    sel_id = m.id
                    break
                end
            end
        else
            sel_id = self._preferred_mode_id
        end
        for _, m in ipairs(MODES) do
            if reaper.ImGui_MenuItem(ctx, m.label, nil, sel_id == m.id) then
                self._preferred_mode_id = m.id
                if self._api_mode ~= -1 then
                    apply_global_mode(m.id)
                end
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local toggle, mode_chip = layout_chips(ctx, rel_x, rel_y, render_width)
    if coords:pointInRelativeRect(mx, my, toggle.x, toggle.y, toggle.w, toggle.h) then
        return toggle.id
    end
    if coords:pointInRelativeRect(mx, my, mode_chip.x, mode_chip.y, mode_chip.w, mode_chip.h) then
        return mode_chip.id
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
    if sub_id == "mode_menu" then
        self._open_mode_popup = true
        return true
    end
    return false
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    local mx, my = coords:getRelativeMouse()
    local toggle, mode_chip = layout_chips(ctx, rel_x, rel_y, render_width)

    local override_on = self._api_mode ~= -1
    local flash_mimic = override_on and override_flash_toolbar_mimic_phase()
    local toggle_text = override_on and "On" or "Off"
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
        draw_chip(ctx, coords, draw_list, toggle, toggle_text, false, toggle_hover, btn_txt, btn_bg, false)
    end

    local mode_hover = coords:pointInRelativeRect(mx, my, mode_chip.x, mode_chip.y, mode_chip.w, mode_chip.h)
    local mode_label = mode_chip_label(self)
    draw_mode_chip_with_arrow(
        ctx,
        coords,
        draw_list,
        mode_chip,
        mode_label,
        override_on,
        mode_hover,
        btn_txt,
        btn_bg,
        btn_txt,
        btn_bg,
        flash_mimic
    )

    draw_mode_popup(self, ctx)
end

return widget
