-- Systems/Interactions/preset_browser/preset_browser_panel_layout.lua
local Tree = require("Systems.Interactions.preset_browser.preset_browser_tree")

local M = {}

function M.safeCall(fn, ...)
    return pcall(fn, ...)
end

function M.parentForPanel(self, root, panel_index)
    if panel_index <= 1 then
        return root
    end
    if not self.preset_browser_path or #self.preset_browser_path < (panel_index - 1) then
        return nil
    end
    return self:resolvePresetNode(Tree.clonePath(self.preset_browser_path, panel_index - 1))
end

function M.panelContentTextWidth(ctx, self, root, panel_index)
    local path_key = table.concat(self.preset_browser_path or {}, "/")
    self._panel_text_width_cache = self._panel_text_width_cache or {}
    local cache_key = path_key .. "|" .. tostring(panel_index)
    if self._panel_text_width_cache[cache_key] ~= nil then
        return self._panel_text_width_cache[cache_key]
    end

    local parent_node = M.parentForPanel(self, root, panel_index)
    local max_w = 0
    if not parent_node or not parent_node.children then
        return max_w
    end

    local all_lua_tables = true
    for _, node in ipairs(parent_node.children) do
        if node.kind ~= "lua_table" then
            all_lua_tables = false
            break
        end
    end

    if all_lua_tables then
        for _, table_node in ipairs(parent_node.children) do
            self:ensurePresetNodeChildrenLoaded(table_node)
            local tw = reaper.ImGui_CalcTextSize(ctx, Tree.stripClusterLabelDetails(table_node.label or "Cluster"))
            if tw > max_w then
                max_w = tw
            end
            for _, action_node in ipairs(table_node.children or {}) do
                local aw = reaper.ImGui_CalcTextSize(ctx, tostring(action_node.label or "Action"))
                if aw > max_w then
                    max_w = aw
                end
            end
        end
    else
        for _, child in ipairs(parent_node.children) do
            local label = tostring(child.label or "Item")
            if child.kind == "lua_table" then
                label = Tree.stripClusterLabelDetails(label)
            end
            local w = reaper.ImGui_CalcTextSize(ctx, label)
            if w > max_w then
                max_w = w
            end
        end
    end

    self._panel_text_width_cache[cache_key] = max_w
    return max_w
end

function M.computePanelWidths(ctx, self, root, panel_count, opts)
    opts = opts or {}
    local spacing = opts.spacing or 14
    local min_panel_w = opts.min_panel_w or 140
    local min_last_panel_w = opts.min_last_panel_w or 180
    local max_non_last_panel_w = opts.max_non_last_panel_w or 420
    local text_pad_w = opts.text_pad_w or 40

    local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
    local path_key = table.concat(self.preset_browser_path or {}, "/")
    local cache_key = path_key .. "|" .. tostring(panel_count) .. "|" .. math.floor(avail_w + 0.5)
    if self._panel_widths_cache_key == cache_key and self._panel_widths_cache then
        return self._panel_widths_cache, avail_w
    end

    local panel_widths = {}
    local used_non_last_w = 0

    for i = 1, panel_count - 1 do
        local content_w = M.panelContentTextWidth(ctx, self, root, i)
        local cap_w = math.max(min_panel_w, math.min(max_non_last_panel_w, content_w + text_pad_w))
        panel_widths[i] = cap_w
        used_non_last_w = used_non_last_w + cap_w
    end

    local spacing_total_w = spacing * (panel_count - 1)
    local last_w = avail_w - spacing_total_w - used_non_last_w
    if last_w < min_last_panel_w then
        local need = min_last_panel_w - last_w
        for i = panel_count - 1, 1, -1 do
            local reducible = math.max(0, panel_widths[i] - min_panel_w)
            local take = math.min(reducible, need)
            panel_widths[i] = panel_widths[i] - take
            need = need - take
            if need <= 0 then
                break
            end
        end
        used_non_last_w = 0
        for i = 1, panel_count - 1 do
            used_non_last_w = used_non_last_w + panel_widths[i]
        end
        last_w = avail_w - spacing_total_w - used_non_last_w
    end
    panel_widths[panel_count] = math.max(min_last_panel_w, last_w)

    self._panel_widths_cache_key = cache_key
    self._panel_widths_cache = panel_widths
    return panel_widths, avail_w
end

function M.parentChildrenAllLuaTables(parent_node)
    if not parent_node or not parent_node.children then
        return false
    end
    for _, node in ipairs(parent_node.children) do
        if node.kind ~= "lua_table" then
            return false
        end
    end
    return true
end

return M
