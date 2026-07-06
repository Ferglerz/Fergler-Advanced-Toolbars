-- Utils/Widget/chip_widget_base.lua
-- Shared setup for chip widget factories (mode row, discrete row, slider presets, spinner slide-out).

local ROW = require("Utils.Chips.chip_row")
local CHIP_HIT = require("Utils.Chips.chip_hit_prefix")

local M = {}

--- Find a mode/entry table row by id.
function M.mode_by_id(list, id)
    return UTILS.findById(list, id)
end

--- Resolve preview subset from ordered id list.
function M.preview_entries_by_ids(preview_ids, list)
    local out = {}
    for _, pid in ipairs(preview_ids or {}) do
        local e = M.mode_by_id(list, pid)
        if e then
            out[#out + 1] = e
        end
    end
    return out
end

--- Alias for mode multiswitch widgets.
M.preview_mode_entries = M.preview_entries_by_ids

--- Standard chip widget table fields from a factory spec.
function M.apply_base_widget(spec, opts)
    opts = opts or {}
    local chip_widget = true
    if opts.chip_widget ~= nil then
        chip_widget = opts.chip_widget
    elseif spec.chip_widget == false then
        chip_widget = false
    end

    local widget = {
        name = spec.name,
        display_name = spec.display_name,
        category = spec.category,
        type = spec.type or "display",
        update_interval = spec.update_interval or opts.update_interval,
        description = spec.description or "",
        label = spec.label or "",
        chip_widget = chip_widget,
        suppress_tooltip = spec.suppress_tooltip ~= false,
        width = spec.width ~= nil and spec.width or opts.default_width,
    }

    if opts.extra then
        for k, v in pairs(opts.extra) do
            widget[k] = v
        end
    end

    for k, v in pairs(spec.state or {}) do
        widget[k] = v
    end

    if spec.slide_out then
        widget._slide_out_mode = true
    end

    if spec.slide_out_can_interact then
        widget.slide_out_can_interact = spec.slide_out_can_interact
    end

    return widget
end

--- Replace widget methods when spec provides overrides.
function M.apply_spec_overrides(widget, spec, method_names)
    for _, method_name in ipairs(method_names) do
        if spec[method_name] then
            widget[method_name] = spec[method_name]
        end
    end
end

--- Parse prefixed subcontrol id (chip_hit_prefix pattern).
function M.strip_click_id(prefix, sub_id)
    return CHIP_HIT.strip(prefix, sub_id)
end

--- Hit-test laid-out chips; returns prefixed sub_id or nil.
function M.hit_test_chips(mx, my, coords, chips, prefix)
    return ROW.hit_test_chips(mx, my, coords, chips, prefix)
end

function M.prefixed_sub_id(prefix, id)
    return prefix .. id
end

return M
