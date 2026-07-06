-- Floating chip on the ruler (far right): toggle REAPER grid lines. No toolbar chrome.
-- Hover slides out sub-chips (left → right): ruler time unit, snap, triplet, grid division; time unit and division open dropdown menus.
local DRAWING = require("Utils.Draw.drawing")
local ANIM = require("Utils.Draw.anim")
local GRID = require("Utils.Core.grid_utils")
local IMGUI = require("Utils.Draw.imgui_utils")

local GridRulerChip = {}

local GRID_TOGGLE_CMD = 40145 -- Main: Options: Toggle grid lines
local SNAP_TOGGLE_CMD = 1157  -- Main: Options: Toggle snapping
local SNAP_ICON_PATH = "IconFonts/icons/Tools/Magnet.ttf"
local SNAP_ICON_CHAR = string.char(0x41)

local RULER_TIME_MODES = {
    { id = "ms", short_label = "M:S", label = "Minutes:Seconds", command_id = 40365 },
    { id = "sec", short_label = "Sec", label = "Seconds", command_id = 40368 },
    { id = "smp", short_label = "Smp", label = "Samples", command_id = 40369 },
    { id = "tc", short_label = "TC", label = "Timecode", command_id = 40370 },
    { id = "mbmin", short_label = "M:B+", label = "Measures:Beats (minimal)", command_id = 41916 },
    { id = "afrm", short_label = "Abs.Frm", label = "Absolute Frames", command_id = 41973 },
}

local RULER_TIME_POPUP = "##ruler_time_unit_popup"
local GRID_DIV_POPUP = "##grid_dropdown_popup"

local CHIP_LABEL = "Grid"
local CHIP_H_PAD, CHIP_V_PAD, CHIP_ROUND = 8, 5, 3
local RULER_MARGIN, CHIP_ABOVE_BOTTOM = 5, 20
local GAP = 4

-- Persistent animation state on module table
GridRulerChip.t = GridRulerChip.t or 0.0
GridRulerChip.hovered = GridRulerChip.hovered or false
GridRulerChip.last_hover_time = GridRulerChip.last_hover_time or 0.0
GridRulerChip.last_frame_time = GridRulerChip.last_frame_time or 0.0
GridRulerChip.last_time_mode_id = GridRulerChip.last_time_mode_id or nil

local function ruler_time_mode_from_reaper()
    for _, m in ipairs(RULER_TIME_MODES) do
        local ok, st = pcall(reaper.GetToggleCommandState, m.command_id)
        if ok and st == 1 then
            return m
        end
    end
    return nil
end

local function ruler_time_active_mode()
    local from_reaper = ruler_time_mode_from_reaper()
    if from_reaper then
        return from_reaper
    end
    if GridRulerChip.last_time_mode_id then
        for _, m in ipairs(RULER_TIME_MODES) do
            if m.id == GridRulerChip.last_time_mode_id then
                return m
            end
        end
    end
    return RULER_TIME_MODES[1]
end

local function ruler_time_chip_max_text_width(ctx)
    local max_w = 0
    for _, m in ipairs(RULER_TIME_MODES) do
        local w = reaper.ImGui_CalcTextSize(ctx, m.short_label) or 0
        if w > max_w then
            max_w = w
        end
    end
    return max_w
end

local function grid_lines_visible()
    return reaper.GetToggleCommandState(GRID_TOGGLE_CMD) == 1
end

local function toggle_grid_lines()
    reaper.Main_OnCommand(GRID_TOGGLE_CMD, 0)
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
    local bg_col, text_col = COLOR_UTILS.rulerPillColors(btn_txt, btn_bg, {active=active, filled=true, hover=hovered or hover_override, disabled=false})

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
    local current_grid_text = GRID.fraction_text(grid_div)
    local tw_drop = reaper.ImGui_CalcTextSize(ctx, current_grid_text)
    local W_dropdown = math.ceil(tw_drop) + CHIP_H_PAD * 2

    local tw_trip = reaper.ImGui_CalcTextSize(ctx, "T")
    local W_triplet = math.ceil(tw_trip) + CHIP_H_PAD * 2

    local active_time_mode = ruler_time_active_mode()
    local current_time_text = active_time_mode.short_label
    local tw_time = ruler_time_chip_max_text_width(ctx)
    local W_time = math.ceil(tw_time) + CHIP_H_PAD * 2

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

    -- Calculate total width when expanded (left → right: time unit, snap, triplet, division, grid)
    local W_total = W_time + GAP + W_snap + GAP + W_triplet + GAP + W_dropdown + GAP + W_main

    -- Frame timing and state initialization (200ms total transition time)
    local dt, now = ANIM.frame_dt(GridRulerChip)

    -- Bounding box calculations for hovering
    local win_y = math.max(rt, rb - chip_h - CHIP_ABOVE_BOTTOM)
    local mx, my = reaper.ImGui_GetMousePos(ctx)

    local x1_main = rr - W_main - RULER_MARGIN
    local x2_main = rr - RULER_MARGIN
    local x1_full = rr - W_total - RULER_MARGIN
    local x2_full = rr - RULER_MARGIN

    local mouse_in_main = (mx >= x1_main and mx <= x2_main and my >= win_y and my <= win_y + chip_h)
    local mouse_in_full = (mx >= x1_full and mx <= x2_full and my >= win_y and my <= win_y + chip_h)

    local grid_popup_open = reaper.ImGui_IsPopupOpen(ctx, GRID_DIV_POPUP)
    local time_popup_open = reaper.ImGui_IsPopupOpen(ctx, RULER_TIME_POPUP)
    local popup_open = grid_popup_open or time_popup_open

    -- State machine logic
    local is_hovered = false
    if GridRulerChip.t > 0.0 then
        is_hovered = mouse_in_full or popup_open
    else
        is_hovered = mouse_in_main
    end

    -- Slide in over 200ms; hold 1.5s after un-hover, then slide/fade out over 200ms.
    ANIM.advance_t(GridRulerChip, is_hovered, dt, now, 1.5, 0.2)

    -- Stagger and Easing Calculations (each chip has duration 0.6, delay staggered by 0.2 [40ms])
    local t_drop_eased = ANIM.ease_in_out(ANIM.staggered_t(GridRulerChip.t, 0.0, 0.6))
    local t_trip_eased = ANIM.ease_in_out(ANIM.staggered_t(GridRulerChip.t, 0.2, 0.6))
    local t_snap_eased = ANIM.ease_in_out(ANIM.staggered_t(GridRulerChip.t, 0.4, 0.6))
    local t_time_eased = ANIM.ease_in_out(ANIM.staggered_t(GridRulerChip.t, 0.6, 0.6))

    local alpha_factor = ANIM.fade_alpha(GridRulerChip.t)

    -- Slide-out chips anchor from the right (Grid → division → triplet → snap → time unit).
    -- Each step uses only its neighbor to the right so stagger never stacks on the same x.
    local function step_left(t_eased, chip_w)
        return t_eased * (GAP + chip_w)
    end

    local rx_main = W_total - W_main
    local rx_dropdown = rx_main - step_left(t_drop_eased, W_dropdown)
    local rx_triplet = rx_dropdown - step_left(t_trip_eased, W_triplet)
    local rx_snap = rx_triplet - step_left(t_snap_eased, W_snap)
    local rx_time = rx_snap - step_left(t_time_eased, W_time)

    -- Window only covers visible/interactive chips so empty slide-out area does not block clicks.
    local hit_left = rx_main
    if alpha_factor > 0.0 then
        hit_left = math.min(hit_left, rx_dropdown, rx_triplet, rx_snap, rx_time)
    end
    if grid_popup_open then
        hit_left = math.min(hit_left, rx_dropdown)
    end
    if time_popup_open then
        hit_left = math.min(hit_left, rx_time)
    end

    local win_w = math.max(W_main, (rx_main + W_main) - hit_left)
    local win_x = (rr - RULER_MARGIN) - win_w
    win_x = math.max(win_x, rl + RULER_MARGIN)
    win_w = math.min(win_w, (rr - RULER_MARGIN) - win_x)
    local x_ofs = hit_left

    reaper.ImGui_SetNextWindowPos(ctx, win_x, win_y, reaper.ImGui_Cond_Always())
    reaper.ImGui_SetNextWindowSize(ctx, win_w, chip_h, reaper.ImGui_Cond_Always())

    local flags = IMGUI.slideOutWindowFlags(true)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)

    local visible = select(1, reaper.ImGui_Begin(ctx, "##atb_grid_ruler_chip", true, flags))
    if visible then
        local win_min_x, win_min_y = reaper.ImGui_GetWindowPos(ctx)

        -- 1. Draw Ruler Time Unit Chip
        if alpha_factor > 0.0 and t_time_eased > 0.02 then
            local interactive = (t_time_eased > 0.9)
            local time_clicked = draw_chip(
                ctx,
                rx_time - x_ofs,
                W_time,
                chip_h,
                current_time_text,
                time_popup_open,
                false,
                alpha_factor,
                interactive,
                nil,
                nil,
                nil,
                nil,
                win_min_x,
                win_min_y
            )
            if time_clicked then
                reaper.ImGui_OpenPopup(ctx, RULER_TIME_POPUP)
            end
        end

        -- 2. Draw Snap Chip
        if alpha_factor > 0.0 and t_snap_eased > 0.02 then
            local snap_on = (reaper.GetToggleCommandState(SNAP_TOGGLE_CMD) == 1)
            local font_arg = use_icons and magnet_font or nil
            local char_arg = use_icons and SNAP_ICON_CHAR or nil
            local interactive = (t_snap_eased > 0.9)
            local clicked = draw_chip(ctx, rx_snap - x_ofs, W_snap, chip_h, "SNAP", snap_on, false, alpha_factor, interactive, font_arg, char_arg, icon_sz, nil, win_min_x, win_min_y)
            if clicked then
                reaper.Main_OnCommand(SNAP_TOGGLE_CMD, 0)
            end
        end

        -- 3. Draw Triplet Chip
        if alpha_factor > 0.0 and t_trip_eased > 0.02 then
            local _, is_trip = GRID.get_state()
            local interactive = (t_trip_eased > 0.9)
            local clicked = draw_chip(ctx, rx_triplet - x_ofs, W_triplet, chip_h, "T", is_trip, false, alpha_factor, interactive, nil, nil, nil, nil, win_min_x, win_min_y)
            if clicked then
                GRID.toggle_triplet()
            end
        end

        -- 4. Draw Dropdown/Display Chip
        local dropdown_clicked = false
        if alpha_factor > 0.0 and t_drop_eased > 0.02 then
            local interactive = (t_drop_eased > 0.9)
            dropdown_clicked = draw_chip(ctx, rx_dropdown - x_ofs, W_dropdown, chip_h, current_grid_text, grid_popup_open, false, alpha_factor, interactive, nil, nil, nil, nil, win_min_x, win_min_y)
            if dropdown_clicked then
                reaper.ImGui_OpenPopup(ctx, GRID_DIV_POPUP)
            end
        end

        -- 5. Draw Main Grid Chip
        local grid_on = grid_lines_visible()
        local main_clicked = draw_chip(ctx, rx_main - x_ofs, W_main, chip_h, CHIP_LABEL, grid_on, false, 1.0, true, nil, nil, nil, nil, win_min_x, win_min_y)
        if main_clicked then
            toggle_grid_lines()
        end

        local function draw_styled_popups()
            -- Ruler time unit dropdown
            reaper.ImGui_SetNextWindowPos(ctx, win_min_x + rx_time - x_ofs, win_min_y + chip_h, reaper.ImGui_Cond_Appearing())
            if reaper.ImGui_BeginPopup(ctx, RULER_TIME_POPUP) then
                local live_mode = ruler_time_mode_from_reaper()
                for _, mode in ipairs(RULER_TIME_MODES) do
                    local is_selected = live_mode and live_mode.id == mode.id
                        or (not live_mode and active_time_mode.id == mode.id)
                    if reaper.ImGui_MenuItem(ctx, mode.label, nil, is_selected) then
                        reaper.Main_OnCommand(mode.command_id, 0)
                        GridRulerChip.last_time_mode_id = mode.id
                    end
                end
                reaper.ImGui_EndPopup(ctx)
            end

            -- Grid division dropdown
            reaper.ImGui_SetNextWindowPos(ctx, win_min_x + rx_dropdown - x_ofs, win_min_y + chip_h, reaper.ImGui_Cond_Appearing())
            if reaper.ImGui_BeginPopup(ctx, GRID_DIV_POPUP) then
                local base_div, is_trip, swmode, swamt = GRID.get_state()
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
                        GRID.set_division(item.val, is_trip, swmode, swamt)
                    end
                end
                reaper.ImGui_EndPopup(ctx)
            end
        end

        if C and C.GlobalStyle and C.GlobalStyle.withGlobalStyle then
            C.GlobalStyle.withGlobalStyle(ctx, draw_styled_popups)
        else
            draw_styled_popups()
        end
    end

    reaper.ImGui_End(ctx)
    reaper.ImGui_PopStyleVar(ctx, 2)
    if font then reaper.ImGui_PopFont(ctx) end
end

return GridRulerChip
