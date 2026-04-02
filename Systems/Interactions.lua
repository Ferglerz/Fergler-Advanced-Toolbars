-- Systems/Interactions.lua
local ACTION_CATALOG_MANIFEST = require("Data.reaper_actions.category_manifest")

local Interactions = {}
Interactions.__index = Interactions

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

local function clonePath(src, max_depth)
    local out = {}
    if type(src) ~= "table" then
        return out
    end
    local limit = max_depth or #src
    for i = 1, limit do
        out[i] = src[i]
    end
    return out
end

local function pathsEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function stripClusterLabelDetails(label)
    local s = tostring(label or "")
    local cluster = s:match("([Cc]luster%s+%d+)")
    if cluster and cluster ~= "" then
        return cluster:gsub("^%l", string.upper)
    end
    s = s:gsub("%s*%b()", "")
    s = s:gsub("%s+$", "")
    if s == "" then
        return tostring(label or "Cluster")
    end
    return s
end

-- Preset browser list striping: shared hover/active; stripe pair differs for card vs plain panel.
local PRESET_ROW_ACTIVE = 0x3D4654FF
local PRESET_ROW_HOVER = 0x3A3A3AFF

local function presetBrowserZebraColors(is_even, variant)
    local stripe_a, stripe_b
    if variant == "card" then
        stripe_a, stripe_b = 0x2E2E2EFF, 0x2C2C2CFF
    else
        stripe_a, stripe_b = 0x353535FF, 0x343434FF
    end
    local stripe = is_even and stripe_a or stripe_b
    return stripe, PRESET_ROW_HOVER, PRESET_ROW_ACTIVE
end

local function simplifyActionDisplayLabel(label)
    local s = tostring(label or "")
    local stripped = s:gsub("^%s*[^:]+:%s*", "")
    stripped = stripped:gsub("^%s+", ""):gsub("%s+$", "")
    if stripped == "" then
        return s
    end
    return stripped
end

local function selectableWithRowStyle(ctx, label, selected, left_pad, row_h, base_col, hover_col, active_col)
    local base_x = reaper.ImGui_GetCursorPosX(ctx)
    reaper.ImGui_SetCursorPosX(ctx, base_x + (left_pad or 0))
    local pushed = false
    if base_col and reaper.ImGui_Col_Header then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), base_col)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), hover_col or base_col)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), active_col or base_col)
        pushed = true
    end
    local ok, clicked = pcall(reaper.ImGui_Selectable, ctx, label, selected)
    if pushed then
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_PopStyleColor(ctx)
    end
    if not ok then
        return false
    end
    return clicked
end

function Interactions:resetPresetBrowserState()
    self.preset_browser_path = {}
    self.preset_browser_selected_path = nil
end

function Interactions:openPresetBrowser(owner_ctx, target_button)
    if not target_button or target_button:isSeparator() then
        return false
    end
    self.preset_browser_target_button = target_button
    if C.PopupContext then
        C.PopupContext.open(self.preset_browser_state, owner_ctx)
    else
        self.preset_browser_state.is_open = true
        self.preset_browser_state.owner_ctx = owner_ctx
    end
    self.preset_browser_open = true
    self:resetPresetBrowserState()
    _G.POPUP_OPEN = true
    return true
end

function Interactions:closePresetBrowser()
    if C.PopupContext then
        C.PopupContext.close(self.preset_browser_state)
    else
        self.preset_browser_state.is_open = false
        self.preset_browser_state.owner_ctx = nil
    end
    self.preset_browser_open = false
    self.preset_browser_target_button = nil
    self:resetPresetBrowserState()
end

function Interactions:isPresetBrowserOpen()
    if C.PopupContext then
        return self.preset_browser_state and self.preset_browser_state.is_open == true
    end
    return self.preset_browser_open == true
end

function Interactions:getPresetBrowserRoot()
    if self.preset_browser_root then
        return self.preset_browser_root
    end

    local root = {
        id = "root",
        label = "REAPER actions",
        kind = "root",
        children = {}
    }

    for _, cat in ipairs((ACTION_CATALOG_MANIFEST and ACTION_CATALOG_MANIFEST.categories) or {}) do
        local cat_node = {
            id = tostring(cat.id or cat.label or "category"),
            label = tostring(cat.label or "Category"),
            kind = "folder",
            children = {}
        }

        for _, subcat in ipairs(cat.subcategories or {}) do
            local subcat_label = tostring(subcat.label or "Subcategory")
            local is_all_actions = subcat_label:lower() == "all actions"
            local subcat_children = cat_node.children
            if not is_all_actions then
                local subcat_node = {
                    id = tostring(subcat.id or subcat.label or "subcategory"),
                    label = subcat_label,
                    kind = "folder",
                    children = {}
                }
                table.insert(cat_node.children, subcat_node)
                subcat_children = subcat_node.children
            end

            for _, rel_file in ipairs(subcat.files or {}) do
                local file_label = tostring(rel_file or ""):gsub("^.+/", ""):gsub("%.lua$", "")
                table.insert(
                    subcat_children,
                    {
                        id = tostring(rel_file),
                        label = file_label ~= "" and file_label or "Action group",
                        kind = "lua_table",
                        file_rel_path = tostring(rel_file),
                        children = nil
                    }
                )
            end
        end

        table.insert(root.children, cat_node)
    end

    self.preset_browser_root = root
    return root
end

function Interactions:loadActionChunk(file_rel_path)
    local rel = tostring(file_rel_path or "")
    if rel == "" then
        return nil
    end
    if self.preset_browser_chunk_cache[rel] ~= nil then
        return self.preset_browser_chunk_cache[rel]
    end

    local full_path = UTILS.joinPath(SCRIPT_PATH, rel)
    local chunk_fn = loadfile(full_path)
    if not chunk_fn then
        self.preset_browser_chunk_cache[rel] = false
        return nil
    end
    local ok, chunk = pcall(chunk_fn)
    if not ok or type(chunk) ~= "table" then
        self.preset_browser_chunk_cache[rel] = false
        return nil
    end
    self.preset_browser_chunk_cache[rel] = chunk
    return chunk
end

function Interactions:ensurePresetNodeChildrenLoaded(node)
    if not node or node.kind ~= "lua_table" then
        return
    end
    if type(node.children) == "table" then
        return
    end

    node.children = {}
    local chunk = self:loadActionChunk(node.file_rel_path)
    if not chunk then
        return
    end

    -- Use semantic group label when available.
    if type(chunk.group_label) == "string" and chunk.group_label ~= "" then
        node.label = chunk.group_label
    end

    for idx, action in ipairs(chunk.actions or {}) do
        local action_id = tostring(action.command_id or "")
        if action_id ~= "" then
            table.insert(
                node.children,
                {
                    id = tostring(chunk.group_id or node.file_rel_path or "group") .. "_action_" .. tostring(idx),
                    label = simplifyActionDisplayLabel(tostring(action.title or action.action_key or ("Action " .. tostring(idx)))),
                    kind = "action_button",
                    action_row = {
                        name = tostring(action.title or action.action_key or "Action"),
                        action_id = action_id
                    }
                }
            )
        end
    end
end

function Interactions:collectToolbarRowsFromNode(node)
    if not node then
        return {}
    end
    if node.kind == "action_button" and node.action_row then
        return { node.action_row }
    end
    if node.kind ~= "lua_table" then
        return {}
    end

    local chunk = self:loadActionChunk(node.file_rel_path)
    local rows = {}
    for _, action in ipairs((chunk and chunk.actions) or {}) do
        local aid = tostring(action.command_id or "")
        if aid ~= "" then
            table.insert(
                rows,
                {
                    name = tostring(action.title or action.action_key or "Action"),
                    action_id = aid
                }
            )
        end
    end
    return rows
end

function Interactions:resolvePresetNode(path)
    local node = self:getPresetBrowserRoot()
    if type(path) ~= "table" then
        return node
    end
    for _, child_index in ipairs(path) do
        self:ensurePresetNodeChildrenLoaded(node)
        if not node or not node.children or not node.children[child_index] then
            return nil
        end
        node = node.children[child_index]
    end
    return node
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

        if not is_editing_mode and hover_time > CONFIG.UI.HOVER_DELAY then
            self:showTooltip(ctx, button, hover_time)
        end
    else
        self.hover_start_times[button.instance_id] = nil
    end

    return hover_time
end

function Interactions:showTooltip(ctx, button, hover_time)
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
        if reaper.ImGui_MenuItem(ctx, "Button") then
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

function Interactions:renderPresetBrowserWindow(ctx)
    if C.PopupContext then
        if not C.PopupContext.shouldRender(self.preset_browser_state, ctx) then
            -- Another toolbar/controller context is rendering this frame.
            -- Keep the window state open; only the owner context should draw it.
            return false
        end
    elseif not self.preset_browser_state.is_open then
        self.preset_browser_open = false
        return false
    end

    self.preset_browser_open = true
    local target = self.preset_browser_target_button
    if not target or target:isSeparator() then
        self:closePresetBrowser()
        return false
    end

    local function tryInsertPresetNode(node)
        if not node then
            return false
        end
        local rows = self:collectToolbarRowsFromNode(node)
        if #rows > 0 then
            local ok = false
            if node.kind == "lua_table" and C.IniManager.insertPresetGroupAfterCurrentGroup then
                ok = C.IniManager:insertPresetGroupAfterCurrentGroup(target, rows)
            else
                ok = C.IniManager:insertPresetButtonSequence(target, rows, "before")
            end
            if ok then
                self:closePresetBrowser()
                return true
            end
        end
        return false
    end

    _G.POPUP_OPEN = true
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)
    reaper.ImGui_SetNextWindowSize(ctx, 900, 500, reaper.ImGui_Cond_FirstUseEver())
    local window_flags = 0
    if reaper.ImGui_WindowFlags_NoDocking then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoDocking()
    end
    local visible, keep_open = reaper.ImGui_Begin(ctx, "Preset Browser (WIP)", true, window_flags)
    if not keep_open or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
        self:closePresetBrowser()
        reaper.ImGui_End(ctx)
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        return false
    end

    if visible then
        reaper.ImGui_TextWrapped(ctx,
            'Vectorized and curated list of actions, grouped together to get you started adding banks of toolbar buttons. Very work in progress. "Clusters" are vector sorting outputs and will eventually be given definitive names. MIDI actions and actions which are duplicated across a range of numbers (like Select track 1/2/3/etc) are intentionally omitted along with the non-toggle versions of options.')
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        local root = self:getPresetBrowserRoot()
        local panel_count = math.max(2, (#self.preset_browser_path or 0) + 1)
        local spacing = 14
        local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
        local panel_height = -78
        local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
        local min_panel_w = 140
        local min_last_panel_w = 180
        local max_non_last_panel_w = 420
        local text_pad_w = 40
        local row_left_pad = 16
        local row_h = reaper.ImGui_GetTextLineHeightWithSpacing(ctx) + 12

        local function parentForPanel(panel_index)
            if panel_index <= 1 then
                return root
            end
            if not self.preset_browser_path or #self.preset_browser_path < (panel_index - 1) then
                return nil
            end
            return self:resolvePresetNode(clonePath(self.preset_browser_path, panel_index - 1))
        end

        local function panelContentTextWidth(panel_index)
            local parent_node = parentForPanel(panel_index)
            local max_w = 0
            if not parent_node or not parent_node.children then
                return max_w
            end

            local all_lua_tables = true
            for _, node in ipairs(parent_node.children) do
                if node.kind ~= "lua_table" then
                    all_lua_tables = false
                    break
                end
            end

            if all_lua_tables then
                for _, table_node in ipairs(parent_node.children) do
                    self:ensurePresetNodeChildrenLoaded(table_node)
                    local tw = reaper.ImGui_CalcTextSize(ctx, stripClusterLabelDetails(table_node.label or "Cluster"))
                    if tw > max_w then
                        max_w = tw
                    end
                    for _, action_node in ipairs(table_node.children or {}) do
                        local aw = reaper.ImGui_CalcTextSize(ctx, tostring(action_node.label or "Action"))
                        if aw > max_w then
                            max_w = aw
                        end
                    end
                end
            else
                for _, child in ipairs(parent_node.children) do
                    local label = tostring(child.label or "Item")
                    if child.kind == "lua_table" then
                        label = stripClusterLabelDetails(label)
                    end
                    local w = reaper.ImGui_CalcTextSize(ctx, label)
                    if w > max_w then
                        max_w = w
                    end
                end
            end

            return max_w
        end

        local panel_widths = {}
        local used_non_last_w = 0
        for i = 1, panel_count - 1 do
            local content_w = panelContentTextWidth(i)
            local cap_w = math.max(min_panel_w, math.min(max_non_last_panel_w, content_w + text_pad_w))
            panel_widths[i] = cap_w
            used_non_last_w = used_non_last_w + cap_w
        end

        local spacing_total_w = spacing * (panel_count - 1)
        local last_w = avail_w - spacing_total_w - used_non_last_w
        if last_w < min_last_panel_w then
            local need = min_last_panel_w - last_w
            for i = panel_count - 1, 1, -1 do
                local reducible = math.max(0, panel_widths[i] - min_panel_w)
                local take = math.min(reducible, need)
                panel_widths[i] = panel_widths[i] - take
                need = need - take
                if need <= 0 then
                    break
                end
            end
            used_non_last_w = 0
            for i = 1, panel_count - 1 do
                used_non_last_w = used_non_last_w + panel_widths[i]
            end
            last_w = avail_w - spacing_total_w - used_non_last_w
        end
        panel_widths[panel_count] = math.max(min_last_panel_w, last_w)

        local inserted_now = false
        for panel_index = 1, panel_count do
            local parent_node = parentForPanel(panel_index)
            local panel_id = "PresetBrowserPanelWindow_" .. tostring(panel_index)
            reaper.ImGui_BeginChild(ctx, panel_id, panel_widths[panel_index] or min_panel_w, panel_height, child_flags)
            if parent_node and parent_node.children and #parent_node.children > 0 then
                    local all_lua_tables = true
                    for _, node in ipairs(parent_node.children) do
                        if node.kind ~= "lua_table" then
                            all_lua_tables = false
                            break
                        end
                    end

                    if all_lua_tables then
                        for table_index, table_node in ipairs(parent_node.children) do
                            self:ensurePresetNodeChildrenLoaded(table_node)
                            local selected_path = self.preset_browser_selected_path or {}
                            local table_path = clonePath(self.preset_browser_path, panel_index - 1)
                            table_path[panel_index] = table_index
                            local table_selected = pathsEqual(selected_path, table_path)
                            local table_label = stripClusterLabelDetails(table_node.label or "Cluster")
                            local actions = table_node.children or {}
                            local card_pad = 14
                            local card_gap = 16
                            local card_pad_top = 12
                            local gap_header_to_actions = 10
                            local n_actions = #actions
                            local card_border = 0x555555FF
                            local card_round = 6
                            local card_bleed = 3
                            local dl = reaper.ImGui_GetWindowDrawList(ctx)
                            -- Do not use DrawList_ChannelsSplit here: it can desync Reaper ImGui's window
                            -- stack so the column panel's EndChild asserts (non-child current window).

                            reaper.ImGui_PushID(ctx, string.format("clu_%d_%d_%s", panel_index, table_index, tostring(table_node.id)))
                            reaper.ImGui_BeginGroup(ctx)
                            reaper.ImGui_Dummy(ctx, 0, card_pad_top)
                            reaper.ImGui_Indent(ctx, card_pad)
                            local frame_rounding_pushed = false
                            local card_ok, card_err = pcall(function()
                                local chip_w = reaper.ImGui_CalcTextSize(ctx, "Add group") + 24
                                local avail_row = reaper.ImGui_GetContentRegionAvail(ctx)
                                local header_w = math.max(50, avail_row - chip_w - 16)
                                local header_base = table_selected and 0x3D4654FF or 0x1E1E1EFF

                                local cluster_label = table_label .. "##cluster_" .. tostring(table_node.id)
                                local cluster_clicked = false
                                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), header_base)
                                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x2A2A2AFF)
                                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), 0x3D4654FF)
                                local hdr_ok, hdr_err = pcall(function()
                                    local sel_ok = pcall(function()
                                        cluster_clicked = reaper.ImGui_Selectable(
                                            ctx,
                                            cluster_label,
                                            table_selected,
                                            0,
                                            header_w,
                                            row_h
                                        )
                                    end)
                                    if not sel_ok then
                                        cluster_clicked = reaper.ImGui_Selectable(ctx, cluster_label, table_selected, 0, header_w)
                                    end
                                end)
                                reaper.ImGui_PopStyleColor(ctx)
                                reaper.ImGui_PopStyleColor(ctx)
                                reaper.ImGui_PopStyleColor(ctx)
                                if not hdr_ok then
                                    error(hdr_err)
                                end

                                if cluster_clicked then
                                    self.preset_browser_selected_path = clonePath(table_path)
                                    if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                                        if tryInsertPresetNode(table_node) then
                                            inserted_now = true
                                        end
                                    end
                                end

                                reaper.ImGui_SameLine(ctx, 0, 8)
                                local line_h = reaper.ImGui_GetTextLineHeightWithSpacing(ctx)
                                local push_ok, push_err = pcall(
                                    reaper.ImGui_PushStyleVar,
                                    ctx,
                                    reaper.ImGui_StyleVar_FrameRounding(),
                                    10
                                )
                                if not push_ok then
                                    error(push_err)
                                end
                                frame_rounding_pushed = true
                                local btn_ok, add_group_pressed = pcall(
                                    reaper.ImGui_Button,
                                    ctx,
                                    "Add group##addgrp_" .. tostring(table_node.id),
                                    chip_w,
                                    line_h + 2
                                )
                                if frame_rounding_pushed then
                                    reaper.ImGui_PopStyleVar(ctx)
                                    frame_rounding_pushed = false
                                end
                                if not btn_ok then
                                    error(add_group_pressed)
                                end
                                if add_group_pressed then
                                    self.preset_browser_selected_path = clonePath(table_path)
                                    if tryInsertPresetNode(table_node) then
                                        inserted_now = true
                                    end
                                end

                                if n_actions > 0 then
                                    reaper.ImGui_Dummy(ctx, 0, gap_header_to_actions)
                                end

                                for action_index, action_node in ipairs(actions) do
                                    if inserted_now then
                                        break
                                    end
                                    local action_path = clonePath(table_path)
                                    action_path[panel_index + 1] = action_index
                                    local action_selected = pathsEqual(selected_path, action_path)
                                    local action_label = tostring(action_node.label or "Action") .. "##action_" .. tostring(action_node.id)
                                    local is_even = (action_index % 2) == 0
                                    local stripe_col, hover_col, active_col = presetBrowserZebraColors(is_even, "card")
                                    local base_col = action_selected and active_col or stripe_col
                                    if selectableWithRowStyle(
                                        ctx,
                                        action_label,
                                        action_selected,
                                        4,
                                        row_h,
                                        base_col,
                                        hover_col,
                                        active_col
                                    ) then
                                        self.preset_browser_selected_path = clonePath(action_path)
                                        if tryInsertPresetNode(action_node) then
                                            inserted_now = true
                                            break
                                        end
                                    end
                                end
                            end)
                            reaper.ImGui_Unindent(ctx, card_pad)
                            reaper.ImGui_EndGroup(ctx)

                            if frame_rounding_pushed then
                                reaper.ImGui_PopStyleVar(ctx)
                                frame_rounding_pushed = false
                            end

                            if card_ok then
                                local imx, imy = reaper.ImGui_GetItemRectMin(ctx)
                                local amx, amy = reaper.ImGui_GetItemRectMax(ctx)
                                local bx1 = imx - card_bleed
                                local by1 = imy - card_bleed
                                local bx2 = amx + card_bleed
                                local by2 = amy + card_bleed
                                if bx1 < bx2 and by1 < by2 then
                                    -- No channel split (Reaper stack bug): light fill + border drawn after widgets.
                                    reaper.ImGui_DrawList_AddRectFilled(dl, bx1, by1, bx2, by2, 0x28282833, card_round)
                                    reaper.ImGui_DrawList_AddRect(dl, bx1, by1, bx2, by2, card_border, card_round)
                                end
                            end

                            reaper.ImGui_PopID(ctx)

                            if not card_ok then
                                reaper.ShowConsoleMsg(
                                    "Advanced Toolbars: Preset browser cluster: " .. tostring(card_err) .. "\n"
                                )
                            end

                            if inserted_now then
                                break
                            end

                            reaper.ImGui_Dummy(ctx, 0, card_gap)
                        end
                    else
                        for child_index, child in ipairs(parent_node.children) do
                            self:ensurePresetNodeChildrenLoaded(child)
                            local selected_path = self.preset_browser_selected_path or {}
                            local candidate_path = clonePath(self.preset_browser_path, panel_index - 1)
                            candidate_path[panel_index] = child_index
                            local is_selected = pathsEqual(selected_path, candidate_path)
                            local has_children = child.kind == "folder" or child.kind == "lua_table" or (child.children and #child.children > 0)
                            local label = tostring(child.label or "Item") .. "##window_" .. tostring(child.id)
                            local is_even = (child_index % 2) == 0
                            local stripe_col, hover_col, active_col = presetBrowserZebraColors(is_even, "panel")
                            local base_col = is_selected and active_col or stripe_col
                            if selectableWithRowStyle(
                                ctx,
                                label,
                                is_selected,
                                row_left_pad,
                                row_h,
                                base_col,
                                hover_col,
                                active_col
                            ) then
                                local next_path = clonePath(self.preset_browser_path, panel_index - 1)
                                next_path[panel_index] = child_index
                                self.preset_browser_selected_path = clonePath(next_path)

                                if has_children then
                                    self.preset_browser_path = clonePath(next_path)
                                end

                                if child.kind == "action_button" then
                                    if tryInsertPresetNode(child) then
                                        inserted_now = true
                                        break
                                    end
                                elseif child.kind == "lua_table" and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                                    if tryInsertPresetNode(child) then
                                        inserted_now = true
                                        break
                                    end
                                end
                            end
                        end
                    end
            else
                reaper.ImGui_TextDisabled(ctx, "No items")
            end
            reaper.ImGui_EndChild(ctx)
            if panel_index < panel_count then
                reaper.ImGui_SameLine(ctx, 0, spacing)
            end
            if inserted_now then
                break
            end
        end

        if not inserted_now then
            local selected_node = self:resolvePresetNode(self.preset_browser_selected_path)
            if selected_node then
                reaper.ImGui_Text(ctx, "Selected: " .. tostring(selected_node.label or ""))
            else
                reaper.ImGui_TextDisabled(ctx, "Select an action table or action")
            end

            local selected_kind = selected_node and selected_node.kind or nil
            local can_add_selection = selected_kind == "lua_table" or selected_kind == "action_button"
            local close_w = reaper.ImGui_CalcTextSize(ctx, "Close") + 16
            local apply_w = can_add_selection and (reaper.ImGui_CalcTextSize(ctx, "Apply") + 16) or 0
            local total_w = close_w + apply_w + (can_add_selection and 8 or 0)
            local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
            if avail_w > total_w then
                reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + (avail_w - total_w))
            end

            if can_add_selection then
                if reaper.ImGui_Button(ctx, "Apply", apply_w, 0) then
                    tryInsertPresetNode(selected_node)
                end
                reaper.ImGui_SameLine(ctx)
            end
            if reaper.ImGui_Button(ctx, "Close", close_w, 0) then
                self:closePresetBrowser()
            end
        end
    end

    reaper.ImGui_End(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    return self.preset_browser_open
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

return Interactions.new()