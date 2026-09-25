-- Run with Lua 5.4 from the repository root: lua5.4 tests/test_regressions.lua
local source = debug.getinfo(1, "S").source
local root = source:match("^@(.*/)tests/") or "./"
package.path = root .. "?.lua;" .. package.path

local tables = require("Utils.Core.table_utils")
local original = {
    ['action_"quoted"\\path'] = "C:\\Users\\name\nquoted \"value\"",
    nested = { ["key\nline"] = "backslash \\ and tab\t" },
}
local restored = assert(load("return " .. tables.serializeTable(original)))()
assert(restored['action_"quoted"\\path'] == original['action_"quoted"\\path'])
assert(restored.nested["key\nline"] == original.nested["key\nline"])

local polling = require("Utils.Widget.polling")
local a, b = {update_interval = 0.05, getValue = function() return 1 end},
    {update_interval = 0.05, getValue = function() return 2 end}
local function fetch(widget) return true, widget.getValue() end
for _, now in ipairs({0, 0.06, 0.12}) do
    assert(polling.refresh(a, now, fetch))
    assert(polling.refresh(b, now, fetch))
end
assert(a.value == 1 and b.value == 2)
assert(not polling.refresh(a, 0.13, fetch))
assert(not polling.refresh(b, 0.13, fetch))

local dropdown = require("Utils.Core.dropdown_items")
local menu = dropdown.normalize({
    {is_separator = true}, {is_heading = true, name = "A"}, {name = "Go", action_id = 42},
})
assert(menu[1].is_separator and menu[2].name == "A" and menu[3].action_id == "42")

local palette = require("Widgets.colour_swatch_state")
local swatch = {
    _button_instance_id = "swatch",
    _state = {user_categories = {{id = "user_swatch_1"}, {id = "user_swatch_3"}}},
}
assert(palette.next_user_cat_id(swatch) == "user_swatch_2")
assert(palette.next_user_cat_id(swatch) == "user_swatch_4")

local layout = {}
require("Managers.Layout.Cache")(layout)
layout.toolbar_layouts, layout._layout_cache_order = {}, {}
layout:storeToolbarLayout("one_100x20_h", {width = 100})
layout:storeToolbarLayout("two_200x20_h", {width = 200})
assert(layout.toolbar_layouts.one_100x20_h and layout.toolbar_layouts.two_200x20_h)

local next_button_id = 0
ID_GENERATOR = {generateButtonId = function()
    next_button_id = next_button_id + 1
    return tostring(next_button_id)
end}
local definition = require("Systems.Button_Definition")
local button_a = definition.createButton("1", "First", 0)
local button_b = definition.createButton("2", "Second", 1)
assert(button_a.clearCache == button_b.clearCache and rawget(button_a, "clearCache") == nil)
button_a:markLayoutClean()
assert(not button_a.layout_dirty and button_b.layout_dirty)

local selected = {{pan = -0.2}, {pan = 0.2}}
reaper = {
    CountSelectedMediaItems = function() return #selected end,
    GetSelectedMediaItem = function(_, i) return selected[i + 1] end,
    GetActiveTake = function(item) return item end,
    GetMediaItemTakeInfo_Value = function(item) return item.pan end,
    SetMediaItemTakeInfo_Value = function(item, _, value) item.pan = value end,
    UpdateItemInProject = function() end,
    UpdateArrange = function() end,
    Undo_OnStateChange = function() end,
    ShowConsoleMsg = function() end,
}
UTILS = require("Utils.Reaper.reaper_utils")
local item_slider = require("Utils.Widget.item_selection_slider")
local base_slider = {}
item_slider.attach(base_slider, {
    read_first = function(item) return item.pan * 100 end,
    write_item = function(item, value) item.pan = value / 100 end,
})
local slider_a = setmetatable({cached_value = 0}, {__index = base_slider})
local slider_b = setmetatable({cached_value = 0}, {__index = base_slider})
base_slider.setValue(30, slider_a)
assert(slider_a.cached_value == 30 and slider_b.cached_value == 0)
selected[1].pan, selected[2].pan = -0.2, 0.2
package.loaded["Utils.Widget.widget_factory"] = {SLIDER_QUICK_CHIPS = {attach = function() end}}
local spread = require("Widgets.item_spreader")
assert(spread.getValue(spread) > 0)
local callbacks = require("Utils.Widget.widget_callbacks")
local legacy = {setValue = function(value) assert(value == 50) end}
assert(callbacks.setValue(legacy, 50))
local calls = 0
local recovering = {getValue = function()
    calls = calls + 1
    if calls == 1 then error("temporary failure") end
    return 5
end}
assert(not callbacks.getValue(recovering))
assert(select(2, callbacks.getValue(recovering)) == 5)
assert(callbacks.setValue(spread, 100))
assert(selected[1].pan == -1 and selected[2].pan == 1)
selected = {}
assert(spread.getValue(spread) == 0 and spread.initial_state == nil)

local armed, toggle = nil, {[1] = -1, [2] = -1}
reaper.GetToggleCommandState = function(command) return toggle[command] or -1 end
reaper.GetArmedCommand = function() return armed end
reaper.ArmCommand = function(command) armed = command end
reaper.Main_OnCommand = function(command) if command == 2020 then armed = nil end end
CACHE_UTILS = {ensureButtonCache = function() end}
BUTTON_UTILS = {resolveActionCommandId = tonumber}
local manager = require("Managers.Button").new()
local first, second = {id = "1", instance_id = "first"}, {id = "2", instance_id = "second"}
manager:registerButton(first)
manager:registerButton(second)
manager:flushDirtyButtonStates()
assert(manager:toggleArmCommand(first) and first.is_armed)
assert(manager:toggleArmCommand(second) and not first.is_armed and second.is_armed)
second.id = "3"
manager:syncButtonCommandWatch(second)
assert(manager.command_instances[2] == nil and manager.command_instances[3].second)
manager:unregisterButton(first)
assert(manager.command_instances[1] == nil)

reaper.ShowConsoleMsg = function() end
reaper.GetOS = function() return "OSX64" end
reaper.time_precise = function() return 10 end
UTILS.serializeTable = tables.serializeTable
local manager_class = {}
require("Managers.Config.Persistence")(manager_class, {SAVE_DEBOUNCE_SEC = 0.4})
local path = os.tmpname()
os.remove(path)
manager_class.backupUserConfigFileBeforeWrite = function() return true end
assert(manager_class:saveConfigToFile({value = "before"}, path))
assert(assert(loadfile(path))().value == "before")
local real_open = io.open
io.open = function(filename, mode)
    if filename:find(".tmp.", 1, true) and mode == "w" then
        return {write = function() return nil, "disk full" end, close = function() return true end}
    end
    return real_open(filename, mode)
end
assert(not manager_class:saveConfigToFile({value = "after"}, path))
io.open = real_open
assert(assert(loadfile(path))().value == "before")
os.remove(path)
manager_class._pending_main_save = true
manager_class._pending_main_save_at = 0
manager_class._pending_toolbar_saves = {}
manager_class.saveMainConfig = function() return false end
assert(not manager_class:flushPendingSaves())
assert(manager_class._pending_main_save and manager_class._pending_main_save_at > 10)

print("Lua regressions passed")
