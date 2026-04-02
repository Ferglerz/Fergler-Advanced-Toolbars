-- Utils/icon_fonts.lua — per-icon .ttf under IconFonts/ (glyph at U+0041). Skips _source_archive/.

local M = {}

M.ICON_CODEPOINT = 0x41

local function formatIconStem(stem)
    return (stem:gsub("_", " "))
end

--- display_name for relative paths like icons/Tools_17/U00C0.ttf
local function displayNameFromRelativePath(rel_no_ext)
    local parts = {}
    for p in rel_no_ext:gmatch("[^/]+") do
        table.insert(parts, p)
    end
    if #parts > 0 and parts[1] == "icons" then
        table.remove(parts, 1)
    end
    if #parts == 0 then
        return formatIconStem(rel_no_ext:gsub("/", " "))
    end
    local last = table.remove(parts)
    local uhex = last and last:match("^U(%x+)$")
    if uhex and #parts >= 1 then
        local group = table.concat(parts, " / "):gsub("_", " ")
        return group .. " · U+" .. uhex
    end
    return formatIconStem((rel_no_ext:gsub("/", " ")))
end

local function shouldSkipRelativeTtf(rel)
    return rel:match("^_source_archive/") ~= nil
end

--- @param icon_fonts_dir absolute path to IconFonts folder
--- @param utils UTILS
--- @return string[] relative paths from IconFonts/ (posix slashes)
local function collectTtfRelativePaths(icon_fonts_dir, utils)
    local norm_root = utils.normalizeSlashes(icon_fonts_dir)
    local results = {}
    local cmd
    if reaper.GetOS():match("Win") then
        local win_path = norm_root:gsub("/", "\\")
        cmd = string.format('cmd /c dir /s /b "%s\\*.ttf"', win_path)
    else
        cmd = string.format('find "%s" -name "*.ttf" -type f 2>/dev/null', norm_root)
    end
    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            line = utils.normalizeSlashes((line or ""):gsub("\r$", ""))
            if line ~= "" and line:lower():match("%.ttf$") then
                local prefix = norm_root .. "/"
                if line:sub(1, #prefix) == prefix then
                    local rel = line:sub(#prefix + 1)
                    if rel ~= "" and not shouldSkipRelativeTtf(rel) then
                        table.insert(results, rel)
                    end
                end
            end
        end
        handle:close()
    end
    table.sort(results)
    return results
end

--- @param script_path string toolbar script directory (SCRIPT_PATH)
--- @param utils table UTILS (joinPath, ensureDirectoryExists, normalizeSlashes)
--- @return table[] entries: path, name, display_name, icon_range (single slot U+0041)
function M.scanIconFonts(script_path, utils)
    local icon_fonts_dir = utils.joinPath(script_path, "IconFonts")
    utils.ensureDirectoryExists(icon_fonts_dir)

    local rel_paths = collectTtfRelativePaths(icon_fonts_dir, utils)
    local out = {}
    local c = M.ICON_CODEPOINT

    for _, rel in ipairs(rel_paths) do
        local stem = rel:gsub("%.ttf$", "")
        local font_path = utils.normalizeSlashes("IconFonts/" .. rel)
        table.insert(
            out,
            {
                path = font_path,
                name = stem,
                display_name = displayNameFromRelativePath(stem),
                icon_range = {{start = c, laFin = c}}
            }
        )
    end

    table.sort(
        out,
        function(a, b)
            return (a.display_name or ""):lower() < (b.display_name or ""):lower()
        end
    )

    return out
end

return M
