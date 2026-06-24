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

return M
