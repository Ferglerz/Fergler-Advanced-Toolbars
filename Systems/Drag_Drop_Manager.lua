-- Systems/Drag_Drop_Manager.lua

local DragDropManager = {}
DragDropManager.__index = DragDropManager

function DragDropManager.new()
    local self = setmetatable({}, DragDropManager)
    
    -- Drag state
    self.is_dragging = false
    self.drag_source_button = nil
    self.drag_payload = nil
    self.last_drop_time = 0  -- Fix issue #4: Prevent duplicate operations
    
    -- ImGui context that started the drag (mouse position stays valid for cross-toolbar hit-tests)
    self.drag_pointer_ctx = nil

    -- Drop state  
    self.current_drop_target = nil
    self.drop_position = "before" -- "before" or "after"
    -- Toolbar with zero buttons: drop onto empty placeholder (no target button instance)
    self.empty_drop_toolbar = nil
    
    return self
end

function DragDropManager:createIniBackup()
    return C.IniManager:createBackup()
end

function DragDropManager:startDrag(ctx, button)
    if self.is_dragging then
        return false
    end
    
    -- Fix issue #4: Ensure we have a unique drag operation
    local current_time = reaper.time_precise()
    if current_time - self.last_drop_time < 0.1 then
        return false -- Too soon after last drop
    end
    
    if not reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_SourceAllowNullID()) then
        return false
    end
    
    -- Create payload with unique identifiers
    self.drag_payload = {
        button_id = button.id,
        button_text = button.original_text,
        source_toolbar = button.parent_toolbar.section,
        instance_id = button.instance_id,
        button_type = button.button_type,
        is_separator = button:isSeparator(),
        separator_index = button.separator_index,  -- Track separator position
        drag_start_time = current_time  -- Track when drag started
    }
    
    local payload_string = UTILS.serializeValue(self.drag_payload)
    reaper.ImGui_SetDragDropPayload(ctx, "TOOLBAR_BUTTON", payload_string)
    
    -- Set drag state
    self.is_dragging = true
    self.drag_source_button = button
    self.drag_pointer_ctx = ctx

    -- Different preview for separators
    local preview_text = button:isSeparator() and "Moving: Separator" or ("Moving: " .. UTILS.stripNewLines(button.display_text))
    reaper.ImGui_Text(ctx, preview_text)
    
    reaper.ImGui_EndDragDropSource(ctx)
    
    return true
end

function DragDropManager:performDrop(target_button, payload_data)
    -- Fix issue #4: Prevent duplicate drops
    local current_time = reaper.time_precise()
    if current_time - self.last_drop_time < 0.2 then
        return false -- Prevent rapid duplicate drops
    end
    
    -- Ensure we have valid payload data
    if not payload_data or not payload_data.instance_id or not target_button then
        return false
    end
    
    -- Don't drop on self
    if payload_data.instance_id == target_button.instance_id then
        return false
    end
    
    self.last_drop_time = current_time
    
    -- Update INI file using IniManager
    local success = C.IniManager:moveButton(target_button, payload_data, self.drop_position)

    if not success then
        reaper.ShowConsoleMsg("Drop failed\n")
    end
    
    return success
end

function DragDropManager:insertButtonInIni(target_button, new_button, position)
    return C.IniManager:insertButton(target_button, new_button, position)
end

function DragDropManager:endDrag()
    self.is_dragging = false
    self.drag_source_button = nil
    self.drag_payload = nil
    self.drag_pointer_ctx = nil
    self.current_drop_target = nil
    self.drop_position = "before"
    self.empty_drop_toolbar = nil
    
    -- Update last drop time to prevent immediate re-drags
    self.last_drop_time = reaper.time_precise()
end

function DragDropManager:isDragging()
    return self.is_dragging
end

function DragDropManager:getDragSource()
    return self.drag_source_button
end

function DragDropManager:getCurrentDropTarget()
    return self.current_drop_target
end

-- Clear drop target once per frame before any toolbar hit-tests (avoids later windows wiping a valid target).
function DragDropManager:beginFrameDropTarget()
    if self.is_dragging then
        self.current_drop_target = nil
        self.empty_drop_toolbar = nil
    end
end

-- After all toolbar windows have run (separate ImGui contexts), handle release once so the hovered toolbar can set the target first.
function DragDropManager:finishFrameDragDrop()
    if not self.is_dragging then
        return
    end
    local released = false
    for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if cd.ctx and cd.controller and cd.controller.is_open then
            if reaper.ImGui_IsMouseReleased(cd.ctx, 0) then
                released = true
                break
            end
        end
    end
    if not released then
        return
    end
    if self.empty_drop_toolbar and self.drag_payload then
        local current_time = reaper.time_precise()
        if current_time - self.last_drop_time >= 0.2 then
            self.last_drop_time = current_time
            local ok = C.IniManager:movePayloadToEmptySection(self.drag_payload, self.empty_drop_toolbar.section)
            if not ok then
                reaper.ShowConsoleMsg("Drop on empty toolbar failed\n")
            end
        end
    elseif self.current_drop_target and self.drag_payload then
        self:performDrop(self.current_drop_target, self.drag_payload)
    end
    self:endDrag()
end

return DragDropManager.new()