-- Renderers/01_Toolbar/helpers.lua

function ToolbarWindow:toolbarEdgePad()
    return math.max(1, math.floor((CONFIG.SIZES.PADDING or 6) / 2))
end

function ToolbarWindow:pinHeightPad()
    return self:toolbarEdgePad() * 2
end

-- REAPER API: col_main_bg2 = main window / transport background (see SetThemeColor / GetThemeColor docs).
function ToolbarWindow:themeTransportBackgroundImgui()
    if not reaper.GetThemeColor then
        return nil
    end
    local ok, c = pcall(function()
        return reaper.GetThemeColor("col_main_bg2", 0)
    end)
    if not ok or type(c) ~= "number" or c < 0 then
        return nil
    end
    return COLOR_UTILS.reaperColorToImGui(c)
end

-- Pinned UI-anchor toolbars always use horizontal row layout; height is content minimum only.
function ToolbarWindow:computePinnedMinContentHeight(layout, layout_switch, show_switch)
    if not layout.groups or #layout.groups == 0 then
        local label = (CONFIG.UI and CONFIG.UI.USE_GROUP_LABELS) and 24 or 0
        return (CONFIG.SIZES.HEIGHT or 38) + label + self:pinHeightPad()
    end
    local row_h = layout.height
    if show_switch and layout_switch then
        row_h = math.max(row_h, layout_switch.height)
    end
    return row_h + self:pinHeightPad()
end
