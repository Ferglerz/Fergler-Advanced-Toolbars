-- Systems/Interactions/preset_browser/preset_browser_tree.lua
local ACTION_CATALOG_MANIFEST = require("Data.reaper_actions.category_manifest")

local M = {}

function M.clonePath(src, max_depth)
    local out = {}
    if type(src) ~= "table" then
        return out
    end
    local limit = max_depth or #src
    for i = 1, limit do
        out[i] = src[i]
    end
    return out
end

function M.pathsEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

function M.stripClusterLabelDetails(label)
    local s = tostring(label or "")
    local cluster = s:match("([Cc]luster%s+%d+)")
    if cluster and cluster ~= "" then
        return cluster:gsub("^%l", string.upper)
    end
    s = s:gsub("%s*%b()", "")
    s = s:gsub("%s+$", "")
    if s == "" then
        return tostring(label or "Cluster")
    end
    return s
end

local function simplifyActionDisplayLabel(label)
    local s = tostring(label or "")
    local stripped = s:gsub("^%s*[^:]+:%s*", "")
    stripped = stripped:gsub("^%s+", ""):gsub("%s+$", "")
    if stripped == "" then
        return s
    end
    return stripped
end

function M.getPresetBrowserRoot(self)
    if self.preset_browser_root then
        return self.preset_browser_root
    end

    local root = {
        id = "root",
        label = "REAPER actions",
        kind = "root",
        children = {}
    }

    for _, cat in ipairs((ACTION_CATALOG_MANIFEST and ACTION_CATALOG_MANIFEST.categories) or {}) do
        local cat_node = {
            id = tostring(cat.id or cat.label or "category"),
            label = tostring(cat.label or "Category"),
            kind = "folder",
            children = {}
        }

        for _, subcat in ipairs(cat.subcategories or {}) do
            local subcat_label = tostring(subcat.label or "Subcategory")
            local is_all_actions = subcat_label:lower() == "all actions"
            local subcat_children = cat_node.children
            if not is_all_actions then
                local subcat_node = {
                    id = tostring(subcat.id or subcat.label or "subcategory"),
                    label = subcat_label,
                    kind = "folder",
                    children = {}
                }
                table.insert(cat_node.children, subcat_node)
                subcat_children = subcat_node.children
            end

            for _, rel_file in ipairs(subcat.files or {}) do
                local file_label = tostring(rel_file or ""):gsub("^.+/", ""):gsub("%.lua$", "")
                table.insert(
                    subcat_children,
                    {
                        id = tostring(rel_file),
                        label = file_label ~= "" and file_label or "Action group",
                        kind = "lua_table",
                        file_rel_path = tostring(rel_file),
                        children = nil
                    }
                )
            end
        end

        table.insert(root.children, cat_node)
    end

    self.preset_browser_root = root
    return root
end

function M.loadActionChunk(self, file_rel_path)
    local rel = tostring(file_rel_path or "")
    if rel == "" then
        return nil
    end
    if self.preset_browser_chunk_cache[rel] ~= nil then
        return self.preset_browser_chunk_cache[rel]
    end

    local full_path = UTILS.joinPath(SCRIPT_PATH, rel)
    local chunk_fn = loadfile(full_path)
    if not chunk_fn then
        self.preset_browser_chunk_cache[rel] = false
        return nil
    end
    local ok, chunk = pcall(chunk_fn)
    if not ok or type(chunk) ~= "table" then
        self.preset_browser_chunk_cache[rel] = false
        return nil
    end
    self.preset_browser_chunk_cache[rel] = chunk
    return chunk
end

function M.ensurePresetNodeChildrenLoaded(self, node)
    if not node or node.kind ~= "lua_table" then
        return
    end
    if type(node.children) == "table" then
        return
    end

    node.children = {}
    local chunk = self:loadActionChunk(node.file_rel_path)
    if not chunk then
        return
    end

    if type(chunk.group_label) == "string" and chunk.group_label ~= "" then
        node.label = chunk.group_label
    end

    for idx, action in ipairs(chunk.actions or {}) do
        local action_id = tostring(action.command_id or "")
        if action_id ~= "" then
            table.insert(
                node.children,
                {
                    id = tostring(chunk.group_id or node.file_rel_path or "group") .. "_action_" .. tostring(idx),
                    label = simplifyActionDisplayLabel(tostring(action.title or action.action_key or ("Action " .. tostring(idx)))),
                    kind = "action_button",
                    action_row = {
                        name = tostring(action.title or action.action_key or "Action"),
                        action_id = action_id
                    }
                }
            )
        end
    end
end

function M.collectToolbarRowsFromNode(self, node)
    if not node then
        return {}
    end
    if node.kind == "action_button" and node.action_row then
        return { node.action_row }
    end
    if node.kind ~= "lua_table" then
        return {}
    end

    local chunk = self:loadActionChunk(node.file_rel_path)
    local rows = {}
    for _, action in ipairs((chunk and chunk.actions) or {}) do
        local aid = tostring(action.command_id or "")
        if aid ~= "" then
            table.insert(
                rows,
                {
                    name = tostring(action.title or action.action_key or "Action"),
                    action_id = aid
                }
            )
        end
    end
    return rows
end

function M.resolvePresetNode(self, path)
    local node = self:getPresetBrowserRoot()
    if type(path) ~= "table" then
        return node
    end
    for _, child_index in ipairs(path) do
        self:ensurePresetNodeChildrenLoaded(node)
        if not node or not node.children or not node.children[child_index] then
            return nil
        end
        node = node.children[child_index]
    end
    return node
end

return M
