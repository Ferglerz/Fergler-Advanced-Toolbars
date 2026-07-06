-- Utils/Core/reaper_png_icon_scan.lua — shared PNG basename scan for REAPER icon folders.

local M = {}

local SCAN_SUBDIRS = {"", "150", "200"}

function M.displayNameFromBasename(basename, strip_prefix)
    local stem = basename:gsub("%.png$", ""):gsub("%.PNG$", "")
    if strip_prefix then
        stem = stem:gsub(strip_prefix, "")
    end
    local words = {}
    for word in stem:gmatch("[^_]+") do
        table.insert(words, word:sub(1, 1):upper() .. word:sub(2):lower())
    end
    if #words == 0 then
        return basename
    end
    return table.concat(words, " ")
end

function M.collectPngBasenames(icons_dir, should_skip)
    local seen = {}
    local names = {}

    local function scan_subdir(sub)
        local dir = icons_dir
        if sub ~= "" then
            dir = icons_dir .. "/" .. sub
        end
        if not reaper.file_exists(dir) then
            return
        end
        local i = 0
        while true do
            local file = reaper.EnumerateFiles(dir, i)
            if not file then
                break
            end
            if file:lower():match("%.png$") and not seen[file] and (not should_skip or not should_skip(file)) then
                seen[file] = true
                table.insert(names, file)
            end
            i = i + 1
        end
    end

    for _, sub in ipairs(SCAN_SUBDIRS) do
        scan_subdir(sub)
    end
    table.sort(names)
    return names
end

--- @return table[] entries: path (basename), name, display_name
function M.buildSortedEntries(basenames, display_name_from_basename)
    local out = {}

    for _, basename in ipairs(basenames) do
        table.insert(
            out,
            {
                path = basename,
                name = basename:gsub("%.png$", ""):gsub("%.PNG$", ""),
                display_name = display_name_from_basename(basename),
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
