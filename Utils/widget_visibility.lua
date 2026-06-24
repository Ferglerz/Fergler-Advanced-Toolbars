-- Shared persisted boolean maps (e.g. widget._visible[id]) and checkbox popups with "at least N on" rules.

local OPT = require("Utils.widget_options_popup")

local M = {}

--- Ensure holder[field_name] is a table with every ordered id -> true if missing.
function M.ensure_bool_field(holder, ordered_ids, field_name)
    field_name = field_name or "_visible"
    if holder[field_name] then
        return
    end
    local t = {}
    for _, id in ipairs(ordered_ids) do
        t[id] = true
    end
    holder[field_name] = t
end

--- Count ids in order where holder[field][id] ~= false.
function M.count_enabled(holder, ordered_ids, field_name)
    field_name = field_name or "_visible"
    local t = holder[field_name]
    if not t then
        return 0
    end
    local n = 0
    for _, id in ipairs(ordered_ids) do
        if t[id] ~= false then
            n = n + 1
        end
    end
    return n
end

--- Merge opts[persist_key] into holder[field]; drop unknown keys; enforce min count afterward.
function M.apply_persisted_bool_map(holder, opts, spec)
    local field = spec.field or "_visible"
    local pk = spec.persist_key or "visible"
    local ordered = spec.ordered_ids
    M.ensure_bool_field(holder, ordered, field)
    if type(opts) ~= "table" or type(opts[pk]) ~= "table" then
        return
    end
    local t = holder[field]
    for id, on in pairs(opts[pk]) do
        if t[id] ~= nil then
            t[id] = on == true
        end
    end
    local min_n = spec.min_after_apply or 1
    if M.count_enabled(holder, ordered, field) < min_n then
        local rid = spec.restore_id or ordered[1]
        if rid then
            t[rid] = true
        end
    end
end

--- Export { [persist_key] = { id -> bool } } for ordered ids.
function M.export_bool_map(holder, spec)
    local field = spec.field or "_visible"
    local pk = spec.persist_key or "visible"
    M.ensure_bool_field(holder, spec.ordered_ids, field)
    local t = holder[field]
    local vis = {}
    for _, id in ipairs(spec.ordered_ids) do
        vis[id] = t[id] ~= false
    end
    return { [pk] = vis }
end

--- Checkbox popup: rows are { label, get(holder), set(holder, bool) } or { separator = true }.
--- total_visible(holder) -> int; min_visible defaults to 1.
--- on_changed(button, ctx) optional instead of default commit_dynamic_widget_layout.
function M.draw_checkbox_list(ctx, button, holder, spec)
    if spec.title then
        reaper.ImGui_TextDisabled(ctx, spec.title)
        reaper.ImGui_Spacing(ctx)
    end

    local changed = false
    local min_vis = spec.min_visible or 1
    local total_fn = spec.total_visible
    local drew_item = false
    local pending_separator = false

    for _, row in ipairs(spec.rows) do
        if row.separator then
            if drew_item then
                pending_separator = true
            end
        else
            if pending_separator then
                reaper.ImGui_Separator(ctx)
                pending_separator = false
            end
            
            local total = total_fn(holder)
            local on = row.get(holder)
            local can_toggle = (not on) or total > min_vis
            
            if not can_toggle then
                reaper.ImGui_BeginDisabled(ctx)
            end
            local ch, new_on = reaper.ImGui_Checkbox(ctx, row.label, on)
            if not can_toggle then
                reaper.ImGui_EndDisabled(ctx)
            end
            
            drew_item = true
            
            if ch and can_toggle then
                row.set(holder, new_on)
                changed = true
            end
        end
    end

    if changed then
        if spec.on_changed then
            spec.on_changed(button, ctx)
        else
            OPT.commit_dynamic_widget_layout(button, ctx)
        end
    end
end

return M
