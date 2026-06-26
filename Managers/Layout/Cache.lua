-- Managers/Layout_Cache.lua
local MAX_LAYOUT_CACHE_ENTRIES = 8
return function(LayoutManager)
function LayoutManager:storeToolbarLayout(cache_key, layout)
    if self.toolbar_layouts[cache_key] then
        for i, key in ipairs(self._layout_cache_order) do
            if key == cache_key then
                table.remove(self._layout_cache_order, i)
                break
            end
        end
    else
        while #self._layout_cache_order >= MAX_LAYOUT_CACHE_ENTRIES do
            local evict = table.remove(self._layout_cache_order, 1)
            if evict then
                self.toolbar_layouts[evict] = nil
            end
        end
    end
    self.toolbar_layouts[cache_key] = layout
    table.insert(self._layout_cache_order, cache_key)
end

function LayoutManager:pruneStaleLayoutCache(eff_w, eff_h, is_vertical)
    local dim_tag = "_" .. eff_w .. "x" .. eff_h .. (is_vertical and "_v" or "_h")
    local keep = {}
    for _, key in ipairs(self._layout_cache_order) do
        if key:find(dim_tag, 1, true) then
            table.insert(keep, key)
        else
            self.toolbar_layouts[key] = nil
        end
    end
    self._layout_cache_order = keep
end

function LayoutManager:ensureTextCache(button)
    return CACHE_UTILS.ensureButtonTextCache(button)
end

function LayoutManager:needsRecalculation(toolbar)
    -- Check if any config parameters that affect layout have changed
    if self.config_changed then
        return true
    end
    
    -- Check if any buttons need layout recalculation
    for _, button in ipairs(toolbar.buttons) do
        if button.layout_dirty then
            return true
        end
    end
    
    -- Check if any groups have invalidated caches
    for _, group in ipairs(toolbar.groups) do
        if not group:getDimensions() then
            return true
        end
    end
    
    return false
end

-- Calculate margins based on orientation
function LayoutManager:invalidateCache()
    -- Drop memoized toolbar layouts: visibility toggles often run during render (after getToolbarLayout),
    -- so force_recalculate alone can be cleared by endFrame before the next layout pass runs.
    self.toolbar_layouts = {}
    self._layout_cache_order = {}
    self.force_recalculate = true
end

-- Call when toolbars finish loading (Load_Toolbar) or after switching the active toolbar.
-- Drops cached layouts so the next getToolbarLayout() recomputes (works even if invalidateCache
-- was cleared by endFrame in the same pass).
function LayoutManager:requestLayoutRecalcAfterToolbarReady()
    self.toolbar_layouts = {}
    self._layout_cache_order = {}
    self.force_recalculate = true
end

function LayoutManager:configChanged()
    self.config_changed = true
end

function LayoutManager:endFrame()
    -- Reset flags at the end of frame
    self.force_recalculate = false
    self.config_changed = false
    self.layout_width_override = nil
    self.layout_height_override = nil
end


end
