-- Systems/Popup_Context.lua
local PopupContext = {}

function PopupContext.open(state, owner_ctx)
    if not state then
        return false
    end

    state.is_open = true
    state.owner_ctx = owner_ctx
    return true
end

function PopupContext.close(state)
    if not state then
        return false
    end

    state.is_open = false
    state.owner_ctx = nil
    return true
end

function PopupContext.shouldRender(state, ctx)
    if not state or not state.is_open then
        return false
    end

    if state.owner_ctx and ctx ~= state.owner_ctx then
        return false
    end

    return true
end

--- Close editors, menus, and optional insert/search chrome. opts: include_settings (default true),
--- include_insert_menu, include_action_search, focus_arrange, clear_popup_flag, icon_selector_cleanup (default true).
function PopupContext.closeAllAuxiliaryWindows(opts)
    opts = opts or {}
    local include_settings = opts.include_settings ~= false
    local icon_cleanup = opts.icon_selector_cleanup ~= false


    if _G.C and C.ButtonDropdownEditor then
        C.ButtonDropdownEditor.is_open = false
    end
    if _G.C and C.IconSelector then
        C.IconSelector.is_open = false
        if icon_cleanup and C.IconSelector.cleanup then
            C.IconSelector:cleanup()
        end
    end
    if _G.C and C.ButtonDropdownMenu then
        C.ButtonDropdownMenu.is_open = false
        C.ButtonDropdownMenu.owner_ctx = nil
    end
    if include_settings and _G.C then
        if C.ButtonSettingsMenu then
            C.ButtonSettingsMenu.is_open = false
        end
        if C.GlobalSettingsMenu then
            C.GlobalSettingsMenu.is_open = false
        end
    end
    if opts.include_insert_menu and _G.C and C.Interactions then
        C.Interactions.insert_menu_button = nil
        C.Interactions.insert_menu_owner_ctx = nil
        C.Interactions.insert_menu_popup_open = false
        C.Interactions.insert_menu_position = "before"
    end
    if opts.include_action_search and _G.C and C.ActionSearch and C.ActionSearch.is_open then
        C.ActionSearch:close()
    end
    if opts.clear_popup_flag then
        _G.POPUP_OPEN = false
    end
    if opts.focus_arrange and _G.UTILS then
        UTILS.focusArrangeWindow(true)
    end
end

return PopupContext
