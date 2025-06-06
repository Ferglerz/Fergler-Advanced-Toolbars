-- Systems/Drag_Drop_Manager.lua

local DragDropManager = {}
DragDropManager.__index = DragDropManager

function DragDropManager.new()
    local self = setmetatable({}, DragDropManager)
    
    -- Drag state
    self.is_dragging = false
    self.drag_source_button = nil
    self.drag_payload = nil
    
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
    
    if not reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_SourceAllowNullID()) then
        return false
    end
    
    -- Create payload (now works for separators too)
    self.drag_payload = {
        button_id = button.id,
        button_text = button.original_text,
        source_toolbar = button.parent_toolbar.section,
        instance_id = button.instance_id,
        is_separator = button.is_separator
    }
    
    local payload_string = UTILS.serializeValue(self.drag_payload)
    reaper.ImGui_SetDragDropPayload(ctx, "TOOLBAR_BUTTON", payload_string)
    
    -- Set drag state
    self.is_dragging = true
    self.drag_source_button = button
    
    -- Different preview for separators
    local preview_text = button.is_separator and "Moving: Separator" or ("Moving: " .. UTILS.stripNewLines(button.display_text))
    reaper.ImGui_Text(ctx, preview_text)
    
    reaper.ImGui_EndDragDropSource(ctx)
    
    return true
end


function DragDropManager:performDrop(target_button, payload_data)    
    -- Update INI file using IniManager
    local success = C.IniManager:moveButtonInIni(target_button, payload_data, self.drop_position)
    
    if success then
        -- Reload all toolbars
        C.IniManager:reloadToolbars()
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