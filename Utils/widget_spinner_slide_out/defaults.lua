-- Utils/widget_spinner_slide_out/defaults.lua

return function()
    local function default_widget_id(spec)
        if spec.widget_id then
            return spec.widget_id
        end
        local id = ""
        for word in (spec.name or "widget"):gmatch("%S+") do
            id = id .. word:sub(1, 1):lower()
        end
        if id == "" then
            id = "w"
        end
        return id
    end

    local function default_preview_ids(modes)
        local ids = {}
        for _, m in ipairs(modes) do
            if m.default_on ~= false then
                ids[#ids + 1] = m.id
            end
        end
        if #ids < 1 and modes[1] then
            ids[1] = modes[1].id
        end
        return ids
    end

    local function default_preview_selected_id(modes)
        for _, m in ipairs(modes) do
            if m.id == "1" then
                return "1"
            end
        end
        for _, m in ipairs(modes) do
            local r = UTILS.asNumber(m.rate, nil)
            if r and math.abs(r - 1.0) < 1e-9 then
                return m.id
            end
        end
        return modes[1] and modes[1].id or "1"
    end

    local function default_readout_width(ctx)
        local samples = { "-24st", "12.5st", "0st" }
        local w = 0
        for _, s in ipairs(samples) do
            local tw = UTILS.asNumber(reaper.ImGui_CalcTextSize(ctx, s), 0)
            w = math.max(w, tw)
        end
        return math.ceil(w + 10)
    end

    return {
        default_widget_id = default_widget_id,
        default_preview_ids = default_preview_ids,
        default_preview_selected_id = default_preview_selected_id,
        default_readout_width = default_readout_width,
    }
end
