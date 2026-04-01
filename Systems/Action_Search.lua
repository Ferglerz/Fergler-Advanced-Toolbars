-- Systems/Action_Search.lua
-- Loads Python-generated reaper_actions_index.lua (full action list in source order) for UI search.

local ActionSearch = {}
ActionSearch.__index = ActionSearch

function ActionSearch.getIndexPath()
    local base = _G.SCRIPT_PATH or ""
    return UTILS.normalizeSlashes(UTILS.joinPath(base, "Data/reaper_actions/reaper_actions_index.lua"))
end

function ActionSearch.load()
    local path = ActionSearch.getIndexPath()
    local chunk, err = loadfile(path)
    if not chunk then
        return nil, err or "loadfile failed"
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" or type(data.actions) ~= "table" then
        return nil, "invalid index data"
    end
    return data, nil
end

--- Match if every whitespace-separated token appears in title (plain substring, case-insensitive ASCII).
function ActionSearch.matchesQuery(title, query)
    if type(title) ~= "string" or type(query) ~= "string" then
        return false
    end
    local t = title:lower()
    for token in query:gmatch("%S+") do
        if not t:find(token:lower(), 1, true) then
            return false
        end
    end
    return true
end

--- Optional section filter: nil or "" = all sections.
function ActionSearch.collectSections(actions)
    local seen = {}
    local out = {}
    for _, row in ipairs(actions or {}) do
        local s = row.s
        if type(s) == "string" and s ~= "" and not seen[s] then
            seen[s] = true
            table.insert(out, s)
        end
    end
    table.sort(out)
    return out
end

function ActionSearch.filter(actions, query, section_filter, max_results)
    local out = {}
    max_results = max_results or 200
    local q = (query or ""):match("^%s*(.-)%s*$") or ""
    if q == "" then
        return out
    end
    local sf = section_filter and section_filter ~= "" and section_filter or nil
    for _, row in ipairs(actions) do
        if not sf or row.s == sf then
            if ActionSearch.matchesQuery(row.t or "", q) then
                table.insert(out, row)
                if #out >= max_results then
                    break
                end
            end
        end
    end
    return out
end

return ActionSearch
