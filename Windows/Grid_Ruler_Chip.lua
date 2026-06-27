-- Floating chip on the ruler (far right): toggle REAPER grid lines. No toolbar chrome.
-- Dynamically slides out three additional sub-chips when hovered: Snap (Magnet), Triplet, and Grid Dropdown.
local DRAWING = require("Utils.drawing")

local GridRulerChip = {}

local GRID_TOGGLE_CMD = 40145 -- Main: Options: Toggle grid lines
local SNAP_TOGGLE_CMD = 1157  -- Main: Options: Toggle snapping
local SNAP_ICON_PATH = "IconFonts/icons/Tools/Magnet.ttf"
local SNAP_ICON_CHAR = string.char(0x41)

local CHIP_LABEL = "Grid"
local CHIP_H_PAD, CHIP_V_PAD, CHIP_ROUND = 8, 5, 3
local RULER_MARGIN, CHIP_ABOVE_BOTTOM = 5, 20
local GAP = 4

-- Persistent animation state on module table
GridRulerChip.t = GridRulerChip.t or 0.0
GridRulerChip.hovered = GridRulerChip.hovered or false
GridRulerChip.last_hover_time = GridRulerChip.last_hover_time or 0.0
GridRulerChip.last_frame_time = GridRulerChip.last_frame_time or 0.0

local function grid_lines_visible()
    local get = reaper.GetToggleCommandState
    if not get then return false end
    local ok, st = pcall(get, 0, GRID_TOGGLE_CMD)
    return ok and st == 1
end

local function toggle_grid_lines()
    reaper.Main_OnCommand(GRID_TOGGLE_CMD, 0)
end

-- Checks if a grid division is a triplet value
local function is_triplet_val(div)
    if not div or div <= 0 then return false end
    local val = div * 1.5
    local log2 = math.log(val) / math.log(2)
    local rounded = math.floor(log2 + 0.5)
    return math.abs(log2 - rounded) < 1e-5
end

-- Decimal to fraction converter using continued fractions
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

-- Formats a grid division value as a fraction string (e.g. 0.25 -> "1/4")
local function get_grid_display_text(div)
    if not div or div <= 0 then return "1/4" end
    local num, denom = decimal_to_fraction(div)
    if num > 1 and denom % num == 0 then denom, num = denom / num, 1 end
    return (num >= denom and num % denom == 0) and ("%.0f"):format(num / denom)
        or ("%.0f/%.0f"):format(num, denom)
end

-- Resolves the current base division and triplet status
local function get_grid_state()
    local _, div, swmode, swamt = reaper.GetSetProjectGrid(0, 0)
    if not div or div <= 0 then div = 0.25 end
    local is_trip = is_triplet_val(div)
    local base_div = is_trip and (div * 1.5) or div
    return base_div, is_trip, swmode, swamt
end

-- Toggles triplet grid state
local function toggle_triplet()
    local base_div, is_trip, swmode, swamt = get_grid_state()
    local new_trip = not is_trip
    local new_div = new_trip and (base_div * (2/3)) or base_div
    reaper.GetSetProjectGrid(0, true, new_div, swmode, swamt)
end


-- Easing function (smoothstep: ease-in, ease-out)
local function ease_in_out(t)
    return t * t * (3 - 2 * t)
end

-- Calculates individual transition progress with delay and duration parameters
local function get_chip_t(overall_t, delay, duration)
    local val = (overall_t - delay) / duration
    if val < 0.0 then return 0.0 end
    if val > 1.0 then return 1.0 end
    return val
end

-- Draws a single chip at relative coordinates, returning interaction results
local function draw_chip(ctx, rx, w, h, label, active, hover_override, alpha_factor, interactive, font_override, icon_char, icon_sz, y_offset, win_min_x, win_min_y)
    local hovered = false
    local clicked = false
    local rclicked = false

    if interactive then
        reaper.ImGui_SetCursorPosX(ctx, rx)
        reaper.ImGui_SetCursorPosY(ctx, 0)
        reaper.ImGui_InvisibleButton(ctx, "##chip_" .. label, w, h)
        hovered = reaper.ImGui_IsItemHovered(ctx)
        clicked = reaper.ImGui_IsItemClicked(ctx, 0)
        rclicked = reaper.ImGui_IsItemClicked(ctx, 1)
    end

    local dummy_coords = {
        relativeToDrawList = function(self, cx, cy)
            return win_min_x + cx, win_min_y + cy
        end,
        relativeRectToDrawList = function(self, cx, cy, cw, ch)
            local x1, y1 = self:relativeToDrawList(cx, cy)
            return x1, y1, x1 + cw, y1 + ch
        end
    }

    local btn_txt = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.TEXT.NORMAL)
    local btn_bg = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.BG.NORMAL)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {active=active, filled=true, hover=hovered or hover_override, disabled=false})

    local dl = reaper.ImGui_GetWindowDrawList(ctx)
    
    DRAWING.drawChipBackground(dummy_coords, dl, rx, 0, w, h, bg_col, {
        rounding = CHIP_ROUND,
        alpha_factor = alpha_factor
    })

    if alpha_factor < 1.0 then
        text_col = COLOR_UTILS.modulateAlpha(text_col, alpha_factor)
    end

    if icon_char and font_override then
        DRAWING.drawCenteredIcon(ctx, dummy_coords, dl, rx, 0, w, h, font_override, icon_char, icon_sz, text_col, y_offset)
    else
        DRAWING.drawCenteredText(ctx, dummy_coords, dl, rx, 0, w, h, label, text_col)
    end

    return clicked, rclicked
end

function GridRulerChip.render(ctx, font)
    if not (ctx and CONFIG and CONFIG.UI and CONFIG.UI.ENABLE_GRID_RULER_CHIP) then return end
    local R = _G.REAPER_UI_ANCHOR
    if not (R and R.get_timeline_ruler_screen_rect) then return end
    local rl, rt, rr, rb = R.get_timeline_ruler_screen_rect()
    if not (rl and rt and rr and rb) then return end

    local text_size = (CONFIG.SIZES and CONFIG.SIZES.TEXT) or 12
    if font then reaper.ImGui_PushFont(ctx, font, text_size) end

    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local chip_h = line_h + CHIP_V_PAD * 2

    if rr - rl < 16 or rb - rt < 10 then
        if font then reaper.ImGui_PopFont(ctx) end
        return
    end

    -- Calculate widths for all chips
    local tw_main = reaper.ImGui_CalcTextSize(ctx, CHIP_LABEL)
    local W_main = math.ceil(tw_main) + CHIP_H_PAD * 2

    local _, grid_div = reaper.GetSetProjectGrid(0, 0)
    local current_grid_text = get_grid_display_text(grid_div)
    local tw_drop = reaper.ImGui_CalcTextSize(ctx, current_grid_text)
    local W_dropdown = math.ceil(tw_drop) + CHIP_H_PAD * 2

    local tw_trip = reaper.ImGui_CalcTextSize(ctx, "T")
    local W_triplet = math.ceil(tw_trip) + CHIP_H_PAD * 2

    -- Resolve snap icon font
    local magnet_font
    if C and C.ButtonContent then
        magnet_font = C.ButtonContent:loadIconFont(SNAP_ICON_PATH)
    end
    local use_icons = false
    if magnet_font then
        if _G.ensureIconFontAttachedToContext then
            use_icons = _G.ensureIconFontAttachedToContext(ctx, magnet_font)
        else
            pcall(reaper.ImGui_Attach, ctx, magnet_font)
            use_icons = true
        end
    end

    local W_snap
    local icon_sz = math.floor(chip_h * 0.6)
    if use_icons then
        reaper.ImGui_PushFont(ctx, magnet_font, icon_sz)
        local w = reaper.ImGui_CalcTextSize(ctx, SNAP_ICON_CHAR)
        reaper.ImGui_PopFont(ctx)
        W_snap = math.ceil(w) + CHIP_H_PAD * 2
    else
        W_snap = math.ceil(reaper.ImGui_CalcTextSize(ctx, "SNAP")) + CHIP_H_PAD * 2
    end

    -- Calculate total width when expanded
    local W_total = W_snap + GAP + W_triplet + GAP + W_dropdown + GAP + W_main

    -- Frame timing and state initialization (200ms total transition time)
    local now = reaper.time_precise()
    if GridRulerChip.last_frame_time == 0.0 then
        GridRulerChip.last_frame_time = now
    end
    local dt = now - GridRulerChip.last_frame_time
    GridRulerChip.last_frame_time = now

    -- Bounding box calculations for hovering
    local win_y = math.max(rt, rb - chip_h - CHIP_ABOVE_BOTTOM)
    local mx, my = reaper.ImGui_GetMousePos(ctx)

    local x1_main = rr - W_main - RULER_MARGIN
    local x2_main = rr - RULER_MARGIN
    local x1_full = rr - W_total - RULER_MARGIN
    local x2_full = rr - RULER_MARGIN

    local mouse_in_main = (mx >= x1_main and mx <= x2_main and my >= win_y and my <= win_y + chip_h)
    local mouse_in_full = (mx >= x1_full and mx <= x2_full and my >= win_y and my <= win_y + chip_h)

    local popup_open = reaper.ImGui_IsPopupOpen(ctx, "##grid_dropdown_popup")

    -- State machine logic
    local is_hovered = false
    if GridRulerChip.t > 0.0 then
        is_hovered = mouse_in_full or popup_open
    else
        is_hovered = mouse_in_main
    end

    if is_hovered then
        GridRulerChip.hovered = true
        GridRulerChip.last_hover_time = now
        GridRulerChip.t = math.min(1.0, GridRulerChip.t + dt / 0.2) -- Slide in over 200ms
    else
        GridRulerChip.hovered = false
        if now - GridRulerChip.last_hover_time >= 1.5 then
            GridRulerChip.t = math.max(0.0, GridRulerChip.t - dt / 0.2) -- Slide/fade out over 200ms
        end
    end

    -- Stagger and Easing Calculations (each chip has duration 0.6, delay staggered by 0.2 [40ms])
    local t_drop_linear = get_chip_t(GridRulerChip.t, 0.0, 0.6)
    local t_trip_linear = get_chip_t(GridRulerChip.t, 0.2, 0.6)
    local t_snap_linear = get_chip_t(GridRulerChip.t, 0.4, 0.6)

    local t_drop_eased = ease_in_out(t_drop_linear)
    local t_trip_eased = ease_in_out(t_trip_linear)
    local t_snap_eased = ease_in_out(t_snap_linear)

    -- Static window metrics (always at full width to prevent coordinate space jittering)
    local win_x = math.max(rr - W_total - RULER_MARGIN, rl + RULER_MARGIN)
    local win_w = W_total

    reaper.ImGui_SetNextWindowPos(ctx, win_x, win_y, reaper.ImGui_Cond_Always())
    reaper.ImGui_SetNextWindowSize(ctx, win_w, chip_h, reaper.ImGui_Cond_Always())

    local flags = reaper.ImGui_WindowFlags_NoTitleBar()
        | reaper.ImGui_WindowFlags_NoCollapse()
        | reaper.ImGui_WindowFlags_NoResize()
        | reaper.ImGui_WindowFlags_NoMove()
        | reaper.ImGui_WindowFlags_NoScrollbar()
        | reaper.ImGui_WindowFlags_NoFocusOnAppearing()
    if reaper.ImGui_WindowFlags_NoDocking then flags = flags | reaper.ImGui_WindowFlags_NoDocking() end
    if reaper.ImGui_WindowFlags_NoBackground then flags = flags | reaper.ImGui_WindowFlags_NoBackground() end

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)

    local visible = select(1, reaper.ImGui_Begin(ctx, "##atb_grid_ruler_chip", true, flags))
    if visible then
        local win_min_x, win_min_y = reaper.ImGui_GetWindowPos(ctx)
        local rx_main = W_total - W_main

        -- Relative coordinates calculations for animation offsets
        local D_dropdown = GAP + W_dropdown
        local D_triplet = 2 * GAP + W_dropdown + W_triplet
        local D_snap = 3 * GAP + W_dropdown + W_triplet + W_snap

        local rx_dropdown = rx_main - t_drop_eased * D_dropdown
        local rx_triplet = rx_main - t_trip_eased * D_triplet
        local rx_snap = rx_main - t_snap_eased * D_snap

        -- Custom Alpha Fading (starts at 100ms/t=0.5 expanding, and immediate fade on way back, completing by 100ms/t=0.5 collapsing)
        local alpha_factor = math.max(0.0, (GridRulerChip.t - 0.5) / 0.5)

        -- 1. Draw Snap Chip
        if alpha_factor > 0.0 then
            local snap_on = (reaper.GetToggleCommandState(SNAP_TOGGLE_CMD) == 1)
            local font_arg = use_icons and magnet_font or nil
            local char_arg = use_icons and SNAP_ICON_CHAR or nil
            local interactive = (t_snap_eased > 0.9)
            local clicked = draw_chip(ctx, rx_snap, W_snap, chip_h, "SNAP", snap_on, false, alpha_factor, interactive, font_arg, char_arg, icon_sz, nil, win_min_x, win_min_y)
            if clicked then
                reaper.Main_OnCommand(SNAP_TOGGLE_CMD, 0)
            end
        end

        -- 2. Draw Triplet Chip
        if alpha_factor > 0.0 then
            local _, is_trip = get_grid_state()
            local interactive = (t_trip_eased > 0.9)
            local clicked = draw_chip(ctx, rx_triplet, W_triplet, chip_h, "T", is_trip, false, alpha_factor, interactive, nil, nil, nil, nil, win_min_x, win_min_y)
            if clicked then
                toggle_triplet()
            end
        end

        -- 3. Draw Dropdown/Display Chip
        local dropdown_clicked = false
        if alpha_factor > 0.0 then
            local interactive = (t_drop_eased > 0.9)
            dropdown_clicked = draw_chip(ctx, rx_dropdown, W_dropdown, chip_h, current_grid_text, popup_open, false, alpha_factor, interactive, nil, nil, nil, nil, win_min_x, win_min_y)
            if dropdown_clicked then
                reaper.ImGui_OpenPopup(ctx, "##grid_dropdown_popup")
            end
        end

        -- 4. Draw Main Grid Chip
        local grid_on = grid_lines_visible()
        local main_clicked = draw_chip(ctx, rx_main, W_main, chip_h, CHIP_LABEL, grid_on, false, 1.0, true, nil, nil, nil, nil, win_min_x, win_min_y)
        if main_clicked then
            toggle_grid_lines()
        end

        -- Render Dropdown Popup
        local win_min_x, win_min_y = reaper.ImGui_GetWindowPos(ctx)
        reaper.ImGui_SetNextWindowPos(ctx, win_min_x + rx_dropdown, win_min_y + chip_h, reaper.ImGui_Cond_Appearing())
        
        -- Apply global styling (padding, colors, rounding) to match other dropdowns
        local colorCount, styleCount = 0, 0
        if C and C.GlobalStyle then
            colorCount, styleCount = C.GlobalStyle.apply(ctx)
        end

        local visible_popup = reaper.ImGui_BeginPopup(ctx, "##grid_dropdown_popup")
        if visible_popup then
            local base_div, is_trip, swmode, swamt = get_grid_state()
            local divisions = {
                { label = "1", val = 1.0 },
                { label = "1/2", val = 0.5 },
                { label = "1/4", val = 0.25 },
                { label = "1/8", val = 0.125 },
                { label = "1/16", val = 0.0625 },
                { label = "1/32", val = 0.03125 },
                { label = "1/64", val = 0.015625 },
                { label = "1/128", val = 0.0078125 },
            }
            for _, item in ipairs(divisions) do
                local is_selected = math.abs(base_div - item.val) < 1e-5
                if reaper.ImGui_MenuItem(ctx, item.label, nil, is_selected) then
                    local new_div = is_trip and (item.val * (2/3)) or item.val
                    reaper.GetSetProjectGrid(0, true, new_div, swmode, swamt)
                end
            end
            reaper.ImGui_EndPopup(ctx)
        end

        if C and C.GlobalStyle then
            C.GlobalStyle.reset(ctx, colorCount, styleCount)
        end
    end

    reaper.ImGui_End(ctx)
    reaper.ImGui_PopStyleVar(ctx, 2)
    if font then reaper.ImGui_PopFont(ctx) end
end

return GridRulerChip
