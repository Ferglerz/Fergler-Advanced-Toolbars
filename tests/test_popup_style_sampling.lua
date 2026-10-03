-- Run from the repository root with Lua 5.4.
package.path = "./?.lua;" .. package.path

local captures, native, active = {}, {}, {}
reaper = {
    ImGui_IsAnyItemActive = function(ctx) return active[ctx] == true end,
    ImGui_PopupFlags_AnyPopupId = function() return 1 end,
    ImGui_PopupFlags_AnyPopupLevel = function() return 2 end,
    ImGui_IsPopupOpen = function(ctx, _, flags)
        assert(flags == 3, "nested popups must be included")
        return native[ctx] == true
    end,
    ImGui_SetNextFrameWantCaptureKeyboard = function(ctx, value) captures[ctx] = value end,
}
local popup = require("Systems.Popup_Context")
C = {IconSelector = {is_open = true, owner_ctx = "a"}}
assert(popup.updateKeyboardCapture("a"))
assert(not popup.updateKeyboardCapture("b"), "another toolbar's editor must not capture keys")
C.IconSelector.is_open = false
native.b = true
assert(popup.updateKeyboardCapture("b"), "widget/ruler popups must capture without global flags")
native.b = false
active.b = true
assert(popup.updateKeyboardCapture("b"), "active text controls must capture keys")
active.b = false
C.Interactions = {preset_browser_state = {is_open = true, owner_ctx = "a"}}
assert(popup.updateKeyboardCapture("a"))
assert(not popup.updateKeyboardCapture("b"))
C.Interactions.preset_browser_state.is_open = false
assert(not popup.updateKeyboardCapture("a"), "closing the last editor releases shortcuts")

-- No style work or lazy module loading when settings are closed.
local toolbar_window = {}
local env = setmetatable({ToolbarWindow = toolbar_window}, {__index = _G})
assert(loadfile("Renderers/01_Toolbar/settings.lua", "t", env))()
reaper.ImGui_IsPopupOpen = function() return false end
C = nil
toolbar_window.renderToolbarSettings({})

-- Live theme changes propagate, and rendering failures still pop every style.
local colors, vars, pushed = 0, 0, {}
reaper = setmetatable({
    ImGui_PushStyleColor = function(_, id, value)
        colors = colors + 1
        pushed[id] = value
    end,
    ImGui_PopStyleColor = function(_, count) colors = colors - count end,
    ImGui_PushStyleVar = function() vars = vars + 1 end,
    ImGui_PopStyleVar = function(_, count) vars = vars - count end,
}, {__index = function(_, key)
    if key:match("^ImGui_Col_") or key:match("^ImGui_StyleVar_") then
        return function() return key end
    end
    error("unexpected API: " .. key)
end})
local style = require("Windows._Global_Style")
CONFIG = nil
style.withGlobalStyle("a", function() assert(colors > 0 and vars > 0) end)
assert(colors == 0 and vars == 0)
CONFIG = {COLORS = {WINDOW_BG = "#FAFAFA33", NORMAL = {
    TEXT = {NORMAL = "#202020FF"}, BORDER = {NORMAL = "#606060FF"},
}}}
style.withGlobalStyle("a", function()
    assert(pushed.ImGui_Col_WindowBg == 0xFAFAFAFF, "editor surfaces stay opaque")
    assert(pushed.ImGui_Col_Text == 0x202020FF)
end)
CONFIG.COLORS.WINDOW_BG = "#102030FF"
local ok, err = pcall(style.withGlobalStyle, "a", function()
    assert(pushed.ImGui_Col_WindowBg == 0x102030FF, "color edits must not wait for a save")
    error("render failure")
end)
assert(not ok and err:find("render failure", 1, true))
assert(colors == 0 and vars == 0, "style stacks must balance on failure")
style.withGlobalStyle("a", function() assert(colors == 0 and vars > 0) end, {colors = false})
assert(colors == 0 and vars == 0)

-- CPU widget instances use one process scan per sampling interval.
local now, calls = 0, 0
reaper = {time_precise = function() return now end, GetOS = function() return "OSX64" end}
local original_popen = io.popen
io.popen = function()
    calls = calls + 1
    return {read = function() return "24.5\n8.5\n" end, close = function() end}
end
local cpu = dofile("Widgets/cpu_usage.lua")
local a, b = {}, {}
assert(cpu.getValue(a) == 24.5 and calls == 1)
assert(cpu.getValue(b) == 24.5 and b.cached_reaper_cpu == 8.5 and calls == 1)
now = 2.99
cpu.getValue(a)
assert(calls == 1)
now = 3
cpu.getValue(b)
cpu.getValue(a)
assert(calls == 2, "one shared scan, regardless of instance order")
io.popen = original_popen
print("Popup, style and shared sampling regressions passed")
