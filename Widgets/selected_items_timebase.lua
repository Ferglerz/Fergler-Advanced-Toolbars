-- Widgets/selected_items_timebase.lua
-- Timebase for selected media items (C_BEATATTACHMODE); disabled when nothing is selected.

local WIDGET = require("Utils.Widget.widget_factory")
local TIMEBASE = require("Utils.Reaper.timebase_modes")

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
        return nil, false, false
    end
    local first = nil
    for i = 0, n - 1 do
        local it = reaper.GetSelectedMediaItem(0, i)
        local v = math.floor(reaper.GetMediaItemInfo_Value(it, "C_BEATATTACHMODE") + 0.5)
        if first == nil then
            first = v
        elseif first ~= v then
            return nil, true, true
        end
    end
    return first, false, true
end

local function project_timebase_caption()
    local m = TIMEBASE.project_mode_at(TIMEBASE.read_project_timebase())
    return WIDGET.CHIP_MS.chip_caption(m)
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

return WIDGET.CHIP_MODE.new(WIDGET.CHIP_MODE.with_slide_out_toolbar({
    name = "Selected Items Timebase",
    category = "Items & selection",
    update_interval = 0.15,
    description = "Timebase for selected items: default (follow project/track), time, or beats. Empty selection dims the row. Toolbar shows current mode; hover for full multiswitch.",
    width = 200,
    slide_namespace = "itb_ms",
    toolbar_fallback = "Timebase",
    modes = MODES,
    prefix = "itb_",
    default_active_id = "def",
    preview_toolbar_label = function()
        return project_timebase_caption()
    end,
    preview_active_id = function(self)
        self._empty = false
        self._mixed = false
        self._active_id = "def"
    end,
    aggregate = {
        scan = aggregate_selection,
        id_from_scalar = id_from_api,
        empty_label = "—",
        mixed_label = "Mixed",
    },
    apply = function(self, mode)
        apply_to_selection(mode.api)
        self._mixed = false
    end,
}))
