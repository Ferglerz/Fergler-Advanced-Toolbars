local function collect_lua_files(dir, out)
    out = out or {}
    -- Files
    local i = 0
    while true do
        local file = reaper.EnumerateFiles(dir, i)
        if not file then break end
        if file:lower():match("%.lua$") then
            table.insert(out, dir .. "/" .. file)
        end
        i = i + 1
    end
    -- Subdirectories
    i = 0
    while true do
        local sub = reaper.EnumerateSubdirectories(dir, i)
        if not sub then break end
        if sub ~= "." and sub ~= ".." then
            collect_lua_files(dir .. "/" .. sub, out)
        end
        i = i + 1
    end
    return out
end
