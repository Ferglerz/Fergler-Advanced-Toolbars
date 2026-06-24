local file = io.open("imgui_api_dump.txt", "w")
for k, v in pairs(reaper) do
    if type(v) == "function" and k:match("^ImGui_") then
        if k:match("Key") or k:match("Pass") or k:match("Focus") or k:match("Input") then
            file:write(k .. "\n")
        end
    end
end
file:close()
