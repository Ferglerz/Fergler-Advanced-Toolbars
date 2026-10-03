-- Run from the repository root with Lua 5.4: lua tests/test_icon_picker.lua
local source = debug.getinfo(1, "S").source
local root = source:match("^@(.*/)tests/") or "./"
package.path = root .. "?.lua;" .. package.path

local png = os.tmpname()
local file = assert(io.open(png, "wb"))
file:write("\137PNG\r\n\26\n", "\0\0\0\13IHDR", "\0\0\0\90", "\0\0\0\40")
file:close()

local entries = {}
for i = 1, 60 do entries[i] = {path = "icon" .. i, display_name = "Icon " .. i} end
local resolves, loads = 0, 0
package.loaded["Utils.Core.icon_fonts"] = {ICON_CODEPOINT = 65}
package.loaded["Utils.Core.reaper_toolbar_icons"] = {
    FRAME_COUNT = 3, scan = function() return entries end,
    resolveAbsolutePath = function() resolves = resolves + 1; return png end,
    frameUv = function() return 0, 0, 1 / 3, 1 end,
}
package.loaded["Utils.Core.reaper_track_icons"] = {scan = function() return {} end}
package.loaded["Utils.Draw.drawing"] = {}
ICON_FONTS = {}
UTILS = {
    normalizeSlashes = function(path) return path end,
    snapWindowToMinimum = function() end,
    focusArrangeWindow = function() end,
}

local pressed, escape, window_close, scroll_y = nil, false, false, 0
local last_extent, image_count, fallback_count, cursor_y, content_width = 0, 0, 0, 0, 120
local clipper_creations, clipper_step, clipper_range = 0, 0, {0, 2}
local submitted_ids = {}
reaper = {
    ImGui_GetCursorPosY = function() return 0 end,
    ImGui_GetContentRegionAvail = function() return content_width, 360 end,
    ImGui_GetScrollY = function() return scroll_y end,
    ImGui_GetWindowHeight = function() return 72 end,
    ImGui_SetCursorPos = function(_, _, y) cursor_y = y end,
    ImGui_Dummy = function() last_extent = cursor_y end,
    ImGui_PushID = function(_, id) submitted_ids[#submitted_ids + 1] = id end,
    ImGui_PopID = function() end,
    ImGui_CreateListClipper = function()
        clipper_creations = clipper_creations + 1
        return {valid = true}
    end,
    ImGui_ValidatePtr = function(ptr, type_name)
        assert(type_name == "ImGui_ListClipper*")
        return ptr.valid
    end,
    ImGui_ListClipper_Begin = function(_, count, height)
        assert(count == math.ceil(60 / math.floor((content_width - 6) / 50)))
        assert(height == 50)
        clipper_step = 0
    end,
    ImGui_ListClipper_Step = function()
        clipper_step = clipper_step + 1
        return clipper_step == 1
    end,
    ImGui_ListClipper_GetDisplayRange = function() return clipper_range[1], clipper_range[2] end,
    ImGui_Image = function() image_count = image_count + 1 end,
    ImGui_InvisibleButton = function() local hit = pressed == "pick"; pressed = nil; return hit end,
    ImGui_IsItemHovered = function() return false end,
    ImGui_HoveredFlags_None = function() return 0 end,
    ImGui_Button = function(_, label)
        if label == "?" then fallback_count = fallback_count + 1 end
        if pressed == label then pressed = nil; return true end
        return false
    end,
    ImGui_InputTextWithHint = function(_, _, _, value) return false, value end,
    ImGui_SetNextItemWidth = function() end,
    ImGui_BeginChild = function() end, ImGui_EndChild = function() end,
    ImGui_TextDisabled = function() end, ImGui_Spacing = function() end,
    ImGui_TextWrapped = function() end, ImGui_SameLine = function() end,
    ImGui_Separator = function() end,
    ImGui_Checkbox = function(_, _, value) return false, value end,
    ImGui_GetStyleVar = function() return 6 end,
    ImGui_StyleVar_ItemSpacing = function() return 0 end,
    ImGui_BeginTabBar = function() return false end,
    ImGui_SetNextWindowPos = function() end,
    ImGui_SetNextWindowSize = function() end,
    ImGui_SetNextWindowSizeConstraints = function() end,
    ImGui_Cond_FirstUseEver = function() return 0 end,
    ImGui_WindowFlags_NoCollapse = function() return 0 end,
    ImGui_WindowFlags_NoFocusOnAppearing = function() return 0 end,
    ImGui_Begin = function() return true, not window_close end,
    ImGui_End = function() end,
    ImGui_IsKeyPressed = function() return escape end,
    ImGui_Key_Escape = function() return 0 end,
    ImGui_ChildFlags_Border = function() return 0 end,
}
C = {
    IconManager = {loadTexture = function() loads = loads + 1; return {} end},
    ButtonManager = {clearIconCache = function(self) self.clears = (self.clears or 0) + 1 end},
}
local selector_class = require("Windows.Icon_Selector")
local grids = require("Windows.icon_selector_grids")

local rows, total = grids.layoutPathRows({{w = 30, h = 10}, {w = 70, h = 40}, {w = 30, h = 20}}, 120)
assert(#rows == 2 and rows[1].h == 40 and rows[2].y == 52 and total == 78)

local button = {
    original_text = "Action", id = "1", cached_width = 50,
    clearLayoutCache = function(self) self.clears = (self.clears or 0) + 1 end,
    saveChanges = function(self) self.saves = (self.saves or 0) + 1 end,
    isSeparator = function() return false end,
}
local selector = selector_class.new()
selector:show(button, "ctx")
local opts = {
    selector = selector, button = button, content_w = function() return 120 end,
    grid_view_h = 150, child_flags = 0,
    applyDisplayText = function(s) button.display_text = s.name_top_buf; button.hide_label = true end,
    clearButtonIcons = function(b) b.icon_char = nil; b.icon_path = nil; b.reaper_icon_path = nil end,
    refreshButtonIconLayout = function(b) b:clearLayoutCache() end,
}
pressed = "pick"
grids.renderReaperIconGrid("ctx", opts)
assert(button.reaper_icon_path == "icon1" and button.saves == nil)
assert(loads < 10 and image_count == loads, "only visible image textures should load")
assert(resolves == 60, "paths should resolve once per filter")
assert(last_extent == 926, "all image rows must contribute to scroll height")
local first_loads = loads
grids.renderReaperIconGrid("ctx", opts)
assert(resolves == 60 and loads == first_loads * 2, "layout/filter should be cached")
scroll_y = 500
grids.renderReaperIconGrid("ctx", opts)
assert(loads > first_loads * 2 and loads < 30, "scrolled rendering should stay bounded")
selector.reaper_icon_filter = "no matches"
grids.renderReaperIconGrid("ctx", opts)
assert(last_extent == 0, "empty results must not retain phantom scroll height")

selector.font_maps = {}
for i = 1, 60 do
    selector.font_maps[i] = {path = "font" .. i, display_name = "abc " .. i, category = "letters"}
end
selector.icon_filter = "abc"
scroll_y = 0
grids.renderFontIconGrid("ctx", opts)
assert(fallback_count == 4 and last_extent == 1506, "font grid should draw two visible columns")
assert(clipper_creations == 1)
content_width = 220
grids.renderFontIconGrid("ctx", opts)
assert(fallback_count == 12 and last_extent == 756, "font columns and scroll height should follow width")
assert(clipper_creations == 1, "a valid clipper should be reused")
content_width = 120
clipper_range = {10, 11}
submitted_ids = {}
selector._grid_cache.fonts.clipper.valid = false
grids.renderFontIconGrid("ctx", opts)
assert(clipper_creations == 2, "expired clipper must be recreated after a hidden tab")
assert(submitted_ids[1] == 21 and submitted_ids[2] == 22,
    "native clipper navigation range must submit offscreen font buttons")

-- Cancel restores nil fields and queues a restored save in case another save
-- flushed the live preview while the picker was open.
selector:revertButtonState()
assert(button.reaper_icon_path == nil and button.display_text == nil and button.hide_label == nil)
assert(button.cached_width == nil and button.saves == 1 and button.clears >= 2)
selector:revertButtonState()
assert(button.saves == 1, "rollback should run once")

selector:show(button, "ctx")
button.icon_path = "preview"
pressed = "Cancel"
selector:renderGrid("ctx")
assert(button.icon_path == nil and button.saves == 2 and not selector.is_open)
selector:cleanup()
assert(button.saves == 2)

selector:show(button, "ctx")
button.icon_path = "committed"
pressed = "OK"
selector:renderGrid("ctx")
selector:cleanup()
assert(button.icon_path == "committed" and button.saves == 3)

selector:show(button, "ctx")
pressed = "Remove Icon"
require("Windows.icon_selector_header").render("ctx", selector, {
    applyDisplayText = opts.applyDisplayText,
    clearButtonIcons = opts.clearButtonIcons,
    refreshButtonIconLayout = opts.refreshButtonIconLayout,
})
assert(button.icon_path == nil and button.saves == 3, "header preview must stay unsaved")
selector:cleanup()
assert(button.icon_path == "committed" and button.saves == 4)

selector:show(button, "ctx")
button.icon_path = "temporary"
escape = true
selector:renderGrid("ctx")
assert(button.icon_path == "committed" and button.saves == 5)
escape = false

selector:show(button, "ctx")
button.icon_path = "close preview"
window_close = true
selector:renderGrid("ctx")
assert(button.icon_path == "committed" and button.saves == 6)
window_close = false

selector:show(button, "ctx")
button.icon_path = "replacement preview"
selector:show(button, "ctx")
assert(button.icon_path == "committed" and button.saves == 7)
button.icon_path = "external close preview"
selector:cleanup()
assert(button.icon_path == "committed" and button.saves == 8)
os.remove(png)
print("icon picker regressions passed")
