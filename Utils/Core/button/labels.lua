-- Utils/Core/button/labels.lua

local M = {}

local function normalize_label_ws(s)
    if not s or s == "" then
        return ""
    end
    s = s:gsub("\\n", " ")
    return (s:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")) or ""
end

local function balanced_space_split(line, max_chars)
    if not line or #line <= max_chars then
        return line
    end
    local best_pos, best_score, best_mid_dist = nil, math.huge, math.huge
    local mid = #line / 2
    for pos = 1, #line do
        if line:byte(pos) == 32 then
            local left = (line:sub(1, pos - 1):gsub("%s+$", ""))
            local right = (line:sub(pos + 1):gsub("^%s+", ""))
            if #left > 0 and #right > 0 then
                local score = math.abs(#left - #right)
                local mid_dist = math.abs(pos - mid)
                if score < best_score or (score == best_score and mid_dist < best_mid_dist) then
                    best_score = score
                    best_mid_dist = mid_dist
                    best_pos = pos
                end
            end
        end
    end
    if not best_pos then
        return line
    end
    local left = line:sub(1, best_pos - 1):gsub("%s+$", "")
    local right = line:sub(best_pos + 1):gsub("^%s+", "")
    return left .. "\n" .. right
end

function M.balancedSpaceSplitLine(line, max_chars)
    return balanced_space_split(line, max_chars)
end

function M.shouldDisplayText(button)
    if not button then
        return false
    end
    return not button.hide_label and
           button.display_text and
           button.display_text ~= "" and
           button.display_text ~= "SEPARATOR"
end

function M.shouldShowText(button)
    if not button then
        return false
    end
    return not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
end

function M.fitTextTwoLinesForWidth(ctx, text, max_width)
    if not text or text == "" then
        return {}
    end
    if not ctx or not max_width or max_width < 4 then
        return { text }
    end
    if reaper.ImGui_CalcTextSize(ctx, text) <= max_width then
        return { text }
    end
    local probe = "ABCDEFGHIJKLMNO"
    local char_w = reaper.ImGui_CalcTextSize(ctx, probe) / #probe
    local max_chars = math.max(4, math.floor(max_width / math.max(char_w, 1)))
    local split = balanced_space_split(text, max_chars)
    local lines = {}
    for line in tostring(split):gmatch("[^\n]+") do
        if line ~= "" then
            table.insert(lines, UTILS.trimTextToWidth(ctx, line, max_width))
        end
    end
    if #lines < 1 then
        return { UTILS.trimTextToWidth(ctx, text, max_width) }
    end
    if #lines > 2 then
        return { lines[1], lines[2] }
    end
    return lines
end

function M.getButtonLabelTextForRender(button)
    if not button then
        return ""
    end
    local raw = button.display_text or ""
    raw = raw:gsub("\\n", "\n")
    if raw:find("\n", 1, true) then
        return raw
    end
    if button.is_separator then
        return raw
    end
    local disp_n = normalize_label_ws(raw)
    local orig_n = normalize_label_ws(button.original_text or "")
    if orig_n == "" or disp_n ~= orig_n then
        return raw
    end
    local maxc = (CONFIG.SIZES and CONFIG.SIZES.ACTION_NAME_FALLBACK_MAX_LINE_CHARS) or 14
    return balanced_space_split(raw, maxc)
end

return M
