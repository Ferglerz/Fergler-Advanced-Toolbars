-- Systems/Interactions/preset_browser/preset_browser_cluster_card.lua
local Tree = require("Systems.Interactions.preset_browser.preset_browser_tree")
local Layout = require("Systems.Interactions.preset_browser.preset_browser_panel_layout")
local PanelList = require("Systems.Interactions.preset_browser.preset_browser_panel_list")

local M = {}

local function clusterSelectable(ctx, label, selected, header_w, row_h)
    local cluster_clicked = false
    local ok, err = Layout.safeCall(function()
        local sel_ok, sel_err = Layout.safeCall(function()
            cluster_clicked = reaper.ImGui_Selectable(ctx, label, selected, 0, header_w, row_h)
        end)
        if not sel_ok then
            cluster_clicked = reaper.ImGui_Selectable(ctx, label, selected, 0, header_w)
        end
    end)
    if not ok then
        error(err)
    end
    return cluster_clicked
end

function M.drawClusterCards(ctx, self, opts)
    opts = opts or {}
    local parent_node = opts.parent_node
    local panel_index = opts.panel_index
    local row_h = opts.row_h
    local tryInsertPresetNode = opts.tryInsertPresetNode

    if not parent_node or not parent_node.children then
        return false
    end

    local card_pad = 14
    local card_gap = 16
    local card_pad_top = 12
    local gap_header_to_actions = 10
    local card_border = 0x555555FF
    local card_round = 6
    local card_bleed = 3
    local dl = reaper.ImGui_GetWindowDrawList(ctx)

    for table_index, table_node in ipairs(parent_node.children) do
        self:ensurePresetNodeChildrenLoaded(table_node)
        local selected_path = self.preset_browser_selected_path or {}
        local table_path = Tree.clonePath(self.preset_browser_path, panel_index - 1)
        table_path[panel_index] = table_index
        local table_selected = Tree.pathsEqual(selected_path, table_path)
        local table_label = Tree.stripClusterLabelDetails(table_node.label or "Cluster")
        local actions = table_node.children or {}
        local n_actions = #actions

        reaper.ImGui_PushID(ctx, string.format("clu_%d_%d_%s", panel_index, table_index, tostring(table_node.id)))
        reaper.ImGui_BeginGroup(ctx)
        reaper.ImGui_Dummy(ctx, 0, card_pad_top)
        reaper.ImGui_Indent(ctx, card_pad)
        local frame_rounding_pushed = false
        local card_ok, inserted = Layout.safeCall(function()
            local chip_w = reaper.ImGui_CalcTextSize(ctx, "Add group") + 24
            local avail_row = reaper.ImGui_GetContentRegionAvail(ctx)
            local header_w = math.max(50, avail_row - chip_w - 16)
            local header_base = table_selected and 0x3D4654FF or 0x1E1E1EFF

            local cluster_label = table_label .. "##cluster_" .. tostring(table_node.id)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), header_base)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x2A2A2AFF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), 0x3D4654FF)
            local cluster_clicked = clusterSelectable(
                ctx,
                cluster_label,
                table_selected,
                header_w,
                row_h
            )
            reaper.ImGui_PopStyleColor(ctx)
            reaper.ImGui_PopStyleColor(ctx)
            reaper.ImGui_PopStyleColor(ctx)

            if cluster_clicked then
                self.preset_browser_selected_path = Tree.clonePath(table_path)
                if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                    if tryInsertPresetNode(table_node) then
                        return true
                    end
                end
            end

            reaper.ImGui_SameLine(ctx, 0, 8)
            local line_h = reaper.ImGui_GetTextLineHeightWithSpacing(ctx)
            local push_ok, push_err = Layout.safeCall(
                reaper.ImGui_PushStyleVar,
                ctx,
                reaper.ImGui_StyleVar_FrameRounding(),
                10
            )
            if not push_ok then
                error(push_err)
            end
            frame_rounding_pushed = true
            local btn_ok, add_group_pressed = Layout.safeCall(
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
                self.preset_browser_selected_path = Tree.clonePath(table_path)
                if tryInsertPresetNode(table_node) then
                    return true
                end
            end

            if n_actions > 0 then
                reaper.ImGui_Dummy(ctx, 0, gap_header_to_actions)
            end

            for action_index, action_node in ipairs(actions) do
                local action_path = Tree.clonePath(table_path)
                action_path[panel_index + 1] = action_index
                local action_selected = Tree.pathsEqual(selected_path, action_path)
                local action_label = tostring(action_node.label or "Action") .. "##action_" .. tostring(action_node.id)
                local is_even = (action_index % 2) == 0
                local stripe_col, hover_col, active_col = PanelList.presetBrowserZebraColors(is_even, "card")
                local base_col = action_selected and active_col or stripe_col
                if PanelList.selectableWithRowStyle(
                    ctx,
                    action_label,
                    action_selected,
                    4,
                    row_h,
                    base_col,
                    hover_col,
                    active_col
                ) then
                    self.preset_browser_selected_path = Tree.clonePath(action_path)
                    if tryInsertPresetNode(action_node) then
                        return true
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
                local dummy_coords = {
                    relativeRectToDrawList = function(_, cx, cy, cw, ch)
                        return cx, cy, cx + cw, cy + ch
                    end
                }
                DRAWING.drawChipBackground(dummy_coords, dl, bx1, by1, bx2 - bx1, by2 - by1, 0x28282833, {
                    rounding = card_round,
                    border_color = card_border,
                    thickness = 1
                })
            end
        end

        reaper.ImGui_PopID(ctx)

        if not card_ok then
            reaper.ShowConsoleMsg(
                "Advanced Toolbars: Preset browser cluster: " .. tostring(inserted) .. "\n"
            )
        end

        if card_ok and inserted == true then
            return true
        end

        reaper.ImGui_Dummy(ctx, 0, card_gap)
    end

    return false
end

return M
