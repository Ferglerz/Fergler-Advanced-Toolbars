-- Factory for sliders that read/write a field on all selected media items.

local M = {}

function M.attach(widget, spec)
    widget.cached_value = widget.cached_value or spec.default_value or 0
    widget.last_selection_hash = widget.last_selection_hash or ""

    widget.is_disabled = function()
        return reaper.CountSelectedMediaItems(0) == 0
    end

    widget.getValue = function()
        return UTILS.cachedOnSelectionChange(widget, "last_selection_hash", "cached_value", spec.default_value or 0, function()
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                return spec.default_value or 0
            end
            if spec.read_first then
                return spec.read_first(item)
            end
            return spec.default_value or 0
        end)
    end

    widget.setValue = function(value)
        widget.cached_value = value
        local item_count = reaper.CountSelectedMediaItems(0)
        if item_count < 1 then
            return
        end
        if spec.use_undo_block then
            reaper.Undo_BeginBlock()
        end
        for i = 0, item_count - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if item and spec.write_item then
                spec.write_item(item, value)
                reaper.UpdateItemInProject(item)
            end
        end
        reaper.UpdateArrange()
        if spec.use_undo_block then
            reaper.Undo_EndBlock(spec.undo_label or widget.name or "Item change", -1)
        else
            reaper.Undo_OnStateChange(spec.undo_label or widget.name or "Item change")
        end
    end
end

return M
