-- Widgets/Under Development/screensets_widget.lua
-- Save/load 4 track-view screensets: host shows active set name; slide-out Load/Save + 2x2 grid.

local WIDGET = require("Utils.Widget.widget_factory")
local OPT = WIDGET.OPTIONS_SLIDE_OUT

local EXT_SECTION = "ATB_ScreensetsWidget"

local MODE_MODES = {
    { id = "load", short_label = "Load", label = "Load" },
    { id = "save", short_label = "Save", label = "Save" },
}

local SLOT_MODES = {
    { id = "slot_1", short_label = "1", label = "Set 1", slot = 1 },
    { id = "slot_2", short_label = "2", label = "Set 2", slot = 2 },
    { id = "slot_3", short_label = "3", label = "Set 3", slot = 3 },
    { id = "slot_4", short_label = "4", label = "Set 4", slot = 4 },
}

local function slot_key(slot)
    return "name_" .. tostring(slot)
end

local function load_slot_name(slot)
    local ok, value = reaper.GetProjExtState(0, EXT_SECTION, slot_key(slot))
    if ok == 1 and value and value ~= "" then
        return value
    end
    return "Set " .. tostring(slot)
end

local function save_slot_name(slot, value)
    reaper.SetProjExtState(0, EXT_SECTION, slot_key(slot), value or "")
end

local function execute_slot(mode, slot)
    if slot < 1 or slot > 4 then
        return
    end
    if mode == "save" then
        reaper.Main_OnCommand(40463 + slot, 0)
    else
        reaper.Main_OnCommand(40443 + slot, 0)
    end
end

local function slot_mode_by_id(id)
    for _, m in ipairs(SLOT_MODES) do
        if m.id == id then
            return m
        end
    end
    return nil
end

local function refresh_slot_labels(self)
    for slot = 1, 4 do
        self._names[slot] = load_slot_name(slot)
    end
    for _, m in ipairs(SLOT_MODES) do
        local name = self._names[m.slot] or ("Set " .. tostring(m.slot))
        local label = name
        if #label > 10 then
            label = label:sub(1, 9) .. "…"
        end
        m.short_label = label
    end
end

local widget = WIDGET.Segmented(OPT.with_slide_out({
    name = "Screensets",
    category = "Under Development",
    update_interval = 0.5,
    width = 120,
    description = "Load/save 4 named track-view screensets. Host shows last used set. Hover for Load/Save and slots. Right-click slot in slide-out to rename.",
    state = {
        _mode = "load",
        _names = { "Set 1", "Set 2", "Set 3", "Set 4" },
        _active_slot = 1,
        _last_slot_hit = nil,
    },

    on_update = function(self)
        refresh_slot_labels(self)
    end,

    rows = {
        OPT.host_readout_row(function(self)
            if self._preview_mode then
                return "Set 1"
            end
            local slot = self._active_slot or 1
            return self._names[slot] or load_slot_name(slot)
        end, { min_width = 80 }),

        OPT.slide_multiswitch(MODE_MODES, function(self)
            return self._mode == "save" and "save" or "load"
        end, function(self, chip_id)
            if chip_id == "save" then
                self._mode = "save"
            elseif chip_id == "load" then
                self._mode = "load"
            end
        end, { min_chip_w = 44 }),

        OPT.slide_multiswitch(SLOT_MODES, function()
            return nil
        end, function(self, chip_id)
            local m = slot_mode_by_id(chip_id)
            if not m then
                return
            end
            execute_slot(self._mode, m.slot)
            self._active_slot = m.slot
            refresh_slot_labels(self)
        end, { min_chip_w = 36, rows = 2 }),
    },
}))

local seg_hit_test = widget.hitTestSubcontrols

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    self._last_slot_hit = nil
    local hit = seg_hit_test(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out and hit then
        local chip_id = hit:match("_(slot_%d)$")
        if chip_id then
            local m = slot_mode_by_id(chip_id)
            if m then
                self._last_slot_hit = m.slot
            end
        end
    end
    return hit
end

function widget.onRightClick(self)
    local slot = self._last_slot_hit
    if not slot then
        return
    end
    local current = self._names[slot] or load_slot_name(slot)
    local ok, out = reaper.GetUserInputs("Rename Screenset Slot", 1, "Name for slot " .. tostring(slot) .. ":", current)
    if not ok then
        return
    end
    out = (out or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if out == "" then
        out = "Set " .. tostring(slot)
    end
    self._names[slot] = out
    save_slot_name(slot, out)
    refresh_slot_labels(self)
end

return widget
