-- Gold template: slider (tier 1b — plain table, no factory).
-- Copy to Widgets/my_slider.lua and edit. This folder is not auto-loaded.

local widget = {
    name = "My Control",
    category = "General",
    type = "slider",
    width = 160,
    update_interval = 0.05,
    min_value = 0,
    max_value = 100,
    default_value = 50,
    format = "%.0f",
    title = "Value",
    description = "Short picker description",
    snap_increment = 1,
    fine_scale = 0.1,

    getValue = function()
        return 50
    end,

    setValue = function(value)
        -- Apply value to project; optional UTILS.withUndoBlock wrapper
    end,
}

return widget
