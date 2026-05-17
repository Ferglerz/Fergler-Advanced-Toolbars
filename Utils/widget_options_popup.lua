-- Shared widget right-click option popups: padded BeginPopup, toggles that don't auto-close (Checkbox),
-- and layout persistence after dynamic width changes.

local M = {}

function M.consume_open_popup(ctx, popup_key, holder, open_flag_name)
    open_flag_name = open_flag_name or "_open_context"
    if holder[open_flag_name] then
        reaper.ImGui_OpenPopup(ctx, popup_key)
        holder[open_flag_name] = false
    end
end

--- Returns visible, pad_pushed
function M.begin_popup_padded(ctx, popup_key)
    local pad_pushed = false
    if reaper.ImGui_StyleVar_WindowPadding then
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 8, 8)
        pad_pushed = true
    end
    if not reaper.ImGui_BeginPopup(ctx, popup_key) then
        if pad_pushed then
            reaper.ImGui_PopStyleVar(ctx, 1)
        end
        return false, pad_pushed
    end
    return true, pad_pushed
end

function M.end_popup_padded(ctx, pad_pushed)
    reaper.ImGui_EndPopup(ctx)
    if pad_pushed then
        reaper.ImGui_PopStyleVar(ctx, 1)
    end
end

--- Checkbox row for multi-toggle visibility menus (popup stays open). Returns changed, new_on.
function M.checkbox_toggle(ctx, label, on, can_toggle)
    local dis = not can_toggle and reaper.ImGui_BeginDisabled
    if dis then
        reaper.ImGui_BeginDisabled(ctx)
    end
    local changed, new_on = reaper.ImGui_Checkbox(ctx, label, on)
    if dis and reaper.ImGui_EndDisabled then
        reaper.ImGui_EndDisabled(ctx)
    end
    if changed and can_toggle then
        return true, new_on
    end
    return false, on
end

--- Refresh stored widget.width, drop layout caches, wipe toolbar layout memo, save toolbar config.
function M.commit_dynamic_widget_layout(button, ctx, opts)
    opts = opts or {}
    if ctx and button and button.widget and button.widget.getLayoutWidth then
        local ok, w = pcall(button.widget.getLayoutWidth, button.widget, ctx)
        if ok and type(w) == "number" then
            button.widget.width = w
        end
    end
    if button and button.clearLayoutCache then
        button:clearLayoutCache()
    elseif button and button.clearCache then
        button:clearCache()
    end
    local gl = _G.C and _G.C.LayoutManager
    if gl then
        gl:invalidateCache()
    end
    if not opts.skip_save and button and button.saveChanges then
        button:saveChanges()
    end
end

return M
