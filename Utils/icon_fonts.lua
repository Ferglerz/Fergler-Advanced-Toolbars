-- Utils/icon_fonts.lua — IconFonts/*.ttf: one file per icon, glyph at U+0041 ("A")

local M = {}

M.ICON_CODEPOINT = 0x41

local function formatIconStem(stem)
    return (stem:gsub("_", " "))
end

--- @param script_path string toolbar script directory (SCRIPT_PATH)
--- @param utils table UTILS (joinPath, ensureDirectoryExists, getFilesInDirectory, normalizeSlashes)
--- @return table[] entries: path, name, display_name, icon_range (single slot U+0041)
function M.scanIconFonts(script_path, utils)
    local icon_fonts_dir = utils.joinPath(script_path, "IconFonts")
    utils.ensureDirectoryExists(icon_fonts_dir)

    local files = utils.getFilesInDirectory(icon_fonts_dir)
    local out = {}
    local c = M.ICON_CODEPOINT

    for _, file in ipairs(files) do
        if file:match("%.ttf$") then
            local stem = file:gsub("%.ttf$", "")
            local font_path = utils.normalizeSlashes("IconFonts/" .. file)
            table.insert(
                out,
                {
                    path = font_path,
                    name = stem,
                    display_name = formatIconStem(stem),
                    icon_range = {{start = c, laFin = c}}
                }
            )
        end
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
