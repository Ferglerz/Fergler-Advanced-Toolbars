-- Utils/Core/button/layout.lua

local identity = require("Utils.Core.button.identity")

local M = {}

function M.getSeparatorHeight(button, is_vertical)
    if not button then
        return CONFIG.SIZES.SEPARATOR_SIZE
    end

    if is_vertical then
        return (button.cache and button.cache.layout and button.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
    else
        return CONFIG.SIZES.HEIGHT
    end
end

function M.getExtraPadding(button)
    if not button then
        return 0
    end
    return (button.cached_width and button.cached_width.extra_padding) or 0
end

function M.liveVerticalStripWidth(ctx, toolbar_layout)
    if not ctx or not toolbar_layout or not toolbar_layout.is_vertical then
        return nil
    end
    if not reaper.ImGui_GetWindowWidth then
        return nil
    end
    local win_w = reaper.ImGui_GetWindowWidth(ctx)
    if not win_w or win_w <= 0 then
        return nil
    end
    local pad = math.max(1, math.floor((CONFIG.SIZES.PADDING or 6) / 2))
    return math.max(CONFIG.SIZES.MIN_WIDTH or 30, win_w - 2 * pad)
end

function M.computeHitRect(button, layout, ctx, rel_x, rel_y, is_vertical)
    if not layout then
        return rel_x, rel_y, CONFIG.SIZES.MIN_WIDTH or 30, CONFIG.SIZES.HEIGHT
    end
    local hit_w = layout.width or CONFIG.SIZES.MIN_WIDTH or 30
    local hit_h = layout.height or CONFIG.SIZES.HEIGHT
    local hit_x, hit_y = rel_x, rel_y
    if identity.hasWidget(button) then
        local title_h = layout.title_height or 0
        if title_h > 0 and not is_vertical then
            hit_y = rel_y - title_h
            hit_h = hit_h + title_h
        end
    end
    return hit_x, hit_y, hit_w, hit_h
end

function M.shouldSkipSeparatorInVerticalMode(button, is_vertical, has_visible_label)
    return is_vertical and
           has_visible_label and
           button:isSeparator() and
           button.is_section_end
end

return M
