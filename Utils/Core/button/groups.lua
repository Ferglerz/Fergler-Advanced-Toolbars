-- Utils/Core/button/groups.lua

local M = {}

function M.isFirstButtonInGroup(button)
    if not button or not button.parent_group then
        return false
    end
    return button.parent_group.buttons[1] == button
end

function M.hasValidGroupLabel(group)
    return CONFIG.UI.USE_GROUP_LABELS and
           group and
           group.group_label and
           group.group_label.text and
           #group.group_label.text > 0
end

function M.shouldShowGroupLabelRow(editing_mode, group)
    if M.hasValidGroupLabel(group) then
        return true
    end
    return editing_mode == true
end

function M.getGroupLabelTextForRender(editing_mode, group)
    if M.hasValidGroupLabel(group) then
        return group.group_label.text or ""
    end
    if editing_mode then
        return "GROUP"
    end
    return ""
end

function M.getGroupLabelText(group)
    if not group or not group.group_label then
        return ""
    end
    return group.group_label.text or ""
end

function M.groupHasSeparator(group)
    if not group or not group.buttons then
        return false
    end

    for _, button in ipairs(group.buttons) do
        if button:isSeparator() then
            return true
        end
    end

    return false
end

return M
