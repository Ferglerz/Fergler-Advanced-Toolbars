-- Track, sliding pill, multi-toggle, and grid draw helpers for chip multiswitch.

local DRAWING = require("Utils.Draw.drawing")

local M = {}

local function draw_multiswitch_track(coords, draw_list, x1, y1, x2, y2, pal, alpha_factor, chip_round)
    local track_col = COLOR_UTILS.modulateAlpha(pal.track, alpha_factor)
    local border_col = COLOR_UTILS.modulateAlpha(COLOR_UTILS.setAlpha(track_col, 0x44), alpha_factor)
    DRAWING.drawChipBackground(coords, draw_list, x1, y1, x2 - x1, y2 - y1, track_col, { rounding = chip_round, border_color = border_col })
end

local function default_label(ms, chip)
    if chip.blank then
        return ""
    end
    if chip.mode then
        return ms.chip_caption(chip.mode)
    end
    return tostring(chip.id or "")
end

local function pill_covers_chip(px1, py1, px2, py2, chip)
    local cx = chip.x + chip.w * 0.5
    local cy = chip.y + chip.h * 0.5
    return cx >= px1 and cx <= px2 and cy >= py1 and cy <= py2
end

local function multiswitch_text_col(palette, enabled, on_pill)
    if not enabled then
        return palette.text_disabled
    end
    if on_pill then
        return palette.text_on_pill
    end
    return palette.text_on_track
end

local function chips_same_row(a, b)
    if not a or not b then
        return false
    end
    return math.abs(a.y - b.y) <= 1
end

--- True when every chip shares the same row (horizontal multi_toggle may use full track height).
local function chips_share_one_row(chips)
    if not chips or #chips < 2 then
        return true
    end
    local y = chips[1].y
    for i = 2, #chips do
        if math.abs(chips[i].y - y) > 1 then
            return false
        end
    end
    return true
end

local function group_chips_by_row(chips)
    local order = {}
    local by_y = {}
    for _, c in ipairs(chips or {}) do
        local key = math.floor(c.y + 0.5)
        if not by_y[key] then
            by_y[key] = {}
            order[#order + 1] = key
        end
        by_y[key][#by_y[key] + 1] = c
    end
    table.sort(order)
    local rows = {}
    for _, key in ipairs(order) do
        rows[#rows + 1] = by_y[key]
    end
    return rows
end

local function draw_multi_toggle_tracks(coords, draw_list, chips, ms, pal, alpha_factor, chip_round, is_vertical)
    if is_vertical or chips_share_one_row(chips) then
        local gx1, gy1, gx2, gy2 = ms.bounds(chips)
        draw_multiswitch_track(coords, draw_list, gx1, gy1, gx2, gy2, pal, alpha_factor, chip_round)
        return
    end
    for _, row in ipairs(group_chips_by_row(chips)) do
        local rx1, ry1, rx2, ry2 = ms.bounds(row)
        draw_multiswitch_track(coords, draw_list, rx1, ry1, rx2, ry2, pal, alpha_factor, chip_round)
    end
end

function M.multi_toggle_pill_flags(chips, i, is_selected_segment, is_vertical)
    local n = #chips
    local chip = chips[i]
    local prev = i > 1 and chips[i - 1]
    local nxt = i < n and chips[i + 1]
    local prev_sel = prev and is_selected_segment(prev)
        and (is_vertical or chips_same_row(chip, prev))
    local next_sel = nxt and is_selected_segment(nxt)
        and (is_vertical or chips_same_row(chip, nxt))
    local round_first = (i == 1) or not prev_sel
    local round_last = (i == n) or not next_sel
    if round_first and round_last then
        return reaper.ImGui_DrawFlags_RoundCornersAll()
    end
    if is_vertical then
        if round_first then return reaper.ImGui_DrawFlags_RoundCornersTop() end
        if round_last then return reaper.ImGui_DrawFlags_RoundCornersBottom() end
    else
        if round_first then return reaper.ImGui_DrawFlags_RoundCornersLeft() end
        if round_last then return reaper.ImGui_DrawFlags_RoundCornersRight() end
    end
    return reaper.ImGui_DrawFlags_RoundCornersNone()
end

local function draw_multi_toggle(ctx, ms, slide, chips, coords, draw_list, btn_txt, btn_bg, opts, is_vertical)
    opts = opts or {}
    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or slide.PILL_INSET
    local enabled = opts.enabled ~= false
    local label_for = opts.label_for or function(chip) return default_label(ms, chip) end
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then
        return
    end

    local alpha_factor = opts.alpha_factor or 1.0
    local pal = COLOR_UTILS.multiswitchPalette(btn_txt, btn_bg)
    local single_row = not is_vertical and chips_share_one_row(chips)
    local gx1, gy1, gx2, gy2 = ms.bounds(chips)

    draw_multi_toggle_tracks(coords, draw_list, chips, ms, pal, alpha_factor, chip_round, is_vertical)

    local pr = math.max(1, chip_round - 1)

    for i, chip in ipairs(chips) do
        if is_selected_segment(chip) then
            local prev = i > 1 and chips[i - 1]
            local nxt = i < #chips and chips[i + 1]
            local prev_sel = prev and is_selected_segment(prev)
                and (is_vertical or single_row or chips_same_row(chip, prev))
            local next_sel = nxt and is_selected_segment(nxt)
                and (is_vertical or single_row or chips_same_row(chip, nxt))

            local px1 = is_vertical and (gx1 + pill_inset) or (chip.x + (prev_sel and 0 or pill_inset))
            local px2 = is_vertical and (gx2 - pill_inset) or (chip.x + chip.w - (next_sel and 0 or pill_inset))
            local py1, py2
            if is_vertical then
                py1 = chip.y + (prev_sel and 0 or pill_inset)
                py2 = chip.y + chip.h - (next_sel and 0 or pill_inset)
            elseif single_row then
                py1 = gy1 + pill_inset
                py2 = gy2 - pill_inset
            else
                py1 = chip.y + pill_inset
                py2 = chip.y + chip.h - pill_inset
            end

            local flags = M.multi_toggle_pill_flags(chips, i, is_selected_segment, is_vertical)
            DRAWING.drawChipBackground(coords, draw_list, px1, py1, px2 - px1, py2 - py1, pal.pill, { rounding = pr, flags = flags, alpha_factor = alpha_factor })
        end
    end

    for _, chip in ipairs(chips) do
        local sel = is_selected_segment(chip)
        local text_col = COLOR_UTILS.modulateAlpha(multiswitch_text_col(pal, enabled, sel), alpha_factor)
        local text = label_for(chip)
        DRAWING.drawCenteredText(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, text, text_col)
    end
end

local function draw_sliding_pill(ctx, ms, slide, self, chips, coords, draw_list, btn_txt, btn_bg, opts, axis)
    opts = opts or {}
    local is_vertical = axis == "y"
    local label_for = opts.label_for or function(chip) return default_label(ms, chip) end
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then
        return
    end

    local alpha_factor = opts.alpha_factor or 1.0
    local pal = COLOR_UTILS.multiswitchPalette(btn_txt, btn_bg)
    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or slide.PILL_INSET
    local enabled = opts.enabled ~= false
    local mixed = opts.mixed == true

    local show_pill = opts.show_pill
    if show_pill == nil then
        show_pill = enabled and not mixed
    end

    local gx1, gy1, gx2, gy2 = ms.bounds(chips)

    local target_pos, pill_span = nil, is_vertical and chips[1].h or chips[1].w
    if show_pill then
        for _, c in ipairs(chips) do
            if is_selected_segment(c) then
                target_pos = is_vertical and c.y or c.x
                pill_span = is_vertical and c.h or c.w
                break
            end
        end
        if target_pos == nil then
            show_pill = false
        end
    end

    local offset_key = is_vertical and "rel_y" or "rel_x"
    local offset = opts[offset_key] or 0
    local local_target = target_pos and (target_pos - offset) or nil
    local slide_ns = slide.resolve_slide_namespace(self, opts)
    local local_slide = slide.advance_slide(self, local_target, show_pill, axis, slide_ns)
    local slide_pos = local_slide and (local_slide + offset) or nil
    local pill_center = (slide_pos and pill_span) and (slide_pos + pill_span * 0.5) or nil

    draw_multiswitch_track(coords, draw_list, gx1, gy1, gx2, gy2, pal, alpha_factor, chip_round)

    if slide_pos and pill_span and show_pill then
        local px1, py1, px2, py2
        if is_vertical then
            px1 = gx1 + pill_inset
            px2 = gx2 - pill_inset
            py1 = slide_pos + pill_inset
            py2 = slide_pos + pill_span - pill_inset
        else
            px1 = slide_pos + pill_inset
            px2 = slide_pos + pill_span - pill_inset
            py1 = gy1 + pill_inset
            py2 = gy2 - pill_inset
        end
        local pr = math.max(1, chip_round - 1)
        DRAWING.drawChipBackground(coords, draw_list, px1, py1, px2 - px1, py2 - py1, pal.pill, { rounding = pr, alpha_factor = alpha_factor })
    end

    for _, chip in ipairs(chips) do
        local under_pill
        if is_vertical then
            under_pill = pill_center
                and pill_center >= chip.y
                and pill_center < chip.y + chip.h
                and slide_pos
                and show_pill
        else
            under_pill = pill_center
                and pill_center >= chip.x
                and pill_center < chip.x + chip.w
                and slide_pos
                and show_pill
        end

        local text_col = COLOR_UTILS.modulateAlpha(multiswitch_text_col(pal, enabled, under_pill), alpha_factor)
        local label_text = label_for(chip)
        if not is_vertical and opts.draw_chip_foreground then
            opts.draw_chip_foreground(ctx, coords, draw_list, chip, text_col, label_text)
        else
            DRAWING.drawCenteredText(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, label_text, text_col)
        end
    end
end

function M.attach(ms, slide)
    function ms.draw_grid(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
        opts = opts or {}
        local label_for = opts.label_for or function(chip) return default_label(ms, chip) end
        local is_selected_segment = opts.is_selected_segment
        if not is_selected_segment then
            return
        end

        local alpha_factor = opts.alpha_factor or 1.0
        local pal = COLOR_UTILS.multiswitchPalette(btn_txt, btn_bg)
        local chip_round = opts.chip_round or 3
        local pill_inset = opts.pill_inset or slide.PILL_INSET
        local enabled = opts.enabled ~= false
        local mixed = opts.mixed == true

        local show_pill = opts.show_pill
        if show_pill == nil then
            show_pill = enabled and not mixed
        end

        local gx1, gy1, gx2, gy2 = ms.bounds(chips)

        local target_x, target_y, pill_w, pill_h = nil, nil, nil, nil
        if show_pill then
            for _, c in ipairs(chips) do
                if is_selected_segment(c) then
                    pill_w = math.max(1, c.w - 2 * pill_inset)
                    pill_h = math.max(1, c.h - 2 * pill_inset)
                    target_x = c.x + (c.w - pill_w) / 2
                    target_y = c.y + (c.h - pill_h) / 2
                    break
                end
            end
            if target_x == nil then
                show_pill = false
            end
        end

        local offset_x = opts.rel_x or 0
        local offset_y = opts.rel_y or 0
        local local_target_x = target_x and (target_x - offset_x) or nil
        local local_target_y = target_y and (target_y - offset_y) or nil

        local slide_ns = slide.resolve_slide_namespace(self, opts) or "grid"
        local local_slide_x, local_slide_y = slide.advance_slide_xy(self, local_target_x, local_target_y, show_pill, slide_ns)

        local slide_x = local_slide_x and (local_slide_x + offset_x) or nil
        local slide_y = local_slide_y and (local_slide_y + offset_y) or nil
        draw_multiswitch_track(coords, draw_list, gx1, gy1, gx2, gy2, pal, alpha_factor, chip_round)

        local pr = math.max(1, chip_round - 1)
        if slide_x and slide_y and pill_w and pill_h and show_pill then
            DRAWING.drawChipBackground(coords, draw_list, slide_x, slide_y, pill_w, pill_h, pal.pill, { rounding = pr, alpha_factor = alpha_factor })
        end

        local px1, py_a, px2, py_b
        if slide_x and slide_y and pill_w and pill_h and show_pill then
            px1, py_a = slide_x, slide_y
            px2, py_b = slide_x + pill_w, slide_y + pill_h
        end

        for _, chip in ipairs(chips) do
            if not chip.blank then
                local under_pill = px1 and pill_covers_chip(px1, py_a, px2, py_b, chip)
                local text_col = COLOR_UTILS.modulateAlpha(multiswitch_text_col(pal, enabled, under_pill), alpha_factor)
                local text = label_for(chip)
                if text ~= "" then
                    DRAWING.drawCenteredText(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, text, text_col)
                end
            end
        end
    end

    function ms.draw_multi_toggle_horizontal(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
        draw_multi_toggle(ctx, ms, slide, chips, coords, draw_list, btn_txt, btn_bg, opts, false)
    end

    function ms.draw_multi_toggle_vertical(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
        draw_multi_toggle(ctx, ms, slide, chips, coords, draw_list, btn_txt, btn_bg, opts, true)
    end

    function ms.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
        opts = opts or {}
        if not chips or #chips == 0 then
            return
        end

        if opts.grid_layout then
            ms.draw_grid(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
            return
        end

        if opts.vertical then
            ms.draw_vertical(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
            return
        end

        local label_for = opts.label_for or function(chip) return default_label(ms, chip) end
        local is_selected_segment = opts.is_selected_segment
        if not is_selected_segment then
            return
        end

        if opts.multi_toggle then
            opts.label_for = label_for
            opts.is_selected_segment = is_selected_segment
            ms.draw_multi_toggle_horizontal(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
            return
        end

        draw_sliding_pill(ctx, ms, slide, self, chips, coords, draw_list, btn_txt, btn_bg, opts, "x")
    end

    function ms.draw_vertical(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
        opts = opts or {}
        local label_for = opts.label_for or function(chip) return default_label(ms, chip) end
        local is_selected_segment = opts.is_selected_segment
        if not is_selected_segment then
            return
        end

        if opts.multi_toggle then
            opts.label_for = label_for
            opts.is_selected_segment = is_selected_segment
            ms.draw_multi_toggle_vertical(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
            return
        end

        draw_sliding_pill(ctx, ms, slide, self, chips, coords, draw_list, btn_txt, btn_bg, opts, "y")
    end
end

return M
