-- toolbar_settings.lua

local ToolbarSettings = {}
ToolbarSettings.__index = ToolbarSettings

function ToolbarSettings.new(reaper, helpers)
    local self = setmetatable({}, ToolbarSettings)
    self.r = reaper
    self.helpers = helpers
    return self
end

function ToolbarSettings:render(ctx, toolbars, currentToolbarIndex, setCurrentToolbar, saveState)
    if not toolbars or #toolbars == 0 then
        self.r.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        return
    end

    self.r.ImGui_Separator(ctx)
    self.r.ImGui_TextDisabled(ctx, "Toolbar:")
    self.r.ImGui_Separator(ctx)

    for i, toolbar in ipairs(toolbars) do
        local displayName = toolbar.custom_name or toolbar.name
        
        if self.r.ImGui_MenuItem(ctx, displayName, nil, currentToolbarIndex == i) then
            setCurrentToolbar(i)
            if saveState then
                self.r.SetExtState("AdvancedToolbars", "last_toolbar_index", tostring(i), true)
            end
        end

        if toolbar.custom_name and self.r.ImGui_IsItemHovered(ctx) then
            self.r.ImGui_BeginTooltip(ctx)
            self.r.ImGui_Text(ctx, toolbar.section)
            self.r.ImGui_EndTooltip(ctx)
        end
    end

    self.r.ImGui_Separator(ctx)
    
    local current_toolbar = toolbars[currentToolbarIndex]
    if current_toolbar then
        if self.r.ImGui_MenuItem(ctx, "Rename Current Toolbar") then
            local current_name = current_toolbar.custom_name or current_toolbar.name
            local retval, new_name = self.r.GetUserInputs("Rename Toolbar", 1, "New Name:,extrawidth=100", current_name)

            if retval then
                current_toolbar:updateName(new_name)
                if saveState then saveState() end
            end
        end

        if current_toolbar.custom_name and self.r.ImGui_MenuItem(ctx, "Reset Toolbar Name") then
            current_toolbar.custom_name = nil
            current_toolbar:updateName(nil)
            if saveState then saveState() end
        end
    end
end

return {
    new = function(reaper, helpers)
        return ToolbarSettings.new(reaper, helpers)
    end
}
