-- Utils/dim_utils.lua
local dim_utils = {}

-- Dimensional operations
function dim_utils.calculateTextWidth(ctx, text, font)
    local max_width = 0
    if font then
        reaper.ImGui_PushFont(ctx, font)
    end
    for line in text:gmatch("[^\n]+") do
        local line_width = reaper.ImGui_CalcTextSize(ctx, line)
        max_width = math.max(max_width, line_width)
    end
    if font then
        reaper.ImGui_PopFont(ctx)
    end
    return max_width
end

function dim_utils.calculateImageDimensions(texture, max_height, scale_factor)
    if not texture then
        return nil
    end

    local success, w, h =
        pcall(
        function()
            return reaper.ImGui_Image_GetSize(texture)
        end
    )

    if success and w and h then
        local scale = math.min(1, max_height / h)
        return {
            width = math.floor(w * scale * (scale_factor or 1)),
            height = math.floor(h * scale * (scale_factor or 1))
        }
    end

    return nil
end

function dim_utils.calculateIconDimensions(button)
    if not button or not button.icon_texture then
        return
    end

    local max_height = CONFIG.SIZES.HEIGHT - (CONFIG.ICON_FONT.PADDING * 2)
    local dimensions = UTILS.calculateImageDimensions(button.icon_texture, max_height, CONFIG.ICON_FONT.SCALE)

    return dimensions
end

return dim_utils
