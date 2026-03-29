-- widgets/toolbars_list.lua
-- Dropdown lists reaper-menu toolbar sections for this Advanced Toolbar window. Selection switches
-- currentToolbarIndex for the host controller (same as Settings > toolbar combo).

local function findControllerForId(id)
    if not id or not _G.TOOLBAR_CONTROLLERS then
        return nil
    end
    for _, cd in ipairs(TOOLBAR_CONTROLLERS) do
        if cd.controller and cd.controller.toolbar_id == id then
            return cd.controller
        end
    end
    return nil
end

-- Padding matches Renderers/_Widgets.lua renderDropdownWidget: 8 left, 8 right, 8 before arrow, arrow 8 wide
local function dropdown_chrome_width(ctx, text)
    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    return math.max(CONFIG.SIZES.MIN_WIDTH or 30, tw + 32)
end

local widget = {
    name = "Toolbars List",
    update_interval = 0.25,
    type = "dropdown",
    placeholder = "Select Toolbar...",
    label = "",
    description = "Switch the underlying toolbar (reaper-menu section) for this window",
    selected_text = "Toolbars",

    getLayoutWidth = function(self, ctx)
        local controller = findControllerForId(self._atb_controller_id)
        local text = self.placeholder or "Toolbars"
        if controller and controller.toolbars and controller.currentToolbarIndex then
            local t = controller.toolbars[controller.currentToolbarIndex]
            if t then
                text = t.custom_name or t.name or text
            end
        elseif self.selected_text and self.selected_text ~= "" then
            text = self.selected_text
        end
        return dropdown_chrome_width(ctx, text)
    end,

    dropdown_menu = {},

    scanMenuItems = function(self)
        self.dropdown_menu = {}
        local controller = findControllerForId(self._atb_controller_id)
        if not controller or not controller.toolbars then
            return
        end
        local active_indices = _G.getActiveToolbarIndices and getActiveToolbarIndices() or {}
        local cur = controller.currentToolbarIndex
        for i, t in ipairs(controller.toolbars) do
            local displayName = t.custom_name or t.name
            local is_selected = (cur == i)
            local disabled = active_indices[i] and not is_selected
            table.insert(
                self.dropdown_menu,
                {
                    name = displayName,
                    toolbar_index = i,
                    disabled = disabled
                }
            )
        end
    end,

    getValue = function(self)
        self:scanMenuItems()
        local controller = findControllerForId(self._atb_controller_id)
        if controller and controller.toolbars and controller.currentToolbarIndex then
            local t = controller.toolbars[controller.currentToolbarIndex]
            self.selected_text = t and (t.custom_name or t.name) or "Toolbars"
        else
            self.selected_text = "Toolbars"
        end
        return self.selected_text
    end,

    onSelect = function(self, selected_item)
        if not selected_item or not selected_item.toolbar_index then
            return
        end
        if selected_item.disabled then
            return
        end
        local controller = findControllerForId(self._atb_controller_id)
        if not controller then
            return
        end
        controller:setCurrentToolbarIndex(selected_item.toolbar_index)
        reaper.SetExtState("AdvancedToolbars", "last_toolbar_index", tostring(selected_item.toolbar_index), true)
        if selected_item.name then
            self.selected_text = selected_item.name
        end
    end
}

return widget
