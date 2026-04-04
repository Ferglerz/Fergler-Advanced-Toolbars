-- Widgets/Under Development/transport_controls.lua
-- Chip-style controls modeled on REAPER's transport bar (theme images transport_play, transport_stop,
-- transport_record, transport_repeat, etc.). Project time on the right.
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

local TRANSPORT_ITEMS = {
    { id = "home", short_label = "|<", label = "Go to start", cmd = 40042, settings_cmd = SETTINGS.play_pos_tempo_ts },
    { id = "rewind", short_label = "<<", label = "Rewind", cmd = 40084, settings_cmd = SETTINGS.metronome_preroll },
    { id = "play", short_label = ">", label = "Play", cmd = 1007, settings_cmd = SETTINGS.play_timecode },
    { id = "pause", short_label = "||", label = "Pause", cmd = 1008, settings_cmd = SETTINGS.metronome_preroll },
    { id = "stop", short_label = "[]", label = "Stop", cmd = 1016, settings_cmd = SETTINGS.audio_device },
    { id = "record", short_label = "O", label = "Record", cmd = 1013, settings_cmd = SETTINGS.project_recording },
    -- id must not be a Lua keyword (e.g. "repeat") so toolbar config serializes as plain Lua.
    { id = "repeat_toggle", short_label = "R", label = "Repeat", cmd = 1068, settings_cmd = SETTINGS.loop_link_ts },
    { id = "forward", short_label = ">>", label = "Forward", cmd = 40085, settings_cmd = SETTINGS.metronome_preroll },
    { id = "end_", short_label = ">|", label = "Go to end", cmd = 40043, settings_cmd = SETTINGS.play_pos_tempo_ts },
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

function widget.getLayoutWidth(self, ctx)
    if not ctx then
        return self.width or 320
    end

    ensure_state(self)
    local inset = CHIP_ROW.button_rounding_content_pad()
    local w = ROW_PAD_X + inset
    local list = visible_item_list(self)
    for i, it in ipairs(list) do
        w = w + chip_text_width(ctx, CHIP_MS.chip_caption(it))
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

local function layout_chips(ctx, self, rel_x, rel_y, render_width)
    ensure_state(self)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2

    local list = visible_item_list(self)
    local chips = {}
    local inset = CHIP_ROW.button_rounding_content_pad()
    local x = rel_x + ROW_PAD_X + inset
    for _, it in ipairs(list) do
        local cw = chip_text_width(ctx, CHIP_MS.chip_caption(it))
        chips[#chips + 1] = {
            id = it.id,
            label = CHIP_MS.chip_caption(it),
            cmd = it.cmd,
            x = x,
            y = row_y,
            w = cw,
            h = chip_h,
        }
        x = x + cw + CHIP_GAP
    end

    local time_x, time_w = nil, 0
    if self._show_time then
        local txt = project_time_string()
        time_w = reaper.ImGui_CalcTextSize(ctx, txt)
        time_x = rel_x + render_width - ROW_PAD_X - inset - time_w
        if time_x < x then
            time_x = x
        end
    end

    return chips, time_x, time_w, chip_h
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local chips, time_x, time_w, chip_h = layout_chips(ctx, self, rel_x, rel_y, render_width)

    for _, chip in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            return "btn_" .. chip.id
        end
    end

    if self._show_time and time_x and time_w > 0 then
        local h = CONFIG.SIZES.HEIGHT
        local row_y = rel_y + (h - chip_h) / 2
        if coords:pointInRelativeRect(mx, my, time_x, row_y, time_w, chip_h) then
            return "time"
        end
    end

    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    local id = sub_id and sub_id:match("^btn_(.+)$")
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
    local id = sub_id and sub_id:match("^btn_(.+)$")
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
    local key = "##transport_widget_ctx_" .. tostring(button and button.instance_id or self.name or "x")
    if self._open_context then
        reaper.ImGui_OpenPopup(ctx, key)
        self._open_context = false
    end

    if not reaper.ImGui_BeginPopup(ctx, key) then
        return
    end

    ensure_state(self)
    reaper.ImGui_TextDisabled(ctx, "Transport widget")
    local changed = false
    for _, it in ipairs(TRANSPORT_ITEMS) do
        local on = self._visible[it.id] ~= false
        local menu_text = it.label
        if reaper.ImGui_MenuItem(ctx, menu_text, nil, on) then
            self._visible[it.id] = not on
            changed = true
        end
    end
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Show project time", nil, self._show_time) then
        self._show_time = not self._show_time
        changed = true
    end

    reaper.ImGui_EndPopup(ctx)

    if changed and button and button.widget then
        local ok, w = pcall(button.widget.getLayoutWidth, button.widget, ctx)
        if ok and type(w) == "number" then
            button.widget.width = w
        end
        button:clearCache()
        button:saveChanges()
    end
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
    local tw = reaper.ImGui_CalcTextSize(ctx, chip.label)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, chip.label)
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
            local cw = chip_text_width(ctx, CHIP_MS.chip_caption(it))
            segments[#segments + 1] = { it = it, w = cw }
            total_w = total_w + cw + CHIP_GAP
        end
    end

    if #segments == 0 then
        DRAWING.drawWidgetCenteredValueText(ctx, "Transport", rel_x, rel_y, render_width, h, coords, draw_list, text_color, 0)
        return
    end

    if total_w > render_width - 8 then
        DRAWING.drawWidgetCenteredValueText(ctx, "Transport", rel_x, rel_y, render_width, h, coords, draw_list, text_color, 0)
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
    local chips, time_x, _, chip_h = layout_chips(ctx, self, rel_x, rel_y, render_width)

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

    if self._show_time and time_x then
        local txt = project_time_string()
        local h = CONFIG.SIZES.HEIGHT
        local row_y = rel_y + (h - chip_h) / 2
        local ty = row_y + (chip_h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(time_x, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_color, txt)
    end
end

function widget.onWidgetFrame(self, ctx, button)
    draw_context_menu(self, ctx, button)
end

return widget
