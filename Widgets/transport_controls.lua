-- widgets/transport_controls.lua
-- Chip-style controls modeled on REAPER's transport bar (theme images transport_play, transport_stop,
-- transport_record, transport_repeat, etc.). Project time on the right.
-- Right-click a chip: open Action list (40605); console shows the action name and command ID to filter.
-- Right-click empty area: toggle which chips and the time readout are shown (saved in toolbar config).

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
local TIME_COLOR = 0xCCCCCCFF

local ACTION_LIST_CMD = 40605

local TRANSPORT_ITEMS = {
    { id = "home", label = "|<", cmd = 40042 },
    { id = "rewind", label = "<<", cmd = 40084 },
    { id = "play", label = ">", cmd = 1007 },
    { id = "pause", label = "||", cmd = 1008 },
    { id = "stop", label = "[]", cmd = 1016 },
    { id = "record", label = "O", cmd = 1013 },
    { id = "repeat", label = "R", cmd = 1068 },
    { id = "forward", label = ">>", cmd = 40085 },
    { id = "end_", label = ">|", cmd = 40043 },
}

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
    update_interval = 0.05,
    type = "display",
    width = 380,
    label = "",
    description = "REAPER-style transport chips plus project time. Right-click a chip to open the Action list for that command; right-click empty space to choose visible controls.",
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
    local w = ROW_PAD_X
    local list = visible_item_list(self)
    for i, it in ipairs(list) do
        w = w + chip_text_width(ctx, it.label)
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

    w = w + ROW_PAD_X
    return math.max(120, math.ceil(w))
end

local function layout_chips(ctx, self, rel_x, rel_y, render_width)
    ensure_state(self)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2

    local list = visible_item_list(self)
    local chips = {}
    local x = rel_x + ROW_PAD_X
    for _, it in ipairs(list) do
        local cw = chip_text_width(ctx, it.label)
        chips[#chips + 1] = {
            id = it.id,
            label = it.label,
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
        time_x = rel_x + render_width - ROW_PAD_X - time_w
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

local function hint_for_command(cmd)
    local title
    if reaper.CF_GetCommandText then
        title = reaper.CF_GetCommandText(0, cmd)
    end
    if title and title ~= "" then
        reaper.ShowConsoleMsg('Action list: search for "' .. title .. '" or ID ' .. tostring(cmd) .. "\n")
    else
        reaper.ShowConsoleMsg("Action list: filter by command ID " .. tostring(cmd) .. "\n")
    end
end

function widget.onRightClickSubcontrol(self, sub_id, _button)
    reaper.Main_OnCommand(ACTION_LIST_CMD, 0)

    local id = sub_id and sub_id:match("^btn_(.+)$")
    if id then
        for _, it in ipairs(TRANSPORT_ITEMS) do
            if it.id == id then
                hint_for_command(it.cmd)
                return
            end
        end
    end

    if sub_id == "time" then
        reaper.ShowConsoleMsg("Action list: search for ruler time, position, or transport time actions.\n")
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
        if reaper.ImGui_MenuItem(ctx, it.label .. "  (" .. tostring(it.cmd) .. ")", nil, on) then
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

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color)
    local mx, my = coords:getRelativeMouse()
    local chips, time_x, _, chip_h = layout_chips(ctx, self, rel_x, rel_y, render_width)

    local playing = (self._play_state & 1) == 1
    local recording = (self._play_state & 4) == 4
    local paused = (self._play_state & 2) == 2

    for _, chip in ipairs(chips) do
        local is_active = false
        local is_record_arm = false
        if chip.id == "play" then
            is_active = playing and not paused
        elseif chip.id == "pause" then
            is_active = paused
        elseif chip.id == "record" then
            is_record_arm = recording
        elseif chip.id == "repeat" then
            is_active = self._repeat_on
        end

        local hover = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        draw_chip(ctx, coords, draw_list, chip, is_active, hover, is_record_arm)
    end

    if self._show_time and time_x then
        local txt = project_time_string()
        local h = CONFIG.SIZES.HEIGHT
        local row_y = rel_y + (h - chip_h) / 2
        local ty = row_y + (chip_h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(time_x, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, TIME_COLOR, txt)
    end
end

function widget.onWidgetFrame(self, ctx, button)
    draw_context_menu(self, ctx, button)
end

return widget
