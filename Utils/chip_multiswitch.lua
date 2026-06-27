-- Utils/chip_multiswitch.lua
-- Grouped track + sliding pill + labels (CodePen-style multiswitch) for widget chip rows.
--
-- Chip entry tables (e.g. MODES): use `label` for the full/human-readable text; optional `short_label`
-- for compact horizontal chips. If only `short_label` is set, call normalize_chip_entry(s) so `label`
-- is copied from `short_label`. Default chip text: short_label if set, else label, else id.

local M = {}

local function draw_multiswitch_track(coords, draw_list, x1, y1, x2, y2, pal, alpha_factor, chip_round)
    local track_col = COLOR_UTILS.modulateAlpha(pal.track, alpha_factor)
    local border_col = COLOR_UTILS.modulateAlpha(COLOR_UTILS.setAlpha(track_col, 0x44), alpha_factor)
    DRAWING.drawChipBackground(coords, draw_list, x1, y1, x2 - x1, y2 - y1, track_col, { rounding = chip_round, border_color = border_col })
end


local DRAWING = require("Utils.drawing")

M.PILL_INSET = 1
M.SLIDE_TAU = 0.065
M.MAX_DT = 0.05

function M.track_fill_color(btn_bg)
    return COLOR_UTILS.multiswitchTrackFill(btn_bg)
end

local function slide_axis_key(axis, ns)
    axis = axis or "x"
    local base = axis == "y" and "_slide_y" or "_slide_x"
    if ns and ns ~= "" then
        return base .. "_" .. ns
    end
    return base
end

local function slide_last_time_key(ns)
    if ns and ns ~= "" then
        return "_slide_last_time_" .. ns
    end
    return "_slide_last_time"
end

-- Toolbar buttons (and widgets) are shared across controller windows; isolate pill animation per window.
local function resolve_slide_namespace(self, opts)
    local base = (opts and opts.slide_namespace) or ""
    local cid = self and self._atb_controller_id
    local bid = self and self._button_instance_id
    if cid and bid then
        local suffix = tostring(cid) .. "_" .. tostring(bid)
        if base ~= "" then
            return base .. "_" .. suffix
        end
        return suffix
    end
    if base ~= "" then
        return base
    end
    return nil
end

--- axis: "x" (default) or "y". Updates self._slide_x / self._slide_y; returns current pill edge or nil.
--- ns: optional suffix so multiple chip rows on one widget do not share slide state (e.g. "rec", "lane").
function M.advance_slide(self, target, show_pill, axis, ns)
    axis = axis or "x"
    local key = slide_axis_key(axis, ns)
    local other_axis = axis == "y" and "x" or "y"
    local other = slide_axis_key(other_axis, ns)
    self[other] = nil

    local now = _G.FRAME_TIME or reaper.time_precise()
    local ltk = slide_last_time_key(ns)
    local last = self[ltk] or now
    local dt = math.min(math.max(now - last, 0), M.MAX_DT)
    self[ltk] = now

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

--- Independent horizontal + vertical slide keys (for grid multiswitch); does not clear the other axis.
function M.advance_slide_xy(self, target_x, target_y, show_pill, ns)
    ns = ns or ""
    local kx = "_slide_grid_x_" .. ns
    local ky = "_slide_grid_y_" .. ns
    local ltk = "_slide_grid_last_" .. ns

    local now = _G.FRAME_TIME or reaper.time_precise()
    local last = self[ltk] or now
    local dt = math.min(math.max(now - last, 0), M.MAX_DT)
    self[ltk] = now

    if not show_pill or target_x == nil or target_y == nil then
        self[kx] = nil
        self[ky] = nil
        return nil, nil
    end

    if self[kx] == nil then
        self[kx] = target_x
    end
    if self[ky] == nil then
        self[ky] = target_y
    end

    local k = 1 - math.exp(-dt / M.SLIDE_TAU)
    self[kx] = self[kx] + (target_x - self[kx]) * k
    self[ky] = self[ky] + (target_y - self[ky]) * k
    if math.abs(self[kx] - target_x) < 0.35 then
        self[kx] = target_x
    end
    if math.abs(self[ky] - target_y) < 0.35 then
        self[ky] = target_y
    end

    return self[kx], self[ky]
end

--- Chip entry tables use `label` (full / human-readable) and optional `short_label` (compact chip text).
--- If only `short_label` is set, `label` is filled to match (call once after defining entries).
function M.normalize_chip_entry(e)
    if type(e) ~= "table" then
        return e
    end
    if type(e.short_label) == "string" and e.short_label ~= "" and (e.label == nil or e.label == "") then
        e.label = e.short_label
    end
    return e
end

function M.normalize_chip_entries(entries)
    if not entries then
        return entries
    end
    for _, e in ipairs(entries) do
        M.normalize_chip_entry(e)
    end
    return entries
end

--- Text drawn on a chip: prefer short_label, else label, else id.
function M.chip_caption(mode)
    if type(mode) ~= "table" then
        return ""
    end
    if type(mode.short_label) == "string" and mode.short_label ~= "" then
        return mode.short_label
    end
    if type(mode.label) == "string" and mode.label ~= "" then
        return mode.label
    end
    return tostring(mode.id or "")
end

--- Vertical toolbars: use full `label` when it fits; otherwise compact caption.
function M.label_for_orientation(ctx, mode, chip_w, is_vertical, pad)
    pad = pad or 4
    if is_vertical and type(mode) == "table" and type(mode.label) == "string" and mode.label ~= "" then
        local tw = reaper.ImGui_CalcTextSize(ctx, mode.label) or 0
        if tw <= chip_w - pad then
            return mode.label
        end
    end
    return M.chip_caption(mode)
end

local function default_label(chip)
    if chip.blank then
        return ""
    end
    if chip.mode then
        return M.chip_caption(chip.mode)
    end
    return tostring(chip.id or "")
end

local function pill_covers_chip(px1, py1, px2, py2, chip)
    local cx = chip.x + chip.w * 0.5
    local cy = chip.y + chip.h * 0.5
    return cx >= px1 and cx <= px2 and cy >= py1 and cy <= py2
end

function M.bounds(chips)
    if not chips or #chips == 0 then return 0, 0, 0, 0 end
    local x1, y1 = chips[1].x, chips[1].y
    local x2, y2 = x1 + chips[1].w, y1 + chips[1].h
    for i = 2, #chips do
        local c = chips[i]
        x1 = math.min(x1, c.x)
        y1 = math.min(y1, c.y)
        x2 = math.max(x2, c.x + c.w)
        y2 = math.max(y2, c.y + c.h)
    end
    return x1, y1, x2, y2
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

function M.draw_grid(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
    opts = opts or {}
    local label_for = opts.label_for or default_label
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then
        return
    end

    local alpha_factor = opts.alpha_factor or 1.0
    local pal = COLOR_UTILS.multiswitchPalette(btn_txt, btn_bg)

    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or M.PILL_INSET
    local mx = opts.mx or 0
    local my = opts.my or 0
    local enabled = opts.enabled ~= false
    local mixed = opts.mixed == true

    local show_pill = opts.show_pill
    if show_pill == nil then
        show_pill = enabled and not mixed
    end

    local gx1, gy1, gx2, gy2 = M.bounds(chips)

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

    local slide_ns = resolve_slide_namespace(self, opts) or "grid"
    local local_slide_x, local_slide_y = M.advance_slide_xy(self, local_target_x, local_target_y, show_pill, slide_ns)

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

local function multi_toggle_pill_flags(chips, i, is_selected_segment, is_vertical)
    local n = #chips
    local prev_sel = i > 1 and is_selected_segment(chips[i - 1])
    local next_sel = i < n and is_selected_segment(chips[i + 1])
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

local function draw_multi_toggle(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts, is_vertical)
    opts = opts or {}
    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or M.PILL_INSET
    local enabled = opts.enabled ~= false
    local label_for = opts.label_for or default_label
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then return end

    local alpha_factor = opts.alpha_factor or 1.0
    local pal = COLOR_UTILS.multiswitchPalette(btn_txt, btn_bg)

    local gx1, gy1, gx2, gy2 = M.bounds(chips)
    draw_multiswitch_track(coords, draw_list, gx1, gy1, gx2, gy2, pal, alpha_factor, chip_round)

    local pr = math.max(1, chip_round - 1)

    for i, chip in ipairs(chips) do
        if is_selected_segment(chip) then
            local prev_sel = i > 1 and is_selected_segment(chips[i - 1])
            local next_sel = i < #chips and is_selected_segment(chips[i + 1])
            
            local px1 = is_vertical and (gx1 + pill_inset) or (chip.x + (prev_sel and 0 or pill_inset))
            local px2 = is_vertical and (gx2 - pill_inset) or (chip.x + chip.w - (next_sel and 0 or pill_inset))
            local py1 = is_vertical and (chip.y + (prev_sel and 0 or pill_inset)) or (gy1 + pill_inset)
            local py2 = is_vertical and (chip.y + chip.h - (next_sel and 0 or pill_inset)) or (gy2 - pill_inset)
            
            local flags = multi_toggle_pill_flags(chips, i, is_selected_segment, is_vertical)
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

function M.draw_multi_toggle_horizontal(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
    draw_multi_toggle(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts, false)
end

function M.draw_multi_toggle_vertical(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
    draw_multi_toggle(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts, true)
end

--- opts: mx, my, enabled, mixed, chip_round, pill_inset, label_for(chip), is_selected_segment(chip),
--- optional draw_chip_foreground(ctx, coords, draw_list, chip, text_col, label_text) — replaces default
--- centered ImGui_DrawList_AddText for each segment (horizontal sliding-pill layout only).
--- optional show_pill (override enabled and not mixed).
--- multi_toggle: if true, flush multi-toggle track (independent segments; highlight merges; sliding pill off).
--- vertical: true = chips stacked; pill slides vertically; each chip uses full row width.
--- grid_layout: equal rectangular grid; use with ROW.layout_multiswitch_grid (pad blanks non-interactive).
--- slide_namespace: optional string; isolates slide animation keys when drawing multiple rows on one widget.
function M.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
    opts = opts or {}
    if not chips or #chips == 0 then
        return
    end

    if opts.grid_layout then
        M.draw_grid(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
        return
    end

    if opts.vertical then
        M.draw_vertical(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
        return
    end

    local label_for = opts.label_for or default_label
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then
        return
    end

    local alpha_factor = opts.alpha_factor or 1.0

    if opts.multi_toggle then
        opts.label_for = label_for
        opts.is_selected_segment = is_selected_segment
        M.draw_multi_toggle_horizontal(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
        return
    end

    local pal = COLOR_UTILS.multiswitchPalette(btn_txt, btn_bg)

    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or M.PILL_INSET
    local mx = opts.mx or 0
    local my = opts.my or 0
    local enabled = opts.enabled ~= false
    local mixed = opts.mixed == true

    local show_pill = opts.show_pill
    if show_pill == nil then
        show_pill = enabled and not mixed
    end

    local gx1, gy1, gx2, gy2 = M.bounds(chips)

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

    local offset_x = opts.rel_x or 0
    local local_target_x = target_x and (target_x - offset_x) or nil
    local slide_ns = resolve_slide_namespace(self, opts)
    local local_slide_x = M.advance_slide(self, local_target_x, show_pill, "x", slide_ns)
    local slide_x = local_slide_x and (local_slide_x + offset_x) or nil
    local pill_cx = (slide_x and pill_w) and (slide_x + pill_w * 0.5) or nil
    draw_multiswitch_track(coords, draw_list, gx1, gy1, gx2, gy2, pal, alpha_factor, chip_round)

    if slide_x and pill_w and show_pill then
        local px1 = slide_x + pill_inset
        local px2 = slide_x + pill_w - pill_inset
        local py1 = gy1 + pill_inset
        local py2 = gy2 - pill_inset
        local pr = math.max(1, chip_round - 1)
        DRAWING.drawChipBackground(coords, draw_list, px1, py1, px2 - px1, py2 - py1, pal.pill, { rounding = pr, alpha_factor = alpha_factor })
    end

    for _, chip in ipairs(chips) do
        local under_pill = pill_cx
            and pill_cx >= chip.x
            and pill_cx < chip.x + chip.w
            and slide_x
            and show_pill

        local text_col = COLOR_UTILS.modulateAlpha(multiswitch_text_col(pal, enabled, under_pill), alpha_factor)

        local label_text = label_for(chip)
        if opts.draw_chip_foreground then
            opts.draw_chip_foreground(ctx, coords, draw_list, chip, text_col, label_text)
        else
            DRAWING.drawCenteredText(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, label_text, text_col)
        end
    end
end

function M.draw_vertical(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
    opts = opts or {}
    local label_for = opts.label_for or default_label
    local is_selected_segment = opts.is_selected_segment
    if not is_selected_segment then
        return
    end

    local alpha_factor = opts.alpha_factor or 1.0

    if opts.multi_toggle then
        opts.label_for = label_for
        opts.is_selected_segment = is_selected_segment
        M.draw_multi_toggle_vertical(ctx, chips, coords, draw_list, btn_txt, btn_bg, opts)
        return
    end

    local pal = COLOR_UTILS.multiswitchPalette(btn_txt, btn_bg)

    local chip_round = opts.chip_round or 3
    local pill_inset = opts.pill_inset or M.PILL_INSET
    local mx = opts.mx or 0
    local my = opts.my or 0
    local enabled = opts.enabled ~= false
    local mixed = opts.mixed == true

    local show_pill = opts.show_pill
    if show_pill == nil then
        show_pill = enabled and not mixed
    end

    local gx1, gy1, gx2, gy2 = M.bounds(chips)

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

    local offset_y = opts.rel_y or 0
    local local_target_y = target_y and (target_y - offset_y) or nil
    local slide_ns_v = resolve_slide_namespace(self, opts)
    local local_slide_y = M.advance_slide(self, local_target_y, show_pill, "y", slide_ns_v)
    local slide_y = local_slide_y and (local_slide_y + offset_y) or nil
    local pill_cy = (slide_y and pill_h) and (slide_y + pill_h * 0.5) or nil
    draw_multiswitch_track(coords, draw_list, gx1, gy1, gx2, gy2, pal, alpha_factor, chip_round)

    if slide_y and pill_h and show_pill then
        local px1 = gx1 + pill_inset
        local px2 = gx2 - pill_inset
        local py1 = slide_y + pill_inset
        local py2 = slide_y + pill_h - pill_inset
        local pr = math.max(1, chip_round - 1)
        DRAWING.drawChipBackground(coords, draw_list, px1, py1, px2 - px1, py2 - py1, pal.pill, { rounding = pr, alpha_factor = alpha_factor })
    end

    for _, chip in ipairs(chips) do
        local under_pill = pill_cy
            and pill_cy >= chip.y
            and pill_cy < chip.y + chip.h
            and slide_y
            and show_pill

        local text_col = COLOR_UTILS.modulateAlpha(multiswitch_text_col(pal, enabled, under_pill), alpha_factor)
        local text = label_for(chip)
        DRAWING.drawCenteredText(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, text, text_col)
    end
end

return M
