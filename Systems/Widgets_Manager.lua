-- Systems/Widgets_Manager.lua

local WidgetsManager = {}
WidgetsManager.__index = WidgetsManager

function WidgetsManager.new()
    local self = setmetatable({}, WidgetsManager)

    _G.WIDGETS = {}

    self:scanWidgets()
    
    return self
end

function WidgetsManager:scanWidgets()
    local widgets_dir = UTILS.joinPath(SCRIPT_PATH, "Widgets")
    
    if not UTILS.ensureDirectoryExists(widgets_dir) then
        return
    end
    
    local paths = UTILS.collectLuaFilesRecursive(widgets_dir)

    for _, full_path in ipairs(paths) do
        local widget_name = full_path:match("([^/\\]+)%.lua$") or ""
        if widget_name == "" then
        elseif WIDGETS[widget_name] then
            reaper.ShowConsoleMsg(
                "Advanced Toolbars: skipping duplicate widget filename (already loaded): " .. widget_name .. "\n"
            )
        else
            local success, widget = pcall(function()
                return dofile(full_path)
            end)

            if success and widget and widget.name and widget.type then
                WIDGETS[widget_name] = widget
            else
                reaper.ShowConsoleMsg("Failed to load widget: " .. widget_name .. " (" .. full_path .. ")\n")
            end
        end
    end
end

-- Fresh instance for toolbar or preview (not yet assigned to a button).
function WidgetsManager:cloneWidgetInstance(widget_name)
    if not WIDGETS[widget_name] then
        return nil
    end

    local widget = WIDGETS[widget_name]
    local widget_instance = {}
    for key, value in pairs(widget) do
        widget_instance[key] = value
    end

    widget_instance.name = widget_name
    widget_instance.value = 0
    widget_instance.last_update_time = 0
    widget_instance.update_interval = widget.update_interval or 0.1

    for key in pairs(widget_instance) do
        if type(key) == "string" and key:match("^__guard_") then
            widget_instance[key] = nil
        end
    end

    if widget_instance.getValue then
        local success, value = pcall(widget_instance.getValue, widget_instance)
        if success then
            widget_instance.value = value
        end
    end

    return widget_instance
end

-- opts: optional { skip_save = true } — caller persists toolbar (e.g. insert + widget in one save)
function WidgetsManager:assignWidgetToButton(button, widget_name, opts)
    if not button or not WIDGETS[widget_name] then
        return false
    end
    opts = opts or {}

    local widget_instance = self:cloneWidgetInstance(widget_name)
    if not widget_instance then
        return false
    end

    -- Single runtime source: button.widget (persisted via BUTTON_CUSTOM_PROPERTIES on save).
    button.widget = widget_instance

    -- Clear button cache to force recalculation with the new widget width
    button:clearCache()
    if not opts.skip_save then
        button:saveChanges()
    end

    return true
end

function WidgetsManager:removeWidgetFromButton(button)
    if not button or not button.widget then
        return false
    end
    
    -- Remove from button
    button.widget = nil
    
    return true
end

-- Top-level sections in the widget picker (order matters).
local MACRO_GROUP_ORDER = {
    "Time, grid & tempo",
    "Items & selection",
    "Mix & monitoring",
    "Project & surfaces",
    "General",
    "Under Development",
}

local function macro_group_sort_key(name)
    name = name or ""
    for i, g in ipairs(MACRO_GROUP_ORDER) do
        if g == name then
            return i, name
        end
    end
    return 200, name
end

local function resolve_macro_group(widget)
    if type(widget.macro_group) == "string" and widget.macro_group ~= "" then
        return widget.macro_group
    end
    if widget.category == "Under Development" then
        return "Under Development"
    end
    return "General"
end

function WidgetsManager:getWidgetList()
    local list = {}
    for name, widget in pairs(WIDGETS) do
        local macro_group = resolve_macro_group(widget)
        table.insert(list, {
            name = name,
            display_name = widget.name,
            type = widget.type,
            description = widget.description or "",
            macro_group = macro_group,
            category = widget.category or "",
        })
    end

    table.sort(list, function(a, b)
        local ra, ga = macro_group_sort_key(a.macro_group)
        local rb, gb = macro_group_sort_key(b.macro_group)
        if ra ~= rb then
            return ra < rb
        end
        if ga ~= gb then
            return ga < gb
        end
        local ca, cb = a.category or "", b.category or ""
        if ca ~= cb then
            if ca == "" then
                return true
            end
            if cb == "" then
                return false
            end
            return ca < cb
        end
        return a.display_name < b.display_name
    end)

    return list
end

return WidgetsManager