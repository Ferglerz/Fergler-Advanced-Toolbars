-- widgets/ftc_adaptive_grid.lua
-- FeedTheCat Adaptive Grid / Gridbox-style grid readout for Advanced Toolbars.
-- Left: snap strip (Gridbox); grid area: click = same as running "Adaptive grid menu.lua";
-- Alt+hover shows swing %; Alt+drag adjusts swing; Alt+click toggles swing.
-- Right-click: small helper menu (full Gridbox "Customize" menu only exists on transport Gridbox).
-- Persist FTC folder in CONFIG.WIDGET_SAVED_STATES.ftc_adaptive_grid[<button id>].

local SEP = package.config:sub(1, 1)
local MENU_NAME = "Adaptive grid menu.lua"
local GRIDBOX_NAME = "Gridbox.lua"
local EXT_ADAPT = "FTC.AdaptiveGrid"

-- Cached callables from Gridbox.lua (see LUA_SCRIPT_EXTRACT.load_global_function_cached).
local ftc_gridbox_fn_cache = {}

local function concat_dir(dir)
    if not dir or dir == "" then return nil end
    local last = dir:sub(-1)
    return (last == "/" or last == "\\") and (dir .. MENU_NAME) or (dir .. SEP .. MENU_NAME)
end

local function gridbox_path(dir)
    if not dir or dir == "" then return nil end
    local last = dir:sub(-1)
    return (last == "/" or last == "\\") and (dir .. GRIDBOX_NAME) or (dir .. SEP .. GRIDBOX_NAME)
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

-- True only when config has a folder and Adaptive grid menu.lua exists there.
local function ftc_menu_path_ok(self)
    local dir = get_dir(self)
    local p = dir and concat_dir(dir)
    return p and reaper.file_exists(p) or false
end

local function set_dir(self, dir)
    local store = ensure_store()
    local key = state_key(self)
    store[key] = store[key] or {}
    local prev = store[key].ftc_dir
    if prev and prev ~= dir then LUA_SCRIPT_EXTRACT.invalidate_script_cache(ftc_gridbox_fn_cache, gridbox_path(prev)) end
    store[key].ftc_dir = dir
    LUA_SCRIPT_EXTRACT.invalidate_script_cache(ftc_gridbox_fn_cache, gridbox_path(dir))
    if CONFIG_MANAGER and CONFIG_MANAGER.saveMainConfig then CONFIG_MANAGER:saveMainConfig() end
end

local function pick_ftc_dir(self)
    -- API: (initial_folder, dialog_title, extension) — extension without dot
    local rv, path = reaper.GetUserFileNameForRead("", "Select " .. MENU_NAME .. " (in your FTC Adaptive grid folder)", "lua")
    if not rv or not path or path == "" then return end
    path = path:gsub("[\\/][^\\/]+$", "")
    if path == "" then return end
    local menu_path = concat_dir(path)
    if not menu_path or not reaper.file_exists(menu_path) then
        reaper.MB("Could not find:\n" .. tostring(menu_path), "FTC Adaptive Grid", 0)
        return
    end
    set_dir(self, path)
    self._menu_cmd, self._ftc_api = nil, nil
end

-- Last resort if Gridbox.lua is missing or extraction fails.
local function decimal_to_fraction_fallback(x, err)
    err = err or 1e-10
    local n = math.floor(x) ; x = x - n
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

local function load_gridbox_named_function(dir, func_name)
    local path = gridbox_path(dir)
    if not path or not reaper.file_exists(path) then return nil end
    return LUA_SCRIPT_EXTRACT.load_global_function_cached(ftc_gridbox_fn_cache, path, func_name, {})
end

local function decimal_to_fraction_for_widget(self, x)
    local dir = self and get_dir(self)
    local fn = dir and load_gridbox_named_function(dir, "DecimalToFraction") or nil
    if fn then return fn(x) end
    return decimal_to_fraction_fallback(x)
end

local function grid_display_text(self)
    if reaper.GetToggleCommandState(40904) == 1 then return "Frame", false end
    local _, grid_div, swing, swing_amt = reaper.GetSetProjectGrid(0, 0)
    if grid_div ~= grid_div then grid_div = 1 end
    if swing == 3 then return "Measure", false end
    local is_adaptive = (tonumber(reaper.GetExtState(EXT_ADAPT, "main_mult")) or 0) ~= 0
    local num, denom = decimal_to_fraction_for_widget(self, grid_div)
    -- Simplify triplet/dotted/etc logic if possible
    local suffix = ""
    if grid_div > 1 then
        if 2 * grid_div % (2 / 3) == 0 then suffix, denom = "T", denom * 2 / 3
        elseif 4 * grid_div % (4 / 5) == 0 then suffix, denom = "Q", denom * 4 / 5
        elseif 4 * grid_div % (4 / 7) == 0 then suffix, denom = "S", denom * 4 / 7
        elseif 2 * grid_div % 3 == 0 then suffix, denom, num = "D", denom / 2, num / 3 end
    else
        if 2 / grid_div % 3 == 0 then suffix, denom = "T", denom * 2 / 3
        elseif 4 / grid_div % 5 == 0 then suffix, denom = "Q", denom * 4 / 5
        elseif 4 / grid_div % 7 == 0 then suffix, denom = "S", denom * 4 / 7
        elseif 2 / grid_div % (2 / 3) == 0 then suffix, denom, num = "D", denom / 2, num / 3 end
    end
    if num > 1 and denom % num == 0 then denom, num = denom / num, 1 end
    local text = (num >= denom and num % denom == 0) and ("%.0f%s"):format(num / denom, suffix)
        or ("%.0f/%.0f%s"):format(num, denom, suffix)
    return text, is_adaptive, swing, swing_amt
end

local function alt_held()
    return reaper.JS_Mouse_GetState and reaper.JS_Mouse_GetState(16) == 16 or false
end

local function ensure_menu_cmd(self)
    if self._menu_cmd and self._menu_cmd ~= 0 then return true end
    local dir = get_dir(self) ; if not dir then return false end
    local menu_path = concat_dir(dir)
    if not menu_path or not reaper.file_exists(menu_path) then return false end
    self._menu_cmd = reaper.AddRemoveReaScript(true, 0, menu_path, true)
    return self._menu_cmd ~= nil and self._menu_cmd ~= 0
end

-- Load and run grid menu script, caching its env table
local function load_fresh_ftc_env(self)
    local dir = get_dir(self) ; if not dir then return nil end
    local menu_path = concat_dir(dir)
    if not menu_path or not reaper.file_exists(menu_path) or not ensure_menu_cmd(self) then return nil end
    local env = setmetatable({ menu = true, cmd = self._menu_cmd }, { __index = _G })
    env._G = env
    local chunk, err = loadfile(menu_path, "bt", env)
    if not chunk then reaper.ShowConsoleMsg("FTC Adaptive Grid: loadfile failed: " .. tostring(err) .. "\n") ; return nil end
    local ok, err2 = pcall(chunk)
    if not ok then reaper.ShowConsoleMsg("FTC Adaptive Grid: " .. tostring(err2) .. "\n") ; return nil end
    if type(env.menu) ~= "table" then return nil end
    return env
end

local function ftc_api_env(self)
    if self._ftc_api then return self._ftc_api end
    local env = load_fresh_ftc_env(self)
    if env then self._ftc_api = env end
    return env
end

local function show_embedded_ftc_menu(self)
    if not get_dir(self) then pick_ftc_dir(self) return end
    local env = load_fresh_ftc_env(self)
    if not env or type(env.MenuCreateRecursive) ~= "function" or type(env.MenuReturnRecursive) ~= "function" or type(env.ShowMenu) ~= "function" then return end
    self._ftc_api = env
    local ret = env.ShowMenu(env.MenuCreateRecursive(env.menu))
    env.MenuReturnRecursive(env.menu, ret)
    if env.GetGridMultiplier and env.UpdateToolbarToggleStates then
        env.UpdateToolbarToggleStates(0, env.GetGridMultiplier())
        env.UpdateToolbarToggleStates(32060, env.GetMIDIGridMultiplier())
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

local widget = {
    name = "FTC Adaptive Grid",
    type = "display",
    update_interval = 0.15,
    description = "FeedTheCat Adaptive Grid readout: SNAP chip + grid (Alt: swing). Set folder to Adaptive grid scripts once.",
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
        local m = 4
        local gap = 4
        local text_block = 2 * line_h + 2
        local bar_reserve = 3 + 6
        return m + chip_h + gap + text_block + bar_reserve + m
    end,

    getValue = function(self)
        local text, is_adapt, swing, swing_amt = grid_display_text(self)
        self._last_text = (is_adapt and "A " or "") .. text
        self._cached_swing = swing
        self._cached_swing_amt = swing_amt
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

    -- If hit-test ever misses, still prompt until menu file is valid.
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
            if alt_held() and self._swing_drag and not self._swing_moved then
                local env = ftc_api_env(self)
                if env then
                    env.SetStraightGrid()
                    local _, grid_div, sw, sa = reaper.GetSetProjectGrid(0, 0)
                    local new_swing = sw ~= 1 and 1 or 0
                    reaper.GetSetProjectGrid(0, 1, nil, new_swing, sa)
                    env.SaveProjectGrid(grid_div, new_swing, sa)
                end
                self._suppress_grid_menu = true
            end
            self._swing_drag, self._swing_moved, self._swing_armed_alt = false, false, false
            if self._suppress_grid_menu then self._suppress_grid_menu = false return true end
            if ensure_menu_cmd(self) then
                reaper.Main_OnCommand(self._menu_cmd, 0)
            else
                show_embedded_ftc_menu(self)
            end
            return true
        end
        return false
    end,

    onRightClick = function(self)
        if not ftc_menu_path_ok(self) then pick_ftc_dir(self) return end
        local sub = self.hitTestSubcontrols(self, nil, self._last_coords, self._last_rel_x, self._last_rel_y, self._last_rw, nil)
        if sub == "snap" then reaper.Main_OnCommand(40071, 0) return end
        local env = ftc_api_env(self)
        if not env or type(env.MenuCreateRecursive) ~= "function" or type(env.MenuReturnRecursive) ~= "function" or type(env.ShowMenu) ~= "function" then return end
        local menu = {
            { title = "Adaptive grid menu…", OnReturn = function() show_embedded_ftc_menu(self) end },
            { title = "Snap/Grid settings", OnReturn = function() reaper.Main_OnCommand(40071, 0) end },
            { separator = true },
            { title = "Choose FTC Adaptive Grid folder…", OnReturn = function() pick_ftc_dir(self) end },
        }
        local ret = env.ShowMenu(env.MenuCreateRecursive(menu))
        env.MenuReturnRecursive(menu, ret)
    end,

    onMouseWheel = function(self, wheel)
        if not ftc_menu_path_ok(self) then pick_ftc_dir(self) return end
        local env = ftc_api_env(self); if not env then return end
        local osn = reaper.GetOS()
        local scroll_dir = tonumber(reaper.GetExtState("FTC.GridBox", "scroll_dir")) or ((osn:match("OSX") or osn:match("macOS")) and -1 or 1)
        wheel = wheel * scroll_dir
        local mouse_state = reaper.JS_Mouse_GetState and reaper.JS_Mouse_GetState(20) or 0
        local _, grid_div, swing, swing_amt = reaper.GetSetProjectGrid(0, 0)
        if mouse_state & 16 == 16 then
            wheel = wheel / math.abs(wheel)
            if swing == 0 then
                env.SetStraightGrid()
                reaper.GetSetProjectGrid(0, 1, nil, 1, swing_amt)
            end
            local amt = wheel * (mouse_state == 20 and 0.01 or 0.03)
            reaper.GetSetProjectGrid(0, 1, nil, 1, swing_amt + amt)
            local _, gd, sw, sa = reaper.GetSetProjectGrid(0, 0)
            env.SaveProjectGrid(gd, sw, sa)
            return
        end
        local factor = tonumber(reaper.GetExtState(EXT_ADAPT, "zoom_div")) or 2
        local min_grid_div = tonumber(reaper.GetExtState(EXT_ADAPT, "min_limit")) or (1 / 4096 * 2 / 3)
        local max_grid_div = tonumber(reaper.GetExtState(EXT_ADAPT, "max_limit")) or (4096 * 3 / 2)
        local new_div = wheel < 0 and grid_div * factor or grid_div / factor
        if (new_div < min_grid_div and wheel < 0) or (new_div > max_grid_div and wheel > 0) then return end
        if not env.LoadProjectGrid(new_div) then
            reaper.GetSetProjectGrid(0, 1, new_div, swing, swing_amt)
        end
    end,

    -- Signature matches Renderers/_Widgets.lua renderDisplayWidget: renderCustom(ctx, widget, ...)
    renderCustom = function(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local height = (layout and layout.height) or CONFIG.SIZES.HEIGHT or 38
        local bar_h, m = 3, 4
        local is_vert = layout and layout.is_vertical
        widget._last_coords, widget._last_rel_x, widget._last_rel_y, widget._last_rw = coords, rel_x, rel_y, render_width
        widget._snap_chip_x, widget._snap_chip_y, widget._snap_chip_w, widget._snap_chip_h = nil

        -- Widget picker: show SNAP chip, divider, and sample grid text (no FTC folder required)
        if widget._preview_mode then
            local _, _, chip_w, chip_h = snap_chip_metrics(ctx)
            local chip_x, chip_y = rel_x + SNAP_CHIP_MARGIN_L, rel_y + (height - chip_h) / 2
            local sep_x = chip_x + chip_w + SNAP_CHIP_GAP_BEFORE_SEP
            local grid_left = sep_x + SNAP_SEP_TO_GRID
            local lw = grid_left - rel_x
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

        -- Vertical toolbar: SNAP chip full width, grid readout below (grouped column)
        if is_vert then
            if not ftc_menu_path_ok(widget) then
                widget._ftc_grid_left = rel_x
                local msg = "Click: select Adaptive grid menu.lua"
                local tw = reaper.ImGui_CalcTextSize(ctx, msg)
                local tx, ty = coords:relativeToDrawList(rel_x + (render_width - tw) / 2, rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2)
                reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_color, msg)
                return
            end

            local mx, my = coords:getRelativeMouse()
            local inside = coords:pointInRelativeRect(mx, my, rel_x, rel_y, render_width, height)
            local alt_down = alt_held() or ((reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0)
            local _, _, _nw, chip_h = snap_chip_metrics(ctx)
            local chip_margin = 4
            local chip_x = rel_x + chip_margin
            local chip_y = rel_y + chip_margin
            local chip_w = math.max(1, render_width - 2 * chip_margin)
            local grid_top = chip_y + chip_h + 4
            widget._snap_chip_x, widget._snap_chip_y = chip_x, chip_y
            widget._snap_chip_w, widget._snap_chip_h = chip_w, chip_h
            widget._ftc_grid_left = rel_x

            local _, _, swing, swing_amt = reaper.GetSetProjectGrid(0, 0)
            if swing ~= 1 then swing_amt = 0 end

            local line_h = reaper.ImGui_GetTextLineHeight(ctx)
            local show_alt_swing = inside and alt_down and my >= grid_top
            local bar_reserve = ((math.abs(swing_amt) > 0.0001 or show_alt_swing) and (render_width - 2 * m > 8)) and (bar_h + 6) or 0
            local text_h_budget = math.max(0, height - (grid_top - rel_y) - bar_reserve - m)

            if inside and alt_down and my >= grid_top then
                if reaper.ImGui_IsMouseClicked(ctx, 0) then
                    widget._swing_drag, widget._swing_start_mx, widget._swing_moved, widget._swing_armed_alt = true, mx, false, true
                end
                if widget._swing_drag and reaper.ImGui_IsMouseDown(ctx, 0) then
                    if math.abs(mx - (widget._swing_start_mx or mx)) > 2 then widget._swing_moved = true end
                    local env = ftc_api_env(widget)
                    if env then
                        local swing_w = math.max(1, render_width - 2 * m)
                        local amt = 2 * (mx - (rel_x + m)) / swing_w - 1
                        amt = math.max(-1, math.min(1, amt))
                        amt = math.floor(amt * 100 + 0.5) / 100
                        local _, grid_div, sw = reaper.GetSetProjectGrid(0, 0)
                        if sw == 0 then
                            env.SetStraightGrid()
                            reaper.GetSetProjectGrid(0, 1, nil, 1, amt)
                        end
                        reaper.GetSetProjectGrid(0, 1, nil, 1, amt)
                        env.SaveProjectGrid(grid_div, 1, amt)
                        widget._suppress_grid_menu = true
                    end
                end
            end

            if reaper.ImGui_IsMouseReleased(ctx, 0) and widget._swing_moved then
                widget._suppress_grid_menu = true
            end

            local display = widget._last_text or widget.value or "—"
            local swing_line1, swing_line2
            if show_alt_swing then
                swing_line1 = "Swing:"
                swing_line2 = (swing == 1) and (math.floor(swing_amt * 100 + 0.5) .. "%") or "off"
                display = swing_line1 .. " " .. swing_line2
            end

            local sep_c = (text_color & 0xFFFFFF00) | 0x55
            local hsx1, hsy1 = coords:relativeToDrawList(rel_x + m, chip_y + chip_h + 2)
            local hsx2, _ = coords:relativeToDrawList(rel_x + render_width - m, chip_y + chip_h + 2)
            reaper.ImGui_DrawList_AddLine(draw_list, hsx1, hsy1, hsx2, hsy1, sep_c, 1)

            local snap_on = reaper.GetToggleCommandState(1157) == 1
            local snap_hover = coords:pointInRelativeRect(mx, my, chip_x, chip_y, chip_w, chip_h)
            local btn_bg = bg_color or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.BG.NORMAL)
            local chip_bg, chip_txt = COLOR_UTILS.widgetPillColors(text_color, btn_bg, {
                active = snap_on, hover = snap_hover,
            })
            DRAWING.drawTextChip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, SNAP_CHIP_LABEL, {
                bg_color = chip_bg, text_color = chip_txt, rounding = SNAP_CHIP_ROUND,
            })

            local use_swing_two_line = show_alt_swing and swing_line1 and swing_line2
                and text_h_budget >= 2 * line_h + 2
            if use_swing_two_line then
                local w1 = reaper.ImGui_CalcTextSize(ctx, swing_line1)
                local w2 = reaper.ImGui_CalcTextSize(ctx, swing_line2)
                local span = math.max(w1, w2)
                local block_h = 2 * line_h
                local ty0 = grid_top + (text_h_budget - block_h) / 2
                local tx0 = rel_x + (render_width - span) / 2
                local dx1, dy1 = coords:relativeToDrawList(tx0 + (span - w1) / 2, ty0)
                local dx2, dy2 = coords:relativeToDrawList(tx0 + (span - w2) / 2, ty0 + line_h)
                reaper.ImGui_DrawList_AddText(draw_list, dx1, dy1, text_color, swing_line1)
                reaper.ImGui_DrawList_AddText(draw_list, dx2, dy2, text_color, swing_line2)
            else
                local tw = reaper.ImGui_CalcTextSize(ctx, display)
                local tx = rel_x + (render_width - tw) / 2
                local ty = grid_top + math.max(0, (text_h_budget - line_h) / 2)
                local tpx, tpy = coords:relativeToDrawList(tx, ty)
                reaper.ImGui_DrawList_AddText(draw_list, tpx, tpy, text_color, display)
            end

            local bar_y = rel_y + height - bar_h - 3
            if (math.abs(swing_amt) > 0.0001 or show_alt_swing) and render_width - 2 * m > 8 then
                local accent = 0x66AAFFFF
                local right_w = render_width - 2 * m
                local x0 = rel_x + m
                local len = math.ceil(math.abs(swing_amt) * right_w / 2)
                local x_start = x0 + math.floor(right_w / 2)
                if swing_amt < 0 then x_start = x_start - len end
                local bx1, by1 = coords:relativeToDrawList(x_start, bar_y)
                local bx2, _ = coords:relativeToDrawList(x_start + math.max(1, len), bar_y + bar_h)
                reaper.ImGui_DrawList_AddRectFilled(draw_list, bx1, by1, bx2, by1 + bar_h, accent, 1)
            end
            return
        end

        -- If FTC menu not configured, prompt user
        if not ftc_menu_path_ok(widget) then
            widget._ftc_grid_left = rel_x
            local msg = "Click: select Adaptive grid menu.lua"
            local tw = reaper.ImGui_CalcTextSize(ctx, msg)
            local tx, ty = coords:relativeToDrawList(rel_x + (render_width - tw) / 2, rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2)
            reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_color, msg)
            return
        end

        local mx, my = coords:getRelativeMouse()
        local inside = coords:pointInRelativeRect(mx, my, rel_x, rel_y, render_width, height)
        local alt_down = alt_held() or ((reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0)
        local _, _, chip_w, chip_h = snap_chip_metrics(ctx)
        local chip_x, chip_y = rel_x + SNAP_CHIP_MARGIN_L, rel_y + (height - chip_h) / 2
        local sep_x = chip_x + chip_w + SNAP_CHIP_GAP_BEFORE_SEP
        local grid_left = sep_x + SNAP_SEP_TO_GRID
        local narrow = grid_left + 48 > rel_x + render_width
        local lw = 0
        if narrow then
            grid_left = rel_x
            widget._ftc_grid_left = rel_x
        else
            lw = grid_left - rel_x
            widget._snap_chip_x, widget._snap_chip_y = chip_x, chip_y
            widget._snap_chip_w, widget._snap_chip_h = chip_w, chip_h
            widget._ftc_grid_left = grid_left
        end

        local _, _, swing, swing_amt = reaper.GetSetProjectGrid(0, 0)
        if swing ~= 1 then swing_amt = 0 end

        if inside and alt_down and mx >= grid_left then
            if reaper.ImGui_IsMouseClicked(ctx, 0) then
                widget._swing_drag, widget._swing_start_mx, widget._swing_moved, widget._swing_armed_alt = true, mx, false, true
            end
            if widget._swing_drag and reaper.ImGui_IsMouseDown(ctx, 0) then
                if math.abs(mx - (widget._swing_start_mx or mx)) > 2 then widget._swing_moved = true end
                local env = ftc_api_env(widget)
                if env then
                    local swing_w = math.max(1, render_width - lw)
                    local amt = 2 * (mx - grid_left) / swing_w - 1
                    amt = math.max(-1, math.min(1, amt))
                    amt = math.floor(amt * 100 + 0.5) / 100
                    local _, grid_div, sw = reaper.GetSetProjectGrid(0, 0)
                    if sw == 0 then
                        env.SetStraightGrid()
                        reaper.GetSetProjectGrid(0, 1, nil, 1, amt)
                    end
                    reaper.GetSetProjectGrid(0, 1, nil, 1, amt)
                    env.SaveProjectGrid(grid_div, 1, amt)
                    widget._suppress_grid_menu = true
                end
            end
        end

        if reaper.ImGui_IsMouseReleased(ctx, 0) and widget._swing_moved then
            widget._suppress_grid_menu = true
        end

        local display = widget._last_text or widget.value or "—"
        local show_alt_swing = inside and alt_down and mx >= grid_left
        local swing_line1, swing_line2
        if show_alt_swing then
            swing_line1 = "Swing:"
            swing_line2 = (swing == 1) and (math.floor(swing_amt * 100 + 0.5) .. "%") or "off"
            display = swing_line1 .. " " .. swing_line2
        end

        -- Draw separator
        local sep_c = (text_color & 0xFFFFFF00) | 0x55
        if lw > 0 then
            local x1, y1 = coords:relativeToDrawList(sep_x, rel_y + 6)
            local _, y2 = coords:relativeToDrawList(sep_x, rel_y + height - 6)
            reaper.ImGui_DrawList_AddLine(draw_list, x1, y1, x1, y2, sep_c, 1)
        end

        -- Draw snap chip
        if lw > 0 then
            local snap_on = reaper.GetToggleCommandState(1157) == 1
            local snap_hover = coords:pointInRelativeRect(mx, my, chip_x, chip_y, chip_w, chip_h)
            local btn_bg = bg_color or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.BG.NORMAL)
            local chip_bg, chip_txt = COLOR_UTILS.widgetPillColors(text_color, btn_bg, {
                active = snap_on, hover = snap_hover,
            })
            DRAWING.drawTextChip(ctx, coords, draw_list, chip_x, chip_y, chip_w, chip_h, SNAP_CHIP_LABEL, {
                bg_color = chip_bg, text_color = chip_txt, rounding = SNAP_CHIP_ROUND,
            })
        end

        -- Draw grid text (Alt swing: two lines after ":" when vertical room allows)
        local line_h = reaper.ImGui_GetTextLineHeight(ctx)
        local bar_reserve = ((math.abs(swing_amt) > 0.0001 or show_alt_swing) and lw < render_width - m * 2) and (bar_h + 6) or 0
        local text_h_budget = height - bar_reserve
        local use_swing_two_line = show_alt_swing and swing_line1 and swing_line2
            and text_h_budget >= 2 * line_h + 2
        if use_swing_two_line then
            local w1 = reaper.ImGui_CalcTextSize(ctx, swing_line1)
            local w2 = reaper.ImGui_CalcTextSize(ctx, swing_line2)
            local span = math.max(w1, w2)
            local block_h = 2 * line_h
            local ty0 = rel_y + (text_h_budget - block_h) / 2
            local tx0 = rel_x + lw + (render_width - lw - span) / 2
            local dx1, dy1 = coords:relativeToDrawList(tx0 + (span - w1) / 2, ty0)
            local dx2, dy2 = coords:relativeToDrawList(tx0 + (span - w2) / 2, ty0 + line_h)
            reaper.ImGui_DrawList_AddText(draw_list, dx1, dy1, text_color, swing_line1)
            reaper.ImGui_DrawList_AddText(draw_list, dx2, dy2, text_color, swing_line2)
        else
            local tw = reaper.ImGui_CalcTextSize(ctx, display)
            local tx = rel_x + lw + (render_width - lw - tw) / 2
            local ty = rel_y + (height - line_h) / 2
            local tpx, tpy = coords:relativeToDrawList(tx, ty)
            reaper.ImGui_DrawList_AddText(draw_list, tpx, tpy, text_color, display)
        end

        -- Draw swing bar
        local bar_y = rel_y + height - bar_h - 3
        if (math.abs(swing_amt) > 0.0001 or show_alt_swing) and lw < render_width - m * 2 then
            local accent = 0x66AAFFFF
            local right_w = render_width - lw - 2 * m
            local x0 = grid_left + m
            local len = math.ceil(math.abs(swing_amt) * right_w / 2)
            local x_start = x0 + math.floor(right_w / 2)
            if swing_amt < 0 then x_start = x_start - len end
            local bx1, by1 = coords:relativeToDrawList(x_start, bar_y)
            local bx2, _ = coords:relativeToDrawList(x_start + math.max(1, len), bar_y + bar_h)
            reaper.ImGui_DrawList_AddRectFilled(draw_list, bx1, by1, bx2, by1 + bar_h, accent, 1)
        end
    end,
}

return widget
