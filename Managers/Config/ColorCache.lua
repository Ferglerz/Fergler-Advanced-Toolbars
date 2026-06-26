-- Managers/Config_ColorCache.lua
local DEFAULT_CACHE_MISS_COLOR = "#FF0000FF"
return function(ConfigManager)
local DEFAULT_CACHE_MISS_COLOR = "#FF0000FF"

local function normalizeColorPathKeys(path)
    if type(path) == "string" then
        local keys = {}
        for key in path:gmatch("[^%.]+") do
            table.insert(keys, key)
        end
        return keys
    elseif type(path) == "table" then
        return path
    end
    return nil
end

-- Leaf value at dot/table path, or nil if any segment missing.
local function colorValueAtKeys(root, keys)
    if type(root) ~= "table" or type(keys) ~= "table" then
        return nil
    end
    local cur = root
    for _, key in ipairs(keys) do
        if type(cur) ~= "table" or cur[key] == nil then
            return nil
        end
        cur = cur[key]
    end
    return cur
end

-- Pre-convert all config colors to ImGui format for performance
function ConfigManager:cacheColors()
    if not _G.CONFIG or not _G.CONFIG.COLORS then
        return
    end

    -- Clear existing cache
    self.cached_colors = {}

    -- Function to recursively cache colors in a table
    local function cacheColorTable(source, target)
        for key, value in pairs(source) do
            if type(value) == "table" then
                target[key] = {}
                cacheColorTable(value, target[key])
            elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x%x?%x?$") then
                -- Convert hex color to ImGui format
                target[key] = COLOR_UTILS.toImGuiColor(value)
            else
                target[key] = value
            end
        end
    end

    -- Cache all colors from CONFIG.COLORS
    cacheColorTable(_G.CONFIG.COLORS, self.cached_colors)
end

-- Get cached ImGui color (fallback to conversion if not cached)
-- Accepts either a dot-separated string path (e.g., "GROUP.LABEL") or a table path (e.g., {"GROUP", "LABEL"})
function ConfigManager:getCachedColor(path)
    local keys = normalizeColorPathKeys(path)
    if not keys then
        return COLOR_UTILS.toImGuiColor(DEFAULT_CACHE_MISS_COLOR)
    end

    local cached = colorValueAtKeys(self.cached_colors, keys)
    if cached ~= nil then
        return cached
    end

    local original = colorValueAtKeys(_G.CONFIG and _G.CONFIG.COLORS, keys)
    if original == nil then
        return COLOR_UTILS.toImGuiColor(DEFAULT_CACHE_MISS_COLOR)
    end
    return COLOR_UTILS.toImGuiColor(original)
end

-- Convenience method for getting cached color with safe fallback
-- Returns the cached color if available, otherwise converts from CONFIG
function ConfigManager:getCachedColorSafe(...)
    local keys = {...}
    if #keys == 0 then
        return nil
    end

    local cached = colorValueAtKeys(self.cached_colors, keys)
    if cached ~= nil then
        return cached
    end

    local original = colorValueAtKeys(_G.CONFIG and _G.CONFIG.COLORS, keys)
    if original == nil then
        return nil
    end
    if type(original) == "string" then
        return COLOR_UTILS.toImGuiColor(original)
    end
    return original
end

--- Cached theme color with CONFIG.COLORS fallback (replaces getCachedColorSafe(...) or toImGuiColor(...) at call sites).
function ConfigManager:color(...)
    local keys = {...}
    local cached = self:getCachedColorSafe(table.unpack(keys))
    if cached ~= nil then
        return cached
    end
    local original = colorValueAtKeys(_G.CONFIG and _G.CONFIG.COLORS, keys)
    if original == nil then
        return nil
    end
    return COLOR_UTILS.toImGuiColor(original)
end


end
