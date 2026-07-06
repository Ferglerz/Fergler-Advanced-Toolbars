-- Utils/file_utils.lua
local M = {}

local StringUtils = require("Utils.Core.string_utils")

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
