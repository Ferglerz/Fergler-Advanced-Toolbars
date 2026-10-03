-- Run from the repository root: lua tests/test_dropdown_ui.lua
local source = debug.getinfo(1, "S").source
local root = source:match("^@(.*/)tests/") or "./"
package.path = root .. "?.lua;" .. package.path

local DropdownItems = require("Utils.Core.dropdown_items")
local original = {
    {name = "Tools", children = {
        {name = "Same", action_id = 42},
        {name = "Nested", children = {{name = "Same", action_id = "_CUSTOM"}}},
    }},
    {name = "Same", action_id = 42},
}
local normalized = DropdownItems.normalize(original)
assert(normalized[1].children[1].action_id == "42")
assert(normalized[1].children[2].children[1].action_id == "_CUSTOM")
assert(DropdownItems.normalize(normalized)[1].children[2].children[1].name == "Same")
local serialized = require("Utils.Core.table_utils").serializeTable(normalized)
local restored = assert(load("return " .. serialized))()
assert(restored[1].children[2].children[1].action_id == "_CUSTOM",
    "nested menus must survive the same serialization used for toolbar files")

local clicked, menu_rows, submenu_rows, notices = nil, {}, {}, {}
local button_clicks, text_edits, button_calls = {}, {}, {}
local id_stack = {}
local saves = 0
local button = {
    instance_id = "button_1", display_text = "Dropdown", parent_toolbar = {},
    dropdown_menu = normalized,
}

C = {
    GlobalStyle = {withGlobalStyle = function(_, fn) return fn() end},
    PopupContext = require("Systems.Popup_Context"),
    ActionSearch = nil,
}
UTILS = {stripNewLines = function(s) return s end, snapWindowToMinimum = function() end}
CONFIG_MANAGER = {requestSaveToolbarConfig = function() saves = saves + 1 end}
BUTTON_UTILS = {resolveActionCommandId = function(id) return tonumber(id) or 0 end}
reaper = {
    ImGui_Cond_Always = function() return 1 end,
    ImGui_Cond_FirstUseEver = function() return 1 end,
    ImGui_WindowFlags_NoCollapse = function() return 1 end,
    ImGui_WindowFlags_NoDocking = function() return 2 end,
    ImGui_SetNextWindowPos = function() end,
    ImGui_SetNextWindowSize = function() end,
    ImGui_SetNextWindowSizeConstraints = function() end,
    ImGui_OpenPopup = function() end,
    ImGui_BeginPopup = function() return true end,
    ImGui_EndPopup = function() end,
    ImGui_BeginMenu = function(_, label)
        submenu_rows[#submenu_rows + 1] = label
        return true
    end,
    ImGui_EndMenu = function() end,
    ImGui_MenuItem = function(_, label, _, checked)
        menu_rows[#menu_rows + 1] = {label = label, checked = checked}
        return clicked == label
    end,
    ImGui_Separator = function() end,
    ImGui_Text = function() end,
    ImGui_TextDisabled = function() end,
    ImGui_IsItemHovered = function() return false end,
    ImGui_CloseCurrentPopup = function() end,
    ImGui_GetToggleCommandState = function() return -1 end,
    GetToggleCommandState = function(id) return id == 42 and 1 or -1 end,
    Main_OnCommand = function() end,
    ShowConsoleMsg = function(msg) notices[#notices + 1] = msg end,
    ImGui_Begin = function() return true, true end,
    ImGui_End = function() end,
    ImGui_Button = function(_, label)
        button_calls[#button_calls + 1] = label
        if button_clicks[label] then button_clicks[label] = nil return true end
        return false
    end,
    ImGui_BeginDisabled = function() end,
    ImGui_EndDisabled = function() end,
    ImGui_SameLine = function() end,
    ImGui_GetContentRegionAvail = function() return 600, 310 end,
    ImGui_ChildFlags_Border = function() return 1 end,
    ImGui_BeginChild = function() return true end,
    ImGui_EndChild = function() end,
    ImGui_PushID = function(_, id) id_stack[#id_stack + 1] = id end,
    ImGui_PopID = function() table.remove(id_stack) end,
    ImGui_SetNextItemWidth = function() end,
    ImGui_CalcTextSize = function(_, text) return #text * 12 end,
    ImGui_InputTextWithHint = function(_, id, hint, value)
        local key = tostring(id_stack[#id_stack]) .. ":" .. id
        if text_edits[key] then
            local edit = text_edits[key]
            text_edits[key] = nil
            return true, edit
        end
        return false, value
    end,
}

local DropdownMenu = require("Menus.Button_Dropdown_Menu")
local menu = DropdownMenu.new()
menu.is_open, menu.owner_ctx, menu.popup_open = true, "owner", true
menu.current_button, menu.current_position = button, {x = 0, y = 0}
assert(menu:renderDropdown("other") == false and menu.popup_open,
    "another context must not clear the owner's popup state")
menu:renderDropdown("owner")
assert(submenu_rows[1]:find("##dropdown_row_root/1", 1, true))
assert(submenu_rows[2]:find("##dropdown_row_root/1/2", 1, true))
assert(menu_rows[1].label ~= menu_rows[2].label and menu_rows[1].checked,
    "duplicate labels need unique row IDs and toggle checkmarks")

clicked = "Same##dropdown_row_root/1/2/1"
menu:renderDropdown("owner")
assert(#notices == 1 and notices[1]:find("_CUSTOM", 1, true),
    "unresolved commands should report the missing ID")

local widget = {
    instance_id = "widget_dropdown_1",
    widget_ref = {selected_text = "before", onSelect = function(self)
        self.selected_text = "Reset by widget"
    end},
    dynamic_items = {{name = "Template", action_id = ""}},
}
menu.is_open, menu.owner_ctx, menu.popup_open = true, "owner", true
menu.current_button = widget
clicked = "Template##dropdown_row_root/1"
BUTTON_UTILS.resolveActionCommandId = function() error("widget row must not resolve a command") end
reaper.GetToggleCommandState = function() error("widget row must not query toggle state") end
reaper.ImGui_IsItemHovered = function() return true end
reaper.ImGui_BeginTooltip = function() error("widget row must not show action diagnostics") end
menu:renderDropdown("owner")
assert(widget.widget_ref.selected_text == "Reset by widget",
    "widget onSelect must control the selected label")

local Editor = require("Windows.Button_Dropdown_Editor")
local editor = Editor.new()
button.dropdown_menu = {{name = "First", action_id = "42"}}
editor:show(button, "owner")
text_edits["1:##name"] = "Renamed"
text_edits["1:##action"] = "43"
local before = saves
editor:renderDropdownEditor("owner")
assert(button.dropdown_menu[1].name == "Renamed" and button.dropdown_menu[1].action_id == "43")
assert(saves == before + 2, "each text field edit must request autosave")
assert(button_calls[5] == "↑" or table.concat(button_calls, ","):find("↑,↓", 1, true),
    "disabled reorder controls must still be laid out")

button_clicks["Add Submenu"] = true
editor:renderDropdownEditor("owner")
assert(button.dropdown_menu[2].children and saves == before + 3)
button_clicks["Edit children"] = true
editor:renderDropdownEditor("owner")
assert(#editor.path == 1 and editor.path[1] == 2)
button_clicks["Add Item"] = true
editor:renderDropdownEditor("owner")
assert(#button.dropdown_menu[2].children == 1)
button_clicks["Back to parent"] = true
editor:renderDropdownEditor("owner")
assert(#editor.path == 0 and button.dropdown_menu[1].name == "Renamed",
    "child navigation must preserve flat legacy items")

local Search = require("Windows.Action_Search")
local search = Search.new()
C.ActionSearch = search
editor:pickAction("owner", button, button.dropdown_menu[1])
assert(search.mode == "callback" and search.on_pick)
assert(search:applyPick({name = "Selected", id_str = "99"}))
assert(button.dropdown_menu[1].action_id == "99")
search:close()
assert(search.on_pick == nil and search.target_button == nil,
    "closing search must release the target callback")

editor:pickAction("owner", button, button.dropdown_menu[1])
button.dropdown_menu[1] = nil
assert(not search:applyPick({name = "Stale", id_str = "100"}),
    "picker must not write to a removed row")
search:close()

button.dropdown_menu = {{name = "Fresh", action_id = ""}}
editor:pickAction("owner", button, button.dropdown_menu[1])
editor:show({instance_id = "button_2", display_text = "Other", dropdown_menu = {}}, "owner")
assert(search.on_pick == nil and not search.is_open,
    "switching editor targets must clear the previous picker callback")

-- The picker should render only the clipped match range.
local selectable_labels, clipper_steps, clipper_creations = {}, 0, 0
reaper.ImGui_WindowFlags_NoFocusOnAppearing = function() return 4 end
reaper.ImGui_IsKeyPressed = function() return false end
reaper.ImGui_Key_Escape = function() return 0 end
reaper.ImGui_TextWrapped = function() end
reaper.ImGui_Spacing = function() end
reaper.ImGui_GetCursorPosX = function() return 0 end
reaper.ImGui_GetCursorPosY = function() return 0 end
reaper.ImGui_SetCursorPos = function() end
reaper.ImGui_GetTextLineHeight = function() return 16 end
reaper.ImGui_Selectable = function(_, label)
    selectable_labels[#selectable_labels + 1] = label
    return false
end
reaper.ImGui_CreateListClipper = function()
    clipper_creations = clipper_creations + 1
    return {valid = true}
end
reaper.ImGui_ValidatePtr = function(ptr) return ptr.valid end
reaper.ImGui_ListClipper_Begin = function() clipper_steps = 0 end
reaper.ImGui_ListClipper_Step = function()
    clipper_steps = clipper_steps + 1
    return clipper_steps == 1
end
reaper.ImGui_ListClipper_GetDisplayRange = function() return 1, 2 end
search.catalog = {
    {name = "One", id_str = "1", haystack = "match"},
    {name = "Two", id_str = "2", haystack = "match"},
    {name = "Three", id_str = "3", haystack = "match"},
}
search:open({mode = "callback", ctx = "owner", on_pick = function() return true end})
search.filter_text = "match"
search:render("owner")
assert(#search.matches == 3 and #selectable_labels == 2)
assert(selectable_labels[1] == "Two" and selectable_labels[2] == "2",
    "only the visible action-search row should be submitted")
search.clipper.valid = false
search:render("owner")
assert(clipper_creations == 2, "expired list clipper must be recreated")
search:close()
search:open({mode = "callback", ctx = "owner", on_pick = function() return true end})
search.filter_text = "match"
search:render("owner")
assert(clipper_creations == 3, "reopening search must not reuse a stale clipper")
search:close()

print("dropdown UI checks passed")
