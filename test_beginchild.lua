local ctx = reaper.ImGui_CreateContext('test')
local function loop()
    local rv, open = reaper.ImGui_Begin(ctx, 'test', true)
    if rv then
        local child_rv = reaper.ImGui_BeginChild(ctx, 'child', 0, 0)
        reaper.ImGui_EndChild(ctx)
        reaper.ImGui_End(ctx)
    end
    if open then reaper.defer(loop) end
end
reaper.defer(loop)
