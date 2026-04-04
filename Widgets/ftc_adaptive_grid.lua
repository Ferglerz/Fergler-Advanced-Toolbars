-- widgets/ftc_adaptive_grid.lua
-- FeedTheCat Adaptive Grid readout: SNAP chip + grid label; grid click runs "Adaptive grid menu.lua" (registered action).
-- Persist FTC folder in CONFIG.WIDGET_SAVED_STATES.ftc_adaptive_grid[<button id>].
-- If unset or saved path missing, uses REAPER resource path Scripts/.../FTC/.../Adaptive Grid/ (several casings) when the menu script exists there.

local SEP = package.config:sub(1, 1)
local MENU_NAME = "Adaptive grid menu.lua"
local EXT_ADAPT = "FTC.AdaptiveGrid"

local function menu_path_for_dir(dir)
    if not dir or dir == "" then return nil end
    local last = dir:sub(-1)
    return (last == "/" or last == "\\") and (dir .. MENU_NAME) or (dir .. SEP .. MENU_NAME)
end

-- REAPER resource folder + relative segments; try several casings (case-sensitive volumes / manual renames).
local DEFAULT_FTC_REL_SEGMENTS = {
    { "Scripts", "FTC", "Adaptive Grid" },
    { "Scripts", "ftc", "Adaptive Grid" },
    { "Scripts", "FTC", "adaptive grid" },
    { "Scripts", "ftc", "adaptive grid" },
}

local function default_ftc_dir_candidates()
    local rp = reaper.GetResourcePath()
    if not rp or rp == "" then return {} end
    local out = {}
    for _, segs in ipairs(DEFAULT_FTC_REL_SEGMENTS) do
        table.insert(out, rp .. SEP .. table.concat(segs, SEP))
    end
    return out
end

local function first_default_dir_with_menu()
    for _, dir in ipairs(default_ftc_dir_candidates()) do
        local p = menu_path_for_dir(dir)
        if p and reaper.file_exists(p) then return dir end
    end
    return nil
end

local function state_key(self)
    return tostring(self._button_instance_id or self.name or "default")
end

local function ensure_store()
    CONFIG.WIDGET_SAVED_STATES = CONFIG.WIDGET_SAVED_STATES or {}
    CONFIG.WIDGET_SAVED_STATES.ftc_adaptive_grid = CONFIG.WIDGET_SAVED_STATES.ftc_adaptive_grid or {}
    return CONFIG.WIDGET_SAVED_STATES.ftc_adaptive_grid
end

local function get_dir(self)
    local st = ensure_store()[state_key(self)]
    return (type(st) == "table" and type(st.ftc_dir) == "string" and st.ftc_dir ~= "") and st.ftc_dir or nil
end

--- Saved folder if the menu exists there; else first default resource path (several folder name casings) where the menu exists.
local function compute_resolved_ftc_dir(self)
    local cfg = get_dir(self)
    if cfg then
        local p = menu_path_for_dir(cfg)
        if p and reaper.file_exists(p) then return cfg end
    end
    return first_default_dir_with_menu()
end

local function resolved_ftc_dir(self)
    if self._ftc_resolved_dirty ~= false then
        self._ftc_cached_resolved_dir = compute_resolved_ftc_dir(self)
        self._ftc_resolved_dirty = false
    end
    return self._ftc_cached_resolved_dir
end

local function ftc_menu_path_ok(self)
    return resolved_ftc_dir(self) ~= nil
end

local function set_dir(self, dir)
    local store = ensure_store()
    local key = state_key(self)
    store[key] = store[key] or {}
    store[key].ftc_dir = dir
    self._menu_cmd = nil
    self._ftc_resolved_dirty = true
    if CONFIG_MANAGER and CONFIG_MANAGER.saveMainConfig then CONFIG_MANAGER:saveMainConfig() end
end

local function pick_ftc_dir(self)
    local rv, path = reaper.GetUserFileNameForRead("", "Select " .. MENU_NAME .. " (in your FTC Adaptive grid folder)", "lua")
    if not rv or not path or path == "" then return end
    path = path:gsub("[\\/][^\\/]+$", "")
    if path == "" then return end
    local p = menu_path_for_dir(path)
    if not p or not reaper.file_exists(p) then
        reaper.MB("Could not find:\n" .. tostring(p), "FTC Adaptive Grid", 0)
        return
    end
    set_dir(self, path)
end

-- Local fraction for display only (no Gridbox.lua).
local function decimal_to_fraction(x)
    local err = 1e-10
    local n = math.floor(x)
    x = x - n
    if x < err then return n, 1 end
    if 1 - err < x then return n + 1, 1 end
    local lower_n, lower_d, upper_n, upper_d = 0, 1, 1, 1
    while true do
        local middle_n = lower_n + upper_n
        local middle_d = lower_d + upper_d
        if middle_d * (x + err) < middle_n then
            upper_n, upper_d = middle_n, middle_d
        elseif middle_n < (x - err) * middle_d then
            lower_n, lower_d = middle_n, middle_d
        else
            return n * middle_d + middle_n, middle_d
        end
    end
end

local function grid_display_text(_self)
    local _, grid_div0, swing0, swing_amt0 = reaper.GetSetProjectGrid(0, 0)
    if reaper.GetToggleCommandState(40904) == 1 then return "Frame", false, swing0, swing_amt0 end
    local grid_div, swing, swing_amt = grid_div0, swing0, swing_amt0
    if grid_div ~= grid_div then grid_div = 1 end
    if swing == 3 then return "Measure", false, swing, swing_amt end
    local is_adaptive = (tonumber(reaper.GetExtState(EXT_ADAPT, "main_mult")) or 0) ~= 0
    local num, denom = decimal_to_fraction(grid_div)
    if num > 1 and denom % num == 0 then denom, num = denom / num, 1 end
    local text = (num >= denom and num % denom == 0) and ("%.0f"):format(num / denom)
        or ("%.0f/%.0f"):format(num, denom)
    return text, is_adaptive, swing, swing_amt
end

local function alt_held()
    if not reaper.JS_Mouse_GetState then return false end
    return reaper.JS_Mouse_GetState(16) == 16
end

local function ensure_menu_cmd(self)
    if self._menu_cmd and self._menu_cmd ~= 0 then return true end
    local dir = resolved_ftc_dir(self)
    if not dir then return false end
    local path = menu_path_for_dir(dir)
    if not path then return false end
    self._menu_cmd = reaper.AddRemoveReaScript(true, 0, path, true)
    return self._menu_cmd ~= nil and self._menu_cmd ~= 0
end

local function run_adaptive_menu(self)
    if ensure_menu_cmd(self) then
        reaper.Main_OnCommand(self._menu_cmd, 0)
    end
end

-- Snap chip appearance
local SNAP_CHIP_LABEL, SNAP_CHIP_PAD_H, SNAP_CHIP_PAD_V = "SNAP", 10, 3
local SNAP_CHIP_ROUND, SNAP_CHIP_MARGIN_L, SNAP_CHIP_GAP_BEFORE_SEP, SNAP_SEP_TO_GRID = 3, 4, 4, 2

local function snap_chip_metrics(ctx)
    return DRAWING.getTextChipMetrics(ctx, SNAP_CHIP_LABEL, SNAP_CHIP_PAD_H, SNAP_CHIP_PAD_V)
end

local function snap_left_allocation_w(ctx)
    local _, _, cw = snap_chip_metrics(ctx)
    return SNAP_CHIP_MARGIN_L + cw + SNAP_CHIP_GAP_BEFORE_SEP + SNAP_SEP_TO_GRID
end

--- Draw configured widget body: optional vertical (chip stacked) or horizontal (chip | text).
local function draw_snap_and_grid_text(ctx, coords, draw_list, rel_x, rel_y, render_width, height, text_color, bg_color, widget, vertical)
    local mx, my = coords:getRelativeMouse()
    local btn_bg = bg_color or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.BG.NORMAL)
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local display = widget._last_text or widget.value or "—"
    local sep_c = (text_color & 0xFFFFFF00) | 0x55

    if vertical then
        local _, _, _, chip_h = snap_chip_metrics(ctx)
        local chip_margin = 4
        local chip_x = rel_x + chip_margin
        local chip_y = rel_y + chip_margin
        local chip_w = math.max(1, render_width - 2 * chip_margin)
        local grid_top = chip_y + chip_h + 4
        widget._snap_chip_x, widget._snap_chip_y = chip_x, chip_y
        widget._snap_chip_w, widget._snap_chip_h = chip_w, chip_h
        widget._ftc_grid_left = rel_x

        local hsx1, hsy1 = coords:relativeToDrawList(rel_x + chip_margin, chip_y + chip_h + 2)
        local hsx2, _ = coords:relativeToDrawList(rel_x + render_width - chip_margin, chip_y + chip_h + 2)
        reaper.ImGui_DrawList_AddLine(draw_list, hsx1, hsy1, hsx2, hsy1, sep_c, 1)

        local snap_on = reaper.GetToggleCommandState(1157) == 1
        local snap_hover = coords:pointInRelativeRect(mx, my, chip_x, chip_y, chip_w, chip_h)
        local chip_bg, chip_txt = COLOR_UTILS.widgetPillColors(text_color, btn_bg, { active = snap_on, hover = snap_hover })
        DRAWING.drawTextChip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, SNAP_CHIP_LABEL, {
            bg_color = chip_bg, text_color = chip_txt, rounding = SNAP_CHIP_ROUND,
        })

        local tw = reaper.ImGui_CalcTextSize(ctx, display)
        local bottom = rel_y + height - chip_margin
        local ty = grid_top + math.max(0, (bottom - grid_top - line_h) / 2)
        local tpx, tpy = coords:relativeToDrawList(rel_x + (render_width - tw) / 2, ty)
        reaper.ImGui_DrawList_AddText(draw_list, tpx, tpy, text_color, display)
        return
    end

    local _, _, chip_w, chip_h = snap_chip_metrics(ctx)
    local chip_x, chip_y = rel_x + SNAP_CHIP_MARGIN_L, rel_y + (height - chip_h) / 2
    local sep_x = chip_x + chip_w + SNAP_CHIP_GAP_BEFORE_SEP
    local grid_left = sep_x + SNAP_SEP_TO_GRID
    local narrow = grid_left + 48 > rel_x + render_width
    local lw = 0
    if narrow then
        widget._ftc_grid_left = rel_x
    else
        lw = grid_left - rel_x
        widget._snap_chip_x, widget._snap_chip_y = chip_x, chip_y
        widget._snap_chip_w, widget._snap_chip_h = chip_w, chip_h
        widget._ftc_grid_left = grid_left
    end

    if lw > 0 then
        local x1, y1 = coords:relativeToDrawList(sep_x, rel_y + 6)
        local _, y2 = coords:relativeToDrawList(sep_x, rel_y + height - 6)
        reaper.ImGui_DrawList_AddLine(draw_list, x1, y1, x1, y2, sep_c, 1)
        local snap_on = reaper.GetToggleCommandState(1157) == 1
        local snap_hover = coords:pointInRelativeRect(mx, my, chip_x, chip_y, chip_w, chip_h)
        local chip_bg, chip_txt = COLOR_UTILS.widgetPillColors(text_color, btn_bg, { active = snap_on, hover = snap_hover })
        DRAWING.drawTextChip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, SNAP_CHIP_LABEL, {
            bg_color = chip_bg, text_color = chip_txt, rounding = SNAP_CHIP_ROUND,
        })
    end

    local tw = reaper.ImGui_CalcTextSize(ctx, display)
    local tx = rel_x + lw + (render_width - lw - tw) / 2
    local ty = rel_y + (height - line_h) / 2
    local tpx, tpy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, tpx, tpy, text_color, display)
end

local widget = {
    name = "FTC Adaptive Grid",
    category = "Time, grid & tempo",
    type = "display",
    update_interval = 0.15,
    description = "FeedTheCat Adaptive Grid: SNAP chip + grid readout. Click grid area to open Adaptive grid menu. When no valid saved folder, looks for Adaptive grid menu.lua under Scripts/FTC/Adaptive Grid (and common casing variants) in your REAPER resource path.",
    label = "",
    chip_widget = true,

    getLayoutWidth = function(self, ctx)
        local text = self._last_text or "1/16"
        if self._preview_mode or self._preview_width_cap then
            text = "A 1/16"
        end
        local tw = reaper.ImGui_CalcTextSize(ctx, text)
        if not ftc_menu_path_ok(self) and not self._preview_mode and not self._preview_width_cap then
            local mw = reaper.ImGui_CalcTextSize(ctx, "Click: select Adaptive grid menu.lua")
            return math.max(CONFIG.SIZES.MIN_WIDTH or 30, mw + 16)
        end
        local lw = snap_left_allocation_w(ctx)
        local w = math.max(CONFIG.SIZES.MIN_WIDTH or 30, lw + tw + 28)
        local cap = tonumber(self._preview_width_cap)
        if cap and cap > 0 then
            return math.min(w, cap)
        end
        return w
    end,

    getLayoutHeight = function(self, ctx, _inner_w, is_vertical_toolbar)
        local base = CONFIG.SIZES.HEIGHT or 38
        if not is_vertical_toolbar or not ctx then
            return base
        end
        local _, _, _, chip_h = snap_chip_metrics(ctx)
        local line_h = reaper.ImGui_GetTextLineHeight(ctx)
        local m, gap = 4, 4
        return m + chip_h + gap + line_h + m
    end,

    getValue = function(self)
        local text, is_adapt = grid_display_text(self)
        self._last_text = (is_adapt and "A " or "") .. text
        return self._last_text
    end,

    hitTestSubcontrols = function(self, _ctx, coords, rel_x, rel_y, render_width, layout)
        local h = (layout and layout.height) or CONFIG.SIZES.HEIGHT or 38
        local mx, my = coords:getRelativeMouse()
        if not coords:pointInRelativeRect(mx, my, rel_x, rel_y, render_width, h) then return nil end
        if not ftc_menu_path_ok(self) then return "grid" end
        if self._snap_chip_x and self._snap_chip_w and self._snap_chip_h then
            if coords:pointInRelativeRect(mx, my, self._snap_chip_x, self._snap_chip_y, self._snap_chip_w, self._snap_chip_h) then
                return "snap"
            end
        end
        return "grid"
    end,

    onClick = function(self, sub_hit)
        if sub_hit ~= nil then return end
        if not ftc_menu_path_ok(self) then pick_ftc_dir(self) end
    end,

    onSubcontrolClick = function(self, sub)
        if not ftc_menu_path_ok(self) then pick_ftc_dir(self) return true end
        if sub == "snap" then
            reaper.Main_OnCommand(alt_held() and 41054 or 1157, 0)
            return true
        end
        if sub == "grid" then
            run_adaptive_menu(self)
            return true
        end
        return false
    end,

    onRightClick = function(self)
        if not ftc_menu_path_ok(self) then pick_ftc_dir(self) return end
        local sub = self.hitTestSubcontrols(self, nil, self._last_coords, self._last_rel_x, self._last_rel_y, self._last_rw, nil)
        if sub == "snap" then
            reaper.Main_OnCommand(40071, 0)
            return
        end
        run_adaptive_menu(self)
    end,

    renderCustom = function(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local height = (layout and layout.height) or CONFIG.SIZES.HEIGHT or 38
        local is_vert = layout and layout.is_vertical
        widget._last_coords, widget._last_rel_x, widget._last_rel_y, widget._last_rw = coords, rel_x, rel_y, render_width
        widget._snap_chip_x, widget._snap_chip_y, widget._snap_chip_w, widget._snap_chip_h = nil, nil, nil, nil

        if widget._preview_mode then
            local _, _, chip_w, chip_h = snap_chip_metrics(ctx)
            local chip_x, chip_y = rel_x + SNAP_CHIP_MARGIN_L, rel_y + (height - chip_h) / 2
            local sep_x = chip_x + chip_w + SNAP_CHIP_GAP_BEFORE_SEP
            local lw = sep_x + SNAP_SEP_TO_GRID - rel_x
            local sep_c = (text_color & 0xFFFFFF00) | 0x55
            local x1, y1 = coords:relativeToDrawList(sep_x, rel_y + 6)
            local _, y2 = coords:relativeToDrawList(sep_x, rel_y + height - 6)
            reaper.ImGui_DrawList_AddLine(draw_list, x1, y1, x1, y2, sep_c, 1)
            local btn_bg = bg_color or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.BG.NORMAL)
            local chip_bg, chip_txt = COLOR_UTILS.widgetPillColors(text_color, btn_bg, { active = true, hover = false })
            DRAWING.drawTextChip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, SNAP_CHIP_LABEL, {
                bg_color = chip_bg, text_color = chip_txt, rounding = SNAP_CHIP_ROUND,
            })
            local display = "A 1/16"
            local line_h = reaper.ImGui_GetTextLineHeight(ctx)
            local tw = reaper.ImGui_CalcTextSize(ctx, display)
            local tx = rel_x + lw + (render_width - lw - tw) / 2
            local ty = rel_y + (height - line_h) / 2
            local tpx, tpy = coords:relativeToDrawList(tx, ty)
            reaper.ImGui_DrawList_AddText(draw_list, tpx, tpy, text_color, display)
            return
        end

        if not ftc_menu_path_ok(widget) then
            widget._ftc_grid_left = rel_x
            local msg = "Click: select Adaptive grid menu.lua"
            local tw = reaper.ImGui_CalcTextSize(ctx, msg)
            local tx, ty = coords:relativeToDrawList(rel_x + (render_width - tw) / 2, rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2)
            reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_color, msg)
            return
        end

        draw_snap_and_grid_text(ctx, coords, draw_list, rel_x, rel_y, render_width, height, text_color, bg_color, widget, is_vert)
    end,
}

return widget
