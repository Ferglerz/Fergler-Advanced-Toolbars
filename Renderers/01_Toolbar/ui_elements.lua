-- Renderers/01_Toolbar/ui_elements.lua

function ToolbarWindow:renderUIElements(ctx, popup_open)
    local button_settings_menu = rawget(C, "ButtonSettingsMenu")
    local action_search = rawget(C, "ActionSearch")
    local icon_selector = rawget(C, "IconSelector")
    local button_dropdown_menu = rawget(C, "ButtonDropdownMenu")
    local button_dropdown_editor = rawget(C, "ButtonDropdownEditor")
    if popup_open
        or (C.Interactions and (C.Interactions.preset_browser_open or C.Interactions.insert_menu_button))
        or (button_settings_menu and button_settings_menu.widget_selection and button_settings_menu.widget_selection.is_open)
        or (button_settings_menu and button_settings_menu.dropdown_edit_button)
        or (action_search and action_search.is_open)
        or (icon_selector and icon_selector.is_open)
        or (button_dropdown_menu and button_dropdown_menu.is_open)
        or (button_dropdown_editor and button_dropdown_editor.is_open)
    then
        require("Systems.Modules_Factory").ensureUiModules()
    end

    if C.IconSelector and C.IconSelector.is_open then
        popup_open = C.IconSelector:renderGrid(ctx) or popup_open
    end

    if C.ButtonDropdownMenu and C.ButtonDropdownMenu.is_open then
        popup_open = C.ButtonDropdownMenu:renderDropdown(ctx) or popup_open
    end

    if C.Interactions and C.Interactions.insert_menu_button then
        popup_open = C.Interactions:renderInsertMenu(ctx) or popup_open
    end
    if C.ActionSearch then
        popup_open = C.ActionSearch:render(ctx) or popup_open
    end
    if C.Interactions and C.Interactions.preset_browser_open then
        C.Interactions:ensurePresetBrowserLoaded()
        popup_open = C.Interactions:renderPresetBrowserWindow(ctx) or popup_open
    end
    if C.Interactions then
        popup_open = C.Interactions:renderUnderMouseAutoArmNotice(ctx) or popup_open
    end

    button_settings_menu = rawget(C, "ButtonSettingsMenu")
    if button_settings_menu and button_settings_menu.widget_selection and button_settings_menu.widget_selection.is_open then
        popup_open = button_settings_menu:renderWidgetSelector(ctx) or popup_open
    end

    if button_settings_menu and button_settings_menu.dropdown_edit_button then
        self.toolbar_controller:showDropdownEditor(button_settings_menu.dropdown_edit_button, ctx)
        button_settings_menu.dropdown_edit_button = nil
    end

    if C.ButtonDropdownEditor and C.ButtonDropdownEditor.is_open then
        popup_open = C.ButtonDropdownEditor:renderDropdownEditor(ctx, C.ButtonDropdownEditor.current_button) or popup_open
    end

    -- GlobalColorEditor floating window is no longer used;
    -- colors are now rendered inline via the Colors tab in the settings popup.

    return popup_open
end
