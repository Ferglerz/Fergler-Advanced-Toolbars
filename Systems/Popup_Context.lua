-- Systems/Popup_Context.lua
local PopupContext = {}
local KEYBOARD_EDITORS = {"IconSelector", "ButtonDropdownEditor", "ActionSearch", "ButtonDropdownMenu", "ToolbarImport"}

-- Helper for wrapping window rendering in global style
function PopupContext.withGlobalStyle(ctx, render_fn, options)
    if _G.C and C.GlobalStyle and C.GlobalStyle.withGlobalStyle then
        return C.GlobalStyle.withGlobalStyle(ctx, render_fn, options)
    end
    return render_fn()
end

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

-- Evaluate after every window for this context has rendered, including ruler and
-- widget-native popups that do not participate in the editor state flags.
function PopupContext.updateKeyboardCapture(ctx)
    if not reaper.ImGui_SetNextFrameWantCaptureKeyboard or not reaper.ImGui_IsAnyItemActive then
        return
    end
    local capture = reaper.ImGui_IsAnyItemActive(ctx)
    if reaper.ImGui_IsPopupOpen and reaper.ImGui_PopupFlags_AnyPopupId then
        local flags = reaper.ImGui_PopupFlags_AnyPopupId()
        if reaper.ImGui_PopupFlags_AnyPopupLevel then
            flags = flags | reaper.ImGui_PopupFlags_AnyPopupLevel()
        end
        capture = capture or reaper.ImGui_IsPopupOpen(ctx, "", flags)
    end
    if _G.C then
        for _, name in ipairs(KEYBOARD_EDITORS) do
            capture = capture or PopupContext.shouldRender(rawget(C, name), ctx)
        end
        local settings = rawget(C, "ButtonSettingsMenu")
        capture = capture or PopupContext.shouldRender(settings and settings.widget_selection, ctx)
        local interactions = rawget(C, "Interactions")
        capture = capture or PopupContext.shouldRender(interactions and interactions.preset_browser_state, ctx)
    end
    reaper.ImGui_SetNextFrameWantCaptureKeyboard(ctx, capture)
    return capture
end

-- DRY Helpers for components that might not have C available yet
function PopupContext.openOrFallback(state, owner_ctx)
    if _G.C and C.PopupContext then
        C.PopupContext.open(state, owner_ctx)
    else
        state.is_open = true
        state.owner_ctx = owner_ctx
    end
end

function PopupContext.closeOrFallback(state)
    if _G.C and C.PopupContext then
        C.PopupContext.close(state)
    else
        state.is_open = false
        state.owner_ctx = nil
    end
end

function PopupContext.guardRender(state, ctx)
    if _G.C and C.PopupContext then
        if not C.PopupContext.shouldRender(state, ctx) then
            if not state or not state.is_open then
                _G.POPUP_OPEN = false
            end
            return false
        end
    elseif not state.is_open then
        _G.POPUP_OPEN = false
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

    if not _G.C then return end

    local components = {
        ToolbarImport = true,
        ButtonDropdownEditor = true,
        IconSelector = true,
        ButtonDropdownMenu = true,
        ButtonSettingsMenu = include_settings,
        GlobalSettingsMenu = include_settings,
        ActionSearch = opts.include_action_search
    }

    for name, should_close in pairs(components) do
        local state = C[name]
        if state and should_close then
            if name == "ActionSearch" then
                if state.is_open and state.close then state:close() end
            else
                state.is_open = false
                if name == "IconSelector" and icon_cleanup and state.cleanup then
                    state:cleanup()
                end
                if name == "ButtonDropdownMenu" then
                    state.owner_ctx = nil
                end
            end
        end
    end

    -- Handle interactions specific menu
    if opts.include_insert_menu and _G.C and C.Interactions then
        C.Interactions.insert_menu_button = nil
        C.Interactions.insert_menu_owner_ctx = nil
        C.Interactions.insert_menu_popup_open = false
        C.Interactions.insert_menu_position = "before"
    end

    if opts.clear_popup_flag then
        _G.POPUP_OPEN = false
    end
    if opts.focus_arrange and _G.UTILS then
        UTILS.focusArrangeWindow(true)
    end
end

return PopupContext
