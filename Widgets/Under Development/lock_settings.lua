-- Widgets/Under Development/lock_settings.lua
-- Project lock: one chip toggles Options: locking (1135). Right-click menu sets each lock mode
-- (Main section toggles 40573–41854) and the chip label (e.g. "Time Lock" for L/R items + regions + markers).

local ROW = require("Renderers.Widgets.chip_row")
local ICON_FONTS_LIB = require("Utils.icon_fonts")
local OPT_POPUP = require("Utils.widget_options_popup")
local DRAWING = require("Utils.drawing")

local CHIP_ROUND = ROW.CHIP_ROUND
local TOGGLE_PAD_H = 10
local ICON_NAME_GAP = 4
local DEFAULT_CHIP_LABEL = "Lock"
local LABEL_INPUT_HINT = "Chip name"

local LOCK_ICON_PATH_CLOSED = UTILS.normalizeSlashes("IconFonts/icons/Tools/Lock Closed.ttf")
local LOCK_ICON_PATH_OPEN = UTILS.normalizeSlashes("IconFonts/icons/Tools/Lock Open.ttf")
local LOCK_GLYPH = utf8.char(ICON_FONTS_LIB.ICON_CODEPOINT)

local CMD_MASTER = 1135

local TIME_LOOP = {
    { id = "time", short_label = "Time", label = "Time selection", cmd = 40573 },
    { id = "loop", short_label = "Loop", label = "Loop points", cmd = 40629 },
}

local ITEMS = {
    { id = "item_full", short_label = "Full", label = "Items (full)", cmd = 40576 },
    { id = "item_edge", short_label = "Edge", label = "Item edges", cmd = 40597 },
    { id = "item_lr", short_label = "L/R", label = "Items (prevent left/right movement)", cmd = 40579 },
    { id = "item_ud", short_label = "U/D", label = "Items (prevent up/down movement)", cmd = 40582 },
    { id = "item_fade", short_label = "Fade", label = "Item fade/volume handles", cmd = 40600 },
    { id = "item_stretch", short_label = "Str", label = "Item stretch markers", cmd = 41854 },
}

local ENVS = {
    { id = "take_env", short_label = "Take", label = "Take envelopes", cmd = 41851 },
    { id = "track_env", short_label = "Trk", label = "Track envelopes", cmd = 40585 },
}

local MARKS = {
    { id = "region", short_label = "Rgn", label = "Regions", cmd = 40588 },
    { id = "marker", short_label = "Mrk", label = "Markers", cmd = 40591 },
    { id = "tsig", short_label = "Tsig", label = "Time signature markers", cmd = 40594 },
}

local ALL_ORDER = {}
for _, t in ipairs({ TIME_LOOP, ITEMS, ENVS, MARKS }) do
    for _, e in ipairs(t) do
        ALL_ORDER[#ALL_ORDER + 1] = e
    end
end

local SUB_CHIP = "lock_c"

local widget = {
    name = "Lock Settings",
    category = "Under Development",
    type = "display",
    update_interval = 0,
    width = 96,
    label = "",
    description = "One chip toggles project locking (Main:1135). Right-click: lock modes, optional Tools lock/unlock icon before the name, and chip label. Uses Main toggle actions 40573–41854.",
    chip_widget = true,
    suppress_tooltip = true,
    _chip_label = nil,
    _show_lock_icon = true,
    _open_context = false,
    _context_button = nil,
    _chip_label_edit = "",
}

local _lock_icon_cache_rev
local _lock_icon_resolved

local function lock_icon_bundle()
    local rev = _G._adv_tb_icon_font_rev or 0
    if _lock_icon_cache_rev ~= rev then
        _lock_icon_cache_rev = rev
        _lock_icon_resolved = nil
    end
    if _lock_icon_resolved ~= nil then
        return _lock_icon_resolved
    end
    _lock_icon_resolved = { use_icons = false }
    if not SCRIPT_PATH or SCRIPT_PATH == "" or not C or not C.ButtonContent then
        return _lock_icon_resolved
    end
    local p_open = UTILS.joinPath(SCRIPT_PATH, "IconFonts", "icons", "Tools", "Lock Open.ttf")
    local p_closed = UTILS.joinPath(SCRIPT_PATH, "IconFonts", "icons", "Tools", "Lock Closed.ttf")
    if not reaper.file_exists(p_open) or not reaper.file_exists(p_closed) then
        return _lock_icon_resolved
    end
    local f_open = C.ButtonContent:loadIconFont(LOCK_ICON_PATH_OPEN)
    local f_closed = C.ButtonContent:loadIconFont(LOCK_ICON_PATH_CLOSED)
    if not f_open or not f_closed then
        return _lock_icon_resolved
    end
    _lock_icon_resolved = { use_icons = true, font_open = f_open, font_closed = f_closed }
    return _lock_icon_resolved
end

--- Layout-only width (no PushFont/Attach: getLayoutWidth can run outside an ImGui frame).
local function lock_icon_glyph_column_width_approx(ctx)
    if not ctx then
        return 0
    end
    local icon_sz = ROW.magnet_icon_size(ctx)
    return math.max(icon_sz * 0.65, icon_sz)
end

local function toggle_on(cmd)
    local ok, st = pcall(reaper.GetToggleCommandState, cmd)
    return ok and st == 1
end

function widget.chip_display_text(self)
    local s = self._chip_label
    if type(s) == "string" then
        s = (s:gsub("^%s+", ""):gsub("%s+$", ""))
        if s ~= "" then
            return s
        end
    end
    return DEFAULT_CHIP_LABEL
end

function widget.applyPersistedOptions(self, opts)
    if type(opts) ~= "table" then
        return
    end
    if type(opts.chip_label) == "string" then
        self._chip_label = opts.chip_label
    end
    if opts.show_lock_icon == true then
        self._show_lock_icon = true
    elseif opts.show_lock_icon == false then
        self._show_lock_icon = false
    end
end

function widget.exportPersistedOptions(self)
    return {
        chip_label = type(self._chip_label) == "string" and self._chip_label or "",
        show_lock_icon = self._show_lock_icon == true,
    }
end

function widget.getValue(self)
    self._master_on = toggle_on(CMD_MASTER)
    self._on = {}
    for _, e in ipairs(ALL_ORDER) do
        self._on[e.id] = toggle_on(e.cmd)
    end
    return 0
end

function widget.getLayoutWidth(self, ctx)
    if not ctx or not reaper.ImGui_CalcTextSize then
        return math.max(48, self.width or 96)
    end
    local txt = (self._preview_mode and "Time Lock") or self:chip_display_text()
    local tw = reaper.ImGui_CalcTextSize(ctx, txt)
    local bundle = lock_icon_bundle()
    local show_glyph = (self._show_lock_icon or self._preview_mode) and bundle.use_icons
    local extra = 0
    if show_glyph then
        extra = lock_icon_glyph_column_width_approx(ctx) + ICON_NAME_GAP
    end
    local w = tw + extra + TOGGLE_PAD_H * 2
    w = math.max(w, 36)
    local R = ROW.button_rounding_content_pad()
    local natural = 4 + R + w + 4 + R
    return ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    return ROW.standard_horizontal_or_vertical_height(ctx, 1, is_vertical_toolbar)
end

function widget.layout_geometry(self, ctx, rel_x, rel_y, render_width, layout)
    local chip_h = ROW.chip_line_height(ctx)
    local R = ROW.button_rounding_content_pad()
    local btn_h = (layout and layout.height) or CONFIG.SIZES.HEIGHT
    local is_vert = layout and layout.is_vertical
    local pad_x = 4 + R
    local pad_y = is_vert and (4 + R) or 0
    local y = is_vert and (rel_y + pad_y) or (rel_y + (btn_h - chip_h) / 2)
    local usable = math.max(40, render_width - pad_x * 2)
    local txt = (self._preview_mode and "Time Lock") or self:chip_display_text()
    local bundle = lock_icon_bundle()
    local show_glyph = (self._show_lock_icon or self._preview_mode) and bundle.use_icons
    local tw = reaper.ImGui_CalcTextSize(ctx, txt)
    local extra = 0
    if show_glyph then
        extra = lock_icon_glyph_column_width_approx(ctx) + ICON_NAME_GAP
    end
    local chip_w = tw + extra + TOGGLE_PAD_H * 2
    chip_w = math.max(chip_w, 36)
    chip_w = math.min(chip_w, usable)
    local x = rel_x + pad_x + math.max(0, (usable - chip_w) / 2)
    self._chip_rect = {
        x = x,
        y = y,
        w = chip_w,
        h = chip_h,
    }
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    self:layout_geometry(ctx, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local t = self._chip_rect
    if t and coords:pointInRelativeRect(mx, my, t.x, t.y, t.w, t.h) then
        return SUB_CHIP
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == SUB_CHIP then
        reaper.Main_OnCommand(CMD_MASTER, 0)
        return true
    end
    return false
end

local function mark_layout_dirty(button, ctx)
    OPT_POPUP.commit_dynamic_widget_layout(button, ctx)
end

local function draw_section_header(ctx, title)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_TextDisabled(ctx, title)
end

function widget.onSettingsMenu(self, ctx, button)
    if self._chip_label_edit == nil or self._chip_label_edit == "" then
        self._chip_label_edit = self:chip_display_text()
    end
    
    reaper.ImGui_TextDisabled(ctx, "Lock Modes")

    draw_section_header(ctx, "Time / loop")
    for _, e in ipairs(TIME_LOOP) do
        local on = self._on[e.id] == true
        if reaper.ImGui_MenuItem(ctx, e.label, nil, on) then
            reaper.Main_OnCommand(e.cmd, 0)
        end
    end

    draw_section_header(ctx, "Items")
    for _, e in ipairs(ITEMS) do
        local on = self._on[e.id] == true
        if reaper.ImGui_MenuItem(ctx, e.label, nil, on) then
            reaper.Main_OnCommand(e.cmd, 0)
        end
    end

    draw_section_header(ctx, "Envelopes")
    for _, e in ipairs(ENVS) do
        local on = self._on[e.id] == true
        if reaper.ImGui_MenuItem(ctx, e.label, nil, on) then
            reaper.Main_OnCommand(e.cmd, 0)
        end
    end

    draw_section_header(ctx, "Markers / regions")
    for _, e in ipairs(MARKS) do
        local on = self._on[e.id] == true
        if reaper.ImGui_MenuItem(ctx, e.label, nil, on) then
            reaper.Main_OnCommand(e.cmd, 0)
        end
    end

    reaper.ImGui_Separator(ctx)
    local bundle = lock_icon_bundle()
    if bundle.use_icons then
        if reaper.ImGui_MenuItem(ctx, "Show lock icon", nil, self._show_lock_icon == true) then
            self._show_lock_icon = not self._show_lock_icon
            mark_layout_dirty(button, ctx)
        end
        reaper.ImGui_Separator(ctx)
    end
    reaper.ImGui_Text(ctx, "Chip label")
    reaper.ImGui_SetNextItemWidth(ctx, 220)
    local ch, buf = reaper.ImGui_InputTextWithHint(ctx, "##lock_chip_lbl", LABEL_INPUT_HINT, self._chip_label_edit)
    if ch and buf ~= nil then
        self._chip_label_edit = buf
        local trimmed = (buf:gsub("^%s+", ""):gsub("%s+$", ""))
        self._chip_label = trimmed
        mark_layout_dirty(button, ctx)
    end
end

local function draw_toggle_chip(
    ctx,
    coords,
    draw_list,
    chip,
    text,
    is_active,
    is_hover,
    btn_txt,
    btn_bg,
    show_lock_glyph,
    lock_bundle
)
    local icon_font
    local icon_sz = 0
    if show_lock_glyph and lock_bundle and lock_bundle.use_icons then
        icon_sz = ROW.magnet_icon_size(ctx)
        icon_font = is_active and lock_bundle.font_closed or lock_bundle.font_open
    end
    DRAWING.drawWidgetPillChipLeadingIcon(ctx, coords, draw_list, chip, text, btn_txt, btn_bg, {
        active = is_active,
        filled = true,
        hover = is_hover and not is_active,
        rounding = CHIP_ROUND,
        icon_font = icon_font,
        icon_char = LOCK_GLYPH,
        icon_sz = icon_sz,
        icon_gap = ICON_NAME_GAP,
    })
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    if self._preview_mode then
        self._master_on = true
        self._on = {
            time = false,
            loop = false,
            item_full = false,
            item_lr = true,
            item_ud = false,
            item_edge = false,
            item_fade = false,
            item_stretch = false,
            take_env = false,
            track_env = false,
            region = true,
            marker = true,
            tsig = false,
        }
    end
    self:layout_geometry(ctx, rel_x, rel_y, render_width, layout)

    local mx, my = coords:getRelativeMouse()
    local t = self._chip_rect
    if t then
        local hov = coords:pointInRelativeRect(mx, my, t.x, t.y, t.w, t.h)
        local cap = (self._preview_mode and "Time Lock") or self:chip_display_text()
        local bundle = lock_icon_bundle()
        local show_glyph = (self._show_lock_icon or self._preview_mode) and bundle.use_icons
        draw_toggle_chip(ctx, coords, draw_list, t, cap, self._master_on, hov, btn_txt, btn_bg, show_glyph, bundle)
    end
end

return widget
