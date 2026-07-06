-- Utils/grid_utils.lua
-- Shared project-grid math/state used by Grid_Ruler_Chip, ftc_adaptive_grid, and other grid widgets.
local M = {}

-- Continued-fraction decimal -> fraction. Returns numerator, denominator.
function M.decimal_to_fraction(x)
    local err = 1e-10
    local n = math.floor(x)
    x = x - n
    if x < err then return n, 1 end
    if 1 - err < x then return n + 1, 1 end
    local lower_n, lower_d, upper_n, upper_d = 0, 1, 1, 1
    while true do
        local middle_n = lower_n + upper_n
        local middle_d = lower_d + upper_d
        if middle_d * (x + err) < middle_n then
            upper_n, upper_d = middle_n, middle_d
        elseif middle_n < (x - err) * middle_d then
            lower_n, lower_d = middle_n, middle_d
        else
            return n * middle_d + middle_n, middle_d
        end
    end
end

-- Formats a grid division value as a fraction string (e.g. 0.25 -> "1/4", 1.0 -> "1").
function M.fraction_text(div)
    if not div or div <= 0 then return "1/4" end
    local num, denom = M.decimal_to_fraction(div)
    if num > 1 and denom % num == 0 then denom, num = denom / num, 1 end
    return (num >= denom and num % denom == 0) and ("%.0f"):format(num / denom)
        or ("%.0f/%.0f"):format(num, denom)
end

-- True if a grid division is a triplet value.
function M.is_triplet(div)
    if not div or div <= 0 then return false end
    local val = div * 1.5
    local log2 = math.log(val) / math.log(2)
    local rounded = math.floor(log2 + 0.5)
    return math.abs(log2 - rounded) < 1e-5
end

-- Current project grid: base division (triplet folded out), triplet flag, swing mode, swing amount.
function M.get_state()
    local _, div, swmode, swamt = reaper.GetSetProjectGrid(0, 0)
    if not div or div <= 0 then div = 0.25 end
    local trip = M.is_triplet(div)
    local base_div = trip and (div * 1.5) or div
    return base_div, trip, swmode, swamt
end

-- Sets a base division, applying triplet folding and preserving swing settings.
function M.set_division(base_div, trip, swmode, swamt)
    local new_div = trip and (base_div * (2 / 3)) or base_div
    reaper.GetSetProjectGrid(0, true, new_div, swmode, swamt)
end

-- Toggles triplet state on the current grid.
function M.toggle_triplet()
    local base_div, trip, swmode, swamt = M.get_state()
    M.set_division(base_div, not trip, swmode, swamt)
end

return M
