-- Systems/Icon_Manager.lua
-- Manages icon resources, textures, and dimensions for toolbar buttons

local IconManager = {}
IconManager.__index = IconManager

function IconManager.new()
    local self = setmetatable({}, IconManager)
    
    -- Resource caches
    self.texture_cache = {}  -- Cache of loaded textures
    
    return self
end

function IconManager:loadButtonIcon(button)
    if not button or not button.icon_path or button.skip_icon then return end
    
    -- Initialize cache if needed
    if not button.cache.icon then
        button.cache.icon = {}
    end
    
    -- Normalize the path for consistent caching
    local normalized_path = UTILS.normalizeSlashes(button.icon_path)
    
    -- Already cached on the button? Use it
    if button.cache.icon.texture then
        return
    end
    
    -- Check if texture is already in global cache
    local cached_texture = self.texture_cache[normalized_path]
    
    if cached_texture then
        -- Use the cached texture
        button.cache.icon.texture = cached_texture
    else
        -- Load the texture
        local texture = reaper.ImGui_CreateImage(normalized_path)
        if texture then
            self.texture_cache[normalized_path] = texture
            button.cache.icon.texture = texture
        end
    end
    
    -- Calculate dimensions if we have a texture
    if button.cache.icon.texture then
        self:calculateIconDimensions(button)
    end
end

function IconManager:calculateIconDimensions(button)
    if not button or not button.cache.icon or not button.cache.icon.texture then
        return nil
    end
    
    -- Initialize dimensions cache if needed
    if not button.cache.icon.dimensions then
        button.cache.icon.dimensions = {}
    end
    
    -- Skip if dimensions are already cached
    if button.cache.icon.dimensions.width and button.cache.icon.dimensions.height then
        return
    end
    
    -- Get the maximum height based on button height and padding
    local max_height = CONFIG.SIZES.HEIGHT - (CONFIG.ICON_FONT.PADDING * 2)
    
    -- Get the size of the texture
    local success, width, height = pcall(function()
        return reaper.ImGui_Image_GetSize(button.cache.icon.texture)
    end)
    
    if not success or not width or not height then
        return nil
    end
    
    -- Calculate the scale to maintain aspect ratio
    local scale = math.min(1, max_height / height)
    
    -- Apply user scale factor
    local user_scale = CONFIG.ICON_FONT.SCALE or 1
    
    button.cache.icon.dimensions = {
        width = math.floor(width * scale * user_scale),
        height = math.floor(height * scale * user_scale)
    }
end

function IconManager:clearCache()
    -- Clear the texture cache
    self.texture_cache = {}
end

function IconManager:cleanup()
    -- Release resources
    self.texture_cache = {}
end

return IconManager.new()