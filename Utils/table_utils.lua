-- Utils/table_utils.lua
local M = {}

local serializeValue -- forward declaration

function M.tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function M.dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            local key_str = k
            if type(k) ~= "number" then
                key_str = '"' .. k .. '"'
            end
            s = s .. "[" .. key_str .. "] = " .. M.dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

function serializeValue(value, indent)
    if value == nil then
        return "nil"
    elseif type(value) == "table" then
        return M.serializeTable(value, indent)
    elseif type(value) == "string" then
        return string.format('"%s"', value:gsub('"', '\\"'):gsub("\n", "\\n"))
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    else
        return string.format('"%s"', tostring(value))
    end
end
M.serializeValue = serializeValue

function M.serializeTable(tbl, indent)
    indent = indent or "    "
    local parts = {}

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(
        keys,
        function(a, b)
            return tostring(a) < tostring(b)
        end
    )

    for _, key in ipairs(keys) do
        local value = tbl[key]
        -- Use simple key format if possible
        local key_str
        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            key_str = key
        elseif type(key) == "number" then
            -- For numeric keys, use array-style indexing
            key_str = "[" .. key .. "]"
        else
            key_str = '["' .. tostring(key) .. '"]'
        end

        local value_str = serializeValue(value, indent .. "    ")
        table.insert(parts, indent .. key_str .. " = " .. value_str)
    end

    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent:sub(1, -5) .. "}"
end

function M.findById(list, id, id_key)
    id_key = id_key or "id"
    for _, item in ipairs(list or {}) do
        if item[id_key] == id then
            return item
        end
    end
    return nil
end

return M
