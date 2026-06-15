-- Windows/Action_Search.lua
-- Searchable picker for REAPER Main (section 0) actions; uses CF_EnumerateActions + CF_GetCommandText.

local ActionSearch = {}
ActionSearch.__index = ActionSearch

local MAIN_SECTION = 0
local MATCH_LIMIT = 500
local CATALOG_CAP = 65536

local function actionIdStringForCommand(cmd_id)
    if not cmd_id or cmd_id == 0 then
        return nil
    end
    if reaper.APIExists("ReverseNamedCommandLookup") then
        local named = reaper.ReverseNamedCommandLookup(cmd_id)
        if named and named ~= "" then
            if not named:match("^_") then
                named = "_" .. named
            end
            return named
        end
    end
    return tostring(math.floor(cmd_id))
end

local function buildCatalog()
    local list = {}
    if not reaper.APIExists("CF_EnumerateActions") or not reaper.APIExists("CF_GetCommandText") then
        return list, "missing_cf_api"
    end

    local i = 0
    while i < CATALOG_CAP do
        local ok, a, b = pcall(reaper.CF_EnumerateActions, MAIN_SECTION, i)
        if not ok or not a or a == 0 then
            break
        end
        local cmd_id = a
        local name = (type(b) == "string" and b ~= "") and b or (reaper.CF_GetCommandText(MAIN_SECTION, cmd_id) or "")
        name = tostring(name or "")
        if name ~= "" then
            local id_str = actionIdStringForCommand(cmd_id)
            if id_str then
                table.insert(list, { cmd_id = cmd_id, name = name, id_str = id_str })
            end
        end
        i = i + 1
    end

    return list, nil
end

local function utf8_lower(s)
    return (s and tostring(s):lower()) or ""
end

function ActionSearch.new()
    local self = setmetatable({}, ActionSearch)
    self.is_open = false
    self.owner_ctx = nil
    self.mode = nil
    self.target_button = nil
    self.insert_anchor = nil
    self.filter_text = ""
    self.catalog = nil
    self.catalog_error = nil
    self.matches = {}
    self.matches_dirty = true
    return self
end

function ActionSearch:close()
    if C.PopupContext then
        C.PopupContext.close(self)
    else
        self.is_open = false
        self.owner_ctx = nil
    end
    self.mode = nil
    self.target_button = nil
    self.insert_anchor = nil
    self.filter_text = ""
    self.matches_dirty = true
end

function ActionSearch:open(opts)
    opts = opts or {}
    self.mode = opts.mode
    self.target_button = opts.button
    self.insert_anchor = opts.insert_anchor
    self.filter_text = ""
    self.matches = {}
    self.matches_dirty = true

    if C.PopupContext then
        C.PopupContext.open(self, opts.ctx)
    else
        self.owner_ctx = opts.ctx
        self.is_open = true
    end
end

function ActionSearch:ensureCatalog()
    if self.catalog ~= nil then
        return
    end
    local list, err = buildCatalog()
    self.catalog = list
    self.catalog_error = err
end

function ActionSearch:rebuildMatches()
    self.matches = {}
    if not self.catalog or #self.catalog == 0 then
        return
    end
    local q = utf8_lower(self.filter_text)
    if q == "" then
        return
    end
    local n = 0
    for _, entry in ipairs(self.catalog) do
        local hay = utf8_lower(entry.name) .. "\0" .. utf8_lower(entry.id_str)
        if hay:find(q, 1, true) then
            table.insert(self.matches, entry)
            n = n + 1
            if n >= MATCH_LIMIT then
                break
            end
        end
    end
end

local function propertyPositionSuffix(property_key)
    if type(property_key) ~= "string" then
        return nil
    end
    return property_key:match("_pos(%d+)$")
end

local function queueUnderMouseIfNeeded(display_name)
    local name = tostring(display_name or ""):lower()
    if name:find("under mouse cursor", 1, true) and C and C.Interactions and C.Interactions.queueUnderMouseAutoArmNotice then
        C.Interactions:queueUnderMouseAutoArmNotice()
    end
end

function ActionSearch:applyToExistingButton(button, entry)
    if not button or button:isSeparator() or not entry then
        return false
    end

    local id_str = entry.id_str
    local title = entry.name
    local pos = propertyPositionSuffix(button.property_key)
    button.id = id_str
    button.original_text = title
    button.display_text = title
    button.property_key = C.ButtonDefinition.createPropertyKey(id_str, title, pos)
    button.right_click = C.ButtonDefinition.getDefaultRightClickBehavior(id_str)

    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
    button:saveChanges()
    queueUnderMouseIfNeeded(title)
    return true
end

function ActionSearch:applyInsertBeforeAnchor(anchor, entry)
    if not anchor or anchor:isSeparator() or not entry then
        return false
    end

    local new_button = C.ButtonDefinition.createButton(entry.id_str, entry.name)
    new_button.parent_toolbar = anchor.parent_toolbar

    local source = C.ButtonRenderer:getInsertionColorSource(anchor)
    if source then
        C.ButtonRenderer:copyColorProperties(source, new_button)
    end

    C.IniManager:insertButton(anchor, new_button, "before")
    queueUnderMouseIfNeeded(entry.name)
    return true
end

function ActionSearch:applyInsertAfterAnchor(anchor, entry)
    if not anchor or not entry then
        return false
    end

    local new_button = C.ButtonDefinition.createButton(entry.id_str, entry.name)
    new_button.parent_toolbar = anchor.parent_toolbar

    local source = C.ButtonRenderer:getInsertionColorSource(anchor)
    if source then
        C.ButtonRenderer:copyColorProperties(source, new_button)
    end

    if anchor.is_empty_toolbar_placeholder then
        C.IniManager:insertFirstButtonInSection(anchor.parent_toolbar.section, new_button)
    else
        C.IniManager:insertButton(anchor, new_button, "after")
    end
    queueUnderMouseIfNeeded(entry.name)
    return true
end

function ActionSearch:applyPick(entry)
    if self.mode == "change_action" then
        return self:applyToExistingButton(self.target_button, entry)
    end
    if self.mode == "insert_before" then
        return self:applyInsertBeforeAnchor(self.insert_anchor, entry)
    end
    if self.mode == "insert_after" then
        return self:applyInsertAfterAnchor(self.insert_anchor, entry)
    end
    if self.mode == "right_click_action" then
        local b = self.target_button
        if b and entry then
            b.right_click_action = entry.id_str
            b:saveChanges()
            return true
        end
    end
    return false
end

function ActionSearch:render(ctx)
    if C.PopupContext then
        if not C.PopupContext.shouldRender(self, ctx) then
            return false
        end
    elseif not self.is_open then
        return false
    end

    _G.POPUP_OPEN = true

    self:ensureCatalog()

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    reaper.ImGui_SetNextWindowSize(ctx, 520, 420, reaper.ImGui_Cond_FirstUseEver())

    local colorCount, styleCount = C.GlobalStyle.apply(ctx)
    local visible, open =
        reaper.ImGui_Begin(ctx, "Assign REAPER action##at_action_search", true, window_flags)

    if not open or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        reaper.ImGui_End(ctx)
        self:close()
        return true
    end

    if visible then
        if self.catalog_error == "missing_cf_api" then
            reaper.ImGui_TextWrapped(
                ctx,
                "Action search needs CF_EnumerateActions (same extension as CF_GetCommandText). Install or enable SWS / ReaImGui extension pack so those APIs are available."
            )
        elseif not self.catalog or #self.catalog == 0 then
            reaper.ImGui_TextWrapped(ctx, "No actions were returned. Check that Main section actions are available.")
        else
            reaper.ImGui_TextWrapped(
                ctx,
                "Type to filter " .. tostring(#self.catalog) .. " Main section actions (name or id). Click a row to assign."
            )
        end

        reaper.ImGui_Spacing(ctx)

        reaper.ImGui_SetNextItemWidth(ctx, -1)
        local changed, text =
            reaper.ImGui_InputTextWithHint(ctx, "##action_filter", "Search by action name or command id…", self.filter_text or "")
        if changed then
            self.filter_text = text or ""
            self.matches_dirty = true
        end

        if self.matches_dirty then
            self:rebuildMatches()
            self.matches_dirty = false
        end

        reaper.ImGui_Separator(ctx)

        local footer_h = 28
        local avail_h = select(2, reaper.ImGui_GetContentRegionAvail(ctx))
        local list_h = math.max(120, avail_h - footer_h)
        local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
        reaper.ImGui_BeginChild(ctx, "##action_list", 0, list_h, child_flags)

        if self.catalog and #self.catalog > 0 then
            if utf8_lower(self.filter_text) == "" then
                reaper.ImGui_TextDisabled(ctx, "Start typing to search.")
            elseif #self.matches == 0 then
                reaper.ImGui_TextDisabled(ctx, "No matches.")
            else
                local avail_w = select(1, reaper.ImGui_GetContentRegionAvail(ctx))
                local gap = 10
                local id_w = math.min(200, math.max(96, math.floor(avail_w * 0.32)))
                local name_w = math.max(80, avail_w - id_w - gap)

                local hx0 = reaper.ImGui_GetCursorPosX(ctx)
                local hy0 = reaper.ImGui_GetCursorPosY(ctx)
                reaper.ImGui_SetCursorPos(ctx, hx0, hy0)
                reaper.ImGui_TextDisabled(ctx, "Action name")
                reaper.ImGui_SetCursorPos(ctx, hx0 + name_w + gap, hy0)
                reaper.ImGui_TextDisabled(ctx, "Command ID")
                reaper.ImGui_SetCursorPos(ctx, hx0, hy0 + reaper.ImGui_GetTextLineHeight(ctx) + 4)
                reaper.ImGui_Separator(ctx)

                if #self.matches >= MATCH_LIMIT then
                    reaper.ImGui_TextDisabled(ctx, "Showing first " .. tostring(MATCH_LIMIT) .. " matches — refine search.")
                    reaper.ImGui_Separator(ctx)
                end
                for mi, entry in ipairs(self.matches) do
                    reaper.ImGui_PushID(ctx, mi)
                    local picked = false
                    if reaper.ImGui_Selectable(ctx, entry.name, false, 0, name_w) then
                        picked = true
                    end
                    reaper.ImGui_SameLine(ctx, 0, gap)
                    if reaper.ImGui_Selectable(ctx, entry.id_str, false, 0, id_w) then
                        picked = true
                    end
                    if picked then
                        self:applyPick(entry)
                        open = false
                    end
                    reaper.ImGui_PopID(ctx)
                end
            end
        end

        reaper.ImGui_EndChild(ctx)

        if reaper.ImGui_Button(ctx, "Close", 0, 0) then
            open = false
        end
    end

    reaper.ImGui_End(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)

    if not open then
        self:close()
    end

    return true
end

return ActionSearch
