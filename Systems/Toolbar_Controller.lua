-- Systems/Toolbar_Controller.lua

local ToolbarController = {}
ToolbarController.__index = ToolbarController

function ToolbarController.new(toolbar_id)
    local self = setmetatable({}, ToolbarController)

    self.currentToolbarIndex = nil
    self.button_editing_mode = false
    self.is_open = true

    -- Use provided ID or generate a new one
    self.toolbar_id = toolbar_id or ID_GENERATOR.generateToolbarId()

    -- Docking state
    self.current_dock_id = nil
    self.target_dock_id = nil
    self.last_dock_id = nil
    self.dock_pending = false

    self.toolbars = nil
    self.menu_path = nil
    self.ctx = nil 

    -- UI state
    self.clicked_button = nil
    self.active_group = nil
    self.is_mouse_down = false
    self.was_mouse_down = false

    self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    self.last_height = CONFIG.SIZES.HEIGHT
    self.last_spacing = CONFIG.SIZES.SPACING

    self.toolbar_switch_toolbar = nil

    -- Pin floating window to a REAPER main-window region (undocked only; requires js_ReaScriptAPI)
    self.ui_pin = false
    self.ui_anchor = "off"
    self.ui_anchor_align = "center"
    self.ui_pin_offset_x = 0
    self.ui_pin_offset_y = 0
    self._imgui_window_restart_pending = false

    -- Multi-row support: extra toolbars rendered as additional rows/columns
    self.extra_rows = {}               -- { { toolbar_index=N, enable_toolbar_switch=bool }, ... }
    self.enable_toolbar_switch = true   -- per-toolbar switch widget toggle (row 0)
    self.enable_row_scroll = true       -- per-row scrolling (row 0)
    self.extra_row_switch_toolbars = {} -- [row_index] = parsed switch toolbar objects
    self.is_vertical = false

    return self
end

-- Built-in config for the prepended Toolbars List widget (no separate user file).
local TOOLBAR_SWITCH_WIDGET_CONFIG = {
    CUSTOM_NAME = "",
    SYNTHETIC_ITEMS = {
        { id = "65535", text = "", pos = "0", widget = { name = "toolbars_list" } }
    },
    TOOLBAR_GROUPS = { { group_label = { text = "" } } },
    BUTTON_CUSTOM_PROPERTIES = {}
}

function ToolbarController:initialize(toolbars, menu_path)
    self.toolbars = toolbars
    self.menu_path = menu_path

    -- Ensure this toolbar has an entry (using tostring to handle numeric IDs)
    local toolbar_id_str = tostring(self.toolbar_id)
    
    -- Load settings for this toolbar controller
    if type(CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str]) == "table" then
        local controller_settings = CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str]
        
        -- Apply saved dock state
        if controller_settings.dock_id and controller_settings.dock_id ~= 0 then
            self.target_dock_id = controller_settings.dock_id
            self.dock_pending = true
        end
        
        -- Load saved toolbar index if available
        if controller_settings.last_toolbar_index and
           tonumber(controller_settings.last_toolbar_index) >= 1 and
           tonumber(controller_settings.last_toolbar_index) <= #toolbars then
            self.currentToolbarIndex = tonumber(controller_settings.last_toolbar_index)
        end

        self.ui_pin = controller_settings.ui_pin == true
        self.ui_anchor = controller_settings.ui_anchor or "off"
        if self.ui_pin and self.ui_anchor == "off" then
            self.ui_anchor = "tcp_corner"
        end
        self.ui_anchor_align = controller_settings.ui_anchor_align or "center"
        self.ui_pin_offset_x = tonumber(controller_settings.ui_pin_offset_x) or 0
        self.ui_pin_offset_y = tonumber(controller_settings.ui_pin_offset_y) or 0

        -- Multi-row settings
        self.enable_toolbar_switch = controller_settings.enable_toolbar_switch ~= false
        self.enable_row_scroll = controller_settings.enable_row_scroll ~= false
        if type(controller_settings.extra_rows) == "table" then
            self.extra_rows = {}
            for _, row in ipairs(controller_settings.extra_rows) do
                if type(row) == "table" and row.toolbar_index then
                    table.insert(self.extra_rows, {
                        toolbar_index = tonumber(row.toolbar_index),
                        enable_toolbar_switch = row.enable_toolbar_switch == true
                    })
                end
            end
        end
    else
        -- Create new entry in TOOLBAR_CONTROLLERS for this controller
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] = {
            dock_id = 0, -- Default to undocked
            last_toolbar_index = self.currentToolbarIndex or 1,
            ui_pin = false,
            ui_anchor = "off",
            ui_anchor_align = "center",
            ui_pin_offset_x = 0,
            ui_pin_offset_y = 0,
            enable_toolbar_switch = true,
            extra_rows = {}
        }
        CONFIG_MANAGER:saveMainConfigImmediate()
    end

    return self
end

function ToolbarController:showDropdownEditor(button, owner_ctx)
    require("Systems.Modules_Factory").ensureUiModules()
    if C.ButtonDropdownEditor then
        if C.ButtonDropdownEditor.show then
            C.ButtonDropdownEditor:show(button, owner_ctx)
        else
            C.ButtonDropdownEditor.is_open = true
            C.ButtonDropdownEditor.current_button = button
            C.ButtonDropdownEditor.owner_ctx = owner_ctx
        end
        return true
    end
    return false
end

function ToolbarController:getCurrentToolbar()
    return self.toolbars[self.currentToolbarIndex]
end

function ToolbarController:setCurrentToolbarIndex(index)
    if index >= 1 and index <= #self.toolbars then
        self.currentToolbarIndex = index
        
        -- Save to controller-specific settings
        local toolbar_id_str = tostring(self.toolbar_id)
        if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
            CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index = index
            CONFIG_MANAGER:requestSaveMainConfig()
        end

        if C.LayoutManager then
            C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
        end

        return true
    end
    return false
end

function ToolbarController:createToolbarFromTemplate(template_section)
    if not C.IniManager or not self.loader then
        return false
    end

    local ini_content = C.IniManager:getContent()
    if not ini_content then
        ini_content = C.IniManager:loadContent(true)
    end
    local new_section = CONFIG_MANAGER:createToolbarFromIniTemplate(template_section, ini_content)
    if not new_section then
        return false
    end

    if C.SharedToolbars then
        C.SharedToolbars:invalidate()
    end

    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if controller_data.controller and controller_data.controller.loader then
            controller_data.controller.loader:loadToolbars()
        end
    end

    for i, t in ipairs(self.toolbars or {}) do
        if t.section == new_section then
            self:setCurrentToolbarIndex(i)
            break
        end
    end

    return true
end

function ToolbarController:clearToolbarSwitchWidget()
    if not self.toolbar_switch_toolbar then
        return
    end
    for _, b in ipairs(self.toolbar_switch_toolbar.buttons) do
        C.ButtonManager:unregisterButton(b)
    end
    self.toolbar_switch_toolbar = nil
end

function ToolbarController:ensureToolbarSwitchWidget()
    self:clearToolbarSwitchWidget()
    if not self.enable_toolbar_switch then
        return
    end
    self.toolbar_switch_toolbar = C.ParseToolbars:buildToolbarSwitchWidgetToolbar(TOOLBAR_SWITCH_WIDGET_CONFIG)
end

function ToolbarController:toggleEditingMode(value, get_only)
    if get_only then
        return self.button_editing_mode
    end

    local new_value
    if value ~= nil then
        new_value = value
    else
        new_value = not self.button_editing_mode
    end

    local was_editing = self.button_editing_mode

    self.button_editing_mode = new_value
    
    -- Sync edit mode across all toolbar controllers to enable cross-toolbar drag and drop
    if _G.TOOLBAR_CONTROLLERS then
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            if controller_data.controller and controller_data.controller ~= self then
                controller_data.controller.button_editing_mode = new_value
            end
        end
    end

    if new_value and not was_editing and self.toolbars then
        for _, toolbar in ipairs(self.toolbars) do
            CONFIG_MANAGER:persistToolbarConfigSanitize(toolbar)
        end
    end

    return self.button_editing_mode
end

function ToolbarController:needCacheUpdate()
    local need_update = false

    -- Check for MIN_WIDTH changes
    if self.last_min_width ~= CONFIG.SIZES.MIN_WIDTH then
        need_update = true
        self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    end

    -- Check for HEIGHT changes
    if self.last_height ~= CONFIG.SIZES.HEIGHT then
        need_update = true
        self.last_height = CONFIG.SIZES.HEIGHT
    end

    -- Check for SPACING changes
    if self.last_spacing ~= CONFIG.SIZES.SPACING then
        need_update = true
        self.last_spacing = CONFIG.SIZES.SPACING
    end

    return need_update
end

function ToolbarController:updateButtonCaches(toolbar)
    -- Check if caches need to be cleared due to config changes
    if not self:needCacheUpdate() or not toolbar then
        return false
    end

    -- Clear button caches
    for _, button in ipairs(toolbar.buttons) do
        button.cached_width = nil
        button.screen_coords = nil
    end

    -- Clear group caches
    for _, group in ipairs(toolbar.groups) do
        group:clearCache()
    end

    return true
end

--- Remove this controller's per-instance buttons from global ButtonManager (switch widget, placeholders).
function ToolbarController:unregisterAllButtons()
    self:clearToolbarSwitchWidget()
    self:clearEmptyPlaceholderCache()
end

--- Drop this controller's buttons and chrome without wiping other toolbars' ButtonManager registry.
function ToolbarController:disposeForImGuiRestart()
    self:unregisterAllButtons()
    if C.PopupContext then
        C.PopupContext.closeAllAuxiliaryWindows()
    end
end

function ToolbarController:cleanup()
    self:unregisterAllButtons()

    if C.PopupContext then
        C.PopupContext.closeAllAuxiliaryWindows()
    end

    CONFIG_MANAGER:cleanup()
end

function ToolbarController:setDockState(dock_id)
    if not dock_id then
        return false
    end

    -- Store the dock ID (positive for ImGui docks, negative for REAPER dockers)
    if type(dock_id) == "number" and dock_id > 0 and dock_id <= 16 then
        -- Convert REAPER docker numbers (1-16) to negative IDs
        self.target_dock_id = -dock_id
    else
        -- Store as-is for ImGui docks or already-formatted REAPER dockers
        self.target_dock_id = dock_id
    end

    -- Mark that we need to apply the dock change
    self.dock_pending = true

    -- Save for persistence in controller-specific settings
    local toolbar_id_str = tostring(self.toolbar_id)
    if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].dock_id = self.target_dock_id
        CONFIG_MANAGER:requestSaveMainConfig()
    end

    return true
end

function ToolbarController:updateDockState(ctx)
    -- Get the current dock ID after the window has been rendered
    local new_dock_id = reaper.ImGui_GetWindowDockID(ctx)

    -- Only update if we have a valid dock ID that changed
    if new_dock_id ~= nil and new_dock_id ~= self.current_dock_id then
        self.current_dock_id = new_dock_id

        -- Save the change if it's a user-initiated dock change
        local toolbar_id_str = tostring(self.toolbar_id)
        if not self.dock_pending and CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
            CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].dock_id = new_dock_id
            CONFIG_MANAGER:requestSaveMainConfig()
        end
    end
end

function ToolbarController:toggleDocking()
    -- If currently docked, undock
    if self.current_dock_id and self.current_dock_id ~= 0 then
        -- Remember the current dock before undocking
        self.last_dock_id = self.current_dock_id
        self:setDockState(0) -- 0 = undocked
    else
        -- If undocked, dock to last known docker or default
        local dock_target = self.last_dock_id or -1 -- Default to REAPER docker 1
        self:setDockState(dock_target)
    end

    return true
end

function ToolbarController:applyDockState(ctx)
    -- Pin-to-REAPER-UI must stay a free-floating ImGui window (not ImGui dockspace, not REAPER docker).
    if self:wantsPinToReaperUi() then
        if reaper.ImGui_SetNextWindowDockID then
            reaper.ImGui_SetNextWindowDockID(ctx, 0)
        end
        self.target_dock_id = 0
        self.dock_pending = false
        return false
    end
    if self.dock_pending and self.target_dock_id ~= nil then
        -- Apply the dock state at the appropriate time in the ImGui frame
        reaper.ImGui_SetNextWindowDockID(ctx, self.target_dock_id)
        self.dock_pending = false
        return true
    end
    return false
end

function ToolbarController:wantsPinToReaperUi()
    if not self.ui_pin or self.ui_anchor == "off" then
        return false
    end
    local target = self.target_dock_id
    -- User chose a REAPER docker this frame: do not run pin layout until that applies
    if self.dock_pending and type(target) == "number" and target < 0 then
        return false
    end
    local d = self.current_dock_id
    if type(d) == "number" and d < 0 then
        -- Still reported as docker until ImGui undocks: follow anchor if we're forcing float (pin)
        return type(target) == "number" and target == 0
    end
    return true
end

function ToolbarController:shouldUsePinnedChrome()
    return self:wantsPinToReaperUi()
end

function ToolbarController:shouldFollowUiAnchor()
    if not self:shouldUsePinnedChrome() then
        return false
    end
    local R = _G.REAPER_UI_ANCHOR
    return R and R.is_available() and R.get_anchor_rect ~= nil
end

function ToolbarController:setUiPinSettings(pin, anchor, align)
    self.ui_pin = pin == true
    local a = anchor or "off"
    if self.ui_pin and a == "off" then
        a = "tcp_corner"
    end
    self.ui_anchor = a
    self.ui_anchor_align = align or "center"
    if self.ui_pin then
        self:setDockState(0)
    end
    local toolbar_id_str = tostring(self.toolbar_id)
    if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].ui_pin = self.ui_pin
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].ui_anchor = self.ui_anchor
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].ui_anchor_align = self.ui_anchor_align
        CONFIG_MANAGER:requestSaveMainConfig()
    end
    self._imgui_window_restart_pending = true
    return true
end

--- Screen-space nudge for pinned UI-anchor position (pixels). nil keeps existing axis.
function ToolbarController:setUiPinOffsets(offset_x, offset_y)
    local toolbar_id_str = tostring(self.toolbar_id)
    if offset_x ~= nil then
        self.ui_pin_offset_x = offset_x
    end
    if offset_y ~= nil then
        self.ui_pin_offset_y = offset_y
    end
    if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].ui_pin_offset_x = self.ui_pin_offset_x
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].ui_pin_offset_y = self.ui_pin_offset_y
        CONFIG_MANAGER:requestSaveMainConfig()
    end
    return true
end

function ToolbarController:isOpen()
    return self.is_open
end

function ToolbarController:setOpen(is_open)
    self.is_open = is_open
end

-- In-memory only: styled like a real toolbar button; used when reaper-menu section has no items yet.
function ToolbarController:getEmptyPlaceholderButton(toolbar)
    local key = tostring(toolbar.section)
    if self._empty_ph_button and self._empty_ph_key == key then
        self._empty_ph_button.parent_toolbar = toolbar
        return self._empty_ph_button, self._empty_ph_group
    end

    if self._empty_ph_button then
        C.ButtonManager:unregisterButton(self._empty_ph_button)
        self._empty_ph_button = nil
        self._empty_ph_group = nil
    end

    local btn = C.ButtonDefinition.createNoopButton("Add")
    btn.display_text = "Add"
    btn.is_empty_toolbar_placeholder = true
    btn.instance_id = "empty_toolbar_ph_" .. tostring(self.toolbar_id) .. "_" .. key:gsub("[^%w_]", "_")
    btn.parent_toolbar = toolbar

    local grp = C.ParseGrouping.new()
    grp:addButton(btn)

    C.ButtonManager:registerButton(btn)
    self._empty_ph_button = btn
    self._empty_ph_group = grp
    self._empty_ph_key = key
    return btn, grp
end

function ToolbarController:clearEmptyPlaceholderCache()
    if self._empty_ph_button then
        C.ButtonManager:unregisterButton(self._empty_ph_button)
    end
    self._empty_ph_button = nil
    self._empty_ph_group = nil
    self._empty_ph_key = nil
end

-- ── Multi-row management ──────────────────────────────────────────────────

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