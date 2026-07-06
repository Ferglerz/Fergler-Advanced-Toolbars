-- Shared widget right-click option popups: padded BeginPopup, toggles that don't auto-close (Checkbox),
-- and layout persistence after dynamic width changes.

local M = {}



--- Refresh stored widget.width, drop layout caches, wipe toolbar layout memo, save toolbar config.
function M.commit_dynamic_widget_layout(button, ctx, opts)
    opts = opts or {}
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
