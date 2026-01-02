-- Utils/cache_utils.lua
-- Utility functions for cache initialization and management

local CacheUtils = {}

-- Ensure a button has a cache table initialized
function CacheUtils.ensureButtonCache(button)
    if not button.cache then
        button.cache = {}
    end
    return button.cache
end

-- Ensure a button has a specific cache sub-table initialized
function CacheUtils.ensureButtonCacheSubtable(button, subtable_name)
    local cache = CacheUtils.ensureButtonCache(button)
    if not cache[subtable_name] then
        cache[subtable_name] = {}
    end
    return cache[subtable_name]
end

-- Ensure a group has a cache table initialized
function CacheUtils.ensureGroupCache(group)
    if not group.cache then
        group.cache = {}
    end
    return group.cache
end

-- Ensure a group has a specific cache sub-table initialized
function CacheUtils.ensureGroupCacheSubtable(group, subtable_name)
    local cache = CacheUtils.ensureGroupCache(group)
    if not cache[subtable_name] then
        cache[subtable_name] = {}
    end
    return cache[subtable_name]
end

return CacheUtils

