-- Systems/Widgets_Manager.lua

local WidgetsManager = {}
WidgetsManager.__index = WidgetsManager

function WidgetsManager.new()
    local self = setmetatable({}, WidgetsManager)

    self.button_widgets = {}
    _G.WIDGETS = {}

    self:scanWidgets()
    
    return self
end

function WidgetsManager:scanWidgets()
    local widgets_dir = UTILS.joinPath(SCRIPT_PATH, "Widgets")
    
    if not UTILS.ensureDirectoryExists(widgets_dir) then
        return
    end
    
    -- Get files in directory
    local files = UTILS.getFilesInDirectory(widgets_dir)


    -- Load each .lua file as a widget
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            local widget_name = file:gsub("%.lua$", "")
            local success, widget = pcall(function()
                local full_path = UTILS.normalizeSlashes(widgets_dir .. "/" .. file)
                return dofile(full_path)
            end
        )
            
            if success and widget and widget.name and widget.type then
                WIDGETS[widget_name] = widget
            else
                reaper.ShowConsoleMsg("Failed to load widget: " .. widget_name .. "\n")
            end
        end
    end
end

function WidgetsManager:assignWidgetToButton(button, widget_name)
    if not button or not WIDGETS[widget_name] then
        return false
    end
    
    local widget = WIDGETS[widget_name]
    
    -- Create widget instance with direct references to functions
    local widget_instance = {
        name = widget_name,
        type = widget.type,
        width = widget.width or 100,
        label = widget.label or "",
        format = widget.format or "%.2f",
        col_primary = widget.col_primary or nil,
        min_value = widget.min_value or 0,
        max_value = widget.max_value or 1,
        default_value = widget.default_value,
        value = 0,
        getValue = widget.getValue,
        setValue = widget.setValue,
        description = widget.description,
        last_update_time = 0,
        update_interval = widget.update_interval or 0.1 
    }
    
    -- Store on button
    button.widget = widget_instance
    
    -- Store in button_widgets
    self.button_widgets[button.id] = widget_instance
    
    -- Initialize with current value
    if widget_instance.getValue then
        local success, value = pcall(widget_instance.getValue)
        if success then
            widget_instance.value = value
        end
    end
    
    -- Clear button cache to force recalculation with the new widget width
    button:clearCache()
    button:saveChanges()
    
    return true
end

function WidgetsManager:removeWidgetFromButton(button)
    if not button or not button.widget then
        return false
    end
    
    -- Remove from button_widgets
    self.button_widgets[button.id] = nil
    
    -- Remove from button
    button.widget = nil
    
    return true
end

function WidgetsManager:getWidgetList()
    local list = {}
    for name, widget in pairs(WIDGETS) do
        table.insert(list, {
            name = name,
            display_name = widget.name,
            type = widget.type,
            description = widget.description or ""
        })
    end
    
    -- Sort by name
    table.sort(list, function(a, b) return a.display_name < b.display_name end)
    
    return list
end

function WidgetsManager:cleanup()
    self.button_widgets = {}
end

return WidgetsManager.new()