-- Systems/Interactions/preset_browser/preset_browser_panel_list.lua
local Tree = require("Systems.Interactions.preset_browser.preset_browser_tree")
local Layout = require("Systems.Interactions.preset_browser.preset_browser_panel_layout")

local M = {}

local PRESET_ROW_ACTIVE = 0x3D4654FF
local PRESET_ROW_HOVER = 0x3A3A3AFF

function M.presetBrowserZebraColors(is_even, variant)
    local stripe_a, stripe_b
    if variant == "card" then
        stripe_a, stripe_b = 0x2E2E2EFF, 0x2C2C2CFF
    else
        stripe_a, stripe_b = 0x353535FF, 0x343434FF
    end
    local stripe = is_even and stripe_a or stripe_b
    return stripe, PRESET_ROW_HOVER, PRESET_ROW_ACTIVE
end

function M.selectableWithRowStyle(ctx, label, selected, left_pad, row_h, base_col, hover_col, active_col)
    local base_x = reaper.ImGui_GetCursorPosX(ctx)
    reaper.ImGui_SetCursorPosX(ctx, base_x + (left_pad or 0))
    local pushed = false
    if base_col and reaper.ImGui_Col_Header then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), base_col)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), hover_col or base_col)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), active_col or base_col)
        pushed = true
    end
    local ok, clicked = Layout.safeCall(reaper.ImGui_Selectable, ctx, label, selected)
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

function M.drawPanelList(ctx, self, opts)
    opts = opts or {}
    local parent_node = opts.parent_node
    local panel_index = opts.panel_index
    local row_h = opts.row_h
    local row_left_pad = opts.row_left_pad or 16
    local tryInsertPresetNode = opts.tryInsertPresetNode

    if not parent_node or not parent_node.children then
        return false
    end

    for child_index, child in ipairs(parent_node.children) do
        self:ensurePresetNodeChildrenLoaded(child)
        local selected_path = self.preset_browser_selected_path or {}
        local candidate_path = Tree.clonePath(self.preset_browser_path, panel_index - 1)
        candidate_path[panel_index] = child_index
        local is_selected = Tree.pathsEqual(selected_path, candidate_path)
        local has_children = child.kind == "folder" or child.kind == "lua_table" or (child.children and #child.children > 0)
        local label = tostring(child.label or "Item") .. "##window_" .. tostring(child.id)
        local is_even = (child_index % 2) == 0
        local stripe_col, hover_col, active_col = M.presetBrowserZebraColors(is_even, "panel")
        local base_col = is_selected and active_col or stripe_col
        if M.selectableWithRowStyle(
            ctx,
            label,
            is_selected,
            row_left_pad,
            row_h,
            base_col,
            hover_col,
            active_col
        ) then
            local next_path = Tree.clonePath(self.preset_browser_path, panel_index - 1)
            next_path[panel_index] = child_index
            self.preset_browser_selected_path = Tree.clonePath(next_path)

            if has_children then
                self.preset_browser_path = Tree.clonePath(next_path)
                self._panel_widths_cache_key = nil
                self._panel_widths_cache = nil
                self._panel_text_width_cache = nil
            end

            if child.kind == "action_button" then
                if tryInsertPresetNode(child) then
                    return true
                end
            elseif child.kind == "lua_table" and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                if tryInsertPresetNode(child) then
                    return true
                end
            end
        end
    end

    return false
end

return M
