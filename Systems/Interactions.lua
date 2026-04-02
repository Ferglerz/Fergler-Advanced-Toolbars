-- Systems/Interactions.lua

local Interactions = {}
Interactions.__index = Interactions

-- Delay before showing the edit-mode "Drag to move" hint (seconds).
local EDIT_MODE_DRAG_HINT_DELAY = 0.5

function Interactions.new()
    local self = setmetatable({}, Interactions)

    self.hover_start_times = {}
    self.active_buttons = {}

    self.is_mouse_down = false
    self.was_mouse_down = false

    self.dropdown_button = nil
    self.dropdown_position = nil
    self.button_settings_button = nil
    self.button_settings_group = nil

    self.insert_menu_button = nil
    self.insert_menu_owner_ctx = nil
    self.insert_menu_popup_open = false
    self.insert_menu_beginpopup_grace = 0
    self.preset_browser_open = false
    self.preset_browser_target_button = nil
    self.preset_browser_state = {is_open = false, owner_ctx = nil}
    self.preset_browser_path = {}
    self.preset_browser_selected_path = nil
    self.preset_browser_root = nil
    self.preset_browser_chunk_cache = {}
    self.under_mouse_auto_arm_notice_pending = false
    self.edit_mode_group_label_hover_times = {}

    return self
end

local function shouldShowUnderMouseAutoArmNotice()
    if not CONFIG or type(CONFIG.UI) ~= "table" then
        return true
    end
    if CONFIG.UI.SHOW_UNDER_MOUSE_CURSOR_AUTO_ARM_NOTICE == nil then
        return true
    end
    return CONFIG.UI.SHOW_UNDER_MOUSE_CURSOR_AUTO_ARM_NOTICE == true
end


function Interactions:setupInteractionArea(ctx, rel_x, rel_y, width, height, button_id)
    if not button_id then
        button_id = "unknown_" .. tostring(rel_x) .. "_" .. tostring(rel_y)
    end

    -- Use an invisible button to create the interactive hit area without style pushes per call
    local unique_id = button_id .. "_" .. tostring(math.floor(rel_x)) .. "_" .. tostring(math.floor(rel_y))

    reaper.ImGui_PushID(ctx, unique_id)
    reaper.ImGui_SetCursorPos(ctx, rel_x, rel_y)

    local clicked = reaper.ImGui_InvisibleButton(ctx, "##hit", width, height)
    local is_hovered = reaper.ImGui_IsItemHovered(ctx)
    local is_clicked = reaper.ImGui_IsItemActive(ctx)

    reaper.ImGui_PopID(ctx)

    return clicked, is_hovered, is_clicked
end

function Interactions:determineStateKey(button)
    -- Separators use their own color scheme
    if button:isSeparator() then
        return "SEPARATOR"
    end
    
    if button.is_toggled then
        return "TOGGLED"
    elseif button.is_armed then
        return button.is_flashing and "ARMED_FLASH" or "ARMED"
    else
        return "NORMAL"
    end
end

function Interactions:determineMouseKey(is_hovered, is_clicked)
    if is_clicked then
        return "CLICKED"
    elseif is_hovered then
        return "HOVER"
    else
        return "NORMAL"
    end
end

function Interactions:handleHover(ctx, button, is_hovered, is_editing_mode)
    -- Disable hover highlighting for separators in normal mode
    if button:isSeparator() and not is_editing_mode then
        button.is_hovered = false
    else
        button.is_hovered = is_hovered
    end
    button.is_right_clicked = is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1)

    local hover_time = 0
    if is_hovered then
        if not self.hover_start_times[button.instance_id] then
            self.hover_start_times[button.instance_id] = reaper.ImGui_GetTime(ctx)
        end
        hover_time = reaper.ImGui_GetTime(ctx) - self.hover_start_times[button.instance_id]

        if is_editing_mode then
            if not button.is_empty_toolbar_placeholder and
                not (C.DragDropManager and C.DragDropManager:isDragging()) and
                hover_time > EDIT_MODE_DRAG_HINT_DELAY then
                self:showEditModeDragHintTooltip(ctx, hover_time)
            end
        elseif hover_time > CONFIG.UI.HOVER_DELAY then
            self:showTooltip(ctx, button, hover_time)
        end
    else
        self.hover_start_times[button.instance_id] = nil
    end

    return hover_time
end

function Interactions:showEditModeDragHintTooltip(ctx, hover_time)
    local fade_progress = math.min((hover_time - EDIT_MODE_DRAG_HINT_DELAY) / 0.25, 1)
    reaper.ImGui_BeginTooltip(ctx)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
    reaper.ImGui_Text(ctx, "Drag to move")
    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_EndTooltip(ctx)
end

--- Group label hit area in edit mode: same delay/hint as toolbar buttons.
function Interactions:updateEditModeGroupLabelDragHint(ctx, hover_key, is_hovered)
    if not is_hovered then
        self.edit_mode_group_label_hover_times[hover_key] = nil
        return
    end
    if C.DragDropManager and C.DragDropManager:isDragging() then
        return
    end
    if not self.edit_mode_group_label_hover_times[hover_key] then
        self.edit_mode_group_label_hover_times[hover_key] = reaper.ImGui_GetTime(ctx)
    end
    local hover_time = reaper.ImGui_GetTime(ctx) - self.edit_mode_group_label_hover_times[hover_key]
    if hover_time > EDIT_MODE_DRAG_HINT_DELAY then
        self:showEditModeDragHintTooltip(ctx, hover_time)
    end
end

function Interactions:showTooltip(ctx, button, hover_time)
    if BUTTON_UTILS.shouldSuppressWidgetTooltip(button) then
        return
    end
    local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)
    
    -- Separators get simple tooltips
    if button:isSeparator() then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
        reaper.ImGui_Text(ctx, "Separator")
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_EndTooltip(ctx)
        return
    end
    
    if BUTTON_UTILS.hasWidgetDescription(button) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
        reaper.ImGui_Text(ctx, button.widget.description)
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_EndTooltip(ctx)
    else
        local command_id = C.ButtonManager:getCommandID(button.id)
        local action_name = command_id and reaper.CF_GetCommandText(0, command_id)

        if action_name and action_name ~= "" then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
            reaper.ImGui_Text(ctx, action_name)
            reaper.ImGui_PopStyleVar(ctx)
            reaper.ImGui_EndTooltip(ctx)
        end
    end
end

function Interactions:showDropdownMenu(ctx, button, position)
    if not button then
        return false
    end
    
    if not button.dropdown_menu or #button.dropdown_menu == 0 then
        -- Widget dropdowns populate themselves; still open the popup so the user sees an empty
        -- state (e.g. "No regions") instead of nothing happening on click.
        local is_widget_dropdown = (button.instance_id and button.instance_id:match("^widget_dropdown_")) or button.widget_ref ~= nil
        if is_widget_dropdown then
            self.dropdown_button = button
            self.dropdown_position = position
            if C.PopupContext then
                C.PopupContext.open(C.ButtonDropdownMenu, ctx)
            else
                C.ButtonDropdownMenu.is_open = true
                C.ButtonDropdownMenu.owner_ctx = ctx
            end
            C.ButtonDropdownMenu.current_button = button
            C.ButtonDropdownMenu.current_position = position
            C.ButtonDropdownMenu.beginpopup_grace = 3
            _G.POPUP_OPEN = true
            reaper.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.instance_id)
            return true
        end
        if C.ButtonDropdownEditor then
            if C.ButtonDropdownEditor.show then
                C.ButtonDropdownEditor:show(button, ctx)
            else
                C.ButtonDropdownEditor.is_open = true
                C.ButtonDropdownEditor.current_button = button
                C.ButtonDropdownEditor.owner_ctx = ctx
            end
            _G.POPUP_OPEN = true
            return true
        end
        return false
    end

    self.dropdown_button = button
    self.dropdown_position = position

    if C.PopupContext then
        C.PopupContext.open(C.ButtonDropdownMenu, ctx)
    else
        C.ButtonDropdownMenu.is_open = true
        C.ButtonDropdownMenu.owner_ctx = ctx
    end
    C.ButtonDropdownMenu.current_button = button
    C.ButtonDropdownMenu.current_position = position
    C.ButtonDropdownMenu.beginpopup_grace = 3
    _G.POPUP_OPEN = true

    reaper.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.instance_id)

    return true
end

function Interactions:showButtonSettings(button, group)
    self.button_settings_button = button
    self.button_settings_group = group
    _G.POPUP_OPEN = true
    return true
end

function Interactions:openInsertMenu(ctx, button)
    if not button or button:isSeparator() then
        return false
    end
    self.insert_menu_button = button
    self.insert_menu_owner_ctx = ctx
    self.insert_menu_popup_open = false
    self.insert_menu_beginpopup_grace = 3
    self:resetPresetBrowserState()
    _G.POPUP_OPEN = true
    return true
end

function Interactions:queueUnderMouseAutoArmNotice()
    if not shouldShowUnderMouseAutoArmNotice() then
        return false
    end
    self.under_mouse_auto_arm_notice_pending = true
    return true
end

function Interactions:renderUnderMouseAutoArmNotice(ctx)
    if not shouldShowUnderMouseAutoArmNotice() then
        self.under_mouse_auto_arm_notice_pending = false
        return false
    end

    if self.under_mouse_auto_arm_notice_pending then
        reaper.ImGui_OpenPopup(ctx, "under_mouse_auto_arm_notice")
        self.under_mouse_auto_arm_notice_pending = false
    end

    local visible = reaper.ImGui_BeginPopupModal(ctx, "under_mouse_auto_arm_notice", nil)
    if not visible then
        return false
    end

    _G.POPUP_OPEN = true
    reaper.ImGui_TextWrapped(
        ctx,
        "Actions with \"under mouse cursor\" in the name automatically arm when left-clicked."
    )
    reaper.ImGui_Separator(ctx)

    if reaper.ImGui_Button(ctx, "Ok", 140, 0) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Ok, don't show again", 220, 0) then
        CONFIG.UI = CONFIG.UI or {}
        CONFIG.UI.SHOW_UNDER_MOUSE_CURSOR_AUTO_ARM_NOTICE = false
        CONFIG_MANAGER:saveMainConfig()
        reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
    return true
end

function Interactions:renderInsertMenu(ctx)
    if not self.insert_menu_button then
        return false
    end
    if self.insert_menu_owner_ctx and ctx ~= self.insert_menu_owner_ctx then
        return true
    end

    _G.POPUP_OPEN = true
    local target = self.insert_menu_button
    local popup_id = "insert_toolbar_item_" .. target.instance_id

    if not self.insert_menu_popup_open then
        reaper.ImGui_OpenPopup(ctx, popup_id)
        self.insert_menu_popup_open = true
    end

    local colorCount, styleCount = C.GlobalStyle.apply(ctx, {styles = false})
    local visible = reaper.ImGui_BeginPopup(ctx, popup_id)

    if visible then
        local function closeInsertPopup()
            reaper.ImGui_CloseCurrentPopup(ctx)
            self.insert_menu_button = nil
            self.insert_menu_owner_ctx = nil
            self.insert_menu_popup_open = false
        end

        self.insert_menu_beginpopup_grace = 0
        if C.ActionSearch and reaper.ImGui_MenuItem(ctx, "Button (choose action)…") then
            C.ActionSearch:open({ mode = "insert_before", insert_anchor = target, ctx = ctx })
            closeInsertPopup()
        elseif reaper.ImGui_MenuItem(ctx, "Button") then
            C.ButtonRenderer:handleAddButton(target)
            closeInsertPopup()
        elseif reaper.ImGui_MenuItem(ctx, "Separator") then
            C.ButtonRenderer:handleAddSeparator(target)
            closeInsertPopup()
        elseif WIDGETS and reaper.ImGui_MenuItem(ctx, "Widget") then
            C.ButtonSettingsMenu:showWidgetSelector(
                target,
                {
                    insert_new_button = true,
                    target_button = target,
                    position = "before"
                }
            )
            closeInsertPopup()
        end

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Open Preset Browser (WIP)...") then
            self:openPresetBrowser(ctx, target)
            closeInsertPopup()
        end
        reaper.ImGui_EndPopup(ctx)
    else
        if reaper.ImGui_IsPopupOpen(ctx, popup_id) then
            self.insert_menu_beginpopup_grace = 0
        elseif (self.insert_menu_beginpopup_grace or 0) > 0 then
            self.insert_menu_beginpopup_grace = self.insert_menu_beginpopup_grace - 1
        else
            self.insert_menu_button = nil
            self.insert_menu_owner_ctx = nil
            self.insert_menu_popup_open = false
        end
    end

    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    return self.insert_menu_button ~= nil
end


function Interactions:showGlobalColorEditor(show, owner_ctx)
    if not C.GlobalColorEditor then
        return false
    end

    if C.GlobalColorEditor.show then
        C.GlobalColorEditor:show(show or false, owner_ctx)
    else
        C.GlobalColorEditor.is_open = show or false
        C.GlobalColorEditor.owner_ctx = show and owner_ctx or nil
    end
    if show then
        _G.POPUP_OPEN = true
    end
    return true
end

function Interactions:showIconSelector(button, owner_ctx)
    if not C.IconSelector then
        return false
    end

    C.IconSelector:show(button, owner_ctx)
    _G.POPUP_OPEN = true
    return true
end

function Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)
    if not is_hovered or not reaper.ImGui_IsMouseClicked(ctx, 1) then
        return false
    end

    local key_mods = reaper.ImGui_GetKeyMods(ctx)
    local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0
    
    -- Separators only support settings menu in edit mode or with Ctrl
    if button:isSeparator() then
        if is_cmd_down or editing_mode then
            self:showButtonSettings(button, button.parent_group)
            reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
        end
        return true
    end
    
    -- Normal button right-click behavior
    if is_cmd_down or editing_mode then
        self:showButtonSettings(button, button.parent_group)
        reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
    elseif button.right_click == "dropdown" then
        local x, y = reaper.ImGui_GetMousePos(ctx)
        self:showDropdownMenu(ctx, button, {x = x, y = y})
    elseif button.right_click == "launch" and button.right_click_action then
        self:executeRightClickAction(button)
    elseif button.right_click == "arm" and not BUTTON_UTILS.isWidgetSlider(button) then
        C.ButtonManager:toggleArmCommand(button)
    end

    return true
end

function Interactions:executeRightClickAction(button)
    if not button or not button.right_click_action or button.right_click_action == "" then
        return false
    end

    local cmdID
    if button.right_click_action:match("^_") then
        cmdID = reaper.NamedCommandLookup(button.right_click_action)
    else
        cmdID = tonumber(button.right_click_action)
    end

    if cmdID and cmdID ~= 0 then
        reaper.Main_OnCommand(cmdID, 0)
        return true
    end

    return false
end

function Interactions:cleanup()
    self.hover_start_times = {}
    self.edit_mode_group_label_hover_times = {}
    self.dropdown_button = nil
    self.dropdown_position = nil
    self.button_settings_button = nil
    self.button_settings_group = nil
    self.insert_menu_button = nil
    self.insert_menu_owner_ctx = nil
    self.insert_menu_popup_open = false
    self.insert_menu_beginpopup_grace = 0
    self:closePresetBrowser()
    self.preset_browser_root = nil
    self.preset_browser_chunk_cache = {}
    self.under_mouse_auto_arm_notice_pending = false
    self.was_mouse_down = false
    self.is_mouse_down = false
end

local Interactions_Preset_Browser = require("Systems.Interactions_Preset_Browser")
for k, v in pairs(Interactions_Preset_Browser) do
    Interactions[k] = v
end

return Interactions.new()