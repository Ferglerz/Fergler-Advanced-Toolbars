-- Create a new general_utils.lua file
local GeneralUtils = {}

function GeneralUtils.tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function GeneralUtils.getFilesInDirectory(directory, reaper)
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

-- Path normalization function
function GeneralUtils.normalizePath(path)
    return path:gsub("\\", "/")
end

-- Safe callback execution with error handling
function GeneralUtils.safeCall(callback, ...)
    local success, result = pcall(callback, ...)
    if not success then
        reaper.ShowConsoleMsg("Error: " .. tostring(result) .. "\n")
        return nil
    end
    return result
end

return GeneralUtils