-- Utils/chip_multiswitch.lua
-- Grouped track + sliding pill + labels (CodePen-style multiswitch) for widget chip rows.

local M = {}

M.PILL_INSET = 1
M.SLIDE_TAU = 0.065
M.MAX_DT = 0.05

function M.track_fill_color(btn_bg)
    local br = (btn_bg >> 24) & 0xFF
    local bg = (btn_bg >> 16) & 0xFF
    local bb = (btn_bg >> 8) & 0xFF
    local r = math.floor(br * 0.4 + 0x33 * 0.6)
    local g = math.floor(bg * 0.4 + 0x33 * 0.6)
    local b = math.floor(bb * 0.4 + 0x33 * 0.6)
    return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

function M.dim_text_color(btn_txt, alpha)
    return btn_txt & 0xFFFFFF00 | (alpha & 0xFF)
end

--- axis: "x" (default) or "y". Updates self._slide_x / self._slide_y; returns current pill edge or nil.
function M.advance_slide(self, target, show_pill, axis)
    axis = axis or "x"
    local key = axis == "y" and "_slide_y" or "_slide_x"
    local other = axis == "y" and "_slide_x" or "_slide_y"
    self[other] = nil

    local now = _G.FRAME_TIME or reaper.time_precise()
    local last = self._slide_last_time or now
    local dt = math.min(math.max(now - last, 0), M.MAX_DT)
    self._slide_last_time = now

    if not show_pill or target == nil then
        self[key] = nil
        return nil
    end

    if self[key] == nil then
        self[key] = target
        return self[key]
    end

    local k = 1 - math.exp(-dt / M.SLIDE_TAU)
    self[key] = self[key] + (target - self[key]) * k
    if math.abs(self[key] - target) < 0.35 then
        self[key] = target
    end
    return self[key]
end

local function default_label(chip)
    if type(chip.label) == "string" then
        return chip.label
    end
    if chip.mode and type(chip.mode.label) == "string" then
        return chip.mode.label
    end
    return tostring(chip.id or "")
end

--- opts: mx, my, enabled, mixed, chip_round, pill_inset, label_for(chip), is_selected_segment(chip),
--- optional show_pill (override enabled and not mixed).
--- vertical: true = chips stacked; pill slides vertically; each chip uses full row width.
function M.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
    opts = opts or {}
    if not chips or #chips == 0 then
        return
    end

    if opts.vertical then
        M.draw_vertical(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
        return
    end

    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or M.PILL_INSET
    local mx = opts.mx or 0
    local my = opts.my or 0
    local enabled = opts.enabled ~= false
    local mixed = opts.mixed == true
    local label_for = opts.label_for or default_label
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then
        return
    end

    local show_pill = opts.show_pill
    if show_pill == nil then
        show_pill = enabled and not mixed
    end

    local chip_h = chips[1].h
    local row_y = chips[1].y
    local gx1 = chips[1].x
    local gx2 = chips[#chips].x + chips[#chips].w
    local gy1 = row_y
    local gy2 = row_y + chip_h

    local target_x, pill_w = nil, chips[1].w
    if show_pill then
        for _, c in ipairs(chips) do
            if is_selected_segment(c) then
                target_x = c.x
                pill_w = c.w
                break
            end
        end
        if target_x == nil then
            show_pill = false
        end
    end

    local slide_x = M.advance_slide(self, target_x, show_pill, "x")
    local pill_cx = (slide_x and pill_w) and (slide_x + pill_w * 0.5) or nil

    local track_col = M.track_fill_color(btn_bg)
    local ix1, iy1 = coords:relativeToDrawList(gx1, gy1)
    local ix2, iy2 = coords:relativeToDrawList(gx2, gy2)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, ix1, iy1, ix2, iy2, track_col, chip_round)
    local border_col = track_col & 0xFFFFFF00 | 0x44
    reaper.ImGui_DrawList_AddRect(draw_list, ix1, iy1, ix2, iy2, border_col, chip_round, 0, 1)

    if slide_x and pill_w and show_pill then
        local py1 = row_y + pill_inset
        local py2 = row_y + chip_h - pill_inset
        local pill_bg, _ = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, { active = true, disabled = false })
        local pr = math.max(1, chip_round - 1)
        local px1, py_a = coords:relativeToDrawList(slide_x, py1)
        local px2, py_b = coords:relativeToDrawList(slide_x + pill_w, py2)
        reaper.ImGui_DrawList_AddRectFilled(draw_list, px1, py_a, px2, py_b, pill_bg, pr)
    end

    for _, chip in ipairs(chips) do
        local is_hover = enabled and coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local under_pill = pill_cx
            and pill_cx >= chip.x
            and pill_cx < chip.x + chip.w
            and slide_x
            and show_pill

        local _, text_col
        if not enabled then
            _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
                active = false,
                hover = false,
                disabled = true,
            })
        elseif under_pill then
            _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
                active = true,
                hover = false,
                disabled = false,
            })
        elseif is_hover then
            _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
                active = false,
                hover = true,
                disabled = false,
            })
        else
            text_col = M.dim_text_color(btn_txt, 0xCC)
        end

        local text = label_for(chip)
        local tw = reaper.ImGui_CalcTextSize(ctx, text)
        local tx = chip.x + (chip.w - tw) / 2
        local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, text)
    end
end

function M.draw_vertical(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or M.PILL_INSET
    local mx = opts.mx or 0
    local my = opts.my or 0
    local enabled = opts.enabled ~= false
    local mixed = opts.mixed == true
    local label_for = opts.label_for or default_label
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then
        return
    end

    local show_pill = opts.show_pill
    if show_pill == nil then
        show_pill = enabled and not mixed
    end

    local gx1 = chips[1].x
    local gx2 = chips[1].x + chips[1].w
    local gy1 = chips[1].y
    local gy2 = chips[#chips].y + chips[#chips].h

    local target_y, pill_h = nil, chips[1].h
    if show_pill then
        for _, c in ipairs(chips) do
            if is_selected_segment(c) then
                target_y = c.y
                pill_h = c.h
                break
            end
        end
        if target_y == nil then
            show_pill = false
        end
    end

    local slide_y = M.advance_slide(self, target_y, show_pill, "y")
    local pill_cy = (slide_y and pill_h) and (slide_y + pill_h * 0.5) or nil

    local track_col = M.track_fill_color(btn_bg)
    local ix1, iy1 = coords:relativeToDrawList(gx1, gy1)
    local ix2, iy2 = coords:relativeToDrawList(gx2, gy2)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, ix1, iy1, ix2, iy2, track_col, chip_round)
    local border_col = track_col & 0xFFFFFF00 | 0x44
    reaper.ImGui_DrawList_AddRect(draw_list, ix1, iy1, ix2, iy2, border_col, chip_round, 0, 1)

    if slide_y and pill_h and show_pill then
        local col_w = chips[1].w
        local px1 = gx1 + pill_inset
        local px2 = gx1 + col_w - pill_inset
        local py1 = slide_y + pill_inset
        local py2 = slide_y + pill_h - pill_inset
        local pill_bg, _ = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, { active = true, disabled = false })
        local pr = math.max(1, chip_round - 1)
        local ax1, ay_a = coords:relativeToDrawList(px1, py1)
        local ax2, ay_b = coords:relativeToDrawList(px2, py2)
        reaper.ImGui_DrawList_AddRectFilled(draw_list, ax1, ay_a, ax2, ay_b, pill_bg, pr)
    end

    for _, chip in ipairs(chips) do
        local is_hover = enabled and coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local under_pill = pill_cy
            and pill_cy >= chip.y
            and pill_cy < chip.y + chip.h
            and slide_y
            and show_pill

        local _, text_col
        if not enabled then
            _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
                active = false,
                hover = false,
                disabled = true,
            })
        elseif under_pill then
            _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
                active = true,
                hover = false,
                disabled = false,
            })
        elseif is_hover then
            _, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
                active = false,
                hover = true,
                disabled = false,
            })
        else
            text_col = M.dim_text_color(btn_txt, 0xCC)
        end

        local text = label_for(chip)
        local tw = reaper.ImGui_CalcTextSize(ctx, text)
        local tx = chip.x + (chip.w - tw) / 2
        local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, text)
    end
end

return M
