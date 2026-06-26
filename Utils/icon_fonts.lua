-- Utils/icon_fonts.lua — per-icon .ttf under IconFonts/ (glyph at U+0041). Skips _source_archive/.

local M = {}

M.ICON_CODEPOINT = 0x41

local function formatCategoryLabel(name)
    return (name:gsub("_", " "))
end

--- @param rel_stem path without .ttf, e.g. icons/Tools/U00C0
local function categoryAndDisplayFromStem(rel_stem)
    local parts = {}
    for p in rel_stem:gmatch("[^/]+") do
        table.insert(parts, p)
    end

    if #parts >= 1 and parts[1] == "icons" and #parts >= 3 then
        table.remove(parts, 1)
        local category = parts[1]
        local last = table.remove(parts)
        local uhex = last and last:match("^U(%x+)$")
        if uhex then
            return category, formatCategoryLabel(category) .. " · U+" .. uhex
        end
        return category, formatCategoryLabel(rel_stem:gsub("/", " "))
    end

    if #parts >= 2 then
        local category = parts[1]
        local last = table.remove(parts)
        local uhex = last and last:match("^U(%x+)$")
        if uhex then
            return category, formatCategoryLabel(category) .. " · U+" .. uhex
        end
    end

    return nil, formatCategoryLabel(rel_stem:gsub("/", " "))
end

local function shouldSkipRelativeTtf(rel)
    return rel:match("^_source_archive/") ~= nil
end

--- @param icon_fonts_dir absolute path to IconFonts folder
--- @param utils UTILS
--- @return string[] relative paths from IconFonts/ (posix slashes)
local function collectTtfRelativePaths(icon_fonts_dir, utils, fp_override)
    local norm_root = utils.normalizeSlashes(icon_fonts_dir)
    local fp = fp_override or utils.computeTreeScanFingerprint(norm_root, "*.ttf")
    local cached = utils.getScanCacheEntry("icon_fonts:" .. norm_root)
    if fp and cached and cached.fingerprint == fp and type(cached.payload) == "table" then
        return cached.payload
    end

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
        for line_raw in handle:lines() do
            local line = utils.normalizeSlashes((line_raw or ""):gsub("\r$", ""))
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
    if fp then
        utils.setScanCacheEntry("icon_fonts:" .. norm_root, fp, results)
    end
    return results
end

--- @param script_path string toolbar script directory (SCRIPT_PATH)
--- @param utils table UTILS (joinPath, ensureDirectoryExists, normalizeSlashes)
--- @return table[] entries: path, name, display_name, category, icon_range
function M.scanIconFonts(script_path, utils)
    local icon_fonts_dir = utils.joinPath(script_path, "IconFonts")
    utils.ensureDirectoryExists(icon_fonts_dir)

    local norm_root = utils.normalizeSlashes(icon_fonts_dir)
    local cache_key = "icon_fonts_scan:" .. norm_root
    local cached = utils.tryScanCacheWithoutFingerprint(cache_key)
    if cached and type(cached.payload) == "table" and type(cached.payload.entries) == "table" then
        M.path_index = cached.payload.path_index or {}
        return cached.payload.entries
    end

    local fp = utils.computeTreeScanFingerprint(norm_root, "*.ttf")
    cached = utils.getScanCacheEntry(cache_key)
    if fp and cached and cached.fingerprint == fp and type(cached.payload) == "table" and type(cached.payload.entries) == "table" then
        M.path_index = cached.payload.path_index or {}
        return cached.payload.entries
    end

    local rel_paths = collectTtfRelativePaths(icon_fonts_dir, utils, fp)
    local out = {}
    local c = M.ICON_CODEPOINT

    for _, rel in ipairs(rel_paths) do
        local stem = rel:gsub("%.ttf$", "")
        local font_path = utils.normalizeSlashes("IconFonts/" .. rel)
        local category, display_name = categoryAndDisplayFromStem(stem)
        table.insert(
            out,
            {
                path = font_path,
                name = stem,
                display_name = display_name,
                category = category or "Other",
                icon_range = {{start = c, laFin = c}}
            }
        )
    end

    table.sort(
        out,
        function(a, b)
            local ca = a.category:lower()
            local cb = b.category:lower()
            if ca ~= cb then
                return ca < cb
            end
            return (a.display_name or ""):lower() < (b.display_name or ""):lower()
        end
    )

    M.path_index = {}
    for i, entry in ipairs(out) do
        M.path_index[utils.normalizeSlashes(entry.path)] = i
    end

    if fp then
        utils.setScanCacheEntry(
            "icon_fonts_scan:" .. norm_root,
            fp,
            { entries = out, path_index = M.path_index }
        )
    end

    return out
end

local _toolbar_icon_cache = {}
local _toolbar_icon_rev

--- Cached toolbar icon font resolve. rel_path e.g. "icons/Math and Code/Plus.ttf"
function M.resolveToolbarIcon(rel_path)
    local rev = _G._adv_tb_icon_font_rev or 0
    if _toolbar_icon_rev ~= rev then
        _toolbar_icon_rev = rev
        _toolbar_icon_cache = {}
    end
    local cached = _toolbar_icon_cache[rel_path]
    if cached ~= nil then
        return cached
    end

    local resolved = { use_icons = false }
    if not SCRIPT_PATH or SCRIPT_PATH == "" or not C or not C.ButtonContent then
        _toolbar_icon_cache[rel_path] = resolved
        return resolved
    end

    local norm = UTILS.normalizeSlashes("IconFonts/" .. rel_path)
    local abs = UTILS.joinPath(SCRIPT_PATH, norm)
    if not reaper.file_exists(abs) then
        _toolbar_icon_cache[rel_path] = resolved
        return resolved
    end

    local f = C.ButtonContent:loadIconFont(norm)
    if not f then
        _toolbar_icon_cache[rel_path] = resolved
        return resolved
    end

    resolved = { use_icons = true, font = f }
    _toolbar_icon_cache[rel_path] = resolved
    return resolved
end

return M
