-- Floating chip on the ruler (far right): toggle REAPER grid lines. No toolbar chrome.

local GridRulerChip = {}

local GRID_TOGGLE_CMD = 40145 -- Main: Options: Toggle grid lines
local MAIN_ACTION_SECTION = 0

local CHIP_LABEL = "Grid"
local CHIP_H_PAD = 8
local CHIP_V_PAD = 5
local CHIP_ROUND = 3
local RULER_MARGIN = 5

local function grid_lines_visible()
    if not reaper.GetToggleCommandState then
        return false
    end
    local ok, st = pcall(reaper.GetToggleCommandState, MAIN_ACTION_SECTION, GRID_TOGGLE_CMD)
    return ok and st == 1
end

local function toggle_grid_lines()
    reaper.Main_OnCommand(GRID_TOGGLE_CMD, 0)
end

function GridRulerChip.render(ctx, font)
    if not ctx or not CONFIG or not CONFIG.UI or CONFIG.UI.ENABLE_GRID_RULER_CHIP ~= true then
        return
    end
    local R = _G.REAPER_UI_ANCHOR
    if not R or not R.get_timeline_ruler_screen_rect then
        return
    end
    local rl, rt, rr, rb = R.get_timeline_ruler_screen_rect()
    if not rl or not rt or not rr or not rb then
        return
    end

    local text_size = (CONFIG.SIZES and CONFIG.SIZES.TEXT) or 12
    if font then
        reaper.ImGui_PushFont(ctx, font, text_size)
    end

    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local tw = reaper.ImGui_CalcTextSize(ctx, CHIP_LABEL)
    local chip_w = tw + CHIP_H_PAD * 2
    local chip_h = line_h + CHIP_V_PAD * 2
    local ruler_w = rr - rl
    local ruler_h = rb - rt
    if ruler_w < 16 or ruler_h < 10 then
        if font then
            reaper.ImGui_PopFont(ctx)
        end
        return
    end

    local win_x = rr - chip_w - RULER_MARGIN
    local win_y = rt + (ruler_h - chip_h) * 0.5
    if win_x < rl + RULER_MARGIN then
        win_x = rl + RULER_MARGIN
    end

    reaper.ImGui_SetNextWindowPos(ctx, win_x, win_y, reaper.ImGui_Cond_Always())

    local flags = reaper.ImGui_WindowFlags_NoTitleBar()
        | reaper.ImGui_WindowFlags_NoCollapse()
        | reaper.ImGui_WindowFlags_NoResize()
        | reaper.ImGui_WindowFlags_NoMove()
        | reaper.ImGui_WindowFlags_AlwaysAutoResize()
        | reaper.ImGui_WindowFlags_NoScrollbar()
        | reaper.ImGui_WindowFlags_NoFocusOnAppearing()
    if reaper.ImGui_WindowFlags_NoDocking then
        flags = flags | reaper.ImGui_WindowFlags_NoDocking()
    end
    if reaper.ImGui_WindowFlags_NoBackground then
        flags = flags | reaper.ImGui_WindowFlags_NoBackground()
    end

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)

    local visible, _open = reaper.ImGui_Begin(ctx, "##atb_grid_ruler_chip", true, flags)
    if visible then
        local on = grid_lines_visible()
        local btn_txt = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.TEXT.NORMAL)
        local btn_bg = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.BG.NORMAL)

        reaper.ImGui_InvisibleButton(ctx, "##atb_grid_chip_hit", chip_w, chip_h)
        local hovered = reaper.ImGui_IsItemHovered(ctx)
        bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
            active = on,
            hover = hovered,
            disabled = false,
        })
        if reaper.ImGui_IsItemClicked(ctx, 0) then
            toggle_grid_lines()
        end

        local dl = reaper.ImGui_GetWindowDrawList(ctx)
        local x1, y1 = reaper.ImGui_GetItemRectMin(ctx)
        local x2, y2 = reaper.ImGui_GetItemRectMax(ctx)
        reaper.ImGui_DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_col, CHIP_ROUND)
        local tx = x1 + (chip_w - tw) * 0.5
        local ty = y1 + (chip_h - line_h) * 0.5
        reaper.ImGui_DrawList_AddText(dl, tx, ty, text_col, CHIP_LABEL)
    end
    reaper.ImGui_End(ctx)

    reaper.ImGui_PopStyleVar(ctx, 2)
    if font then
        reaper.ImGui_PopFont(ctx)
    end
end

return GridRulerChip
