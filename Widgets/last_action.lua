-- widgets/last_action.lua
-- Display: top undo string (Edit > Undo).
-- Click: resolve that string to an Actions-list entry and Main_OnCommand / MIDIEditor_OnCommand
--        the numeric command ID; if no confident match, fall back to "Repeat the most recent action" (2999).
-- REAPER does not expose the true last-run command ID; matching undo text to the action list is the stock approach.

local REPEAT_LAST_ACTION_CMD = 2999

-- Main, Main (alt recording), MIDI Editor, MIDI Event list, MIDI Inline — see MPL keyboard viz defaults.
local SECTION_IDS = { 0, 100, 32060, 32061, 32062 }

local widget = {
    name = "Last Action",
    update_interval = 0.35,
    type = "display",
    width = 200,
    label = "Last action",
    description = "Shows the top undo description. Click matches that text to the Actions list and runs that command ID directly when possible; otherwise repeats the last action (2999). First click may briefly build an action-name cache.",
    _display = "",
}

-- Lazily filled: { { cmd = int, sec = sectionUniqueId, text = string }, ... }
local action_rows = nil

local function trim(s)
    if not s then
        return ""
    end
    return (s:match("^%s*(.-)%s*$") or "")
end

local function resolve_section(sid)
    local sec, err = reaper.SectionFromUniqueID(sid)
    if sec then
        return sec
    end
    if sid == 0 then
        return 0
    end
    return nil
end

local function build_action_cache()
    if action_rows then
        return
    end
    action_rows = {}
    for _, sid in ipairs(SECTION_IDS) do
        local sec = resolve_section(sid)
        if sec then
            local i = 0
            while true do
                local cmd, enum_name = reaper.kbd_enumerateActions(sec, i)
                if not cmd or cmd == 0 then
                    break
                end
                local disp = trim(reaper.kbd_getTextFromCmd(cmd, sec) or "")
                if disp == "" then
                    disp = trim(enum_name or "")
                end
                if disp ~= "" then
                    table.insert(action_rows, { cmd = cmd, sec = sid, text = disp })
                end
                i = i + 1
                if i > 250000 then
                    break
                end
            end
        end
    end
end

--- Higher score = better match between undo line and Actions list title.
local function match_score(undo_u, action_t)
    if undo_u == "" or action_t == "" then
        return 0
    end
    local ul, tl = undo_u:lower(), action_t:lower()
    if undo_u == action_t then
        return 1000000 + #action_t
    end
    if ul == tl then
        return 500000 + #action_t
    end
    local after_colon = action_t:match(":%s*(.+)$")
    if after_colon and trim(after_colon) == undo_u then
        return 450000 + #undo_u
    end
    if after_colon and trim(after_colon):lower() == ul then
        return 420000 + #undo_u
    end
    local min_sub = 4
    if #undo_u >= min_sub and tl:find(ul, 1, true) then
        return 400000 + #undo_u
    end
    if #action_t >= min_sub and ul:find(tl, 1, true) then
        return 300000 + #action_t
    end
    return 0
end

local function find_resolved_command(undo_str)
    local u = trim(undo_str)
    if u == "" or u == "—" then
        return nil, nil
    end
    build_action_cache()
    local best_cmd, best_sec, best = nil, nil, 0
    for _, row in ipairs(action_rows) do
        local sc = match_score(u, row.text)
        if sc > best then
            best = sc
            best_cmd = row.cmd
            best_sec = row.sec
        end
    end
    if best >= 300000 then
        return best_cmd, best_sec
    end
    if best >= 100000 then
        return best_cmd, best_sec
    end
    return nil, nil
end

local function run_resolved_command(cmd, section_id)
    if not cmd then
        reaper.Main_OnCommand(REPEAT_LAST_ACTION_CMD, 0)
        return
    end
    -- Main / global
    if section_id == 0 or section_id == 100 then
        reaper.Main_OnCommand(cmd, 0)
        return
    end
    -- MIDI-family sections: route to MIDI editor context
    if section_id == 32060 or section_id == 32061 or section_id == 32062 then
        local me = reaper.MIDIEditor_GetActive()
        if me then
            reaper.MIDIEditor_OnCommand(me, cmd)
        elseif reaper.MIDIEditor_LastFocused_OnCommand(cmd, false) then
            return
        else
            reaper.Main_OnCommand(REPEAT_LAST_ACTION_CMD, 0)
        end
        return
    end
    reaper.Main_OnCommand(cmd, 0)
end

local function truncate_to_width(ctx, text, max_w)
    if not text or text == "" then
        return "—"
    end
    if reaper.ImGui_CalcTextSize(ctx, text) <= max_w then
        return text
    end
    local ell = "…"
    local s = text
    while #s > 0 and reaper.ImGui_CalcTextSize(ctx, s .. ell) > max_w do
        s = s:sub(1, -2)
    end
    return s .. ell
end

function widget.getValue(self)
    local s = reaper.Undo_CanUndo2(0)
    if not s or s == "" then
        s = "—"
    end
    self._display = s
    return s
end

function widget.onClick(self)
    local undo_str = reaper.Undo_CanUndo2(0)
    local cmd, sec = find_resolved_command(undo_str or "")
    if cmd then
        run_resolved_command(cmd, sec)
    else
        reaper.Main_OnCommand(REPEAT_LAST_ACTION_CMD, 0)
    end
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT
    local pad = 8
    local span = math.max(20, render_width - pad * 2)
    local line = truncate_to_width(ctx, self._display or self.value or "—", span)
    DRAWING.drawWidgetCenteredLabel(ctx, self, rel_x, rel_y, render_width, coords, draw_list, rel_y + 1)
    DRAWING.drawWidgetCenteredValueText(ctx, line, rel_x, rel_y, render_width, height, coords, draw_list, text_color, 7)
end

return widget
