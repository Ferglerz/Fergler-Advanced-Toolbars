-- Widgets/Under Development/recording_options.lua
-- Project record mode + overlapping recording: lanes, item behavior, loop-takes toggle.
-- Command IDs for newer Options entries are resolved once by scanning Main action names (kbd_getTextFromCmd).

local ROW = require("Renderers.Widgets.chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_HIT = require("Utils.chip_hit_prefix")

local PAD_Y = 2
local ROW_GAP = 4
local SEP_EXTRA = 6
local CHIP_GAP = ROW.CHIP_GAP
local SCAN_LO, SCAN_HI = 40000, 50000

local RECORD = {
    { id = "rec_norm", short_label = "Norm", label = "Record: normal", cmd = 40252 },
    { id = "rec_time", short_label = "Time", label = "Record: time selection auto-punch", cmd = 40076 },
    { id = "rec_item", short_label = "Auto", label = "Record: selected item auto-punch", cmd = 40253 },
}

local LANE = {
    { id = "lane_no", short_label = "No", label = "Do not add lanes", key = "lane_no" },
    { id = "lane_ex", short_label = "Lanes", label = "Add lanes (exclusive)", key = "lane_exclusive" },
    { id = "lane_ly", short_label = "Lyrs", label = "Lanes in layers", key = "lane_layers" },
}

local ITEM = {
    { id = "item_sp", short_label = "Split", label = "Split and add takes", key = "item_split" },
    { id = "item_tr", short_label = "Trim", label = "Trim (tape mode)", key = "item_trim" },
    { id = "item_ad", short_label = "Add", label = "Add media in layers", key = "item_add" },
}

local LOOP_CHIP = { id = "loop_tk", short_label = "Loop+", label = "Loop recording always adds takes", key = "loop_takes" }

CHIP_MS.normalize_chip_entries(RECORD)
CHIP_MS.normalize_chip_entries(LANE)
CHIP_MS.normalize_chip_entries(ITEM)
CHIP_MS.normalize_chip_entry(LOOP_CHIP)

local FALLBACK = {
    lane_layers = 41329,
    item_split = 41330,
    item_trim = 41186,
    loop_takes = 40114,
}

local SCAN_SUBSTR = {
    lane_no = "Do not add lanes",
    lane_exclusive = "new lanes play exclusively",
    lane_layers = "separate lanes (layers)",
    item_split = "splits existing items and creates new takes",
    item_trim = "New recording trims existing items behind new recording (tape mode)",
    item_add = "Add media items in layers",
    loop_takes = "Loop recording always adds takes",
}

local PREFIX = "recopt_"

local widget = {
    name = "Recording Options",
    category = "Under Development",
    type = "display",
    update_interval = 0.2,
    width = 560,
    label = "",
    description = "Record mode (Norm / Time / Auto), then overlapping recording: lane mode (No / Lanes / Lyrs), item mode (Split / Trim / Add), and Loop+ toggle. Main action IDs for lane/item rows are found by scanning your REAPER build (fallbacks where listed).",
    chip_widget = true,
    suppress_tooltip = true,
    _slide_out_mode = true,
    _resolved = nil,
}

local function main_section()
    return reaper.SectionFromUniqueID(0)
end

local function scan_cmd(substr)
    if not substr or substr == "" then
        return nil
    end
    local sec = main_section()
    for cmd = SCAN_LO, SCAN_HI do
        local ok, name = pcall(reaper.kbd_getTextFromCmd, cmd, sec)
        if ok and name and name:find(substr, 1, true) then
            return cmd
        end
    end
    return nil
end

local function ensure_resolved()
    if widget._resolved then
        return widget._resolved
    end
    local r = {}
    for k, sub in pairs(SCAN_SUBSTR) do
        local id = scan_cmd(sub)
        if not id then
            id = FALLBACK[k]
        end
        r[k] = id
    end
    widget._resolved = r
    return r
end

local function detect_record_mode()
    for _, e in ipairs(RECORD) do
        local ok, st = pcall(reaper.GetToggleCommandState, e.cmd)
        if ok and st == 1 then
            return e.id
        end
    end
    return nil
end

local function detect_mutex_active(ids, cmd_for)
    for _, e in ipairs(ids) do
        local cmd = cmd_for(e)
        if cmd then
            local ok, st = pcall(reaper.GetToggleCommandState, cmd)
            if ok and st == 1 then
                return e.id
            end
        end
    end
    return nil
end

local function row_line_height(ctx)
    return ROW.chip_line_height(ctx)
end

local function build_row_entries(entries, cmd_for)
    local row_entries = {}
    for _, e in ipairs(entries) do
        local ce = {}
        for k, v in pairs(e) do
            ce[k] = v
        end
        ce.cmd = cmd_for(e)
        row_entries[#row_entries + 1] = ce
    end
    return row_entries
end

--- Chip row at exact y (ROW.layout_entries_horizontal centers in CONFIG.SIZES.HEIGHT — wrong for stacked rows).
local function layout_one_row(ctx, rel_x, row_top_y, render_width, entries, cmd_for, min_chip_w)
    local row_entries = build_row_entries(entries, cmd_for)
    local pad_x = 4 + ROW.button_rounding_content_pad()
    local strip_w = math.max(40, render_width - pad_x * 2)
    return ROW.layout_chip_strip(ctx, rel_x + pad_x, row_top_y, strip_w, row_entries, {
        min_chip_w = min_chip_w,
        chip_pad_h = 6,
    })
end

function widget.getLayoutWidth(self, ctx, is_vertical_toolbar)
    local natural = self.width or 560
    if ctx and reaper.ImGui_GetTextLineHeight and self._slide_out_mode and not is_vertical_toolbar then
        natural = math.max(120, ROW.uniform_chip_row_width(ctx, RECORD, {
            pad_x = 4,
            chip_pad_h = 6,
            min_chip_w = 36,
        }))
    else
        natural = ROW.default_layout_width(ctx, 3, { base_width = natural, min_chip_w = 32 })
    end
    return ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    local lh = row_line_height(ctx)
    local R = ROW.button_rounding_content_pad()
    if self._preview_mode then
        return (PAD_Y + R) * 2 + lh
    end
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    return (PAD_Y + R) * 2 + lh
end

function widget.slide_height(self, ctx, host_w, host_h, layout)
    local lh = row_line_height(ctx)
    local R = ROW.button_rounding_content_pad()
    if layout and layout.is_vertical then
        return host_h
    end
    return (PAD_Y + R) * 2 + lh * 3 + ROW_GAP * 2
end

function widget.slide_width(self, ctx, host_w, _host_h, _layout)
    return host_w
end

function widget.getValue(self)
    local r = ensure_resolved()
    self._active_rec = detect_record_mode()
    self._active_lane = detect_mutex_active(LANE, function(e)
        return r[e.key]
    end)
    self._active_item = detect_mutex_active(ITEM, function(e)
        return r[e.key]
    end)
    local lc = r.loop_takes
    if lc then
        local ok, st = pcall(reaper.GetToggleCommandState, lc)
        self._loop_on = ok and st == 1
    else
        self._loop_on = false
    end
    return 0
end

function widget.layout_geometry(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out)
    local lh = row_line_height(ctx)
    local R = ROW.button_rounding_content_pad()
    local y = rel_y + PAD_Y + R
    local r = ensure_resolved()

    if not is_slide_out then
        local chips_record = layout_one_row(ctx, rel_x, y, render_width, RECORD, function(e)
            return e.cmd
        end, 36)
        self._chips_record = chips_record
        self._chips_lane = nil
        self._chips_item = nil
        self._chips_loop = nil
        self._sep_y = nil
        return
    end

    if is_slide_out then
        local chips_lane = layout_one_row(ctx, rel_x, y, render_width, LANE, function(e)
            return r[e.key]
        end, 32)
        y = y + lh + ROW_GAP

        local chips_item = layout_one_row(ctx, rel_x, y, render_width, ITEM, function(e)
            return r[e.key]
        end, 32)
        y = y + lh + ROW_GAP

        local chips_loop = layout_one_row(ctx, rel_x, y, render_width, { LOOP_CHIP }, function(_e)
            return r.loop_takes
        end, 44)

        self._chips_record = nil
        self._chips_lane = chips_lane
        self._chips_item = chips_item
        self._chips_loop = chips_loop
        self._sep_y = nil
        return
    end
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    self:layout_geometry(ctx, rel_x, rel_y, render_width, layout, is_slide_out)
    local mx, my = coords:getRelativeMouse()

    local function hit(chips)
        if not chips then
            return nil
        end
        for _, chip in ipairs(chips) do
            if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
                return PREFIX .. chip.mode.id
            end
        end
        return nil
    end

    if is_slide_out then
        return hit(self._chips_lane) or hit(self._chips_item) or hit(self._chips_loop)
    end
    return hit(self._chips_record)
end

function widget.onSubcontrolClick(self, sub_id)
    local id = CHIP_HIT.strip(PREFIX, sub_id)
    if not id then
        return false
    end
    local r = ensure_resolved()

    local function run(cmd)
        if cmd and cmd > 0 then
            reaper.Main_OnCommand(cmd, 0)
            return true
        end
        return false
    end

    for _, e in ipairs(RECORD) do
        if e.id == id then
            if self._active_rec == id then
                return true
            end
            run(e.cmd)
            return true
        end
    end

    for _, e in ipairs(LANE) do
        if e.id == id then
            if self._active_lane == id then
                return true
            end
            run(r[e.key])
            return true
        end
    end

    for _, e in ipairs(ITEM) do
        if e.id == id then
            if self._active_item == id then
                return true
            end
            run(r[e.key])
            return true
        end
    end

    if id == LOOP_CHIP.id then
        run(r.loop_takes)
        return true
    end

    return false
end

local function draw_sep(ctx, coords, draw_list, rel_x, y, w)
    local R = ROW.button_rounding_content_pad()
    local x1, y1 = coords:relativeToDrawList(rel_x + 4 + R, y)
    local x2, y2 = coords:relativeToDrawList(rel_x + w - 4 - R, y)
    reaper.ImGui_DrawList_AddLine(draw_list, x1, y1, x2, y2, 0xFFFFFF44, 1)
end

local function draw_row(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, row, slide_ns, label_for, alpha_factor)
    if not chips or #chips == 0 then
        return
    end
    local mx, my = coords:getRelativeMouse()
    CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = ROW.CHIP_ROUND,
        slide_namespace = slide_ns,
        alpha_factor = alpha_factor,
        label_for = label_for,
        is_selected_segment = function(c)
            local m = c.mode
            if row == "rec" then
                return self._active_rec == m.id
            end
            if row == "lane" then
                return self._active_lane == m.id
            end
            if row == "item" then
                return self._active_item == m.id
            end
            if row == "loop" then
                return self._loop_on == true
            end
            return false
        end,
    })
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    if self._preview_mode then
        self._active_rec = "rec_norm"
        self._active_lane = "lane_no"
        self._active_item = "item_sp"
        self._loop_on = true
    end

    local is_slide_out = self._is_rendering_slide_out == true
    self:layout_geometry(ctx, rel_x, rel_y, render_width, layout, is_slide_out)

    local vert = layout and layout.is_vertical
    local function label_for_chip(c)
        return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
    end

    if is_slide_out then
        draw_row(ctx, self, self._chips_lane, coords, draw_list, btn_txt, btn_bg, "lane", "lane", label_for_chip, self._slide_alpha_factor)
        draw_row(ctx, self, self._chips_item, coords, draw_list, btn_txt, btn_bg, "item", "item", label_for_chip, self._slide_alpha_factor)
        draw_row(ctx, self, self._chips_loop, coords, draw_list, btn_txt, btn_bg, "loop", "loop", label_for_chip, self._slide_alpha_factor)
        return
    end

    draw_row(ctx, self, self._chips_record, coords, draw_list, btn_txt, btn_bg, "rec", "rec", label_for_chip, nil)
end

return widget
