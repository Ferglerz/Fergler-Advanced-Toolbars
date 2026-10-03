-- Windows/Button_Dropdown_Editor.lua
local PopupContext = require("Systems.Popup_Context")
local PRESET_CATALOG = require("Data.Dropdown_Preset_Catalog")

local ButtonDropdownEditor = {}
ButtonDropdownEditor.__index = ButtonDropdownEditor

local function containsRow(rows, target)
    for _, row in ipairs(rows or {}) do
        if row == target or (type(row.children) == "table" and containsRow(row.children, target)) then
            return true
        end
    end
    return false
end

function ButtonDropdownEditor.new()
    return setmetatable({is_open = false, owner_ctx = nil, current_button = nil, path = {}}, ButtonDropdownEditor)
end

function ButtonDropdownEditor:show(button, owner_ctx)
    if C.ActionSearch and C.ActionSearch.mode == "callback" then
        C.ActionSearch:close()
    end
    self.current_button = button
    self.path = {}
    PopupContext.openOrFallback(self, owner_ctx)
end

function ButtonDropdownEditor:currentList(button)
    local rows = button.dropdown_menu
    local parent
    for _, index in ipairs(self.path) do
        parent = rows[index]
        if not parent or type(parent.children) ~= "table" then
            self.path = {}
            return button.dropdown_menu, nil
        end
        rows = parent.children
    end
    return rows, parent
end

local function save(button)
    CONFIG_MANAGER:requestSaveToolbarConfig(button.parent_toolbar)
end

local function reorderButton(ctx, label, enabled)
    if not enabled then reaper.ImGui_BeginDisabled(ctx) end
    local pressed = reaper.ImGui_Button(ctx, label, 28, 0)
    if not enabled then reaper.ImGui_EndDisabled(ctx) end
    return enabled and pressed
end

function ButtonDropdownEditor:pickAction(ctx, button, item)
    if not C.ActionSearch then return end
    C.ActionSearch:open({
        mode = "callback", button = button, ctx = ctx,
        on_pick = function(entry)
            if not self.is_open or self.current_button ~= button or
                not containsRow(button.dropdown_menu, item) then
                return false
            end
            item.action_id = entry.id_str
            if item.name == "New Item" or item.name == "" then
                item.name = entry.name
            end
            save(button)
            return true
        end,
    })
end

function ButtonDropdownEditor:renderDropdownEditor(ctx, button)
    if not PopupContext.guardRender(self, ctx) then return false end
    button = button or self.current_button
    if not button then return false end
    _G.POPUP_OPEN = true

    local window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoDocking()
    reaper.ImGui_SetNextWindowSize(ctx, 680, 430, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 620, 300, 1200, 900)
    return C.GlobalStyle.withGlobalStyle(ctx, function()
        local title = "Dropdown Editor - " .. UTILS.stripNewLines(button.display_text) .. "##" .. button.instance_id
        local visible, open = reaper.ImGui_Begin(ctx, title, true, window_flags)
        self.is_open = open
        UTILS.snapWindowToMinimum(ctx, 0, 0, true)

        if visible then
            button.dropdown_menu = button.dropdown_menu or {}
            local rows, parent = self:currentList(button)
            if parent then
                if reaper.ImGui_Button(ctx, "Back to parent") then
                    table.remove(self.path)
                    rows, parent = self:currentList(button)
                else
                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_Text(ctx, "Editing: " .. tostring(parent.name or "Submenu"))
                end
            end

            if reaper.ImGui_Button(ctx, "Add Item") then
                rows[#rows + 1] = {name = "New Item", action_id = ""}
                save(button)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Add Separator") then
                rows[#rows + 1] = {is_separator = true}
                save(button)
            end
            if reaper.ImGui_Button(ctx, "Add Heading") then
                rows[#rows + 1] = {is_heading = true, name = "Section"}
                save(button)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Add Submenu") then
                rows[#rows + 1] = {name = "Submenu", children = {}}
                save(button)
            end

            if not parent then
                if reaper.ImGui_BeginMenu(ctx, "Starter presets") then
                    reaper.ImGui_TextDisabled(ctx, "Built-in action bundles (REAPER 5.9x IDs)")
                    reaper.ImGui_Separator(ctx)
                    for _, cat in ipairs(PRESET_CATALOG.categories) do
                        if reaper.ImGui_BeginMenu(ctx, cat.label) then
                            for _, preset in ipairs(cat.presets or {}) do
                                if reaper.ImGui_BeginMenu(ctx, preset.label) then
                                    if reaper.ImGui_MenuItem(ctx, "Replace entire menu") then
                                        button.dropdown_menu = PRESET_CATALOG.flatten_preset_rows(preset.rows)
                                        rows = button.dropdown_menu
                                        save(button)
                                    end
                                    if reaper.ImGui_MenuItem(ctx, "Append to current menu") then
                                        for _, row in ipairs(PRESET_CATALOG.flatten_preset_rows(preset.rows)) do
                                            rows[#rows + 1] = row
                                        end
                                        save(button)
                                    end
                                    reaper.ImGui_EndMenu(ctx)
                                end
                            end
                            reaper.ImGui_EndMenu(ctx)
                        end
                    end
                    reaper.ImGui_EndMenu(ctx)
                end
            end

            reaper.ImGui_Separator(ctx)
            local avail_h = select(2, reaper.ImGui_GetContentRegionAvail(ctx))
            local list_h = math.max(100, avail_h - 42)
            local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
            reaper.ImGui_BeginChild(ctx, "##dropdown_rows", 0, list_h, child_flags)
            if #rows == 0 then
                reaper.ImGui_TextDisabled(ctx, "No items in this menu")
            end

            local to_delete, move_up, move_down, open_child
            for i, item in ipairs(rows) do
                reaper.ImGui_PushID(ctx, i)
                if reorderButton(ctx, "↑", i > 1) then move_up = i end
                reaper.ImGui_SameLine(ctx)
                if reorderButton(ctx, "↓", i < #rows) then move_down = i end
                reaper.ImGui_SameLine(ctx)

                if item.is_separator then
                    reaper.ImGui_Text(ctx, "--- Separator ---")
                else
                    local row_w = select(1, reaper.ImGui_GetContentRegionAvail(ctx))
                    local action_w = math.max(90, math.min(145, math.floor(row_w * 0.22)))
                    local find_w = reaper.ImGui_CalcTextSize(ctx, "Find action") + 24
                    local child_w = reaper.ImGui_CalcTextSize(ctx, "Edit children") + 24
                    local extra_w = item.is_heading and 0 or
                        (type(item.children) == "table" and child_w or action_w + find_w + 6)
                    local name_w = math.max(100, row_w - extra_w - 52)
                    reaper.ImGui_SetNextItemWidth(ctx, name_w)
                    local hint = item.is_heading and "Section heading" or "Item name"
                    local changed, value = reaper.ImGui_InputTextWithHint(ctx, "##name", hint, item.name or "")
                    if changed then
                        item.name = value
                        save(button)
                    end
                    if not item.is_heading then
                        reaper.ImGui_SameLine(ctx)
                        if type(item.children) == "table" then
                            if reaper.ImGui_Button(ctx, "Edit children", child_w, 0) then open_child = i end
                        else
                            reaper.ImGui_SetNextItemWidth(ctx, action_w)
                            local action_changed, action =
                                reaper.ImGui_InputTextWithHint(ctx, "##action", "Command ID", item.action_id or "")
                            if action_changed then
                                item.action_id = tostring(action)
                                save(button)
                            end
                            reaper.ImGui_SameLine(ctx)
                            if reaper.ImGui_Button(ctx, "Find action", find_w, 0) then
                                self:pickAction(ctx, button, item)
                            end
                        end
                    end
                end

                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "X", 30, 0) then to_delete = i end
                reaper.ImGui_PopID(ctx)
            end
            if to_delete then
                table.remove(rows, to_delete)
                save(button)
            elseif move_up then
                rows[move_up], rows[move_up - 1] = rows[move_up - 1], rows[move_up]
                save(button)
            elseif move_down then
                rows[move_down], rows[move_down + 1] = rows[move_down + 1], rows[move_down]
                save(button)
            elseif open_child then
                self.path[#self.path + 1] = open_child
            end
            reaper.ImGui_EndChild(ctx)

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_TextDisabled(ctx, "Changes save automatically")
        end

        reaper.ImGui_End(ctx)
        if not open then
            if C.ActionSearch and C.ActionSearch.mode == "callback" and
                C.ActionSearch.target_button == button then
                C.ActionSearch:close()
            end
            PopupContext.closeOrFallback(self)
            self.current_button = nil
            self.path = {}
            _G.POPUP_OPEN = false
        end
        return self.is_open
    end)
end

return ButtonDropdownEditor
