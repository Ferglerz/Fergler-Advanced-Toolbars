-- preset_manager.lua
local PresetManager = {}
PresetManager.__index = PresetManager

function PresetManager.new(reaper, helpers)
    local self = setmetatable({}, PresetManager)
    self.r = reaper
    self.helpers = helpers
    self.presets = {}              -- Loaded presets
    self.button_presets = {}       -- Active presets by button ID
    
    -- Load presets from the presets directory
    self:scanPresets()
    
    return self
end

function PresetManager:scanPresets()
    local presets_dir = SCRIPT_PATH .. "presets/"
    
    -- Create directory if it doesn't exist
    if not self.r.file_exists(presets_dir) then
        if self.r.RecursiveCreateDirectory(presets_dir, 0) == 0 then
            self.r.ShowMessageBox("Failed to create presets directory", "Error", 0)
            return
        end
    end
    
    -- Get files in directory
    local files = self:getFilesInDirectory(presets_dir)
    
    -- Load each .lua file as a preset
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            local preset_name = file:gsub("%.lua$", "")
            local success, preset = pcall(function()
                return dofile(presets_dir .. file)
            end)
            
            if success and preset and preset.name and preset.type then
                self.presets[preset_name] = preset
            else
                self.r.ShowConsoleMsg("Failed to load preset: " .. preset_name .. "\n")
            end
        end
    end
end

function PresetManager:getFilesInDirectory(directory)
    local files = {}
    
    -- Platform specific directory listing
    if self.r.GetOS():match("Win") then
        -- Windows
        local cmd = 'dir /b "' .. directory:gsub("/", "\\") .. '"'
        local handle = io.popen(cmd)
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    else
        -- macOS/Linux
        local cmd = 'ls -1 "' .. directory .. '"'
        local handle = io.popen(cmd)
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    end
    
    return files
end

function PresetManager:assignPresetToButton(button, preset_name)
    if not button or not self.presets[preset_name] then
        return false
    end
    
    local preset = self.presets[preset_name]
    
    -- Create preset instance with direct references to functions
    local preset_instance = {
        name = preset_name,
        type = preset.type,
        width = preset.width or 100,  -- Ensure width is set with a default of 100
        label = preset.label or "",
        format = preset.format or "%.2f",
        col_primary = preset.col_primary or nil,
        min_value = preset.min_value or 0,
        max_value = preset.max_value or 1,
        default_value = preset.default_value,
        value = 0,
        getValue = preset.getValue,
        setValue = preset.setValue,
        description = preset.description,
        last_update_time = 0,
        update_interval = preset.update_interval or 0.1 
    }
    
    -- Store on button
    button.preset = preset_instance
    
    -- Store in button_presets
    self.button_presets[button.id] = preset_instance
    
    -- Initialize with current value
    if preset_instance.getValue then
        local success, value = pcall(preset_instance.getValue, self.r)
        if success then
            preset_instance.value = value
        end
    end
    
    -- Clear button cache to force recalculation with the new preset width
    button:clearCache()
    
    return true
end

function PresetManager:removePresetFromButton(button)
    if not button or not button.preset then
        return false
    end
    
    -- Remove from button_presets
    self.button_presets[button.id] = nil
    
    -- Remove from button
    button.preset = nil
    
    return true
end

function PresetManager:getPresetList()
    local list = {}
    for name, preset in pairs(self.presets) do
        table.insert(list, {
            name = name,
            display_name = preset.name,
            type = preset.type,
            description = preset.description or ""
        })
    end
    
    -- Sort by name
    table.sort(list, function(a, b) return a.display_name < b.display_name end)
    
    return list
end

function PresetManager:cleanup()
    self.button_presets = {}
end

return {
    new = function(reaper, helpers)
        return PresetManager.new(reaper, helpers)
    end
}