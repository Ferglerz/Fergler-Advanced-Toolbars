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
    
    -- Drop state  
    self.current_drop_target = nil
    self.drop_position = "before" -- "before" or "after"
    
    return self
end

function DragDropManager:createIniBackup()
    return C.IniManager:createIniBackup()
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
    local success = C.IniManager:moveButtonInIni(target_button, payload_data, self.drop_position)
    
    if success then
        -- Add a small delay before reloading to prevent timing issues
        reaper.defer(function()
            C.IniManager:reloadToolbars()
        end)
    else
        reaper.ShowConsoleMsg("Drop failed\n")
    end
    
    return success
end

function DragDropManager:insertButtonInIni(target_button, new_button, position)
    return C.IniManager:insertButtonInIni(target_button, new_button, position)
end

function DragDropManager:endDrag()
    self.is_dragging = false
    self.drag_source_button = nil
    self.drag_payload = nil
    self.current_drop_target = nil
    self.drop_position = "before"
    
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

return DragDropManager.new()