-- Utils/Core/reaper_track_icons.lua — REAPER Data/track_icons PNGs (single image).

local PNG_SCAN = require("Utils.Core.reaper_png_icon_scan")

local M = {}

local function trackIconsRoot()
    return UTILS.normalizeSlashes(reaper.GetResourcePath() .. "/Data/track_icons")
end

function M.displayNameFromBasename(basename)
    return PNG_SCAN.displayNameFromBasename(basename)
end

--- @return table[] entries: path (basename), name, display_name
function M.scan()
    local basenames = PNG_SCAN.collectPngBasenames(trackIconsRoot())
    return PNG_SCAN.buildSortedEntries(basenames, M.displayNameFromBasename)
end

function M.resolveAbsolutePath(basename)
    if not basename or basename == "" then
        return nil
    end
    basename = basename:gsub("\\", "/")
    if basename:find("/") then
        local abs = UTILS.normalizeSlashes(trackIconsRoot() .. "/" .. basename)
        if reaper.file_exists(abs) then
            return abs
        end
        return nil
    end

    local root = trackIconsRoot()
    for _, prefix in ipairs({"", "150/", "200/"}) do
        local abs = UTILS.normalizeSlashes(root .. "/" .. prefix .. basename)
        if reaper.file_exists(abs) then
            return abs
        end
    end
    return nil
end

--- Pixel size from a loaded texture. No scaling.
function M.nativeSizeFromTexture(texture)
    if not texture then
        return nil, nil
    end
    local ok, w, h = pcall(function()
        return reaper.ImGui_Image_GetSize(texture)
    end)
    if not ok or not w or not h or w <= 0 or h <= 0 then
        return nil, nil
    end
    return math.floor(w), math.floor(h)
end

return M
