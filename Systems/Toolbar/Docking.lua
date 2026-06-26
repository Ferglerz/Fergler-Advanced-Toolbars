-- Systems/Toolbar_Docking.lua
return function(ToolbarController)
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


end
