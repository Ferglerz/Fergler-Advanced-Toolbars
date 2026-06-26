-- widgets/toolbars_list.lua
-- Dropdown lists custom runtime toolbars first, then offers template creation from reaper-menu.ini.

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
    description = "Switch custom toolbars or create one from reaper-menu.ini templates",
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

        -- Section 2 heading + template list sourced from reaper-menu.ini.
        local ini_content = nil
        if C.IniManager then
            ini_content = C.IniManager:getContent()
            if not ini_content then
                ini_content = C.IniManager:loadContent(true)
            end
        end
        local templates = CONFIG_MANAGER:listTemplateEntriesFromIni(ini_content)
        if #templates > 0 then
            table.insert(self.dropdown_menu, { is_separator = true })
            table.insert(
                self.dropdown_menu,
                {
                    name = "Create new from:",
                    disabled = true,
                    is_heading = true
                }
            )

            for _, entry in ipairs(templates) do
                table.insert(
                    self.dropdown_menu,
                    {
                        name = entry.name,
                        template_section = entry.section,
                        menu_role = "template"
                    }
                )
            end
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
        if selected_item.menu_role == "template" and selected_item.template_section then
            if controller:createToolbarFromTemplate(selected_item.template_section) then
                local current = controller:getCurrentToolbar()
                if current then
                    self.selected_text = current.custom_name or current.name or self.selected_text
                end
            end
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
