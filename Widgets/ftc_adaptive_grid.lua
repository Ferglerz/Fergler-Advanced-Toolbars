-- widgets/ftc_adaptive_grid.lua
-- FeedTheCat Adaptive Grid readout: snap chip (Tools/Magnet.ttf icon or "SNAP" fallback) + grid label; grid click runs "Adaptive grid menu.lua" (registered action).
-- Persist FTC folder in CONFIG.WIDGET_SAVED_STATES.ftc_adaptive_grid[<button id>].
-- If unset or saved path missing, uses REAPER resource path Scripts/.../FTC/.../Adaptive Grid/ (several casings) when the menu script exists there.

local CHIP_ROW = require("Renderers._Widgets_chip_row")
local ICON_FONTS_LIB = require("Utils.icon_fonts")

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
    if grid_div == nil or grid_div ~= grid_div then
        grid_div = 1
    end
    if swing == 3 then return "Measure", false, swing, swing_amt end
    local is_adaptive = (tonumber(reaper.GetExtState(EXT_ADAPT, "main_mult")) or 0) ~= 0
    local num, denom = decimal_to_fraction(grid_div)
    if num > 1 and denom % num == 0 then denom, num = denom / num, 1 end
    local text = (num >= denom and num % denom == 0) and ("%.0f"):format(num / denom)
        or ("%.0f/%.0f"):format(num, denom)
    return text, is_adaptive, swing, swing_amt
end

local function alt_held(ctx)
    if ctx and reaper.ImGui_Mod_Alt and reaper.ImGui_GetKeyMods then
        if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0 then
            return true
        end
    end
    if reaper.JS_Mouse_GetState then
        return (reaper.JS_Mouse_GetState(16) & 16) ~= 0
    end
    return false
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

-- Snap chip appearance (icon fonts: per-icon TTF, glyph at U+0041 — see Utils/icon_fonts.lua). Icon px: CHIP_ROW.magnet_icon_size.
local SNAP_LABEL_FALLBACK = "SNAP"
local SNAP_CHIP_PAD_H, SNAP_CHIP_PAD_V = 10, 3
local SNAP_CHIP_ROUND, SNAP_CHIP_MARGIN_L, SNAP_CHIP_GAP_BEFORE_SEP, SNAP_SEP_TO_GRID = 3, 4, 4, 2

-- Horizontal mode: readout width is fixed from these strings so layout does not change when the label updates.
local H_READOUT_REF_STRINGS = { "A 1/128", "Measure", "Frame" }
local H_READOUT_PAD = 10

local function horizontal_readout_text_width(ctx)
    local max_w = 0
    for _, s in ipairs(H_READOUT_REF_STRINGS) do
        local w = reaper.ImGui_CalcTextSize(ctx, s)
        if w > max_w then max_w = w end
    end
    return max_w
end
local SNAP_ICON_PATH = UTILS.normalizeSlashes("IconFonts/icons/Tools/Magnet.ttf")
local SNAP_ICON_CHAR = utf8.char(ICON_FONTS_LIB.ICON_CODEPOINT)

local _snap_icon_resolved
local _snap_icon_cache_rev

local function snap_icon_mode()
    local rev = _G._adv_tb_icon_font_rev or 0
    if _snap_icon_cache_rev ~= rev then
        _snap_icon_cache_rev = rev
        _snap_icon_resolved = nil
    end
    if _snap_icon_resolved ~= nil then
        return _snap_icon_resolved
    end
    _snap_icon_resolved = { use_icons = false }
    if not SCRIPT_PATH or SCRIPT_PATH == "" or not C or not C.ButtonContent then
        return _snap_icon_resolved
    end
    local p_mag = UTILS.joinPath(SCRIPT_PATH, "IconFonts", "icons", "Tools", "Magnet.ttf")
    if not reaper.file_exists(p_mag) then
        return _snap_icon_resolved
    end
    local f = C.ButtonContent:loadIconFont(SNAP_ICON_PATH)
    if not f then
        return _snap_icon_resolved
    end
    _snap_icon_resolved = { use_icons = true, font = f }
    return _snap_icon_resolved
end

local function snap_chip_metrics(ctx)
    local chip_h = CHIP_ROW.chip_line_height(ctx)
    local mode = snap_icon_mode()
    if not mode.use_icons then
        local tw, line_h, cw, _ = DRAWING.getTextChipMetrics(ctx, SNAP_LABEL_FALLBACK, SNAP_CHIP_PAD_H, SNAP_CHIP_PAD_V)
        return tw, line_h, cw, chip_h
    end
    local icon_sz = CHIP_ROW.magnet_icon_size(ctx)
    if not ensureIconFontAttachedToContext(ctx, mode.font) then
        local tw, line_h, cw, _ = DRAWING.getTextChipMetrics(ctx, SNAP_LABEL_FALLBACK, SNAP_CHIP_PAD_H, SNAP_CHIP_PAD_V)
        return tw, line_h, cw, chip_h
    end
    reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
    local w = reaper.ImGui_CalcTextSize(ctx, SNAP_ICON_CHAR)
    reaper.ImGui_PopFont(ctx)
    w = math.max(w, icon_sz * 0.65)
    local chip_w = w + SNAP_CHIP_PAD_H * 2
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    return w, line_h, chip_w, chip_h
end

--- Rounded snap pill: Magnet icon when font loads, else "SNAP". (snap_on only affects colors from caller.)
local function draw_snap_chip(ctx, coords, draw_list, rel_x, rel_y, width, height, _snap_on, chip_bg, chip_txt)
    local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
    local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + height)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, chip_bg, SNAP_CHIP_ROUND)
    local mode = snap_icon_mode()
    if not mode.use_icons then
        local text_w = reaper.ImGui_CalcTextSize(ctx, SNAP_LABEL_FALLBACK)
        local text_rel_x = rel_x + (width - text_w) / 2
        local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local tx, ty = coords:relativeToDrawList(text_rel_x, text_rel_y)
        reaper.ImGui_DrawList_AddText(draw_list, tx, ty, chip_txt, SNAP_LABEL_FALLBACK)
        return
    end
    local icon_sz = CHIP_ROW.magnet_icon_size(ctx)
    if not ensureIconFontAttachedToContext(ctx, mode.font) then
        local text_w = reaper.ImGui_CalcTextSize(ctx, SNAP_LABEL_FALLBACK)
        local text_rel_x = rel_x + (width - text_w) / 2
        local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local tx, ty = coords:relativeToDrawList(text_rel_x, text_rel_y)
        reaper.ImGui_DrawList_AddText(draw_list, tx, ty, chip_txt, SNAP_LABEL_FALLBACK)
        return
    end
    reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
    local text_w = reaper.ImGui_CalcTextSize(ctx, SNAP_ICON_CHAR)
    reaper.ImGui_PopFont(ctx)
    text_w = math.max(text_w, icon_sz * 0.65)
    -- DrawList_AddText uses baseline Y (same heuristic as Renderers/04_Content.lua icon_y).
    local text_rel_x = rel_x + (width - text_w) / 2
    local text_rel_y = rel_y + height / 2 - icon_sz / 4
    reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
    local tx, ty = coords:relativeToDrawList(text_rel_x, text_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, tx, ty, chip_txt, SNAP_ICON_CHAR)
    reaper.ImGui_PopFont(ctx)
end

local function snap_left_allocation_w(ctx)
    local R = CHIP_ROW.button_rounding_content_pad()
    local _, _, cw = snap_chip_metrics(ctx)
    return SNAP_CHIP_MARGIN_L + R + cw + SNAP_CHIP_GAP_BEFORE_SEP + SNAP_SEP_TO_GRID
end

local function point_in_snap_chip(widget, coords, mx, my)
    if not widget._snap_chip_x or not widget._snap_chip_w or widget._snap_chip_w <= 0 then
        return false
    end
    return coords:pointInRelativeRect(mx, my, widget._snap_chip_x, widget._snap_chip_y, widget._snap_chip_w, widget._snap_chip_h)
end

--- Alt-drag swing HUD: grid readout becomes signed swing %; bar at widget bottom, bidirectional from center.
local function draw_ftc_swing_drag_overlay(ctx, coords, draw_list, zx, zy, zw, text_color, rel_y, height)
    local _, _, _, swamt = reaper.GetSetProjectGrid(0, 0)
    if type(swamt) ~= "number" or swamt ~= swamt then
        swamt = 0
    end
    local norm = math.max(-1, math.min(1, swamt * 2 - 1))
    local pct_signed = math.floor(norm * 100 + 0.5)
    local label = string.format("%d%%", pct_signed)

    local pad = 6
    local bar_h = math.max(4, math.floor((height or 24) * 0.14 + 0.5))
    bar_h = math.min(bar_h, 8)
    local bar_y = rel_y + height - pad - bar_h
    local tw_full = math.max(16, zw - 2 * pad)
    local cx = zx + zw * 0.5
    local half = tw_full * 0.5
    local x_track0 = cx - half
    local x_track1 = cx + half

    local lh = reaper.ImGui_GetTextLineHeight(ctx)
    local gap_txt_bar = 4
    local text_bottom = bar_y - gap_txt_bar
    local ty = zy + math.max(0, (text_bottom - zy - lh) / 2)
    local lw = reaper.ImGui_CalcTextSize(ctx, label)
    local lx = zx + (zw - lw) / 2
    local tx, ty_dl = coords:relativeToDrawList(lx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, tx, ty_dl, text_color, label)

    local track_col = (text_color & 0xFFFFFF00) | 0x40
    local ax1, ay1 = coords:relativeToDrawList(x_track0, bar_y)
    local ax2, ay2 = coords:relativeToDrawList(x_track1, bar_y + bar_h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, ax1, ay1, ax2, ay2, track_col, 3)

    local cx1, cy1 = coords:relativeToDrawList(cx, bar_y)
    local _, cy2 = coords:relativeToDrawList(cx, bar_y + bar_h)
    reaper.ImGui_DrawList_AddLine(draw_list, cx1, cy1, cx1, cy2, (text_color & 0xFFFFFF00) | 0xCC, 1)

    local fill_col = (0x5599DDFF & 0xFFFFFF00) | 0xEE
    local extent = math.abs(norm) * half
    if extent > 0.25 then
        if norm > 0 then
            local fx1, fy1 = coords:relativeToDrawList(cx, bar_y + 1)
            local fx2, fy2 = coords:relativeToDrawList(cx + extent, bar_y + bar_h - 1)
            reaper.ImGui_DrawList_AddRectFilled(draw_list, fx1, fy1, fx2, fy2, fill_col, 2)
        else
            local fx1, fy1 = coords:relativeToDrawList(cx - extent, bar_y + 1)
            local fx2, fy2 = coords:relativeToDrawList(cx, bar_y + bar_h - 1)
            reaper.ImGui_DrawList_AddRectFilled(draw_list, fx1, fy1, fx2, fy2, fill_col, 2)
        end
    end
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
        local chip_margin = 4 + CHIP_ROW.button_rounding_content_pad()
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
        draw_snap_chip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, snap_on, chip_bg, chip_txt)

        local bottom = rel_y + height - chip_margin
        local zx = rel_x + chip_margin
        local zy = grid_top
        local zw = math.max(1, render_width - 2 * chip_margin)
        local zh = math.max(line_h + 10, bottom - zy)
        widget._ftc_swing_zone = { x = zx, y = zy, w = zw, h = zh }

        if widget._ftc_swing_dragging then
            draw_ftc_swing_drag_overlay(ctx, coords, draw_list, zx, zy, zw, text_color, rel_y, height)
        else
            local tw = reaper.ImGui_CalcTextSize(ctx, display)
            local ty = zy + math.max(0, (bottom - zy - line_h) / 2)
            local tpx, tpy = coords:relativeToDrawList(rel_x + (render_width - tw) / 2, ty)
            reaper.ImGui_DrawList_AddText(draw_list, tpx, tpy, text_color, display)
        end
        return
    end

    local _, _, chip_w, chip_h = snap_chip_metrics(ctx)
    local chip_x = rel_x + SNAP_CHIP_MARGIN_L + CHIP_ROW.button_rounding_content_pad()
    local chip_y = rel_y + (height - chip_h) / 2
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
        draw_snap_chip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, snap_on, chip_bg, chip_txt)
    end

    local zx = rel_x + lw + 6
    local zy = rel_y + 4
    local zw = math.max(20, render_width - lw - 12)
    local zh = math.max(line_h + 8, height - 8)
    widget._ftc_swing_zone = { x = zx, y = zy, w = zw, h = zh }

    if widget._ftc_swing_dragging then
        draw_ftc_swing_drag_overlay(ctx, coords, draw_list, zx, zy, zw, text_color, rel_y, height)
    else
        local tw = reaper.ImGui_CalcTextSize(ctx, display)
        local tx = rel_x + lw + (render_width - lw - tw) / 2
        local ty = rel_y + (height - line_h) / 2
        local tpx, tpy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, tpx, tpy, text_color, display)
    end
end

local widget = {
    name = "FTC Adaptive Grid",
    category = "Time, grid & tempo",
    type = "display",
    update_interval = 0.15,
    description = "FeedTheCat Adaptive Grid: snap chip (Magnet icon or SNAP) + grid readout. Click grid area to open Adaptive grid menu. When no valid saved folder, looks for Adaptive grid menu.lua under Scripts/FTC/Adaptive Grid (and common casing variants) in your REAPER resource path.",
    label = "",
    chip_widget = true,

    getLayoutWidth = function(self, ctx)
        if not ftc_menu_path_ok(self) and not self._preview_mode and not self._preview_width_cap then
            local mw = reaper.ImGui_CalcTextSize(ctx, "Click: select Adaptive grid menu.lua")
            return math.max(CONFIG.SIZES.MIN_WIDTH or 30, mw + 16 + CHIP_ROW.button_rounding_content_pad())
        end
        local lw = snap_left_allocation_w(ctx)
        local R = CHIP_ROW.button_rounding_content_pad()
        local readout_tw = horizontal_readout_text_width(ctx)
        local w = math.max(CONFIG.SIZES.MIN_WIDTH or 30, lw + readout_tw + H_READOUT_PAD + R)
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
        local m = 4 + CHIP_ROW.button_rounding_content_pad()
        local gap = 4
        return m + chip_h + gap + line_h + m + 22
    end,

    getValue = function(self)
        local text, is_adapt = grid_display_text(self)
        self._last_text = (is_adapt and "A " or "") .. text
        return self._last_text
    end,

    hitTestSubcontrols = function(self, ctx, coords, rel_x, rel_y, render_width, layout)
        if ctx and reaper.ImGui_GetMousePos then
            self._ftc_mouse_x, self._ftc_mouse_y = reaper.ImGui_GetMousePos(ctx)
        end
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

    onSubcontrolClick = function(self, sub, ctx)
        if not ftc_menu_path_ok(self) then pick_ftc_dir(self) return true end
        if sub == "snap" then
            reaper.Main_OnCommand(alt_held(ctx) and 41054 or 1157, 0)
            return true
        end
        if sub == "grid" then
            if ctx and alt_held(ctx) then
                return true
            end
            run_adaptive_menu(self)
            return true
        end
        return false
    end,

    onWidgetFrame = function(self, ctx, _button, is_hovered)
        if not ctx then
            return
        end

        local coords = self._last_coords
        local down = reaper.ImGui_IsMouseDown(ctx, 0)
        local prev_down = self._ftc_prev_lmb == true
        self._ftc_prev_lmb = down

        local zone = self._ftc_swing_zone
        if coords and zone and zone.w and zone.w > 0 and ftc_menu_path_ok(self) and is_hovered and alt_held(ctx) and down and not prev_down then
            local mx, my = coords:getRelativeMouse()
            if coords:pointInRelativeRect(mx, my, zone.x, zone.y, zone.w, zone.h) and not point_in_snap_chip(self, coords, mx, my) then
                self._ftc_swing_dragging = true
                if reaper.ImGui_GetMousePos then
                    self._ftc_swing_drag_prev_mx = select(1, reaper.ImGui_GetMousePos(ctx))
                end
            end
        end

        if not self._ftc_swing_dragging then
            return
        end

        if not down then
            self._ftc_swing_dragging = false
            self._ftc_swing_drag_prev_mx = nil
            return
        end

        local mx = select(1, reaper.ImGui_GetMousePos(ctx))
        local prev = self._ftc_swing_drag_prev_mx or mx
        local delta = mx - prev
        self._ftc_swing_drag_prev_mx = mx
        if delta == 0 then
            return
        end

        local r = { reaper.GetSetProjectGrid(0, 0) }
        local div = r[2]
        local swmode = r[3]
        local swamt = r[4]
        if type(div) ~= "number" or type(swmode) ~= "number" or type(swamt) ~= "number" then
            return
        end

        local sens = 0.002
        local new_amt = swamt + delta * sens
        if new_amt < 0 then
            new_amt = 0
        elseif new_amt > 1 then
            new_amt = 1
        end
        if math.abs(new_amt - swamt) > 1e-9 then
            reaper.GetSetProjectGrid(0, true, div, swmode, new_amt)
        end
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
            local chip_x = rel_x + SNAP_CHIP_MARGIN_L + CHIP_ROW.button_rounding_content_pad()
            local chip_y = rel_y + (height - chip_h) / 2
            local sep_x = chip_x + chip_w + SNAP_CHIP_GAP_BEFORE_SEP
            local lw = sep_x + SNAP_SEP_TO_GRID - rel_x
            local sep_c = (text_color & 0xFFFFFF00) | 0x55
            local x1, y1 = coords:relativeToDrawList(sep_x, rel_y + 6)
            local _, y2 = coords:relativeToDrawList(sep_x, rel_y + height - 6)
            reaper.ImGui_DrawList_AddLine(draw_list, x1, y1, x1, y2, sep_c, 1)
            local btn_bg = bg_color or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.BG.NORMAL)
            local chip_bg, chip_txt = COLOR_UTILS.widgetPillColors(text_color, btn_bg, { active = true, hover = false })
            draw_snap_chip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, true, chip_bg, chip_txt)
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
