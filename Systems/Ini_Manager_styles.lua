-- Systems/Ini_Manager_styles.lua — insertion color snapshots; loaded by Ini_Manager.lua

local function deepCopyTable(value)
    if type(value) ~= "table" then
        return value
    end
    if CONFIG_MANAGER and CONFIG_MANAGER.deepCopy then
        return CONFIG_MANAGER:deepCopy(value)
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deepCopyTable(v)
    end
    return out
end

function IniManager:captureInsertionStyleSnapshot(target_button, exclude_instance_id)
    if not target_button then
        return nil
    end

    local source_button = target_button
    if C.ButtonRenderer and C.ButtonRenderer.getInsertionColorSource then
        source_button = C.ButtonRenderer:getInsertionColorSource(target_button, exclude_instance_id) or target_button
    end

    if not source_button then
        return nil
    end

    local cc = source_button.custom_color
    if cc and BUTTON_UTILS and not BUTTON_UTILS.customColorHasConcreteVisual(cc) then
        cc = nil
    end

    return {
        custom_color = cc and deepCopyTable(cc) or nil,
        user_colors = source_button.user_colors and deepCopyTable(source_button.user_colors) or nil,
        border_offset = source_button.border_offset and {
            saturation = source_button.border_offset.saturation or 0.0,
            value = source_button.border_offset.value or 0.0
        } or nil
    }
end

function IniManager:applyStyleSnapshotToInsertedRange(toolbar_section, start_index, count, style_snapshot)
    if not toolbar_section or not style_snapshot or not start_index or start_index < 1 or (count or 0) < 1 then
        return false
    end

    -- Force a synchronous reload so we style freshly inserted buttons instead of stale toolbar state.
    self:reloadToolbarsNow()

    local toolbar = self:findToolbarByMenuSection(toolbar_section)
    if not toolbar or type(toolbar.buttons) ~= "table" then
        return false
    end

    local applied = false
    local last_index = math.min(#toolbar.buttons, start_index + count - 1)
    for i = start_index, last_index do
        local button = toolbar.buttons[i]
        if button and not button:isSeparator() then
            button.custom_color = style_snapshot.custom_color and deepCopyTable(style_snapshot.custom_color) or nil
            button.user_colors = style_snapshot.user_colors and deepCopyTable(style_snapshot.user_colors) or nil
            if style_snapshot.border_offset then
                button.border_offset = {
                    saturation = style_snapshot.border_offset.saturation or 0.0,
                    value = style_snapshot.border_offset.value or 0.0
                }
            end
            if button.clearLayoutCache then
                button:clearLayoutCache()
            elseif button.clearCache then
                button:clearCache()
            end
            if button.clearColorCache then
                button:clearColorCache()
            end
            applied = true
        end
    end

    if applied and CONFIG_MANAGER then
        CONFIG_MANAGER:saveToolbarConfig(toolbar)
    end

    return applied
end

-- After a single-button drag-drop move, match colors to the destination group (same as insertButton).
function IniManager:inheritGroupColorsForMovedButton(drop_target_button, payload_data, target_section)
    if not drop_target_button or not payload_data or payload_data.is_separator or not payload_data.instance_id then
        return
    end
    if not target_section then
        return
    end

    self:reloadToolbarsNow()

    local toolbar = self:findToolbarByMenuSection(target_section)
    if not toolbar or type(toolbar.buttons) ~= "table" then
        return
    end

    local target_id = drop_target_button.instance_id
    local fresh_target
    for _, b in ipairs(toolbar.buttons) do
        if b.instance_id == target_id then
            fresh_target = b
            break
        end
    end
    if not fresh_target then
        return
    end

    local moved_flat
    for i, b in ipairs(toolbar.buttons) do
        if b.instance_id == payload_data.instance_id then
            moved_flat = i
            break
        end
    end
    if not moved_flat then
        return
    end

    local moved_button = toolbar.buttons[moved_flat]
    if not moved_button or moved_button:isSeparator() then
        return
    end

    local style_snapshot = self:captureInsertionStyleSnapshot(fresh_target, payload_data.instance_id)
    if not style_snapshot then
        return
    end

    self:applyStyleSnapshotToInsertedRange(target_section, moved_flat, 1, style_snapshot)
end
