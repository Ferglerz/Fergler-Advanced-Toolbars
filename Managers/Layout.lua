-- Managers/Layout.lua

local widgetTitle = require("Utils.widget_title")

local LayoutManager = {}
LayoutManager.__index = LayoutManager

local MAX_LAYOUT_CACHE_ENTRIES = 8

function LayoutManager.new()
    local self = setmetatable({}, LayoutManager)
    
    -- Cache for toolbar layouts (LRU via _layout_cache_order)
    self.toolbar_layouts = {}
    self._layout_cache_order = {}
    self._drag_ghost_scratch = nil
    
    -- Flags to track when recalculation is needed
    self.config_changed = false
    self.force_recalculate = false
    
    -- Window dimension cache
    self.last_window_width = 0
    self.last_window_height = 0
    self.last_orientation_vertical = false
    self.layout_width_override = nil
    self.layout_height_override = nil
    self._imgui_window_width = 0
    self._imgui_window_height = 0
    self.last_layout_eff_w = 0
    self.last_layout_eff_h = 0
    
    return self
end

function LayoutManager:getToolbarLayout(toolbar_id, toolbar, opts)
    opts = opts or {}
    local window_width = 0
    local window_height = 0

    if self.ctx then
        window_width = reaper.ImGui_GetWindowWidth(self.ctx)
        window_height = reaper.ImGui_GetWindowHeight(self.ctx)
    end

    -- Split + orientation use main toolbar window, not row/column child dimensions.
    local layout_win_w = opts.main_window_width or window_width
    local layout_win_h = opts.main_window_height or window_height
    self._imgui_window_width = layout_win_w
    self._imgui_window_height = layout_win_h

    local is_vertical
    if opts.toolbar_vertical ~= nil then
        is_vertical = opts.toolbar_vertical == true
    elseif opts.force_horizontal then
        is_vertical = false
    else
        is_vertical = layout_win_w > 0 and layout_win_h > 0 and layout_win_w < layout_win_h
    end
    self.is_vertical = is_vertical

    self.layout_width_override = opts.width_override
    self.layout_height_override = opts.height_override
    self._layout_editing_mode = opts.editing_mode == true
    
    local eff_w = opts.width_override ~= nil and opts.width_override or layout_win_w
    local eff_h = opts.height_override ~= nil and opts.height_override or layout_win_h
    
    local section_key = (toolbar and toolbar.section) and tostring(toolbar.section) or ""
    local ui = CONFIG and CONFIG.UI or {}
    local wt_h = ui.SHOW_WIDGET_TITLES_HORIZONTAL == true and "1" or "0"
    local wt_v = ui.SHOW_WIDGET_TITLES_VERTICAL ~= false and "1" or "0"
    -- Create cache key that includes effective dimensions and active toolbar section (NO SCROLL POSITION)
    local cache_key = toolbar_id .. "_" .. section_key .. "_" .. eff_w .. "x" .. eff_h .. (is_vertical and "_v" or "_h") .. (self._layout_editing_mode and "_gl" or "") .. "_wt" .. wt_h .. wt_v
    
    -- Widget sizes change with live ctx measurements (width/height reflow on resize).
    -- Always recompute; memo key is for LRU eviction only.
    self.last_window_width = layout_win_w
    self.last_window_height = layout_win_h
    self.last_layout_eff_w = eff_w
    self.last_layout_eff_h = eff_h
    self.last_orientation_vertical = is_vertical
    self:pruneStaleLayoutCache(eff_w, eff_h, is_vertical)

    local layout = self:calculateToolbarLayout(toolbar)
    self:storeToolbarLayout(cache_key, layout)

    return layout
end


require("Managers.Layout.Math")(LayoutManager)
require("Managers.Layout.Cache")(LayoutManager)
require("Managers.Layout.Ghost")(LayoutManager)
function LayoutManager:setContext(ctx)
    self.ctx = ctx
end

return LayoutManager

