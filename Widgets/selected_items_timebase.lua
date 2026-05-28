-- Widgets/selected_items_timebase.lua
-- Timebase for selected media items (C_BEATATTACHMODE); disabled when nothing is selected.

local CHIP_MODE = require("Utils.chip_mode_widget")

local MODES = {
    { id = "def", short_label = "Def", label = "Project / track default", api = -1 },
    { id = "time", label = "Time", api = 0 },
    { id = "beats_all", short_label = "B+LR", label = "Beats (position, length, rate)", api = 1 },
    { id = "beats_pos", short_label = "B.pos", label = "Beats (position only)", api = 2 },
}

local function id_from_api(v)
    v = math.floor((v or -1) + 0.5)
    for _, m in ipairs(MODES) do
        if m.api == v then
            return m.id
        end
    end
    return "def"
end

local function aggregate_selection()
    local n = reaper.CountSelectedMediaItems(0)
    if n < 1 then
        return nil, false, true
    end
    local first = nil
    for i = 0, n - 1 do
        local it = reaper.GetSelectedMediaItem(0, i)
        local v = math.floor(reaper.GetMediaItemInfo_Value(it, "C_BEATATTACHMODE") + 0.5)
        if first == nil then
            first = v
        elseif first ~= v then
            return nil, true, false
        end
    end
    return first, false, false
end

local function apply_to_selection(api_val)
    local n = reaper.CountSelectedMediaItems(0)
    if n < 1 then
        return
    end
    reaper.Undo_BeginBlock()
    for i = 0, n - 1 do
        local it = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(it, "C_BEATATTACHMODE", api_val)
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Set item timebase", -1)
end

return CHIP_MODE.new({
    name = "Selected Items Timebase",
    category = "Items & selection",
    update_interval = 0.15,
    description = "Timebase for selected items: default (follow project/track), time, or beats. Empty selection dims the row.",
    width = 260,
    modes = MODES,
    prefix = "itb_",
    min_chip_w = 22,
    preview_ids = { "def", "time", "beats_all" },
    preview_title = "Items timebase",
    default_active_id = "def",
    state = { _mixed = false, _empty = true },
    can_interact = function(self)
        return not self._empty
    end,
    get_draw_state = function(self)
        return { enabled = not self._empty, mixed = self._mixed }
    end,
    getValue = function(self)
        local v, mixed, empty = aggregate_selection()
        self._mixed = mixed
        self._empty = empty
        if empty or mixed then
            self._active_id = nil
        else
            self._active_id = id_from_api(v)
        end
        return 0
    end,
    on_apply = function(self, mode)
        apply_to_selection(mode.api)
        self._mixed = false
    end,
})
