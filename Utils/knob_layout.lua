-- Utils/knob_layout.lua
-- Shared logic for layout of knobs and adjacent chips.

local M = {}

M.EDGE_PAD = 4
M.CHIP_GAP = 6

--- Returns the layout width required.
function M.get_width(base_knob_w, chips_info)
    local total = base_knob_w
    if chips_info and #chips_info > 0 then
        total = total + M.EDGE_PAD
        for _, c in ipairs(chips_info) do
            total = total + c.w
        end
        total = total + (#chips_info) * M.CHIP_GAP
    end
    return total
end

--- Returns the layout for a knob and its extra chips.
--- `chips_info`: array of { id, w, h }
--- Returns:
---   knob_rect: { x, y, w, h }
---   chips: array of { id, x, y, w, h }
function M.layout(rel_x, rel_y, render_width, direction, chips_info)
    local height = CONFIG and CONFIG.SIZES and CONFIG.SIZES.HEIGHT or 24
    
    local total_chips_w = 0
    if chips_info and #chips_info > 0 then
        for _, c in ipairs(chips_info) do
            total_chips_w = total_chips_w + c.w
        end
        total_chips_w = total_chips_w + (#chips_info) * M.CHIP_GAP
    end

    local knob_w = render_width - total_chips_w - M.EDGE_PAD
    if knob_w < 10 then knob_w = 10 end
    local knob_x, current_chip_x

    if direction == "left" then
        -- [ Knob ] [ Gap ] [ Chips ] [ Pad ]
        knob_x = rel_x
        current_chip_x = rel_x + knob_w + M.CHIP_GAP
    else
        -- [ Pad ] [ Chips ] [ Gap ] [ Knob ]
        current_chip_x = rel_x + M.EDGE_PAD
        knob_x = rel_x + M.EDGE_PAD + total_chips_w
    end

    local chips_out = {}
    if chips_info then
        for _, c in ipairs(chips_info) do
            table.insert(chips_out, {
                id = c.id,
                x = current_chip_x,
                y = rel_y + (height - c.h) / 2,
                w = c.w,
                h = c.h
            })
            current_chip_x = current_chip_x + c.w + M.CHIP_GAP
        end
    end

    return { x = knob_x, y = rel_y, w = knob_w, h = height }, chips_out
end

--- Horizontal region opposite the knob circle (value text, edit chip, etc.).
function M.text_area(rel_x, render_width, style, direction, is_merged, height)
    height = height or (CONFIG and CONFIG.SIZES and CONFIG.SIZES.HEIGHT) or 24
    style = style or "knob"
    direction = direction or "right"

    local pad_y = 4
    local edge_pad = (style == "simple_knob" and is_merged) and pad_y or (style == "simple_knob" and 0 or 3)

    local radius
    if style == "simple_knob" then
        radius = math.max(6, (height - 2 * edge_pad) / 2)
    else
        local max_r = math.min((render_width - 2 * edge_pad) / 2, (height - 2 * edge_pad) / 2)
        radius = math.max(6, max_r)
    end

    if style == "simple_knob" then
        local cx_rel
        if direction == "left" then
            cx_rel = rel_x + edge_pad + radius
            return cx_rel + radius, render_width - (cx_rel + radius - rel_x)
        end
        cx_rel = rel_x + render_width - edge_pad - radius
        return rel_x, cx_rel - radius - rel_x
    end

    local cx_rel = rel_x + render_width / 2
    local left_w = cx_rel - radius - rel_x
    local right_w = (rel_x + render_width) - (cx_rel + radius)
    if left_w >= right_w then
        return rel_x, left_w
    end
    return cx_rel + radius, right_w
end

return M
