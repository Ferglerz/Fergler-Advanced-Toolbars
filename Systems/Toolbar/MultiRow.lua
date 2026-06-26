-- Systems/Toolbar_MultiRow.lua
return function(ToolbarController)
function ToolbarController:getRowCount()
    return 1 + #self.extra_rows
end

--- Get the toolbar object for a given row index (0-based: 0 = primary).
function ToolbarController:getRowToolbar(row_index)
    if row_index == 0 then
        return self:getCurrentToolbar()
    end
    local row = self.extra_rows[row_index]
    if not row or not row.toolbar_index then
        return nil
    end
    if self.toolbars and row.toolbar_index >= 1 and row.toolbar_index <= #self.toolbars then
        return self.toolbars[row.toolbar_index]
    end
    return nil
end

--- Returns array of all row toolbars (primary + extras), nils for invalid indices.
function ToolbarController:getAllRowToolbars()
    local rows = { self:getCurrentToolbar() }
    for i = 1, #self.extra_rows do
        rows[#rows + 1] = self:getRowToolbar(i)
    end
    return rows
end

function ToolbarController:saveExtraRowsToConfig()
    local toolbar_id_str = tostring(self.toolbar_id)
    if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].extra_rows = {}
        for _, row in ipairs(self.extra_rows) do
            table.insert(CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].extra_rows, {
                toolbar_index = row.toolbar_index,
                enable_toolbar_switch = row.enable_toolbar_switch or false
            })
        end
        CONFIG_MANAGER:requestSaveMainConfig()
    end
end

function ToolbarController:addExtraRow(toolbar_index)
    table.insert(self.extra_rows, {
        toolbar_index = toolbar_index,
        enable_toolbar_switch = false
    })
    self:saveExtraRowsToConfig()
    self:ensureExtraRowSwitchWidgets()
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
    return #self.extra_rows
end

function ToolbarController:removeExtraRow(row_index)
    if row_index < 1 or row_index > #self.extra_rows then
        return false
    end
    -- Clear switch widget for this row
    if self.extra_row_switch_toolbars[row_index] then
        for _, b in ipairs(self.extra_row_switch_toolbars[row_index].buttons or {}) do
            C.ButtonManager:unregisterButton(b)
        end
        self.extra_row_switch_toolbars[row_index] = nil
    end
    table.remove(self.extra_rows, row_index)
    -- Re-index switch toolbar map
    local new_map = {}
    for k, v in pairs(self.extra_row_switch_toolbars) do
        if k > row_index then
            new_map[k - 1] = v
        elseif k < row_index then
            new_map[k] = v
        end
    end
    self.extra_row_switch_toolbars = new_map
    self:saveExtraRowsToConfig()
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
    return true
end

function ToolbarController:removeRow(row_index)
    local row_count = self:getRowCount()
    if row_count <= 1 then
        return false
    end
    if row_index == 0 then
        local first_extra = self.extra_rows[1]
        if not first_extra then return false end
        
        self.currentToolbarIndex = first_extra.toolbar_index
        local toolbar_id_str = tostring(self.toolbar_id)
        if CONFIG.TOOLBAR_CONTROLLERS and CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
            CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index = first_extra.toolbar_index
        end
        
        self:setEnableToolbarSwitch(first_extra.enable_toolbar_switch or false)
        
        -- Remove the extra row that was promoted
        local ok = self:removeExtraRow(1)
        if ok and self.loader then
            self.loader:loadToolbars()
        end
        return ok
    else
        return self:removeExtraRow(row_index)
    end
end

function ToolbarController:setExtraRowToolbarIndex(row_index, toolbar_index)
    if row_index < 1 or row_index > #self.extra_rows then return false end
    self.extra_rows[row_index].toolbar_index = toolbar_index
    self:saveExtraRowsToConfig()
    self:ensureExtraRowSwitchWidgets()
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
    return true
end

function ToolbarController:reorderExtraRow(from_index, to_index)
    if from_index < 1 or from_index > #self.extra_rows then return false end
    if to_index < 1 or to_index > #self.extra_rows then return false end
    if from_index == to_index then return false end
    local row = table.remove(self.extra_rows, from_index)
    table.insert(self.extra_rows, to_index, row)
    -- Rebuild switch widget map to match new order
    self:clearExtraRowSwitchWidgets()
    self:ensureExtraRowSwitchWidgets()
    self:saveExtraRowsToConfig()
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
    return true
end

function ToolbarController:setEnableToolbarSwitch(enabled)
    local toolbar_id_str = tostring(self.toolbar_id)
    self.enable_toolbar_switch = enabled
    if CONFIG.TOOLBAR_CONTROLLERS and CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].enable_toolbar_switch = enabled
        CONFIG_MANAGER:requestSaveMainConfig()
    end
    self:ensureToolbarSwitchWidget()
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
end

function ToolbarController:setEnableRowScroll(enabled)
    local toolbar_id_str = tostring(self.toolbar_id)
    self.enable_row_scroll = enabled
    if CONFIG.TOOLBAR_CONTROLLERS and CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].enable_row_scroll = enabled
        CONFIG_MANAGER:requestSaveMainConfig()
    end
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
end

function ToolbarController:setExtraRowToolbarSwitch(row_index, enabled)
    if row_index < 1 or row_index > #self.extra_rows then return false end
    self.extra_rows[row_index].enable_toolbar_switch = enabled
    self:saveExtraRowsToConfig()
    self:ensureExtraRowSwitchWidgets()
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
    return true
end

function ToolbarController:clearExtraRowSwitchWidgets()
    for k, sw_tb in pairs(self.extra_row_switch_toolbars) do
        if sw_tb and sw_tb.buttons then
            for _, b in ipairs(sw_tb.buttons) do
                C.ButtonManager:unregisterButton(b)
            end
        end
    end
    self.extra_row_switch_toolbars = {}
end

function ToolbarController:ensureExtraRowSwitchWidgets()
    -- Rebuild: clear all, then create for rows that have switch enabled
    self:clearExtraRowSwitchWidgets()
    for i, row in ipairs(self.extra_rows) do
        if row.enable_toolbar_switch then
            self.extra_row_switch_toolbars[i] = C.ParseToolbars:buildToolbarSwitchWidgetToolbar(TOOLBAR_SWITCH_WIDGET_CONFIG)
        end
    end
end

return ToolbarController
end
