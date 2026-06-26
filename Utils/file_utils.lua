-- Utils/file_utils.lua
local M = {}

local StringUtils = require("Utils.string_utils")
local TableUtils = require("Utils.table_utils")

local scan_cache_store = nil
local scan_cache_loaded = false
local scan_cache_source_mtime = nil
local scan_cache_store_dirty = false
local fingerprint_run_cache = {}

function M.scanCachePath()
    if not _G.SCRIPT_PATH then
        return nil
    end
    return StringUtils.joinPath(SCRIPT_PATH, "User/scan_cache.lua")
end

function M.getFileMtime(path)
    if not path then
        return nil
    end
    if reaper and reaper.file_exists and reaper.file_exists(path) == false then
        return nil
    end
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    file:close()
    if reaper.GetFileMetadata then
        local ok, mtime = reaper.GetFileMetadata(path, "mtime")
        if ok and mtime then
            return mtime
        end
    end
    local handle = io.popen(string.format([=[stat -f "%%m" "%s" 2>/dev/null]=], path))
    if handle then
        local line = handle:read("*l")
        handle:close()
        if line and line ~= "" then
            return line
        end
    end
    return nil
end

function M.loadScanCacheStore()
    if scan_cache_loaded then
        return scan_cache_store
    end
    scan_cache_loaded = true
    scan_cache_store = {}
    local path = M.scanCachePath()
    if not path then
        return scan_cache_store
    end
    scan_cache_source_mtime = M.getFileMtime(path)
    local chunk = loadfile(path)
    if chunk then
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then
            scan_cache_store = data
        end
    end
    return scan_cache_store
end

function M.saveScanCacheStore()
    local path = M.scanCachePath()
    if not path or not scan_cache_store then
        return
    end
    M.ensureDirectoryExists(StringUtils.joinPath(SCRIPT_PATH, "User"))
    local serialized = TableUtils.serializeTable(scan_cache_store)
    if not serialized then
        return
    end
    local file = io.open(path, "w")
    if not file then
        return
    end
    file:write("return " .. serialized .. "\n")
    file:close()
    scan_cache_store_dirty = false
    scan_cache_source_mtime = M.getFileMtime(path)
end

function M.tryScanCacheWithoutFingerprint(cache_key)
    if scan_cache_store_dirty then
        return nil
    end
    local path = M.scanCachePath()
    if not path or not scan_cache_source_mtime then
        return nil
    end
    local current_mtime = M.getFileMtime(path)
    if not current_mtime or current_mtime ~= scan_cache_source_mtime then
        return nil
    end
    return M.getScanCacheEntry(cache_key)
end

function M.computeTreeScanFingerprint(root_dir, name_glob)
    root_dir = StringUtils.normalizeSlashes(root_dir)
    name_glob = name_glob or "*"
    local cache_key = root_dir .. "\0" .. name_glob
    if fingerprint_run_cache[cache_key] then
        return fingerprint_run_cache[cache_key]
    end
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
            [=[find "%s" -name "%s" -type f -print0 2>/dev/null | xargs -0 stat -f "%%m" 2>/dev/null | awk 'BEGIN{c=0;m=0} {c++; if($1+0>m)m=$1+0} END{printf "%%d:%%.0f", c, m}']=],
            root_dir,
            name_glob
        )
    end
    local handle = io.popen(cmd)
    if handle then
        local line = handle:read("*l")
        handle:close()
        if line and line:match("^%d+:") then
            local fp = line:gsub("\r", "")
            fingerprint_run_cache[cache_key] = fp
            return fp
        end
    end
    return nil
end

function M.getScanCacheEntry(key)
    local store = M.loadScanCacheStore()
    local entry = store[key]
    if type(entry) == "table" and type(entry.fingerprint) == "string" then
        return entry
    end
    return nil
end

function M.setScanCacheEntry(key, fingerprint, payload)
    if not key or not fingerprint then
        return
    end
    local store = M.loadScanCacheStore()
    store[key] = {
        fingerprint = fingerprint,
        payload = payload
    }
    scan_cache_store_dirty = true
    M.saveScanCacheStore()
end

function M.collectLuaFilesRecursive(root_dir)
    root_dir = StringUtils.normalizeSlashes(root_dir)
    local out = {}

    local function scan(dir)
        local i = 0
        while true do
            local file = reaper.EnumerateFiles(dir, i)
            if not file then break end
            if file:lower():match("%.lua$") then
                table.insert(out, StringUtils.normalizeSlashes(dir .. "/" .. file))
            end
            i = i + 1
        end

        i = 0
        while true do
            local sub = reaper.EnumerateSubdirectories(dir, i)
            if not sub then break end
            if sub ~= "." and sub ~= ".." then
                scan(dir .. "/" .. sub)
            end
            i = i + 1
        end
    end

    scan(root_dir)
    table.sort(out)
    return out
end

function M.getFilesInDirectory(directory)
    local files = {}

    if reaper.GetOS():match("Win") then
        local cmd = 'dir /b "' .. directory:gsub("/", "\\") .. '"'
        local handle = io.popen(cmd)
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    else
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

function M.ensureDirectoryExists(path)
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

return M
