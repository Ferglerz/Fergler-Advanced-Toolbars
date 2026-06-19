-- Widgets/Under Development/transport_controls.lua
-- Chip-style transport controls. Optional glyphs from IconFonts/icons/Transport/*.ttf (one glyph at U+0041 per file).
-- Falls back to short text labels when a file is missing. Project time on the right.
-- Right-click a chip: open the same settings dialogs as the stock transport (e.g. play → external
-- timecode / LTC sync settings). Right-click empty area or project time: widget visibility menu (saved in toolbar config).

local CHIP_GAP = 4
local CHIP_H_PAD = 6
local CHIP_V_PAD = 3
local CHIP_ROUND = 3
local ROW_PAD_X = 4
local BG_IDLE = 0x131313FF
local BG_ACTIVE = 0x2E70B8FF
local BG_HOVER = 0x232323FF
local BG_RECORD_ARM = 0x8B2E2EFF
local TEXT_IDLE = 0xD9D9D9FF
local TEXT_ACTIVE = 0xFFFFFFFF

-- Main_OnCommand IDs for "settings" dialogs (mirror right-click on stock transport where applicable).
local SETTINGS = {
    play_timecode = 40619, -- Show external timecode synchronization settings (LTC etc.)
    metronome_preroll = 40363, -- Options: Show metronome/pre-roll settings
    project_recording = 40934, -- Project recording settings
    audio_device = 40099, -- Audio device configuration
    loop_link_ts = 40621, -- Options: Toggle loop points linked to time selection
    play_pos_tempo_ts = 40680, -- Transport: Show play position tempo and time signature
}

local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_ROW = require("Renderers._Widgets_chip_row")
local ICON_FONTS_LIB = require("Utils.icon_fonts")
local VIS = require("Utils.widget_visibility")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")
local FLEX_LAYOUT = require("Utils.flex_layout")

local TRANSPORT_ICON_CHAR = utf8.char(ICON_FONTS_LIB.ICON_CODEPOINT)

local TRANSPORT_ITEMS = {
    { id = "home", short_label = "|<", label = "Go to start", cmd = 40042, settings_cmd = SETTINGS.play_pos_tempo_ts, icon_file = "Back.ttf" },
    { id = "rewind", short_label = "<<", label = "Rewind", cmd = 40084, settings_cmd = SETTINGS.metronome_preroll, icon_file = "Back.ttf" },
    { id = "play", short_label = ">", label = "Play", cmd = 1007, settings_cmd = SETTINGS.play_timecode, icon_file = "Play.ttf" },
    { id = "pause", short_label = "||", label = "Pause", cmd = 1008, settings_cmd = SETTINGS.metronome_preroll, icon_file = "Pause.ttf" },
    { id = "stop", short_label = "[]", label = "Stop", cmd = 1016, settings_cmd = SETTINGS.audio_device, icon_file = "Stop.ttf" },
    { id = "record", short_label = "O", label = "Record", cmd = 1013, settings_cmd = SETTINGS.project_recording },
    -- id must not be a Lua keyword (e.g. "repeat") so toolbar config serializes as plain Lua.
    { id = "repeat_toggle", short_label = "R", label = "Repeat", cmd = 1068, settings_cmd = SETTINGS.loop_link_ts },
    { id = "forward", short_label = ">>", label = "Forward", cmd = 40085, settings_cmd = SETTINGS.metronome_preroll, icon_file = "Forward.ttf" },
    { id = "end_", short_label = ">|", label = "Go to end", cmd = 40043, settings_cmd = SETTINGS.play_pos_tempo_ts, icon_file = "Forward.ttf" },
}

CHIP_MS.normalize_chip_entries(TRANSPORT_ITEMS)

local PREVIEW_CHIP_IDS = { "play", "pause", "stop" }

local function default_visible_copy()
    local t = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        t[it.id] = true
    end
    return t
end

local function ensure_state(self)
    if not self._visible then
        self._visible = default_visible_copy()
    end
end

--- Visible chips + project time row (minimum 1 must stay on).
local function transport_visible_slot_count(self)
    ensure_state(self)
    local n = self._show_time == true and 1 or 0
    for _, it in ipairs(TRANSPORT_ITEMS) do
        if self._visible[it.id] ~= false then
            n = n + 1
        end
    end
    return n
end

local widget = {
    name = "Transport",
    category = "Under Development",
    update_interval = 0.05,
    type = "display",
    width = 380,
    label = "",
    description = "REAPER-style transport chips plus project time. Right-click a chip for transport-related settings (e.g. play → external timecode/LTC); right-click empty space or the time display to choose visible controls.",
    chip_widget = true,
    _visible = nil,
    _show_time = true,
    _open_context = false,
    _play_state = 0,
    _repeat_on = false,
}

function widget.applyPersistedOptions(self, opts)
    ensure_state(self)
    if type(opts) ~= "table" then
        return
    end
    if opts.show_time ~= nil then
        self._show_time = opts.show_time == true
    end
    if type(opts.visible) == "table" then
        for id, on in pairs(opts.visible) do
            if self._visible[id] ~= nil then
                self._visible[id] = on == true
            end
        end
    end
end

function widget.exportPersistedOptions(self)
    ensure_state(self)
    local vis = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        vis[it.id] = self._visible[it.id] ~= false
    end
    return {
        visible = vis,
        show_time = self._show_time == true,
    }
end

local function project_time_string()
    local position = reaper.GetPlayPosition()
    if reaper.GetPlayState() == 0 then
        position = reaper.GetCursorPosition()
    end
    local ruler_time = reaper.format_timestr_pos(position, "", -1)
    if ruler_time:find("[:%.]") then
        return ruler_time
    end
    local hms_time = reaper.format_timestr_pos(position, "", 5)
    return ruler_time .. " (" .. hms_time .. ")"
end

local function chip_text_width(ctx, text)
    return reaper.ImGui_CalcTextSize(ctx, text) + CHIP_H_PAD * 2
end

local _transport_font_rev
local _transport_font_by_file = {}

local function resolve_transport_icon_font(filename)
    if type(filename) ~= "string" or filename == "" then
        return nil
    end
    local rev = _G._adv_tb_icon_font_rev or 0
    if _transport_font_rev ~= rev then
        _transport_font_rev = rev
        _transport_font_by_file = {}
    end
    local cached = _transport_font_by_file[filename]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    if not SCRIPT_PATH or SCRIPT_PATH == "" or not C or not C.ButtonContent then
        _transport_font_by_file[filename] = false
        return nil
    end
    local abs = UTILS.joinPath(SCRIPT_PATH, "IconFonts", "icons", "Transport", filename)
    if not reaper.file_exists(abs) then
        _transport_font_by_file[filename] = false
        return nil
    end
    local norm = UTILS.normalizeSlashes("IconFonts/icons/Transport/" .. filename)
    local f = C.ButtonContent:loadIconFont(norm)
    if not f then
        _transport_font_by_file[filename] = false
        return nil
    end
    _transport_font_by_file[filename] = f
    return f
end

local function transport_icon_font_for_item(it)
    if not it or not it.icon_file then
        return nil
    end
    return resolve_transport_icon_font(it.icon_file)
end

local function chip_cell_width(ctx, it)
    local font = transport_icon_font_for_item(it)
    if font then
        local icon_sz = CHIP_ROW.magnet_icon_size(ctx)
        if not ensureIconFontAttachedToContext(ctx, font) then
            return chip_text_width(ctx, CHIP_MS.chip_caption(it))
        end
        reaper.ImGui_PushFont(ctx, font, icon_sz)
        local gw = reaper.ImGui_CalcTextSize(ctx, TRANSPORT_ICON_CHAR)
        reaper.ImGui_PopFont(ctx)
        gw = math.max(gw, icon_sz * 0.65)
        return gw + CHIP_H_PAD * 2
    end
    return chip_text_width(ctx, CHIP_MS.chip_caption(it))
end

local function draw_transport_chip_foreground(ctx, coords, draw_list, chip, text_col, label_text)
    if chip.icon_font then
        local icon_sz = CHIP_ROW.magnet_icon_size(ctx)
        if ensureIconFontAttachedToContext(ctx, chip.icon_font) then
            reaper.ImGui_PushFont(ctx, chip.icon_font, icon_sz)
            local tw = reaper.ImGui_CalcTextSize(ctx, TRANSPORT_ICON_CHAR)
            reaper.ImGui_PopFont(ctx)
            tw = math.max(tw, icon_sz * 0.65)
            local tx = chip.x + (chip.w - tw) / 2
            local ty = chip.y + chip.h / 2 - icon_sz / 4
            local dx, dy = coords:relativeToDrawList(tx, ty)
            reaper.ImGui_PushFont(ctx, chip.icon_font, icon_sz)
            reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, TRANSPORT_ICON_CHAR)
            reaper.ImGui_PopFont(ctx)
            return
        end
        -- fall through to text label below
    end
    local tw = reaper.ImGui_CalcTextSize(ctx, label_text)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, label_text)
end

function widget.getValue(self)
    ensure_state(self)
    self._play_state = reaper.GetPlayState() or 0
    self._repeat_on = reaper.GetToggleCommandState(1068) == 1
    return 0
end

local function visible_item_list(self)
    ensure_state(self)
    local list = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        if self._visible[it.id] ~= false then
            list[#list + 1] = it
        end
    end
    return list
end

local function get_transport_groups(self, ctx, chip_h)
    local groups = {}
    local list = visible_item_list(self)
    local item_map = {}
    for _, it in ipairs(list) do
        local cw = chip_cell_width(ctx, it)
        item_map[it.id] = {
            id = it.id,
            label = CHIP_MS.chip_caption(it),
            cmd = it.cmd,
            mode = it,
            icon_font = transport_icon_font_for_item(it),
            w = cw,
            h = chip_h
        }
    end

    local group_defs = {
        { "home", "rewind" },
        { "play", "pause", "stop" },
        { "record", "repeat_toggle" },
        { "forward", "end_" }
    }

    for _, g in ipairs(group_defs) do
        local current_group = {}
        for _, id in ipairs(g) do
            if item_map[id] then
                table.insert(current_group, item_map[id])
            end
        end
        if #current_group > 0 then
            table.insert(groups, current_group)
        end
    end

    if self._show_time then
        local txt = project_time_string()
        local tw = reaper.ImGui_CalcTextSize(ctx, txt)
        if tw > 0 then
            table.insert(groups, { { id = "time", w = tw + 8, h = chip_h, txt = txt, is_time = true } })
        end
    end

    return groups
end

function widget.getLayoutWidth(self, ctx, layout_is_vertical)
    if not ctx then
        return self.width or 320
    end
    ensure_state(self)
    local inset = CHIP_ROW.button_rounding_content_pad()
    local w = ROW_PAD_X + inset
    local list = visible_item_list(self)
    for i, it in ipairs(list) do
        w = w + chip_cell_width(ctx, it)
        if i < #list then
            w = w + CHIP_GAP
        end
    end
    if self._show_time then
        local tw = reaper.ImGui_CalcTextSize(ctx, project_time_string())
        if tw > 0 then
            w = w + CHIP_GAP + 8 + tw
        end
    end
    w = w + ROW_PAD_X + inset
    local base = math.max(120, math.ceil(w))
    local cap = tonumber(self._preview_width_cap)
    if cap and cap > 0 then
        return math.min(base, cap)
    end
    return base
end

function widget.getLayoutHeight(self, ctx, inner_width, is_vertical_toolbar)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    ensure_state(self)
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local groups = get_transport_groups(self, ctx, chip_h)
    local inset = CHIP_ROW.button_rounding_content_pad()
    local pad = ROW_PAD_X + inset
    local inner_w = math.max(10, (inner_width or self.width or 320) - pad * 2)
    local lines = FLEX_LAYOUT.wrap_groups(groups, inner_w, CHIP_GAP, CHIP_GAP)
    local total_h = #lines * chip_h + (#lines - 1) * CHIP_GAP
    -- Add symmetric padding (same as row_y in horizontal layout calculation)
    local default_h = CONFIG.SIZES.HEIGHT
    local padding_v = math.max(0, default_h - chip_h)
    return total_h + padding_v
end

local function layout_chips(ctx, self, rel_x, rel_y, render_width, layout)
    ensure_state(self)
    local h = layout and layout.height or CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local inset = CHIP_ROW.button_rounding_content_pad()
    local pad = ROW_PAD_X + inset
    local is_vertical = layout and layout.is_vertical
    local inner_w = math.max(10, render_width - pad * 2)

    local groups = get_transport_groups(self, ctx, chip_h)
    local lines
    if is_vertical then
        lines = FLEX_LAYOUT.wrap_groups(groups, inner_w, CHIP_GAP, CHIP_GAP)
    else
        lines = FLEX_LAYOUT.wrap_groups(groups, 99999, CHIP_GAP, CHIP_GAP)
    end

    local chips = {}
    local time_x, time_w, time_y = nil, 0, nil
    
    local total_h = #lines * chip_h + (#lines - 1) * CHIP_GAP
    local start_y = rel_y + (h - total_h) / 2
    local y = start_y
    for i, line in ipairs(lines) do
        local x = rel_x + pad
        for j, it in ipairs(line.items) do
            if it.is_time then
                if not is_vertical and i == 1 then
                    local txt_w = it.w - 8
                    time_x = math.max(x, rel_x + render_width - pad - txt_w)
                    time_w = txt_w
                    time_y = y
                else
                    time_x = x
                    time_w = it.w - 8
                    time_y = y
                end
            else
                it.x = x
                it.y = y
                table.insert(chips, it)
            end
            x = x + it.w + CHIP_GAP
        end
        y = y + chip_h + CHIP_GAP
    end

    return chips, time_x, time_w, chip_h, time_y
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local chips, time_x, time_w, chip_h, time_y = layout_chips(ctx, self, rel_x, rel_y, render_width, layout)

    for _, chip in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            return "btn_" .. chip.id
        end
    end

    if self._show_time and time_x and time_w > 0 and time_y then
        if coords:pointInRelativeRect(mx, my, time_x, time_y, time_w, chip_h) then
            return "time"
        end
    end

    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    local id = CHIP_HIT.strip("btn_", sub_id)
    if not id then
        return false
    end
    for _, it in ipairs(TRANSPORT_ITEMS) do
        if it.id == id then
            reaper.Main_OnCommand(it.cmd, 0)
            return true
        end
    end
    return false
end

function widget.onRightClickSubcontrol(self, sub_id, _button)
    local id = CHIP_HIT.strip("btn_", sub_id)
    if id then
        for _, it in ipairs(TRANSPORT_ITEMS) do
            if it.id == id and it.settings_cmd then
                reaper.Main_OnCommand(it.settings_cmd, 0)
                return
            end
        end
    end

    if sub_id == "time" then
        widget.onRightClick(self)
        return
    end
end

function widget.onRightClick(self)
    self._open_context = true
end

local function draw_context_menu(self, ctx, button)
    ensure_state(self)
    local rows = {}
    for _, it in ipairs(TRANSPORT_ITEMS) do
        local id = it.id
        rows[#rows + 1] = {
            label = it.label,
            get = function(h)
                return h._visible[id] ~= false
            end,
            set = function(h, v)
                h._visible[id] = v
            end,
        }
    end
    rows[#rows + 1] = { separator = true }
    rows[#rows + 1] = {
        label = "Show project time",
        get = function(h)
            return h._show_time == true
        end,
        set = function(h, v)
            h._show_time = v
        end,
    }
    VIS.draw_checkbox_popup(ctx, button, self, {
        popup_prefix = "transport_widget_ctx",
        title = "Transport widget",
        rows = rows,
        total_visible = transport_visible_slot_count,
    })
end

local function draw_chip(ctx, coords, draw_list, chip, is_active, is_hover, is_record_arm)
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
    local base = is_record_arm and BG_RECORD_ARM or BG_IDLE
    if is_active then
        base = BG_ACTIVE
    end
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, base, CHIP_ROUND)
    if is_hover and not is_active and not is_record_arm then
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, BG_HOVER, CHIP_ROUND)
    elseif is_hover and is_record_arm and not is_active then
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, BG_HOVER, CHIP_ROUND)
    end

    local text_col = (is_active or is_record_arm) and TEXT_ACTIVE or TEXT_IDLE
    draw_transport_chip_foreground(ctx, coords, draw_list, chip, text_col, chip.label)
end

local function transport_item_by_id(id)
    for _, it in ipairs(TRANSPORT_ITEMS) do
        if it.id == id then
            return it
        end
    end
    return nil
end

--- Widget browser: grouped play/pause/stop multiswitch when width allows.
local function render_preview_strip(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2

    ensure_state(self)
    local total_w = -CHIP_GAP
    local segments = {}
    for _, pid in ipairs(PREVIEW_CHIP_IDS) do
        local it = transport_item_by_id(pid)
        if it and self._visible[it.id] ~= false then
            local cw = chip_cell_width(ctx, it)
            segments[#segments + 1] = { it = it, w = cw }
            total_w = total_w + cw + CHIP_GAP
        end
    end

    if PREVIEW_FB.when(ctx, #segments == 0 or total_w > render_width - 8, "Transport", rel_x, rel_y, render_width, h, coords, draw_list, text_color, 0) then
        return
    end

    local x = rel_x + (render_width - total_w) / 2
    local mx, my = coords:getRelativeMouse()
    local playing = (self._play_state & 1) == 1
    local paused = (self._play_state & 2) == 2

    local chips = {}
    for _, seg in ipairs(segments) do
        local it = seg.it
        local cw = seg.w
        chips[#chips + 1] = {
            id = it.id,
            label = CHIP_MS.chip_caption(it),
            cmd = it.cmd,
            mode = it,
            icon_font = transport_icon_font_for_item(it),
            x = x,
            y = row_y,
            w = cw,
            h = chip_h,
        }
        x = x + cw + CHIP_GAP
    end

    local btn_txt = text_color or TEXT_IDLE
    local btn_bg = bg_color or BG_IDLE
    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        draw_chip_foreground = draw_transport_chip_foreground,
        label_for = function(c)
            return c.label
        end,
        is_selected_segment = function(chip)
            if chip.id == "play" then
                return playing and not paused
            end
            if chip.id == "pause" then
                return paused
            end
            if chip.id == "stop" then
                return not playing and not paused
            end
            return false
        end,
    })
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt = text_color or TEXT_IDLE
    local btn_bg = bg_color or BG_IDLE
    if self._preview_mode then
        render_preview_strip(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color)
        return
    end

    local mx, my = coords:getRelativeMouse()
    local chips, time_x, time_w, chip_h, time_y = layout_chips(ctx, self, rel_x, rel_y, render_width, _layout)

    local playing = (self._play_state & 1) == 1
    local recording = (self._play_state & 4) == 4
    local paused = (self._play_state & 2) == 2

    local i = 1
    while i <= #chips do
        local c0, c1, c2 = chips[i], chips[i + 1], chips[i + 2]
        if c0 and c1 and c2 and c0.id == "play" and c1.id == "pause" and c2.id == "stop" then
            CHIP_MULTISWITCH.draw(ctx, self, { c0, c1, c2 }, coords, draw_list, btn_txt, btn_bg, {
                mx = mx,
                my = my,
                enabled = true,
                mixed = false,
                chip_round = CHIP_ROUND,
                draw_chip_foreground = draw_transport_chip_foreground,
                label_for = function(c)
                    return c.label
                end,
                is_selected_segment = function(chip)
                    if chip.id == "play" then
                        return playing and not paused
                    end
                    if chip.id == "pause" then
                        return paused
                    end
                    if chip.id == "stop" then
                        return not playing and not paused
                    end
                    return false
                end,
            })
            i = i + 3
        else
            local chip = chips[i]
            local is_active = false
            local is_record_arm = false
            if chip.id == "play" then
                is_active = playing and not paused
            elseif chip.id == "pause" then
                is_active = paused
            elseif chip.id == "stop" then
                is_active = not playing and not paused
            elseif chip.id == "record" then
                is_record_arm = recording
            elseif chip.id == "repeat_toggle" then
                is_active = self._repeat_on
            end

            local hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
            draw_chip(ctx, coords, draw_list, chip, is_active, hover, is_record_arm)
            i = i + 1
        end
    end

    if self._show_time and time_x and time_y then
        local txt = project_time_string()
        local ty = time_y + (chip_h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(time_x, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_color, txt)
    end
end

function widget.onWidgetFrame(self, ctx, button)
    draw_context_menu(self, ctx, button)
end

return widget
