-- Utils/utils.lua
local utils = {}

-- String operations
function utils.stripNewLines(text)
    return text:gsub("[\n\r]", " ")
end

-- Toolbar menu line: item_N=id optional_label — same pattern in INI templates and runtime parse.
function utils.parseToolbarItemLine(line)
    if type(line) ~= "string" then
        return nil, nil, nil
    end
    return line:match("^item_(%d+)=(%S+)%s*(.*)$")
end

--- Inverse of parseToolbarItemLine: 0-based item index, action id, optional label.
function utils.formatToolbarItemLine(index0, id, text)
    id = tostring(id or "")
    if id == "-1" then
        return string.format("item_%d=%s", index0, id)
    end
    text = text ~= nil and tostring(text) or ""
    if text == "" then
        return string.format("item_%d=%s", index0, id)
    end
    return string.format("item_%d=%s %s", index0, id, text)
end

function utils.matchIniSectionHeader(line)
    if type(line) ~= "string" then
        return nil
    end
    return line:match("^%[(.+)%]$")
end

--- Parse reaper-menu-style toolbar template sections (title, default, icons, items).
function utils.parseIniToolbars(content)
    local toolbars = {}
    local current = nil

    if type(content) ~= "string" or content == "" then
        return toolbars
    end

    local function pushCurrent()
        if current then
            table.insert(toolbars, current)
        end
    end

    for line in content:gmatch("[^\r\n]+") do
        local section_name = utils.matchIniSectionHeader(line)
        if section_name then
            pushCurrent()
            current = {
                section = section_name,
                title = nil,
                default = nil,
                icons = {},
                items = {}
            }
        elseif current then
            local _, id, text = utils.parseToolbarItemLine(line)
            if id then
                table.insert(current.items, { id = id, text = text or "" })
            else
                local default_val = line:match("^default=(.*)$")
                if default_val ~= nil then
                    current.default = default_val
                else
                    local icon_idx, icon_val = line:match("^icon_(%d+)=(.*)$")
                    if icon_idx and icon_val ~= nil then
                        current.icons[tonumber(icon_idx)] = icon_val
                    else
                        local title_val = line:match("^title=(.*)$")
                        if title_val ~= nil then
                            current.title = title_val
                        end
                    end
                end
            end
        end
    end

    pushCurrent()
    return toolbars
end

--- Coerce API/ImGui values: numbers (reject NaN), strings via tonumber, else default.
function utils.asNumber(v, default)
    local ty = type(v)
    if ty == "number" then
        if v ~= v then
            return default
        end
        return v
    end
    if ty == "string" then
        return tonumber(v) or default
    end
    return default
end

--- Slider/knob: clamped 01 position plus range and bounds (min/max from widget or 0/1).
function utils.widgetSliderNormalized(widget)
    local min_v = widget.min_value or 0
    local max_v = widget.max_value or 1
    local range = max_v - min_v
    local normalized = range ~= 0 and ((widget.value or 0) - min_v) / range or 0
    normalized = math.max(0, math.min(1, normalized))
    return normalized, range, min_v, max_v
end

--- Safe string.format for display; falls back to tostring on mismatch.
function utils.safeFormat(fmt, value)
    local ok, result = pcall(string.format, fmt or "%s", value)
    if ok then
        return result
    end
    return tostring(value)
end

function utils.formatFontName(name)
    return name:gsub("_[0-9]+$", ""):gsub("_", " ")
end

function utils.getSafeFilename(str)
    -- Replace characters that are problematic in filenames with underscores
    return str:gsub('[%/\\%:%*%?%"<>%|]', "_")
end

function utils.normalizeSlashes(path)
    return (path:gsub("\\", "/"))
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
-- File-tree scan cache (mtime fingerprint); avoids full find/metadata work when unchanged between runs.
local scan_cache_store = nil
local scan_cache_loaded = false

local function scanCachePath()
    if not _G.SCRIPT_PATH then
        return nil
    end
    return utils.joinPath(SCRIPT_PATH, "User/scan_cache.lua")
end

local function loadScanCacheStore()
    if scan_cache_loaded then
        return scan_cache_store
    end
    scan_cache_loaded = true
    scan_cache_store = {}
    local path = scanCachePath()
    if not path then
        return scan_cache_store
    end
    local chunk = loadfile(path)
    if chunk then
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then
            scan_cache_store = data
        end
    end
    return scan_cache_store
end

local function saveScanCacheStore()
    local path = scanCachePath()
    if not path or not scan_cache_store then
        return
    end
    if _G.UTILS and UTILS.ensureDirectoryExists then
        UTILS.ensureDirectoryExists(utils.joinPath(SCRIPT_PATH, "User"))
    end
    local serialized = utils.serializeTable(scan_cache_store)
    if not serialized then
        return
    end
    local file = io.open(path, "w")
    if not file then
        return
    end
    file:write("return " .. serialized .. "\n")
    file:close()
end

--- @return string fingerprint "count:max_mtime"
function utils.computeTreeScanFingerprint(root_dir, name_glob)
    root_dir = utils.normalizeSlashes(root_dir)
    name_glob = name_glob or "*"
    local count = 0
    local max_mtime = 0
    local cmd
    if reaper.GetOS():match("Win") then
        local win_path = root_dir:gsub("/", "\\")
        cmd = string.format(
            [=[powershell -NoProfile -Command "$m=0;$c=0;Get-ChildItem -LiteralPath '%s' -Recurse -Filter '%s' -File -ErrorAction SilentlyContinue | ForEach-Object { $c++; if ($_.LastWriteTimeUtc.Ticks -gt $m) { $m = $_.LastWriteTimeUtc.Ticks } }; Write-Output (\"$c:$m\")"]=],
            win_path:gsub("'", "''"),
            name_glob
        )
    else
        cmd = string.format(
            [=[find "%s" -name "%s" -type f -exec stat -f "%%m" {} \; 2>/dev/null | awk 'BEGIN{c=0;m=0} {c++; if($1+0>m)m=$1+0} END{printf "%%d:%%.0f", c, m}']=],
            root_dir,
            name_glob
        )
    end
    local handle = io.popen(cmd)
    if handle then
        local line = handle:read("*l")
        handle:close()
        if line and line:match("^%d+:") then
            return line:gsub("\r", "")
        end
    end
    return nil
end

function utils.getScanCacheEntry(key)
    local store = loadScanCacheStore()
    local entry = store[key]
    if type(entry) == "table" and type(entry.fingerprint) == "string" then
        return entry
    end
    return nil
end

function utils.setScanCacheEntry(key, fingerprint, payload)
    if not key or not fingerprint then
        return
    end
    local store = loadScanCacheStore()
    store[key] = {
        fingerprint = fingerprint,
        payload = payload
    }
    saveScanCacheStore()
end

-- All .lua files under root (recursive). Used for widget discovery; basename is the widget key.
function utils.collectLuaFilesRecursive(root_dir)
    root_dir = utils.normalizeSlashes(root_dir)
    local fp = utils.computeTreeScanFingerprint(root_dir, "*.lua")
    local cached = utils.getScanCacheEntry("widgets:" .. root_dir)
    if fp and cached and cached.fingerprint == fp and type(cached.payload) == "table" then
        return cached.payload
    end

    local out = {}
    local cmd
    if reaper.GetOS():match("Win") then
        local win_path = root_dir:gsub("/", "\\")
        cmd = string.format('cmd /c dir /s /b "%s\\*.lua"', win_path)
    else
        cmd = string.format('find "%s" -name "*.lua" -type f 2>/dev/null', root_dir)
    end
    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            line = (line or ""):gsub("\r$", "")
            if line ~= "" and line:lower():match("%.lua$") then
                table.insert(out, utils.normalizeSlashes(line))
            end
        end
        handle:close()
    end
    table.sort(out)
    if fp then
        utils.setScanCacheEntry("widgets:" .. root_dir, fp, out)
    end
    return out
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

-- Prevent floating windows from drifting off the left/top edges.
function utils.snapWindowToMinimum(ctx, min_x, min_y, undocked_only)
    if not ctx then
        return false
    end

    min_x = tonumber(min_x) or 0
    min_y = tonumber(min_y) or 0

    if undocked_only then
        local dock_id = reaper.ImGui_GetWindowDockID(ctx)
        if dock_id and dock_id ~= 0 then
            return false
        end
    end

    local x, y = reaper.ImGui_GetWindowPos(ctx)
    local target_x = x
    local target_y = y

    if x < min_x then
        target_x = min_x
    end
    if y < min_y then
        target_y = min_y
    end

    if target_x ~= x or target_y ~= y then
        reaper.ImGui_SetWindowPos(ctx, target_x, target_y)
        return true
    end

    return false
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

-- REAPER track gain (D_VOL) and peak samples: linear amplitude to dBFS-style dB
function utils.linearGainToDb(gain)
    if not gain or gain <= 0 then
        return -150
    end
    return 20 * math.log(gain, 10)
end

function utils.dbToLinearGain(db)
    return 10 ^ (db / 20)
end

function utils.getSelectedTrackVolumeDb()
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        return nil
    end
    local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
    return utils.linearGainToDb(vol)
end

-- Peak envelope linear sample (e.g. Track_GetPeakInfo); floor when silent
function utils.peakLinearToDb(linear, floor_db)
    floor_db = floor_db or -60
    if not linear or linear <= 0 then
        return floor_db
    end
    return 20 * math.log(linear, 10)
end

-- Stable id string for current selected media items (session pointer ids)
function utils.hashSelectedMediaItems()
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then
        return "empty"
    end
    local parts = {}
    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(parts, tostring(item))
    end
    return table.concat(parts, ",")
end

-- Run scan_fn(widget) at most once per widget.update_interval (or interval override)
function utils.throttleScan(widget, last_time_key, scan_fn)
    local interval = widget.update_interval
    if interval == nil then
        interval = 1
    end
    local now = reaper.time_precise()
    local last = widget[last_time_key]
    if not last or (now - last) > interval then
        scan_fn(widget)
        widget[last_time_key] = now
    end
end

return utils