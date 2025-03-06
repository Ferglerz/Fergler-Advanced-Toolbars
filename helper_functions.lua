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

-- Font name handling
function Helpers.getBaseFontName(path)
    -- Extract base font name without numeric suffix for comparison
    local name = path:match("([^/]+)%.ttf$") or path
    return name:gsub("_[0-9]+$", "")
end

function Helpers.formatFontName(name)
    -- Remove _XX numbers at the end of font names and convert _ to spaces
    return name:gsub("_[0-9]+$", ""):gsub("_", " ")
end

-- Font matching that is resilient to numeric suffix changes
function Helpers.matchFontByBaseName(base_name, font_maps)
    if not base_name or not font_maps then return nil end
    
    for i, font_map in ipairs(font_maps) do
        local font_base_name = Helpers.getBaseFontName(font_map.path)
        if font_base_name == base_name then
            return i, font_map
        end
    end
    
    return nil
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

Helpers.stripNewLines = function(text)
    return text:gsub("[\n\r]", " ")
end

return Helpers