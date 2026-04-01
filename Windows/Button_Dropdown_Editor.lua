-- Windows/Button_Dropdown_Editor.lua

local PRESET_CATALOG = require("Systems.Dropdown_Preset_Catalog")
local ACTION_SEARCH = require("Systems.Action_Search")

local ButtonDropdownEditor = {}
ButtonDropdownEditor.__index = ButtonDropdownEditor

function ButtonDropdownEditor.new()
    local self = setmetatable({}, ButtonDropdownEditor)
    
    self.is_open = false
    self.current_button = nil

    -- Action search (generated reaper_actions_index.lua)
    self._action_index_data = nil
    self._action_index_err = nil
    self._action_query = ""
    self._action_section = ""
    self._action_hits = {}
    self._action_sel = 0
    self._action_apply_row_str = "1"
    self._last_action_query = nil
    self._last_action_section = nil
    self._dropdown_editor_target = nil

    return self
end

function ButtonDropdownEditor:ensureActionIndexLoaded()
    if self._action_index_data or self._action_index_err then
        return
    end
    local data, err = ACTION_SEARCH.load()
    if data then
        self._action_index_data = data
    else
        self._action_index_err = tostring(err or "unknown")
    end
end

function ButtonDropdownEditor:refreshActionHits()
    self:ensureActionIndexLoaded()
    if not self._action_index_data or not self._action_index_data.actions then
        self._action_hits = {}
        self._action_sel = 0
        return
    end
    self._action_hits = ACTION_SEARCH.filter(
        self._action_index_data.actions,
        self._action_query,
        self._action_section,
        200
    )
    if #self._action_hits > 0 then
        self._action_sel = math.min(math.max(self._action_sel, 1), #self._action_hits)
    else
        self._action_sel = 0
    end
end

function ButtonDropdownEditor:renderActionSearchPanel(ctx, button)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextDisabled(ctx, "Search all actions (snapshot index)")
    self:ensureActionIndexLoaded()

    if self._action_index_err then
        reaper.ImGui_TextWrapped(ctx, "Could not load action index: " .. self._action_index_err)
        reaper.ImGui_TextWrapped(
            ctx,
            "Run: python3 Data/reaper_actions/generate_action_categorization.py"
        )
        if reaper.ImGui_SmallButton(ctx, "Retry load") then
            self._action_index_err = nil
            self._action_index_data = nil
            self:ensureActionIndexLoaded()
        end
        return
    end

    local count = self._action_index_data.action_count or #(self._action_index_data.actions or {})
    reaper.ImGui_TextDisabled(ctx, string.format("%d actions — IDs may differ in newer REAPER", count))

    reaper.ImGui_SetNextItemWidth(ctx, 320)
    local q_changed, new_q = reaper.ImGui_InputTextWithHint(ctx, "##actionq", "Search title (words…)", self._action_query or "")
    if q_changed then
        self._action_query = new_q
    end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 200)
    local combo_preview = (self._action_section == "" or not self._action_section) and "All sections" or self._action_section
    if reaper.ImGui_BeginCombo(ctx, "##actionsec", combo_preview) then
        local function pick_section(sec)
            self._action_section = sec
            self._last_action_section = nil
        end
        if reaper.ImGui_Selectable(ctx, "All sections", self._action_section == "") then
            pick_section("")
        end
        for _, sec in ipairs(ACTION_SEARCH.collectSections(self._action_index_data.actions)) do
            if reaper.ImGui_Selectable(ctx, sec, self._action_section == sec) then
                pick_section(sec)
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end

    if self._action_query ~= self._last_action_query or self._action_section ~= self._last_action_section then
        self._last_action_query = self._action_query
        self._last_action_section = self._action_section
        self:refreshActionHits()
    end

    if self._action_query == "" or not self._action_query:match("%S") then
        reaper.ImGui_TextDisabled(ctx, "Type to filter. Showing no results until search text is non-empty.")
        return
    end

    reaper.ImGui_TextDisabled(
        ctx,
        string.format("%d match(es)%s", #self._action_hits, #self._action_hits >= 200 and " (max 200)" or "")
    )

    local child_flags = (reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border()) or 0
    if reaper.ImGui_BeginChild(ctx, "action_hit_list##" .. button.instance_id, 0, 180, child_flags) then
        for hi, row in ipairs(self._action_hits) do
            reaper.ImGui_PushID(ctx, "ah_" .. hi .. "_" .. button.instance_id)
            local label = string.format("[%s] %s", row.i or "?", row.t or "")
            local sel = (hi == self._action_sel)
            if reaper.ImGui_Selectable(ctx, label, sel) then
                self._action_sel = hi
            end
            if row.m and reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, row.m)
            elseif reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, row.s or "")
            end
            reaper.ImGui_PopID(ctx)
        end
        reaper.ImGui_EndChild(ctx)
    end

    local hit = (self._action_sel >= 1 and self._action_sel <= #self._action_hits) and self._action_hits[self._action_sel] or nil

    if reaper.ImGui_Button(ctx, "Add match as new item") then
        if hit then
            table.insert(
                button.dropdown_menu,
                { name = hit.t or "Action", action_id = tostring(hit.i or "") }
            )
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end
    end

    reaper.ImGui_SameLine(ctx)

    reaper.ImGui_SetNextItemWidth(ctx, 56)
    local row_changed, new_row_s =
        reaper.ImGui_InputTextWithHint(ctx, "##applyrow", "#", self._action_apply_row_str or "1")
    if row_changed then
        self._action_apply_row_str = new_row_s
    end

    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, "Apply match to row #") then
        if hit and button.dropdown_menu then
            local idx = math.floor(tonumber(self._action_apply_row_str) or 1)
            idx = math.max(1, math.min(idx, #button.dropdown_menu))
            local item = button.dropdown_menu[idx]
            if item and not item.is_separator and not item.is_heading then
                item.name = hit.t or item.name
                item.action_id = tostring(hit.i or "")
                CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
            end
        end
    end
    reaper.ImGui_TextDisabled(ctx, "Row # = position in list above (1 = top). Only normal items, not separators/headings.")
end

function ButtonDropdownEditor:renderDropdownEditor(ctx, button)
    if not self.is_open then
        _G.POPUP_OPEN = false
        return false
    end
    
    _G.POPUP_OPEN = true
    
    button = button or self.current_button
    if not button then return false end

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoDocking()
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)
    
    -- Use instance_id for unique window identification
    local window_title = "Dropdown Editor - " .. UTILS.stripNewLines(button.display_text) .. "##" .. button.instance_id
    reaper.ImGui_SetNextWindowSize(ctx, 520, 640, reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, window_title, true, window_flags)
    
    self.is_open = open

    if visible then
        if self._dropdown_editor_target ~= button.instance_id then
            self._dropdown_editor_target = button.instance_id
            self._action_query = ""
            self._action_section = ""
            self._last_action_query = nil
            self._last_action_section = nil
            self._action_hits = {}
            self._action_sel = 0
        end

        if not button.dropdown_menu then
            button.dropdown_menu = {}
        end

        if reaper.ImGui_Button(ctx, "Add Item") then
            table.insert(button.dropdown_menu, {name = "New Item", action_id = ""})
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Add Separator") then
            table.insert(button.dropdown_menu, {is_separator = true})
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Add Heading") then
            table.insert(button.dropdown_menu, {is_heading = true, name = "Section"})
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_BeginMenu(ctx, "Starter presets") then
            reaper.ImGui_TextDisabled(ctx, "Built-in action bundles (REAPER 5.9x IDs)")
            reaper.ImGui_Separator(ctx)
            for _, cat in ipairs(PRESET_CATALOG.categories) do
                if reaper.ImGui_BeginMenu(ctx, cat.label) then
                    for _, preset in ipairs(cat.presets or {}) do
                        if reaper.ImGui_BeginMenu(ctx, preset.label) then
                            if reaper.ImGui_MenuItem(ctx, "Replace entire menu") then
                                button.dropdown_menu = PRESET_CATALOG.flatten_preset_rows(preset.rows)
                                CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
                            end
                            if reaper.ImGui_MenuItem(ctx, "Append to current menu") then
                                local add = PRESET_CATALOG.flatten_preset_rows(preset.rows)
                                for _, row in ipairs(add) do
                                    table.insert(button.dropdown_menu, row)
                                end
                                CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
                            end
                            reaper.ImGui_EndMenu(ctx)
                        end
                    end
                    reaper.ImGui_EndMenu(ctx)
                end
            end
            reaper.ImGui_EndMenu(ctx)
        end

        reaper.ImGui_Separator(ctx)

        if #button.dropdown_menu == 0 then
            reaper.ImGui_TextDisabled(ctx, "No items in dropdown")
        else
            local to_delete, move_up, move_down
            local dropdown_copy = {table.unpack(button.dropdown_menu)}
            
            local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
            local triangle_height = 10
            local triangle_width = 8
            local button_size = 20

            local function drawTriangle(i, is_up, enabled)
                local triangle_color = enabled and (reaper.ImGui_IsItemHovered(ctx) or reaper.ImGui_IsItemActive(ctx)) 
                    and 0xFFFFFFFF or 0xAAAAAAFF
                
                if not enabled then triangle_color = 0x44444477 end
                
                reaper.ImGui_SetCursorPos(ctx, reaper.ImGui_GetCursorPosX(ctx), reaper.ImGui_GetCursorPosY(ctx))
                
                -- Use instance_id for unique button identification
                local button_id = "##" .. (is_up and "up" or "down") .. i .. "_" .. button.instance_id
                local button_pressed = enabled and reaper.ImGui_InvisibleButton(ctx, button_id, button_size, button_size)
                if not enabled then
                    local disabled_id = "##" .. (is_up and "up" or "down") .. "_disabled" .. i .. "_" .. button.instance_id
                    reaper.ImGui_InvisibleButton(ctx, disabled_id, button_size, button_size)
                end
                
                local pos_x, pos_y = reaper.ImGui_GetItemRectMin(ctx)
                local center_x = pos_x + button_size / 2
                local center_y = pos_y + button_size / 2
                
                center_y = center_y + (is_up and triangle_height/4 or -triangle_height/4)
                
                DRAWING.triangle(
                    draw_list,
                    center_x,
                    center_y,
                    triangle_width,
                    triangle_height,
                    triangle_color,
                    is_up and DRAWING.ANGLE_UP or DRAWING.ANGLE_DOWN
                )
                
                if enabled and reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_BeginTooltip(ctx)
                    reaper.ImGui_Text(ctx, is_up and "Move Up" or "Move Down")
                    reaper.ImGui_EndTooltip(ctx)
                end
                
                return button_pressed
            end

            for i, item in ipairs(dropdown_copy) do
                -- Use instance_id for unique item identification
                reaper.ImGui_PushID(ctx, i .. "_" .. button.instance_id)

                if drawTriangle(i, true, i > 1) then move_up = i end
                reaper.ImGui_SameLine(ctx)
                if drawTriangle(i, false, i < #button.dropdown_menu) then move_down = i end
                reaper.ImGui_SameLine(ctx)

                if item.is_separator then
                    reaper.ImGui_Text(ctx, "--- Separator ---")
                elseif item.is_heading then
                    reaper.ImGui_SetNextItemWidth(ctx, 280)
                    local h_changed, new_h =
                        reaper.ImGui_InputTextWithHint(ctx, "##heading" .. i, "Section heading", item.name or "")
                    if h_changed then
                        item.name = new_h
                        button.dropdown_menu[i].name = new_h
                    end
                else
                    reaper.ImGui_SetNextItemWidth(ctx, 150)
                    local name_changed, new_name =
                        reaper.ImGui_InputTextWithHint(ctx, "##name" .. i, "Action Name", item.name or "")
                    if name_changed then
                        item.name = new_name
                        button.dropdown_menu[i].name = new_name
                    end

                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_SetNextItemWidth(ctx, 100)
                    local action_changed, new_action =
                        reaper.ImGui_InputTextWithHint(ctx, "##action" .. i, "Command ID", item.action_id or "")
                    if action_changed then
                        item.action_id = tostring(new_action)
                        button.dropdown_menu[i].action_id = tostring(new_action)
                    end
                end

                reaper.ImGui_SameLine(ctx)

                if reaper.ImGui_Button(ctx, "X##" .. i) then
                    to_delete = i
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_BeginTooltip(ctx)
                    reaper.ImGui_Text(ctx, "Delete item")
                    reaper.ImGui_EndTooltip(ctx)
                end

                reaper.ImGui_PopID(ctx)
            end

            local changes_made = false
            if to_delete then
                table.remove(button.dropdown_menu, to_delete)
                changes_made = true
            end
            if move_up and move_up > 1 then
                button.dropdown_menu[move_up], button.dropdown_menu[move_up - 1] =
                    button.dropdown_menu[move_up - 1],
                    button.dropdown_menu[move_up]
                changes_made = true
            end
            if move_down and move_down < #button.dropdown_menu then
                button.dropdown_menu[move_down], button.dropdown_menu[move_down + 1] =
                    button.dropdown_menu[move_down + 1],
                    button.dropdown_menu[move_down]
                changes_made = true
            end
            if changes_made then
                CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
            end
        end

        self:renderActionSearchPanel(ctx, button)

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Save Changes") then
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end
    end

    reaper.ImGui_End(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    if not open then
        _G.POPUP_OPEN = false
    end
    self.is_open = open
    
    return self.is_open
end

return ButtonDropdownEditor.new()