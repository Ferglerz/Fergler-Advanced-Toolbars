-- Systems/Drag_Drop_Manager.lua

local DragDropManager = {}
DragDropManager.__index = DragDropManager

function DragDropManager.new()
    local self = setmetatable({}, DragDropManager)
    
    -- Drag state
    self.is_dragging = false
    self.drag_source_button = nil
    self.drag_source_group = nil
    self.drag_payload = nil
    self.last_drop_time = 0 -- Throttle starting a new drag after endDrag (cancel or finish)
    self.last_successful_drop_at = 0 -- Debounce performDrop/performGroupDrop only after a successful INI write
    
    -- ImGui context that started the drag (mouse position stays valid for cross-toolbar hit-tests)
    self.drag_pointer_ctx = nil

    -- Drop state  
    self.current_drop_target = nil
    self.drop_position = "before" -- "before" or "after"
    -- Whole-group drop: toolbar instance + 1-based group index (same frame as hit-test)
    self.drop_target_toolbar = nil
    self.drop_target_group_index = nil
    -- Toolbar with zero buttons: drop onto empty placeholder (no target button instance)
    self.empty_drop_toolbar = nil
    self._drag_mouse_was_down = false

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
        drag_kind = "button",
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
    self._drag_mouse_was_down = true

    -- Different preview for separators
    local preview_text = button:isSeparator() and "Moving: Separator" or ("Moving: " .. UTILS.stripNewLines(button.display_text))
    reaper.ImGui_Text(ctx, preview_text)
    
    reaper.ImGui_EndDragDropSource(ctx)
    
    return true
end

function DragDropManager:startGroupDrag(ctx, group, toolbar, display_label)
    if self.is_dragging then
        return false
    end
    local current_time = reaper.time_precise()
    if current_time - self.last_drop_time < 0.1 then
        return false
    end
    if not reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_SourceAllowNullID()) then
        return false
    end
    local source_gi = nil
    for i, g in ipairs(toolbar.groups) do
        if g == group then
            source_gi = i
            break
        end
    end
    if not source_gi then
        reaper.ImGui_EndDragDropSource(ctx)
        return false
    end
    self.drag_payload = {
        drag_kind = "group",
        source_toolbar = toolbar.section,
        source_group_index = source_gi,
        drag_start_time = current_time
    }
    local payload_string = UTILS.serializeValue(self.drag_payload)
    reaper.ImGui_SetDragDropPayload(ctx, "TOOLBAR_GROUP", payload_string)
    self.is_dragging = true
    self.drag_source_button = nil
    self.drag_source_group = group
    self.drag_pointer_ctx = ctx
    self._drag_mouse_was_down = true
    local label = display_label or "Group"
    reaper.ImGui_Text(ctx, "Moving: Group: " .. UTILS.stripNewLines(label))
    reaper.ImGui_EndDragDropSource(ctx)
    return true
end

function DragDropManager:performDrop(target_button, payload_data)
    local current_time = reaper.time_precise()
    if self.last_successful_drop_at > 0 and (current_time - self.last_successful_drop_at) < 0.15 then
        return false
    end

    if (payload_data.drag_kind or "button") == "group" then
        return false
    end
    -- Ensure we have valid payload data
    if not payload_data or not payload_data.instance_id or not target_button then
        return false
    end
    
    -- Don't drop on self
    if payload_data.instance_id == target_button.instance_id then
        return false
    end
    
    local success = C.IniManager:moveButton(target_button, payload_data, self.drop_position)

    if not success then
        reaper.ShowConsoleMsg("Drop failed\n")
    else
        self.last_successful_drop_at = current_time
    end

    return success
end

function DragDropManager:performGroupDrop(target_toolbar, target_group_index, payload_data)
    local current_time = reaper.time_precise()
    if not payload_data or (payload_data.drag_kind or "button") ~= "group" or not payload_data.source_group_index then
        return false
    end
    local tt = target_toolbar
    if tt and tt.section and C.IniManager then
        local fresh = C.IniManager:findToolbarByMenuSection(tt.section)
        if fresh then
            tt = fresh
        end
    end
    if not tt or not tt.groups or not tt.groups[target_group_index] then
        reaper.ShowConsoleMsg("Advanced Toolbars: group drop aborted (invalid target after reload)\n")
        return false
    end
    local ok = C.IniManager:moveGroup(
        payload_data.source_toolbar,
        payload_data.source_group_index,
        tt,
        target_group_index,
        self.drop_position
    )
    if not ok then
        reaper.ShowConsoleMsg("Group drop failed\n")
    else
        self.last_successful_drop_at = current_time
    end
    return ok
end

function DragDropManager:insertButtonInIni(target_button, new_button, position)
    return C.IniManager:insertButton(target_button, new_button, position)
end

local function reset_all_drag_caches()
    for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        local c = cd.controller
        if c and c.toolbars then
            for _, tb in ipairs(c.toolbars) do
                if tb.buttons then
                    for _, btn in ipairs(tb.buttons) do
                        if btn.cache and btn.cache.drag_state then
                            local ds = btn.cache.drag_state
                            ds.mouse_down_on_button = false
                            ds.was_dragging_last_frame = false
                            ds.drag_start_time = nil
                        end
                    end
                end
                if tb.groups then
                    for _, grp in ipairs(tb.groups) do
                        if grp.cache and grp.cache.label_drag_state then
                            local ls = grp.cache.label_drag_state
                            ls.mouse_down_on_button = false
                            ls.was_dragging_last_frame = false
                        end
                    end
                end
            end
        end
    end
end

function DragDropManager:endDrag()
    self.is_dragging = false
    self.drag_source_button = nil
    self.drag_source_group = nil
    self.drag_payload = nil
    self.drag_pointer_ctx = nil
    self.current_drop_target = nil
    self.drop_position = "before"
    self.drop_target_toolbar = nil
    self.drop_target_group_index = nil
    self.empty_drop_toolbar = nil
    self._drag_mouse_was_down = false

    reset_all_drag_caches()

    -- Update last drop time to prevent immediate re-drags
    self.last_drop_time = reaper.time_precise()
end

function DragDropManager:isDragging()
    return self.is_dragging
end

function DragDropManager:getDragSource()
    return self.drag_source_button
end

function DragDropManager:getDragSourceGroup()
    return self.drag_source_group
end

function DragDropManager:isGroupDrag()
    return self.is_dragging and self.drag_payload and self.drag_payload.drag_kind == "group"
end

function DragDropManager:getCurrentDropTarget()
    return self.current_drop_target
end

-- True when this frame has a valid drop landing (ghost preview is meaningful); used to hide the source item.
function DragDropManager:hasPotentialDropTarget()
    if not self.is_dragging then
        return false
    end
    if self.empty_drop_toolbar then
        return true
    end
    if self.current_drop_target then
        return true
    end
    if self.drop_target_toolbar and self.drop_target_group_index then
        return true
    end
    return false
end

-- Clear drop target once per frame before any toolbar hit-tests (avoids later windows wiping a valid target).
function DragDropManager:beginFrameDropTarget()
    if self.is_dragging then
        self.current_drop_target = nil
        self.empty_drop_toolbar = nil
        self.drop_target_toolbar = nil
        self.drop_target_group_index = nil
    end
end

-- After all toolbar windows have run (separate ImGui contexts), handle release once so the hovered toolbar can set the target first.
function DragDropManager:finishFrameDragDrop()
    if not self.is_dragging then
        return
    end
    local any_down = false
    for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if cd.ctx and cd.controller and cd.controller.is_open then
            if reaper.ImGui_IsMouseDown(cd.ctx, 0) then
                any_down = true
                break
            end
        end
    end
    local released = false
    if self.drag_pointer_ctx and reaper.ImGui_IsMouseReleased(self.drag_pointer_ctx, 0) then
        released = true
    else
        for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
            if cd.ctx and cd.controller and cd.controller.is_open then
                if reaper.ImGui_IsMouseReleased(cd.ctx, 0) then
                    released = true
                    break
                end
            end
        end
    end
    -- Fallback: some contexts never report IsMouseReleased for a drag that started in another window.
    if not released and self._drag_mouse_was_down and not any_down then
        local t0 = self.drag_payload and self.drag_payload.drag_start_time
        if t0 and (reaper.time_precise() - t0) > 0.03 then
            released = true
        end
    end
    if not released then
        self._drag_mouse_was_down = self._drag_mouse_was_down or any_down
        return
    end
    if self.empty_drop_toolbar and self.drag_payload then
        local current_time = reaper.time_precise()
        if self.last_successful_drop_at <= 0 or (current_time - self.last_successful_drop_at) >= 0.15 then
            local ok
            if (self.drag_payload.drag_kind or "button") == "group" then
                ok = C.IniManager:moveGroupToEmptySection(self.drag_payload, self.empty_drop_toolbar.section)
            else
                ok = C.IniManager:movePayloadToEmptySection(self.drag_payload, self.empty_drop_toolbar.section)
            end
            if not ok then
                reaper.ShowConsoleMsg("Drop on empty toolbar failed\n")
            else
                self.last_successful_drop_at = current_time
            end
        end
    elseif self.drop_target_toolbar and self.drop_target_group_index and self.drag_payload and
        (self.drag_payload.drag_kind or "button") == "group" then
        self:performGroupDrop(self.drop_target_toolbar, self.drop_target_group_index, self.drag_payload)
    elseif self.current_drop_target and self.drag_payload then
        self:performDrop(self.current_drop_target, self.drag_payload)
    end
    self:endDrag()
end

return DragDropManager.new()