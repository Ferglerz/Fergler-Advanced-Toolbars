-- Systems/Interactions/Preset_Browser.lua
local PopupContext = require("Systems.Popup_Context")
local Tree = require("Systems.Interactions.preset_browser.preset_browser_tree")
local Layout = require("Systems.Interactions.preset_browser.preset_browser_panel_layout")
local ClusterCard = require("Systems.Interactions.preset_browser.preset_browser_cluster_card")
local PanelList = require("Systems.Interactions.preset_browser.preset_browser_panel_list")

local M = {}

function M.resetPresetBrowserState(self)
    self.preset_browser_path = {}
    self.preset_browser_selected_path = nil
end

function M.openPresetBrowser(self, owner_ctx, target_button)
    if not target_button or target_button:isSeparator() then
        return false
    end
    self.preset_browser_target_button = target_button
    PopupContext.openOrFallback(self.preset_browser_state, owner_ctx)
    self.preset_browser_open = true
    self:resetPresetBrowserState()
    _G.POPUP_OPEN = true
    return true
end

function M.closePresetBrowser(self)
    PopupContext.closeOrFallback(self.preset_browser_state)
    self.preset_browser_open = false
    self.preset_browser_target_button = nil
    self:resetPresetBrowserState()
end

function M.isPresetBrowserOpen(self)
    if C.PopupContext then
        return self.preset_browser_state and self.preset_browser_state.is_open == true
    end
    return self.preset_browser_open == true
end

M.getPresetBrowserRoot = Tree.getPresetBrowserRoot
M.loadActionChunk = Tree.loadActionChunk
M.ensurePresetNodeChildrenLoaded = Tree.ensurePresetNodeChildrenLoaded
M.collectToolbarRowsFromNode = Tree.collectToolbarRowsFromNode
M.resolvePresetNode = Tree.resolvePresetNode

local function renderPresetBrowserContent(self, ctx, tryInsertPresetNode)
    reaper.ImGui_TextWrapped(ctx,
        'Vectorized and curated list of actions, grouped together to get you started adding banks of toolbar buttons. Very work in progress. "Clusters" are vector sorting outputs and will eventually be given definitive names. MIDI actions and actions which are duplicated across a range of numbers (like Select track 1/2/3/etc) are intentionally omitted along with the non-toggle versions of options.')
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    local root = self:getPresetBrowserRoot()
    local panel_count = math.max(2, (#self.preset_browser_path or 0) + 1)
    local spacing = 14
    local panel_height = -78
    local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
    local min_panel_w = 140
    local row_left_pad = 16
    local row_h = reaper.ImGui_GetTextLineHeightWithSpacing(ctx) + 12

    local layout_opts = {
        spacing = spacing,
        min_panel_w = min_panel_w,
        min_last_panel_w = 180,
        max_non_last_panel_w = 420,
        text_pad_w = 40
    }
    local panel_widths = Layout.computePanelWidths(ctx, self, root, panel_count, layout_opts)

    local inserted_now = false
    for panel_index = 1, panel_count do
        local parent_node = Layout.parentForPanel(self, root, panel_index)
        local panel_id = "PresetBrowserPanelWindow_" .. tostring(panel_index)
        reaper.ImGui_BeginChild(ctx, panel_id, panel_widths[panel_index] or min_panel_w, panel_height, child_flags)
        if parent_node and parent_node.children and #parent_node.children > 0 then
            local draw_opts = {
                parent_node = parent_node,
                panel_index = panel_index,
                row_h = row_h,
                tryInsertPresetNode = tryInsertPresetNode
            }
            if Layout.parentChildrenAllLuaTables(parent_node) then
                inserted_now = ClusterCard.drawClusterCards(ctx, self, draw_opts)
            else
                draw_opts.row_left_pad = row_left_pad
                inserted_now = PanelList.drawPanelList(ctx, self, draw_opts)
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
        local footer_avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
        if footer_avail_w > total_w then
            reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + (footer_avail_w - total_w))
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

function M.renderPresetBrowserWindow(self, ctx)
    if not PopupContext.guardRender(self.preset_browser_state, ctx) then
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

    PopupContext.withGlobalStyle(ctx, function()
        reaper.ImGui_SetNextWindowSize(ctx, 900, 500, reaper.ImGui_Cond_FirstUseEver())
        local window_flags = 0
        if reaper.ImGui_WindowFlags_NoDocking then
            window_flags = window_flags | reaper.ImGui_WindowFlags_NoDocking()
        end
        local visible, keep_open = reaper.ImGui_Begin(ctx, "Preset Browser (WIP)", true, window_flags)
        if not keep_open or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            self:closePresetBrowser()
            reaper.ImGui_End(ctx)
            return
        end

        if visible then
            renderPresetBrowserContent(self, ctx, tryInsertPresetNode)
        end

        reaper.ImGui_End(ctx)
    end)

    return self.preset_browser_open
end

return M
