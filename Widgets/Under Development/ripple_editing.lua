-- Widgets/Under Development/ripple_editing.lua
-- Ripple editing: "Ripple" label chip (toggle on/off) plus Track | All multiswitch. Set actions 40309–40311; scope persisted per button.

local WIDGET = require("Utils.widget_factory")

local CHIP_GAP = 6
local CHIP_ROUND = WIDGET.CHIP_ROW.CHIP_ROUND
local TOGGLE_PAD_H = 10
local SCOPE_INNER_GAP = 3

-- Set actions (idempotent); toggle IDs 41990/41991 only for reading state.
local CMD_OFF = 40309
local CMD_PER_TRACK = 40310
local CMD_ALL_TRACKS = 40311

local TOGGLE_PER_TRACK = 41990
local TOGGLE_ALL_TRACKS = 41991

local TOGGLE_LABEL = "Ripple"

local SUB_TOGGLE = "ripple_toggle"
local SCOPE_PREFIX = "ripple_s_"

local SCOPE_MODES = {
    { id = "per_track", label = "Track" },
    { id = "all_tracks", label = "All" },
}

WIDGET.CHIP_MS.normalize_chip_entries(SCOPE_MODES)

-- Active ripple scope from REAPER's toggle state (nil = ripple off).
local function detect_active_mode_id()
    local ok_pt, st_pt = pcall(reaper.GetToggleCommandState, TOGGLE_PER_TRACK)
    if ok_pt and st_pt == 1 then
        return "per_track"
    end
    local ok_all, st_all = pcall(reaper.GetToggleCommandState, TOGGLE_ALL_TRACKS)
    if ok_all and st_all == 1 then
        return "all_tracks"
    end
    return nil
end

-- Remembered scope so toggling ripple back on restores the last Track/All choice.
local function get_saved_scope(self)
    return self._saved_scope or "per_track"
end

local function set_saved_scope(self, scope)
    if scope == "per_track" or scope == "all_tracks" then
        self._saved_scope = scope
    end
end

local widget = WIDGET.Segmented({
    name = "Ripple Editing",
    category = "Under Development",
    type = "display",
    update_interval = 0.2,
    description = "Ripple editing: Click Ripple to turn ripple off (scope is remembered) or on (restores saved Track vs All). Track and All switch scope directly.",
    width = 132,
    state = {
        _last_click_id = nil,
    },
    on_update = function(self)
        -- Keep internal cache updated
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
    segments = {
        {
            type = "toggle",
            label = TOGGLE_LABEL,
            get_state = function(self)
                return self._preview_mode and true or (detect_active_mode_id() ~= nil)
            end,
            on_click = function(self)
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
            end
        },
        {
            type = "multiswitch",
            modes = SCOPE_MODES,
            get_active = function(self)
                if self._preview_mode then
                    return "per_track"
                end
                return detect_active_mode_id() or get_saved_scope(self)
            end,
            on_click = function(self, id)
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
            end
        }
    }
})

return widget
