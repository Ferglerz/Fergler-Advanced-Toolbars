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
    local out = text
    while #out > 1 do
        if reaper.ImGui_CalcTextSize(ctx, out .. ellipsis) <= max_w then
            break
        end
        out = out:sub(1, -2)
    end
    return out .. ellipsis
end

function M.formatWidgetValue(widget, explicit_value)
    local val = explicit_value ~= nil and explicit_value or widget.value
    if type(widget.format) == "function" then
        return widget.format(val or 0)
    end
    local fmt = type(val) == "number" and "%.2f" or "%s"
    return M.safeFormat(widget.format or fmt, val or 0)
end

function M.normalizeSlashes(path)
    return (path:gsub("\\", "/"))
end

function M.joinPath(...)
    local separator = reaper.GetOS():match("Win") and "\\" or "/"
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
