-- Widget catalog titles (ALL CAPS): global on/off per orientation, two-line fit, layout height.

local M = {}

local DRAWING = require("Utils.drawing")

M.PAD_TOP = 1
M.PAD_BOTTOM = 2
M.INSET_X = 4

function M.show_for_layout(is_vertical)
    local ui = CONFIG and CONFIG.UI
    if not ui then
        return false
    end
    if is_vertical then
        return ui.SHOW_WIDGET_TITLES_VERTICAL ~= false
    end
    return ui.SHOW_WIDGET_TITLES_HORIZONTAL == true
end

function M.catalog_display_name(widget)
    if not widget then
        return nil
    end
    if type(widget.display_name) == "string" and widget.display_name ~= "" then
        return widget.display_name
    end
    local catalog = _G.WIDGETS and widget.name and _G.WIDGETS[widget.name]
    if catalog and type(catalog.name) == "string" and catalog.name ~= "" then
        return catalog.name
    end
    if type(widget.name) == "string" and widget.name ~= "" then
        return widget.name:gsub("_", " ")
    end
    return nil
end

function M.should_show(widget, is_vertical)
    if not widget or not M.show_for_layout(is_vertical) then
        return false
    end
    local name = M.catalog_display_name(widget)
    return name ~= nil and name ~= ""
end

function M.uppercase_title(widget)
    local name = M.catalog_display_name(widget)
    if not name or name == "" then
        return nil
    end
    return string.upper(name)
end

--- Returns lines (1–2), total strip height in px.
function M.measure(ctx, widget, width, is_vertical)
    if not ctx or not M.should_show(widget, is_vertical) then
        return 0, nil
    end
    local text = M.uppercase_title(widget)
    local inner_w = math.max(8, (width or 0) - M.INSET_X * 2)
    local lines = BUTTON_UTILS.fitTextTwoLinesForWidth(ctx, text, inner_w)
    
    local is_clipped = false
    local ell = "…"
    for _, line in ipairs(lines) do
        if line:sub(-#ell) == ell then
            is_clipped = true
            break
        end
    end
    
    local probe = "ABCDEFGHIJKLMNO"
    local char_w = reaper.ImGui_CalcTextSize(ctx, probe) / #probe
    local max_chars = math.max(4, math.floor(inner_w / math.max(char_w, 1)))
    local split = BUTTON_UTILS.balancedSpaceSplitLine(text, max_chars)
    local raw_lines = 0
    for _ in tostring(split):gmatch("[^\n]+") do raw_lines = raw_lines + 1 end
    
    if raw_lines > 2 or is_clipped then
        return 0, nil
    end

    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local h = M.PAD_TOP + line_h * #lines + M.PAD_BOTTOM
    return h, lines
end

--- Minimum button width so the catalog title fits (measure returns 0 when clipped).
function M.required_width(ctx, widget, is_vertical)
    if not ctx or not M.should_show(widget, is_vertical) then
        return 0
    end
    local lo, hi, best = 32, 640, 640
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local h = M.measure(ctx, widget, mid, is_vertical)
        if h > 0 then
            best = mid
            hi = mid - 1
        else
            lo = mid + 1
        end
    end
    return best
end

function M.draw(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, opts)
    opts = opts or {}
    local is_vertical = opts.is_vertical
    if not M.should_show(widget, is_vertical) then
        return
    end
    local lines = opts.lines
    if not lines then
        local text = M.uppercase_title(widget)
        local inner_w = math.max(8, (render_width or 0) - M.INSET_X * 2)
        lines = BUTTON_UTILS.fitTextTwoLinesForWidth(ctx, text, inner_w)
    end
    if not lines or #lines < 1 then
        return
    end
    local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local y = rel_y + M.PAD_TOP
    for _, line in ipairs(lines) do
        DRAWING.drawCenteredText(ctx, coords, draw_list, rel_x, y, render_width, line_h, line, label_color, 0)
        y = y + line_h
    end
end

return M
