-- Utils/icon_fonts.lua — single source of truth for IconFonts/*.ttf discovery

local M = {}

--- Per-icon pipeline (fontTools) maps the glyph to U+0041; Reaper buttons use "A".
M.PER_ICON_CODEPOINT = 0x41

--- Legacy category fonts: glyphs from U+00C0 (À) for N code points (filename *_N.ttf).
M.LEGACY_START_CODE = 0xC0

--- True if filename uses the legacy `Stem_<count>.ttf` convention (count is digits only before .ttf).
function M.isLegacyFilename(file)
    return file:match("^(.+)_(%d+)%.ttf$") ~= nil
end

--- @param script_path string toolbar script directory (SCRIPT_PATH)
--- @param utils table UTILS (joinPath, ensureDirectoryExists, getFilesInDirectory, normalizeSlashes, formatFontName)
--- @return table[] entries: path, name, display_name, icon_range, kind ("legacy" | "per_icon")
function M.scanIconFonts(script_path, utils)
    local icon_fonts_dir = utils.joinPath(script_path, "IconFonts")
    utils.ensureDirectoryExists(icon_fonts_dir)

    local files = utils.getFilesInDirectory(icon_fonts_dir)
    local out = {}

    for _, file in ipairs(files) do
        if file:match("%.ttf$") then
            local stem = file:gsub("%.ttf$", "")
            local font_path = utils.normalizeSlashes("IconFonts/" .. file)
            local count = tonumber(file:match("_(%d+)%.ttf$"))

            if count and M.isLegacyFilename(file) then
                local start_code = M.LEGACY_START_CODE
                local end_code = math.min(start_code + count - 1, 0x10FFFF)
                table.insert(
                    out,
                    {
                        path = font_path,
                        name = stem,
                        display_name = utils.formatFontName(stem),
                        icon_range = {{start = start_code, laFin = end_code}},
                        kind = "legacy"
                    }
                )
            else
                local c = M.PER_ICON_CODEPOINT
                table.insert(
                    out,
                    {
                        path = font_path,
                        name = stem,
                        display_name = utils.formatFontName(stem),
                        icon_range = {{start = c, laFin = c}},
                        kind = "per_icon"
                    }
                )
            end
        end
    end

    table.sort(
        out,
        function(a, b)
            if a.kind ~= b.kind then
                return a.kind == "legacy"
            end
            return (a.display_name or ""):lower() < (b.display_name or ""):lower()
        end
    )

    return out
end

return M
