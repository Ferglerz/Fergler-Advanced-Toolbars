-- Utils/string_utils.lua
local M = {}

function M.stripNewLines(text)
    return text:gsub("[\n\r]", " ")
end

function M.parseToolbarItemLine(line)
    if type(line) ~= "string" then
        return nil, nil, nil
    end
    return line:match("^item_(%d+)=(%S+)%s*(.*)$")
end

function M.formatToolbarItemLine(index0, id, text)
    id = tostring(id or "")
    if id == "-1" then
        return string.format("item_%d=%s", index0, id)
    end
    text = text ~= nil and tostring(text) or ""
    if text == "" then
        return string.format("item_%d=%s", index0, id)
    end
    return string.format("item_%d=%s %s", index0, id, text)
end

function M.matchIniSectionHeader(line)
    if type(line) ~= "string" then
        return nil
    end
    return line:match("^%[(.+)%]$")
end

function M.parseIniToolbars(content)
    local toolbars = {}
    local current = nil

    if type(content) ~= "string" or content == "" then
        return toolbars
    end

    local function pushCurrent()
        if current then
            table.insert(toolbars, current)
        end
    end

    for line in content:gmatch("[^\r\n]+") do
        local section_name = M.matchIniSectionHeader(line)
        if section_name then
            pushCurrent()
            current = {
                section = section_name,
                title = nil,
                default = nil,
                icons = {},
                items = {}
            }
        elseif current then
            local _, id, text = M.parseToolbarItemLine(line)
            if id then
                table.insert(current.items, { id = id, text = text or "" })
            else
                local default_val = line:match("^default=(.*)$")
                if default_val ~= nil then
                    current.default = default_val
                else
                    local icon_idx, icon_val = line:match("^icon_(%d+)=(.*)$")
                    if icon_idx and icon_val ~= nil then
                        current.icons[tonumber(icon_idx)] = icon_val
                    else
                        local title_val = line:match("^title=(.*)$")
                        if title_val ~= nil then
                            current.title = title_val
                        end
                    end
                end
            end
        end
    end

    pushCurrent()
    return toolbars
end

function M.asNumber(v, default)
    local ty = type(v)
    if ty == "number" then
        if v ~= v then
            return default
        end
        return v
    end
    if ty == "string" then
        return tonumber(v) or default
    end
    return default
end

function M.safeFormat(fmt, value)
    local ok, result = pcall(string.format, fmt or "%s", value)
    if ok then
        return result
    end
    return tostring(value)
end

function M.formatFontName(name)
    return name:gsub("_[0-9]+$", ""):gsub("_", " ")
end

function M.getSafeFilename(str)
    return str:gsub('[%/\\%:%*%?%"<>%|]', "_")
end

function M.trimTextToWidth(ctx, text, max_w, ellipsis)
    text = text or ""
    if text == "" then return "" end
    ellipsis = ellipsis or "…"
    max_w = max_w or 0
    if reaper.ImGui_CalcTextSize(ctx, text) <= max_w then
        return text
    end
    local lo, hi = 1, #text
    local best = 1
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if reaper.ImGui_CalcTextSize(ctx, text:sub(1, mid) .. ellipsis) <= max_w then
            best = mid
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return text:sub(1, best) .. ellipsis
end

function M.decimalPlacesFromStep(step)
    step = math.abs(M.asNumber(step, 0) or 0)
    if step <= 0 then
        return 0
    end
    if step >= 1 then
        return 0
    end
    local d = 0
    local s = step
    while d < 6 and math.abs(s - math.floor(s + 0.5)) > 1e-9 do
        s = s * 10
        d = d + 1
    end
    return d
end

local TOOLTIP_MAX_DECIMALS = 3

function M.decimalPlacesForValue(val, max_decimals)
    max_decimals = max_decimals or TOOLTIP_MAX_DECIMALS
    val = M.asNumber(val, 0) or 0
    if math.abs(val - math.floor(val + 0.5)) < 1e-9 then
        return 0
    end
    for d = 1, max_decimals do
        local scaled = val * (10 ^ d)
        if math.abs(scaled - math.floor(scaled + 0.5)) < 1e-6 then
            return d
        end
    end
    return max_decimals
end

local function tooltipDecimalCap(widget, fine_mode)
    if widget.tooltip_decimals then
        return math.min(widget.tooltip_decimals, TOOLTIP_MAX_DECIMALS)
    end
    if widget.fine_decimals then
        return math.min(widget.fine_decimals, TOOLTIP_MAX_DECIMALS)
    end
    local cap = M.decimalPlacesFromStep(widget.fine_scale or 0.1)
    if fine_mode then
        cap = math.max(cap, 1)
    end
    if widget.snap_increment and widget.snap_increment > 0 and widget.snap_increment < 1 then
        cap = math.max(cap, M.decimalPlacesFromStep(widget.snap_increment))
    end
    return math.min(cap, TOOLTIP_MAX_DECIMALS)
end

local function adaptiveTooltipFormat(widget, val, fine_mode)
    local base = widget.format
    if type(base) ~= "string" then
        return nil
    end
    local sign, n = base:match("%%(%+?)%.(%d+)f")
    if not n then
        return nil
    end
    n = tonumber(n)
    local max_d = tooltipDecimalCap(widget, fine_mode)
    local d = M.decimalPlacesForValue(val, max_d)
    if d == 0 then
        return nil
    end
    d = math.max(d, n)
    if d == n then
        return nil
    end
    return base:gsub("%%(%+?)%." .. n .. "f", "%%.%1" .. d .. "f")
end

function M.formatWidgetValue(widget, explicit_value, opts)
    opts = opts or {}
    if type(widget.display_text) == "function" then
        return widget.display_text(widget, opts)
    end
    local val = explicit_value ~= nil and explicit_value or widget.value
    if type(widget.format) == "function" then
        return widget.format(val or 0, opts)
    end
    if opts.tooltip then
        local adaptive = adaptiveTooltipFormat(widget, val or 0, opts.fine_mode)
        if adaptive then
            return M.safeFormat(adaptive, val or 0)
        end
    end
    local fmt = type(val) == "number" and "%.2f" or "%s"
    return M.safeFormat(widget.format or fmt, val or 0)
end

function M.normalizeSlashes(path)
    return (path:gsub("\\", "/"))
end

function M.joinPath(...)
    local separator = M._path_separator
    if not separator then
        separator = reaper.GetOS():match("Win") and "\\" or "/"
        M._path_separator = separator
    end
    local result = ""

    for i, part in ipairs({...}) do
        if i > 1 and not result:match("[\\/]$") and not part:match("^[\\/]") then
            result = result .. separator
        end
        result = result .. part
    end

    return result
end

return M
