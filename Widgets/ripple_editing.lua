-- Widgets/ripple_editing.lua
-- Ripple editing: host Ripple toggle; slide-out Track / All scope.

local WIDGET = require("Utils.Widget.widget_factory")
local OPT = WIDGET.OPTIONS_SLIDE_OUT

local CMD_OFF = 40309
local CMD_PER_TRACK = 40310
local CMD_ALL_TRACKS = 40311

local TOGGLE_PER_TRACK = 41990
local TOGGLE_ALL_TRACKS = 41991

local TOGGLE_LABEL = "Ripple"

local SCOPE_MODES = {
    { id = "per_track", label = "Track" },
    { id = "all_tracks", label = "All" },
}

local function detect_active_mode_id()
    if OPT.toggle_command_state(TOGGLE_PER_TRACK) then
        return "per_track"
    end
    if OPT.toggle_command_state(TOGGLE_ALL_TRACKS) then
        return "all_tracks"
    end
    return nil
end

local function get_saved_scope(self)
    return self._saved_scope or "per_track"
end

local function set_saved_scope(self, scope)
    if scope == "per_track" or scope == "all_tracks" then
        self._saved_scope = scope
    end
end

return WIDGET.Segmented(OPT.with_slide_out({
    name = "Ripple Editing",
    category = "Items & selection",
    type = "display",
    update_interval = 0.2,
    description = "Ripple editing: click Ripple to toggle off/on (restores saved Track vs All). Hover for scope chips.",
    width = 96,
    state = {
        _last_click_id = nil,
        _saved_scope = "per_track",
    },
    on_update = function(self)
        local from_reaper = detect_active_mode_id()
        if self._last_click_id == "off" then
            if from_reaper == nil then
                self._last_click_id = nil
            end
        elseif from_reaper then
            set_saved_scope(self, from_reaper)
            self._last_click_id = nil
        end
    end,
    rows = {
        OPT.host_labeled_toggle(TOGGLE_LABEL, function(self)
            return self._preview_mode and true or (detect_active_mode_id() ~= nil)
        end, function(self)
            local active = detect_active_mode_id()
            if active ~= nil then
                set_saved_scope(self, active)
                reaper.Main_OnCommand(CMD_OFF, 0)
                self._last_click_id = "off"
            else
                local scope = get_saved_scope(self)
                if scope == "all_tracks" then
                    reaper.Main_OnCommand(CMD_ALL_TRACKS, 0)
                    self._last_click_id = "all_tracks"
                else
                    reaper.Main_OnCommand(CMD_PER_TRACK, 0)
                    self._last_click_id = "per_track"
                end
            end
        end),
        OPT.slide_multiswitch(SCOPE_MODES, function(self)
            if self._preview_mode then
                return "per_track"
            end
            return detect_active_mode_id() or get_saved_scope(self)
        end, function(self, id)
            if id == "per_track" then
                if detect_active_mode_id() ~= "per_track" then
                    reaper.Main_OnCommand(CMD_PER_TRACK, 0)
                    set_saved_scope(self, "per_track")
                    self._last_click_id = "per_track"
                end
            elseif id == "all_tracks" then
                if detect_active_mode_id() ~= "all_tracks" then
                    reaper.Main_OnCommand(CMD_ALL_TRACKS, 0)
                    set_saved_scope(self, "all_tracks")
                    self._last_click_id = "all_tracks"
                end
            end
        end, { min_chip_w = 44 }),
    },
}))
