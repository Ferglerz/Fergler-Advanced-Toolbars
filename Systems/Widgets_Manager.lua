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
    
    -- Copy ALL properties and functions from the original widget
    local widget_instance = {}
    for key, value in pairs(widget) do
        widget_instance[key] = value
    end
    
    -- Override with instance-specific values
    widget_instance.name = widget_name
    widget_instance.value = 0
    widget_instance.last_update_time = 0
    widget_instance.update_interval = widget.update_interval or 0.1
    
    -- Initialize with current value if getValue exists
    if widget_instance.getValue then
        local success, value = pcall(widget_instance.getValue, widget_instance)
        if success then
            widget_instance.value = value
        end
    end
    
    -- Store on button
    button.widget = widget_instance
    
    -- Store in button_widgets
    self.button_widgets[button.id] = widget_instance
    
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