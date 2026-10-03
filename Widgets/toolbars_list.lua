-- widgets/toolbars_list.lua
-- Switch saved toolbars, create a blank toolbar, or explicitly open REAPER import.

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

-- Padding matches Renderers/Widgets.lua renderDropdownWidget: 8 left, 8 right, 8 before arrow, arrow 8 wide
local function dropdown_min_width_for_text(ctx, text)
    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    return math.max(CONFIG.SIZES.MIN_WIDTH or 30, tw + 32)
end

local widget = {
    name = "Toolbars List",
    category = "Project & surfaces",
    update_interval = 0.25,
    type = "dropdown",
    placeholder = "Select Toolbar...",
    description = "Switch saved toolbars, create a blank toolbar, or import a REAPER toolbar",
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
        return dropdown_min_width_for_text(ctx, text)
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

        -- Section 1: existing custom/runtime toolbars.
        for i, t in ipairs(controller.toolbars) do
            local displayName = t.custom_name or t.name
            local is_selected = (cur == i)
            local disabled = active_indices[i] and not is_selected
            table.insert(
                self.dropdown_menu,
                {
                    name = displayName,
                    toolbar_index = i,
                    disabled = disabled,
                    menu_role = "existing"
                }
            )
        end

        -- Browsing saved toolbars never reads REAPER's menu file.
        if not controller.is_ephemeral then
            table.insert(self.dropdown_menu, { is_separator = true })
            table.insert(self.dropdown_menu, { name = "New Toolbar", menu_role = "new" })
            table.insert(self.dropdown_menu, { name = "Import REAPER Toolbar...", menu_role = "import" })
        end
    end,

    getValue = function(self)
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
        if not selected_item then
            return
        end
        if selected_item.disabled then
            return
        end
        local controller = findControllerForId(self._atb_controller_id)
        if not controller then
            return
        end
        if selected_item.menu_role == "new" then
            controller:createBlankToolbar()
            self:getValue()
            return
        elseif selected_item.menu_role == "import" then
            controller:showToolbarImport()
            return
        end

        if selected_item.toolbar_index then
            controller:setCurrentToolbarIndex(selected_item.toolbar_index)
            if selected_item.name then
                self.selected_text = selected_item.name
            end
        end
    end
}

return widget
