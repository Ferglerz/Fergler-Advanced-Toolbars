-- Utils/utils.lua
local utils = {}

-- String operations
function utils.stripNewLines(text)
    return text:gsub("[\n\r]", " ")
end

function utils.formatFontName(name)
    return name:gsub("_[0-9]+$", ""):gsub("_", " ")
end

function utils.getBaseFontName(path)
    local name = path:match("([^/]+)%.ttf$") or path
    return name:gsub("_[0-9]+$", "")
end

function utils.getSafeFilename(str)
    -- Replace characters that are problematic in filenames with underscores
    return str:gsub('[%/\\%:%*%?%"<>%|]', "_")
end

function utils.normalizeSlashes(path)
    return path:gsub("\\", "/")
end

function utils.joinPath(...)
    local separator = reaper.GetOS():match("Win") and "\\" or "/"
    local result = ""

    for i, part in ipairs({...}) do
        if i > 1 and not result:match("[\\/]$") and not part:match("^[\\/]") then
            result = result .. separator
        end
        result = result .. part
    end

    return result
end

-- Table operations
function utils.tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function utils.dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. utils.dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

function utils.serializeValue(value, indent)
    if value == nil then
        return "nil"
    elseif type(value) == "table" then
        return utils.serializeTable(value, indent)
    elseif type(value) == "string" then
        return string.format('"%s"', value:gsub('"', '\\"'):gsub("\n", "\\n"))
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    else
        return string.format('"%s"', tostring(value))
    end
end

function utils.serializeTable(tbl, indent)
    indent = indent or "    "
    local parts = {}

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(
        keys,
        function(a, b)
            return tostring(a) < tostring(b)
        end
    )

    for _, key in ipairs(keys) do
        local value = tbl[key]
        -- Use simple key format if possible
        local key_str
        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            key_str = key
        elseif type(key) == "number" then
            -- For numeric keys, use array-style indexing
            key_str = "[" .. key .. "]"
        else
            key_str = '["' .. tostring(key) .. '"]'
        end

        local value_str = utils.serializeValue(value, indent .. "    ")
        table.insert(parts, indent .. key_str .. " = " .. value_str)
    end

    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent:sub(1, -5) .. "}"
end

-- Other utilities
function utils.matchFontByBaseName(base_name, font_maps)
    if not base_name or not font_maps then
        return nil
    end

    for i, font_map in ipairs(font_maps) do
        local font_base_name = utils.getBaseFontName(font_map.path)
        if font_base_name == base_name then
            return i, font_map
        end
    end

    return nil
end

function utils.getFilesInDirectory(directory)
    local files = {}

    if reaper.GetOS():match("Win") then
        -- Windows
        local cmd = 'dir /b "' .. directory:gsub("/", "\\") .. '"'
        local handle = io.popen(cmd)
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    else
        -- macOS/Linux
        local cmd = 'ls -1 "' .. directory .. '"'
        local handle = io.popen(cmd)
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    end

    return files
end

function utils.safeCall(callback, ...)
    local success, result = pcall(callback, ...)
    if not success then
        reaper.ShowConsoleMsg("Error: " .. tostring(result) .. "\n")
        return nil
    end
    return result
end

function utils.applyScrollOffset(ctx, x, y)
    if not ctx then
        return x, y
    end

    local scroll_x = reaper.ImGui_GetScrollX(ctx)
    local scroll_y = reaper.ImGui_GetScrollY(ctx)

    return x - scroll_x, y - scroll_y
end

function utils.focusArrangeWindow(force_delay)
    local function delayedFocus()
        reaper.SetCursorContext(1)
    end

    if force_delay then
        reaper.defer(
            function()
                reaper.defer(delayedFocus)
            end
        )
    else
        delayedFocus()
    end

    return true
end

function utils.ensureDirectoryExists(path)
    local ok, _, code = os.rename(path, path)
    local exists = ok or code == 13  -- 13 = permission denied (but exists)

    if not exists then
        local result = reaper.RecursiveCreateDirectory(path, 0)
        if result == 0 then
            reaper.ShowConsoleMsg("Failed to create directory: " .. path .. "\n")
            return false
        end
    end

    return true
end

return utils