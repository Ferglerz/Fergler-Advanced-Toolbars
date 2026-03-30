-- FTC Adaptive Grid toolbar companion: shows arrange grid readout and runs Feed The Cat's
-- own Lua files when installed (menu / lock). Does not change grid from this widget.

local ADAPTIVE_DIR = "FTC Tools/Adaptive grid"
local REAPACK_HINT_URL = "https://reapack.com"

local MENU_NAME_HINTS = { "menu", "settings", "options", "config" }
local LOCK_NAME_HINTS = { "lock", "freeze", "latch" }

local widget = {
    name = "FTC Adaptive Grid",
    type = "display",
    width = 168,
    label = "",
    update_interval = 0.15,
    description = "Shows arrange grid division; opens Feed The Cat Adaptive Grid scripts when installed.",
    _grid_text = "",
    _menu_path = nil,
    _lock_path = nil,
    _last_scan_t = 0,
}

local function join_under_scripts(rel)
    return UTILS.joinPath(reaper.GetResourcePath(), "Scripts", rel)
end

local function norm(s)
    return (s or ""):lower()
end

local function format_grid_label(div, swingmode)
    if swingmode == 3 then
        return "Measure"
    end
    if not div or div <= 0 then
        return "—"
    end
    local inv = 1 / div
    local n = math.floor(inv + 0.5)
    if math.abs(inv - n) < 0.0001 and n >= 1 then
        return "1/" .. tostring(n)
    end
    return string.format("%.4g", div)
end

local function list_lua_in_dir(abs_dir)
    reaper.EnumerateFiles(abs_dir, -1)
    local out = {}
    local i = 0
    while true do
        local name = reaper.EnumerateFiles(abs_dir, i)
        if not name then
            break
        end
        if name:match("%.lua$") then
            out[#out + 1] = UTILS.joinPath(abs_dir, name)
        end
        i = i + 1
    end
    return out
end

local function score_name(fname_lower, hints)
    for _, h in ipairs(hints) do
        if fname_lower:find(h, 1, true) then
            return 1
        end
    end
    return 0
end

local function pick_script(files, hints, avoid_name_sub)
    local best_path, best_score = nil, -1
    for _, path in ipairs(files) do
        local base = path:match("([^/\\]+)$") or path
        local low = norm(base)
        if not avoid_name_sub or not low:find(avoid_name_sub, 1, true) then
            local sc = score_name(low, hints)
            if sc > best_score then
                best_score, best_path = sc, path
            end
        end
    end
    if best_score > 0 then
        return best_path
    end
    return nil
end

-- Prefer not to bind the menu button to the always-on "adapt to zoom" defer script when other .lua files exist.
local function pick_menu_path(files)
    local without_zoom = {}
    for _, path in ipairs(files) do
        local low = norm(path:match("([^/\\]+)$") or path)
        if not (low:find("zoom", 1, true) and low:find("adapt", 1, true)) then
            without_zoom[#without_zoom + 1] = path
        end
    end
    local pool = #without_zoom > 0 and without_zoom or files
    return pick_script(pool, MENU_NAME_HINTS, nil) or pick_script(pool, { "gridbox" }, nil)
end

local function scan_ftc_paths(self)
    local dir = join_under_scripts(ADAPTIVE_DIR)
    if not reaper.file_exists(dir) then
        self._menu_path, self._lock_path = nil, nil
        return
    end

    local files = list_lua_in_dir(dir)
    if #files == 0 then
        self._menu_path, self._lock_path = nil, nil
        return
    end

    local menu = pick_menu_path(files)

    local lock = pick_script(files, LOCK_NAME_HINTS, nil)
    if lock and menu and norm(lock) == norm(menu) then
        lock = nil
    end

    local function exists(p)
        return p and reaper.file_exists(p)
    end

    self._menu_path = exists(menu) and menu or nil
    self._lock_path = exists(lock) and lock or nil
end

local function maybe_rescan(self)
    local t = reaper.time_precise()
    if t - (self._last_scan_t or 0) < 2.0 then
        return
    end
    self._last_scan_t = t
    scan_ftc_paths(self)
end

local function run_lua_file(path)
    if not path or not reaper.file_exists(path) then
        return false
    end
    local chunk, err = loadfile(path)
    if not chunk then
        reaper.ShowMessageBox("Could not load script:\n" .. tostring(path) .. "\n\n" .. tostring(err), "FTC Adaptive Grid", 0)
        return false
    end
    local ok, err2 = pcall(chunk)
    if not ok then
        reaper.ShowMessageBox("Script error:\n" .. tostring(err2), "FTC Adaptive Grid", 0)
        return false
    end
    return true
end

local function open_url(url)
    if not url or url == "" then
        return
    end
    local osname = reaper.GetOS()
    local cmd
    if osname:match("Win") then
        cmd = 'cmd /c start "" "' .. url:gsub('"', "") .. '"'
    elseif osname:match("OSX") or osname:match("macOS") then
        cmd = 'open "' .. url:gsub('"', '\\"') .. '"'
    else
        cmd = 'xdg-open "' .. url:gsub('"', '\\"') .. '"'
    end
    reaper.ExecProcess(cmd, -2)
end

local function show_missing_ftc_message()
    local msg = "Feed The Cat — Adaptive Grid scripts were not found under:\n\n"
        .. "Scripts/"
        .. ADAPTIVE_DIR
        .. "\n\n"
        .. "Install the package in ReaPack (or copy the scripts there), then rescan or restart.\n\n"
        .. "Open ReaPack in your browser?\n"
        .. REAPACK_HINT_URL
    local r = reaper.ShowMessageBox(msg, "FTC Adaptive Grid — not installed", 4)
    if r == 6 then
        open_url(REAPACK_HINT_URL)
    end
end

-- Layout (matches chip-style widgets like RMS status)
local BTN = 22
local GAP = 4

function widget.getLayoutWidth(self, ctx)
    maybe_rescan(self)
    local _, div, swingmode = reaper.GetSetProjectGrid(0, false)
    local label = format_grid_label(div, swingmode)
    reaper.ImGui_PushFont(ctx, reaper.ImGui_GetFont(ctx), CONFIG.SIZES.TEXT or 12)
    local tw = reaper.ImGui_CalcTextSize(ctx, label ~= "" and label or "1/16")
    reaper.ImGui_PopFont(ctx)
    local w = BTN + GAP + tw + GAP + BTN + 8
    return math.max(self.width or 168, math.floor(w))
end

function widget.getValue(self)
    maybe_rescan(self)
    local _, div, swingmode = reaper.GetSetProjectGrid(0, false)
    self._grid_text = format_grid_label(div, swingmode)
    return 0
end

local function chip_rects(rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local cy = rel_y + math.floor((h - BTN) / 2)
    local lock_x = rel_x + 4
    local menu_x = rel_x + render_width - BTN - 4
    local text_x = lock_x + BTN + GAP
    local text_w = math.max(24, menu_x - GAP - text_x)
    return lock_x, cy, text_x, cy, text_w, BTN, menu_x, cy
end

function widget.hitTestSubcontrols(_ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local lx, ly, tx, ty, tw, th, mxp, myp = chip_rects(rel_x, rel_y, render_width)
    if coords:pointInRelativeRect(mx, my, lx, ly, BTN, BTN) then
        return "lock"
    end
    if coords:pointInRelativeRect(mx, my, mxp, myp, BTN, BTN) then
        return "menu"
    end
    if coords:pointInRelativeRect(mx, my, tx, ty, tw, th) then
        return "menu"
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "lock" then
        if self._lock_path then
            run_lua_file(self._lock_path)
        elseif self._menu_path then
            run_lua_file(self._menu_path)
        else
            show_missing_ftc_message()
        end
        return true
    end
    if sub_id == "menu" then
        if self._menu_path then
            run_lua_file(self._menu_path)
        else
            show_missing_ftc_message()
        end
        return true
    end
    return false
end

function widget.onRightClick(self)
    show_missing_ftc_message()
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local mx, my = coords:getRelativeMouse()
    local lx, ly, tx, ty, tw, _, mxp, myp = chip_rects(rel_x, rel_y, render_width)

    local function draw_chip(cx, cy, label, active, has_target)
        local x1, y1 = coords:relativeToDrawList(cx, cy)
        local x2, y2 = coords:relativeToDrawList(cx + BTN, cy + BTN)
        local idle = 0x101010FF
        local stroke = has_target and (text_color & 0xFFFFFF00 | 0xFF) or 0x555555FF
        local fill = active and (text_color & 0xFFFFFF00 | 0x55) or idle
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, fill, 4)
        reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, stroke, 4, 0, 1.0)
        local twl = reaper.ImGui_CalcTextSize(ctx, label)
        local tdx = cx + (BTN - twl) / 2
        local tdy = cy + (BTN - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local tx0, ty0 = coords:relativeToDrawList(tdx, tdy)
        reaper.ImGui_DrawList_AddText(draw_list, tx0, ty0, text_color, label)
    end

    local lock_hover = coords:pointInRelativeRect(mx, my, lx, ly, BTN, BTN)
    local menu_hover = coords:pointInRelativeRect(mx, my, mxp, myp, BTN, BTN)
    local text_hover = coords:pointInRelativeRect(mx, my, tx, ty, tw, BTN)

    local lock_lbl = self._lock_path and "L" or (self._menu_path and "-" or "?")
    draw_chip(lx, ly, lock_lbl, lock_hover, self._lock_path or self._menu_path)
    draw_chip(mxp, myp, "v", menu_hover, self._menu_path)

    local label = self._grid_text or ""
    local tcx = tx + (tw - reaper.ImGui_CalcTextSize(ctx, label)) / 2
    local tcy = ty + (BTN - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local col = text_color
    if not self._menu_path and (text_hover or menu_hover) then
        col = col & 0xFFFFFF00 | 0xAA
    end
    local txx, tyy = coords:relativeToDrawList(tcx, tcy)
    reaper.ImGui_DrawList_AddText(draw_list, txx, tyy, col, label)
end

return widget
