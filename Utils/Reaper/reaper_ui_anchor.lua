-- Utils/reaper_ui_anchor.lua
-- Screen-space rects for anchoring floating ReaImGui windows to REAPER's main window (js_ReaScriptAPI).

local M = {}

local ID_TRACKVIEW = 1000
local ID_TIMELINE = 1005
local ID_TRANSPORT_HOST = 0
-- Child 1010: REAPERstatusdisp (time display in transport). On macOS, id 0 is the main HWND, not transport.
local ID_TRANSPORT_STATUS = 1010

local function is_mac_os()
    local os = reaper.GetOS() or ""
    return os:match("macOS") ~= nil or os:match("OSX") ~= nil or os:match("Darwin") ~= nil
end

local function is_windows()
    return (reaper.GetOS() or ""):match("Win") ~= nil
end

-- js_ReaScriptAPI: on macOS, screen Y is from the bottom of the primary display (Y upward). ImGui uses top-left, Y down.
-- Height from JS_Window_GetViewportFromRect; swap t/b on Mac like Odedd Screen.lua before taking extent.
local function mac_primary_screen_height_topdown()
    if not reaper.JS_Window_GetViewportFromRect then
        return nil
    end
    local ok, pack = pcall(function()
        return table.pack(reaper.JS_Window_GetViewportFromRect(0, 0, 0, 0, false))
    end)
    if not ok or not pack or pack.n < 4 then
        return nil
    end
    local _, vt, _, vb = pack[1], pack[2], pack[3], pack[4]
    if vt == nil or vb == nil then
        return nil
    end
    local t, b = vt, vb
    if is_mac_os() then
        t, b = b, t
    end
    local h = b - t
    if h < 32 then
        return nil
    end
    return h
end

local function screen_rect_mac_bottom_up_to_imgui(l, t, r, b, screen_h)
    local y_lo = math.min(t, b)
    local y_hi = math.max(t, b)
    local td_t = screen_h - y_hi
    local td_b = screen_h - y_lo
    return l, td_t, r, td_b
end

--- HWND may be userdata/lightuserdata on macOS; avoid relying on numeric zero.
local function hwnd_valid(hwnd)
    if hwnd == nil or hwnd == false then
        return false
    end
    if type(hwnd) == "number" then
        return hwnd ~= 0
    end
    return true
end

local function main_hwnd()
    if reaper.GetMainHwnd then
        local ok, h = pcall(reaper.GetMainHwnd)
        if ok and hwnd_valid(h) then
            return h
        end
    end
    if reaper.JS_Window_Find then
        local ok, h = pcall(function()
            return reaper.JS_Window_Find("REAPER", true)
        end)
        if ok and hwnd_valid(h) then
            return h
        end
    end
    if reaper.JS_Window_ListFind and reaper.JS_Window_HandleFromAddress then
        local ok, parts = pcall(function()
            return { reaper.JS_Window_ListFind("REAPER", 1) }
        end)
        if ok and parts and type(parts[2]) == "string" and parts[2] ~= "" then
            local list = parts[2]
            local first = (list .. ","):match("(.-),")
            if first then
                local h2 = reaper.JS_Window_HandleFromAddress(first)
                if hwnd_valid(h2) then
                    return h2
                end
            end
        end
    end
    return nil
end

local function child_by_id(parent, id)
    if not parent or not reaper.JS_Window_FindChildByID then
        return nil
    end
    local ch = reaper.JS_Window_FindChildByID(parent, id)
    if hwnd_valid(ch) then
        return ch
    end
    return nil
end

local function find_child_by_class(parent, class_name)
    if not parent or class_name == nil or class_name == "" then
        return nil
    end
    -- Class-based lookup: FindEx(hwndParent, hwndChildAfter, class, title). Same pattern as talagan_Reannotate / TCP scripts.
    if reaper.JS_Window_FindEx then
        local ok, ch = pcall(function()
            return reaper.JS_Window_FindEx(parent, parent, class_name, "")
        end)
        if ok and hwnd_valid(ch) then
            return ch
        end
    end
    -- FindChild is (parent, name, matchClassName?) — max 3 args in current js_ReaScriptAPI.
    if reaper.JS_Window_FindChild then
        local ok, ch = pcall(function()
            return reaper.JS_Window_FindChild(parent, class_name, true)
        end)
        if ok and hwnd_valid(ch) then
            return ch
        end
    end
    return nil
end

local function find_trackview_and_timeline(main)
    local track = child_by_id(main, ID_TRACKVIEW)
    local time_disp = child_by_id(main, ID_TIMELINE)
    if track and time_disp then
        return track, time_disp
    end
    track = find_child_by_class(main, "REAPERTrackListWindow")
    time_disp = find_child_by_class(main, "REAPERTimeDisplay")
    if track and time_disp then
        return track, time_disp
    end
    return nil, nil
end

-- Direct children of main: left column tall panel (TCP when class lookup fails on Windows / themes).
local function find_tcp_via_child_enumeration(main)
    if not reaper.JS_Window_ListAllChild or not reaper.JS_Window_HandleFromAddress or not reaper.JS_Window_GetParent then
        return nil
    end
    local ml, mt, mr, mb = main_rect_or_nil(main)
    if not ml then
        return nil
    end
    local ok_lc, ret, list = pcall(reaper.JS_Window_ListAllChild, main)
    if not ok_lc or ret == 0 or not list or list == "" then
        return nil
    end
    local mw_w, mw_h = mr - ml, mb - mt
    local best, best_score = nil, 0
    for addr in (list .. ","):gmatch("(.-),") do
        if addr ~= "" then
            local hwnd = reaper.JS_Window_HandleFromAddress(addr)
            if hwnd_valid(hwnd) then
                local okp, p = pcall(reaper.JS_Window_GetParent, hwnd)
                if okp and p == main then
                    local l, t, r, b = hwnd_screen_rect(hwnd)
                    if l then
                        local w, h = r - l, b - t
                        if w >= 40 and w <= mw_w * 0.55 and h >= mw_h * 0.25 and l < ml + mw_w * 0.12 then
                            local leftness = 1 - math.min(1, math.max(0, (l - ml) / math.max(1, mw_w * 0.15)))
                            local s = w * h * leftness
                            if s > best_score then
                                best_score, best = s, hwnd
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Track control panel column (left of ruler / arrange). Same FindEx pattern as talagan_Reannotate.
local function find_tcp_display(main)
    if not hwnd_valid(main) then
        return nil
    end
    local class_names = { "REAPERTCPDisplay", "REAPERtcpdisplay", "REAPERTcpDisplay" }
    for _, class_name in ipairs(class_names) do
        local hwnd = find_child_by_class(main, class_name)
        if hwnd then
            return hwnd
        end
    end
    return find_tcp_via_child_enumeration(main)
end

-- Parse JS_Window_GetRect return shape: (l,t,r,b) or (ok, l,t,r,b) or string coords, etc.
local function rect_from_getrect_values(...)
    local pack = table.pack(...)
    if not pack.n or pack.n == 0 then
        return nil
    end
    if pack[1] == false then
        return nil
    end
    local nums = {}
    for i = 1, pack.n do
        local v = pack[i]
        local n = tonumber(v)
        if n ~= nil then
            nums[#nums + 1] = n
        end
    end
    if #nums < 4 then
        return nil
    end
    local l, t, r, bot = nums[#nums - 3], nums[#nums - 2], nums[#nums - 1], nums[#nums]
    if (r - l) < 4 or (bot - t) < 4 then
        return nil
    end
    return l, t, r, bot
end

-- js API may return (w,h) or (retval, w, h); same for ClientToScreen → (x,y) or (retval, x, y).
local function parse_last_two_numbers(a, b, c)
    local x, y = tonumber(b), tonumber(c)
    if x ~= nil and y ~= nil then
        return x, y
    end
    x, y = tonumber(a), tonumber(b)
    if x ~= nil and y ~= nil then
        return x, y
    end
    return nil
end

local function hwnd_client_size(hwnd)
    if not reaper.JS_Window_GetClientSize then
        return nil
    end
    local ok, a, b, c = pcall(reaper.JS_Window_GetClientSize, hwnd)
    if not ok then
        return nil
    end
    return parse_last_two_numbers(a, b, c)
end

local function hwnd_client_to_screen(hwnd, cx, cy)
    if not reaper.JS_Window_ClientToScreen then
        return nil
    end
    local ok, a, b, c = pcall(reaper.JS_Window_ClientToScreen, hwnd, cx, cy)
    if not ok then
        return nil
    end
    return parse_last_two_numbers(a, b, c)
end

-- Screen-space rect via client size + ClientToScreen (works when GetRect arity/types differ).
local function hwnd_screen_rect_via_client(hwnd)
    if not hwnd_valid(hwnd) then
        return nil
    end
    local w, h = hwnd_client_size(hwnd)
    if not w or not h or w < 4 or h < 4 then
        return nil
    end
    local lx, ly = hwnd_client_to_screen(hwnd, 0, 0)
    local rx, ry = hwnd_client_to_screen(hwnd, w, h)
    if not lx or not ly or not rx or not ry then
        return nil
    end
    local l, top = math.min(lx, rx), math.min(ly, ry)
    local r, b = math.max(lx, rx), math.max(ly, ry)
    if (r - l) < 4 or (b - top) < 4 then
        return nil
    end
    return l, top, r, b
end

-- Returns left, top, right, bottom in screen coordinates (top-left origin, +Y down), or nil.
local function hwnd_screen_rect(hwnd)
    if not hwnd_valid(hwnd) then
        return nil
    end
    local l, t, r, b
    if reaper.JS_Window_GetRect then
        local ok, gl, gt, gr, gb = pcall(function()
            return rect_from_getrect_values(reaper.JS_Window_GetRect(hwnd))
        end)
        if ok and gl then
            l, t, r, b = gl, gt, gr, gb
        end
    end
    if not l then
        l, t, r, b = hwnd_screen_rect_via_client(hwnd)
    end
    if not l then
        return nil
    end
    if is_mac_os() then
        local H = mac_primary_screen_height_topdown()
        if H then
            l, t, r, b = screen_rect_mac_bottom_up_to_imgui(l, t, r, b, H)
        end
    end
    return l, t, r, b
end

--- js_ReaScriptAPI vs ReaImGui coordinate scale on Windows HiDPI (1 when matched).
function M.get_coordinate_scale(ctx)
    if not ctx or not is_windows() or not reaper.ImGui_GetMainViewport then
        return 1
    end
    local main = main_hwnd()
    if not main then
        return 1
    end
    local ml, mt, mr, mb = main_rect_or_nil(main)
    if not ml then
        return 1
    end
    local js_w = mr - ml
    if js_w < 32 then
        return 1
    end
    local vp = reaper.ImGui_GetMainViewport(ctx)
    local vp_w = select(1, reaper.ImGui_Viewport_GetSize(vp))
    if not vp_w or vp_w < 32 then
        return 1
    end
    local scale = vp_w / js_w
    if scale < 0.5 or scale > 2.0 or math.abs(scale - 1) < 0.02 then
        return 1
    end
    return scale
end

function M.is_available()
    local main = main_hwnd()
    if not hwnd_valid(main) or not reaper.JS_Window_FindChildByID then
        return false
    end
    if reaper.JS_Window_GetRect then
        return true
    end
    return reaper.JS_Window_GetClientSize and reaper.JS_Window_ClientToScreen and true or false
end

local function main_rect_or_nil(main)
    return hwnd_screen_rect(main)
end

--- True when a rect is essentially the whole main window (macOS: child id 0 is main, not transport).
local function rect_covers_almost_all_of_main(ml, mt, mr, mb, l, t, r, b)
    if not ml then
        return false
    end
    local mw_w, mw_h = mr - ml, mb - mt
    return (r - l) > mw_w * 0.95 and (b - t) > mw_h * 0.95
end

-- Walk parents from REAPERstatusdisp (1010) to find a wide, short bar that is not the full main window.
local function find_transport_via_status_chain(main)
    local sd = child_by_id(main, ID_TRANSPORT_STATUS)
    if not sd then
        sd = find_child_by_class(main, "REAPERstatusdisp")
    end
    if not sd or not reaper.JS_Window_GetParent then
        return nil
    end
    local ml, mt, mr, mb = main_rect_or_nil(main)
    if not ml then
        return nil
    end
    local mw_w, mw_h = mr - ml, mb - mt
    local main_area = mw_w * mw_h
    local best, best_w = nil, 0
    local cand = sd
    for _ = 1, 16 do
        local l, top, r, b = hwnd_screen_rect(cand)
        if l then
            local w, h = r - l, b - top
            local share = (w * h) / main_area
            if share < 0.93 and h >= 18 and h <= math.max(200, mw_h * 0.38) and w >= mw_w * 0.22 then
                if w > best_w then
                    best_w, best = w, cand
                end
            end
        end
        local ok, par = pcall(reaper.JS_Window_GetParent, cand)
        if not ok or not hwnd_valid(par) or par == main then
            break
        end
        cand = par
    end
    return best
end

-- Direct children of main: pick a wide, shallow band at top or bottom (transport docked).
local function find_transport_via_child_enumeration(main)
    if not reaper.JS_Window_ListAllChild or not reaper.JS_Window_HandleFromAddress or not reaper.JS_Window_GetParent then
        return nil
    end
    local ml, mt, mr, mb = main_rect_or_nil(main)
    if not ml then
        return nil
    end
    local ok_lc, ret, list = pcall(reaper.JS_Window_ListAllChild, main)
    if not ok_lc or ret == 0 or not list or list == "" then
        return nil
    end
    local mw_w, mw_h = mr - ml, mb - mt
    local main_area = math.max(1, mw_w * mw_h)
    local best, score = nil, 0
    for addr in (list .. ","):gmatch("(.-),") do
        if addr ~= "" then
            local hwnd = reaper.JS_Window_HandleFromAddress(addr)
            if hwnd_valid(hwnd) then
                local okp, p = pcall(reaper.JS_Window_GetParent, hwnd)
                if okp and p == main then
                    local l, t, r, b = hwnd_screen_rect(hwnd)
                    if l then
                        local w, h = r - l, b - t
                        local cy = (t + b) * 0.5
                        local share = (w * h) / main_area
                        local in_top = cy < mt + mw_h * 0.34
                        local in_bot = cy > mb - mw_h * 0.4
                        if share < 0.88
                            and h >= 22
                            and h <= math.max(200, mw_h * 0.42)
                            and w >= mw_w * 0.32
                            and (in_top or in_bot)
                        then
                            local s = w * (in_bot and 1.02 or 1)
                            if s > score then
                                score, best = s, hwnd
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function find_transport_hwnd(main)
    local ml, mt, mr, mb = main_rect_or_nil(main)
    if not ml then
        return nil
    end
    local th = child_by_id(main, ID_TRANSPORT_HOST)
    if th then
        local l, t, r, b = hwnd_screen_rect(th)
        if l and not rect_covers_almost_all_of_main(ml, mt, mr, mb, l, t, r, b) then
            return th
        end
    end
    local via = find_transport_via_status_chain(main)
    if via then
        return via
    end
    return find_transport_via_child_enumeration(main)
end

local function finish_anchor_rect(ctx, x, y, w, h)
    if x == nil or y == nil or not w or not h then
        return nil
    end
    if ctx then
        local s = M.get_coordinate_scale(ctx)
        if s ~= 1 then
            return x * s, y * s, w * s, h * s
        end
    end
    return x, y, w, h
end

-- anchor: tcp_corner | arrange | transport — returns x, y, w, h in screen space, or nil on failure
-- ctx: optional ImGui context (Windows HiDPI scale correction when set)
function M.get_anchor_rect(anchor, ctx)
    if not M.is_available() then
        return nil
    end
    local main = main_hwnd()
    if anchor == "transport" then
        local th = find_transport_hwnd(main)
        if not th then
            return nil
        end
        local l, t, r, b = hwnd_screen_rect(th)
        if not l then
            return nil
        end
        local mw_l, mw_t, mw_r, mw_b = main_rect_or_nil(main)
        if rect_covers_almost_all_of_main(mw_l, mw_t, mw_r, mw_b, l, t, r, b) then
            return nil
        end
        return finish_anchor_rect(ctx, l, t, r - l, b - t)
    end

    local track, time_disp = find_trackview_and_timeline(main)
    if not track or not time_disp then
        return nil
    end
    local tv_l, tv_t, tv_r, tv_b = hwnd_screen_rect(track)
    local rl, rt, rr, rb = hwnd_screen_rect(time_disp)
    if not tv_l or not rl then
        return nil
    end

    local tcp_hw = find_tcp_display(main)
    local cp_l, cp_r
    if tcp_hw then
        local cl, _, cr = hwnd_screen_rect(tcp_hw)
        cp_l, cp_r = cl, cr
    end
    local has_tcp = cp_l and cp_r and (cp_r - cp_l) >= 8
    local ruler_h = math.max(8, rb - rt)

    if anchor == "tcp_corner" then
        -- Pin strip: TCP column width; height = ruler row + lane stack (timeline + track list geometry).
        if has_tcp then
            local y0, stack_h
            if rt + 0.5 >= tv_b then
                -- Timeline / ruler band sits below the lane HWND (common on macOS): lanes then ruler.
                local lanes_h = math.max(8, tv_b - tv_t)
                y0 = tv_t
                stack_h = lanes_h + ruler_h
            else
                -- Ruler above lane HWND; lanes from timeline bottom to trackview bottom.
                if rb > tv_b + 0.5 then
                    y0 = math.min(rt, tv_t)
                    stack_h = math.max(8, tv_b - y0)
                else
                    local lanes_h = math.max(8, tv_b - rb)
                    y0 = rt
                    stack_h = ruler_h + lanes_h
                end
            end
            return finish_anchor_rect(ctx, cp_l, y0, cp_r - cp_l, stack_h)
        end
        -- Ruler/trackview corner only when timeline HWND sits inside track list geometry.
        local w = rl - tv_l
        local h = rt - tv_t
        if w >= 8 and h >= 8 then
            return finish_anchor_rect(ctx, tv_l, tv_t, w, h)
        end
        return nil
    end

    if anchor == "arrange" then
        -- Lanes only: left edge at TCP right (not ruler / trackview left when TCP is separate).
        if rt + 0.5 >= tv_b then
            if has_tcp then
                local w = tv_r - cp_r
                if w >= 8 and (tv_b - tv_t) >= 8 then
                    return finish_anchor_rect(ctx, cp_r, tv_t, w, tv_b - tv_t)
                end
            end
            return finish_anchor_rect(ctx, tv_l, tv_t, tv_r - tv_l, tv_b - tv_t)
        end
        local ax = has_tcp and cp_r or math.max(tv_l, rl)
        local ay = rb
        local aw = tv_r - ax
        local ah = tv_b - ay
        if aw >= 8 and ah >= 8 then
            return finish_anchor_rect(ctx, ax, ay, aw, ah)
        end
        local tw = tv_r - tv_l
        local th = tv_b - tv_t
        local ruler_clip = math.max(12, math.min(140, rb - rt))
        ay = rt + ruler_clip
        aw = math.max(8, tv_r - math.max(tv_l, rl))
        ah = math.max(8, tv_b - ay)
        ax = math.min(tv_l, rl)
        if aw < 8 or ah < 8 or tw < 16 then
            return nil
        end
        return finish_anchor_rect(ctx, ax, ay, aw, ah)
    end

    return nil
end

--- Screen rect of the timeline / ruler band (REAPERTimeDisplay child), or nil. l,t,r,b top-left origin +Y down.
function M.get_timeline_ruler_screen_rect()
    if not M.is_available() then
        return nil
    end
    local main = main_hwnd()
    if not hwnd_valid(main) then
        return nil
    end
    local _, time_disp = find_trackview_and_timeline(main)
    if not time_disp then
        return nil
    end
    return hwnd_screen_rect(time_disp)
end

return M
