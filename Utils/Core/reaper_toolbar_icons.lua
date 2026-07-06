-- Utils/Core/reaper_toolbar_icons.lua — REAPER Data/toolbar_icons PNG strips (3 frames).

local PNG_SCAN = require("Utils.Core.reaper_png_icon_scan")

local M = {}

M.FRAME_COUNT = 3

local STRIP_PREFIX = "^toolbar_"

local function toolbarIconsRoot()
    return UTILS.normalizeSlashes(reaper.GetResourcePath() .. "/Data/toolbar_icons")
end

function M.displayNameFromBasename(basename)
    return PNG_SCAN.displayNameFromBasename(basename, STRIP_PREFIX)
end

--- Theme/chrome strips, not action icons.
function M.shouldSkipBasename(basename)
    if not basename or basename == "" then
        return true
    end
    local stem = basename:gsub("%.png$", ""):gsub("%.PNG$", ""):lower()
    if stem:find("_highlight", 1, true) then
        return true
    end
    if stem:find("^animation_", 1) or stem:find("_animation_", 1, true) then
        return true
    end
    return false
end

--- @return table[] entries: path (basename), name, display_name
function M.scan()
    local basenames = PNG_SCAN.collectPngBasenames(toolbarIconsRoot(), M.shouldSkipBasename)
    return PNG_SCAN.buildSortedEntries(basenames, M.displayNameFromBasename)
end

function M.resolveAbsolutePath(basename)
    if not basename or basename == "" then
        return nil
    end
    basename = basename:gsub("\\", "/")
    if basename:find("/") then
        local abs = UTILS.normalizeSlashes(toolbarIconsRoot() .. "/" .. basename)
        if reaper.file_exists(abs) then
            return abs
        end
        return nil
    end

    local root = toolbarIconsRoot()
    for _, prefix in ipairs({"", "150/", "200/"}) do
        local abs = UTILS.normalizeSlashes(root .. "/" .. prefix .. basename)
        if reaper.file_exists(abs) then
            return abs
        end
    end
    return nil
end

function M.frameUv()
    return 0, 0, 1 / M.FRAME_COUNT, 1
end

--- Pixel size of frame 1 (normal state) from a loaded texture. No scaling.
function M.nativeFrameSizeFromTexture(texture)
    if not texture then
        return nil, nil
    end
    local ok, strip_w, strip_h = pcall(function()
        return reaper.ImGui_Image_GetSize(texture)
    end)
    if not ok or not strip_w or not strip_h or strip_w <= 0 or strip_h <= 0 then
        return nil, nil
    end
    return math.floor(strip_w / M.FRAME_COUNT), math.floor(strip_h)
end

return M
