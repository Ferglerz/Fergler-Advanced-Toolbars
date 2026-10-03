-- Run from the repository root with Lua 5.4.
package.path = "./?.lua;" .. package.path

local colors, vars, columns, switcher_width = 0, 0
local noop = function() end
reaper = {
    ImGui_GetContentRegionAvail = function() return 547, 800 end,
    ImGui_GetCursorPosX = function() return 14 end,
    -- Native bindings may include optional outputs: only the width belongs in math.max.
    ImGui_CalcTextSize = function(_, text) return #text * 7, 14, nil, nil end,
    ImGui_GetFrameHeight = function() return 28 end,
    ImGui_IsItemHovered = function() return false end,
    ImGui_Button = function() return false end,
    ImGui_Checkbox = function(_, _, value) return false, value end,
    ImGui_BeginPopup = function() return false end,
    ImGui_GetStyleVar = function() return 10, 8 end,
    ImGui_PushStyleColor = function() colors = colors + 1 end,
    ImGui_PopStyleColor = function(_, n) colors = colors - (n or 1); assert(colors >= 0) end,
    ImGui_PushStyleVar = function() vars = vars + 1 end,
    ImGui_PopStyleVar = function(_, n) vars = vars - (n or 1); assert(vars >= 0) end,
    ImGui_BeginTable = function(_, _, count) columns = count; return true end,
    ImGui_TableSetupColumn = function(_, label, _, width)
        if label == "Switcher" then switcher_width = width end
    end,
}
for _, name in ipairs({"Spacing", "Text", "TextDisabled", "SameLine", "Separator",
    "TableHeadersRow", "TableNextRow", "TableNextColumn", "SetCursorPosX", "EndTable"}) do
    reaper["ImGui_" .. name] = noop
end
setmetatable(reaper, {__index = function(_, key)
    if key:match("^ImGui_Col_") or key:match("^ImGui_StyleVar_")
        or key:match("^ImGui_TableFlags_") or key:match("^ImGui_TableColumnFlags_")
        or key:match("^ImGui_HoveredFlags_") then return function() return 1 end end
    error("unexpected API: " .. key)
end})
C = {GlobalStyle = {colors = {windowBg = 0x333333FF, text = 0xEEEEEEFF, danger = 0xD86868FF}}}
local menu = {
    menuPopupPrepareFrame = noop, menuPopupEndFrame = noop, renderUiPinSettings = noop,
}
local env = setmetatable({GlobalSettingsMenu = menu, POPUP_TOOLBAR_LIST = "toolbar_list",
    mixMenuColor = function(a) return a end}, {__index = _G})
assert(loadfile("Menus/Global_Settings/toolbar_selector.lua", "t", env))()

local toolbars = {{name = "Main toolbar"}}
for _, count in ipairs({1, 4}) do
    local controller = {
        toolbar_id = "test", current_dock_id = 0, extra_rows = {}, enable_toolbar_switch = true,
        shouldUsePinnedChrome = function() return false end,
        getRowCount = function() return count end,
        getRowToolbar = function() return toolbars[1] end,
    }
    local ok, err = pcall(menu.renderThisToolbarTab, menu, "ctx", controller,
        function() error("unexpected save") end, toolbars, 1, noop)
    assert(ok, "settings table must handle optional nil API outputs: " .. tostring(err))
    assert(switcher_width == 56, "switcher width must use text width only")
    assert(columns == (count > 1 and 3 or 2))
    assert(colors == 0 and vars == 0, "table styles must balance")
end
print("Global settings menu regression passed")
