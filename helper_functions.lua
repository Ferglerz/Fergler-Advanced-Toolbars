local Helpers = {}

function Helpers.calculateTextWidth(ctx, text, font)
    local max_width = 0
    if font then
        reaper.ImGui_PushFont(ctx, font)
    end
    for line in text:gmatch("[^\n]+") do
        local line_width = reaper.ImGui_CalcTextSize(ctx, line)
        max_width = math.max(max_width, line_width)
    end
    if font then
        reaper.ImGui_PopFont(ctx)
    end
    return max_width
end

Helpers.dump = function(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. Helpers.dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

return Helpers