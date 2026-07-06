-- Managers/Icon.lua
-- Manages icon resources, textures, and dimensions for toolbar buttons

local REAPER_ICONS = require("Utils.Core.reaper_toolbar_icons")
local REAPER_TRACK_ICONS = require("Utils.Core.reaper_track_icons")
local ControllerHost = require("Bootstrap.controller_host")

local function texturePtrOk(texture)
    return ControllerHost.imguiPtrOk(texture, "ImGui_Image*")
end

local IconManager = {}
IconManager.__index = IconManager

function IconManager.new()
    local self = setmetatable({}, IconManager)

    -- Resource caches
    self.texture_cache = {}  -- Cache of loaded textures

    return self
end

function IconManager:loadTexture(normalized_path)
    if not normalized_path or normalized_path == "" then
        return nil
    end

    local cached_texture = self.texture_cache[normalized_path]
    if cached_texture then
        if texturePtrOk(cached_texture) then
            return cached_texture
        end
        self.texture_cache[normalized_path] = nil
    end

    local texture = reaper.ImGui_CreateImage(normalized_path)
    if texture and texturePtrOk(texture) then
        self.texture_cache[normalized_path] = texture
        return texture
    end
    return nil
end

function IconManager:loadButtonIcon(button)
    if not button or button.skip_icon then
        return
    end

    if not button.icon_path and not button.reaper_icon_path and not button.reaper_track_icon_path then
        return
    end

    if not button.cache.icon then
        button.cache.icon = {}
    end

    if button.cache.icon.texture then
        if texturePtrOk(button.cache.icon.texture) then
            return
        end
        button.cache.icon = {}
    end

    local normalized_path
    local uv

    if button.reaper_icon_path then
        normalized_path = REAPER_ICONS.resolveAbsolutePath(button.reaper_icon_path)
        if not normalized_path then
            return
        end
        local u0, v0, u1, v1 = REAPER_ICONS.frameUv()
        uv = {u0 = u0, v0 = v0, u1 = u1, v1 = v1}
    elseif button.reaper_track_icon_path then
        normalized_path = REAPER_TRACK_ICONS.resolveAbsolutePath(button.reaper_track_icon_path)
        if not normalized_path then
            return
        end
    else
        normalized_path = UTILS.normalizeSlashes(button.icon_path)
    end

    local texture = self:loadTexture(normalized_path)
    if not texture then
        return
    end

    button.cache.icon.texture = texture
    button.cache.icon.source_path = normalized_path
    button.cache.icon.uv = uv
    self:calculateIconDimensions(button)
end

function IconManager:calculateIconDimensions(button)
    if not button or not button.cache.icon or not button.cache.icon.texture then
        return nil
    end

    if not button.cache.icon.dimensions then
        button.cache.icon.dimensions = {}
    end

    if button.cache.icon.dimensions.width and button.cache.icon.dimensions.height then
        return
    end

    local max_height = CONFIG.SIZES.HEIGHT - (CONFIG.ICON_FONT.PADDING * 2)

    local success, width, height = pcall(function()
        return reaper.ImGui_Image_GetSize(button.cache.icon.texture)
    end)

    if not success or not width or not height then
        return nil
    end

    if button.reaper_icon_path and button.cache.icon.uv then
        width = width / REAPER_ICONS.FRAME_COUNT
        button.cache.icon.dimensions = {
            width = math.floor(width),
            height = math.floor(height),
            uv = button.cache.icon.uv
        }
        return
    end

    local scale = math.min(1, max_height / height)

    if button.reaper_track_icon_path then
        button.cache.icon.dimensions = {
            width = math.floor(width * scale),
            height = math.floor(height * scale),
            uv = nil
        }
        return
    end

    -- Custom image icons only: fit icon band + ICON_FONT.SCALE
    local user_scale = CONFIG.ICON_FONT.SCALE

    button.cache.icon.dimensions = {
        width = math.floor(width * scale * user_scale),
        height = math.floor(height * scale * user_scale),
        uv = button.cache.icon.uv
    }
end

function IconManager:clearCache()
    self.texture_cache = {}
end

function IconManager:cleanup()
    self.texture_cache = {}
end

return IconManager
