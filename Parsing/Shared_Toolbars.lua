-- Parsing/Shared_Toolbars.lua — parse toolbar configs once per session; all controllers share result.

local SharedToolbars = {}
SharedToolbars.__index = SharedToolbars

function SharedToolbars.new()
    local self = setmetatable({}, SharedToolbars)
    self.toolbars = nil
    self.menu_path = nil
    self.dirty = true
    self.sanitize_scheduled = false
    return self
end

function SharedToolbars:invalidate()
    self.dirty = true
    self.sanitize_scheduled = false
end

function SharedToolbars:unregisterSharedButtons()
    if not self.toolbars or not C or not C.ButtonManager then
        return
    end
    for _, toolbar in ipairs(self.toolbars) do
        for _, button in ipairs(toolbar.buttons or {}) do
            C.ButtonManager:unregisterButton(button)
        end
    end
end

local function loadIniContent()
    if not C or not C.IniManager then
        return nil
    end
    local content = C.IniManager:getContent()
    if not content then
        content = C.IniManager:loadContent(true)
    end
    return content
end

function SharedToolbars:parseFresh()
    self:unregisterSharedButtons()

    local ini_content = loadIniContent()
    local menu_path = UTILS.joinPath(SCRIPT_PATH, "User/toolbar_configs")
    local menu_content = CONFIG_MANAGER:buildRuntimeIniContentFromToolbarConfigs(ini_content)
    if not menu_content then
        return nil, menu_path
    end

    local toolbars = C.ParseToolbars:parseToolbars(menu_content)
    if #toolbars == 0 then
        return nil, menu_path
    end

    self.toolbars = toolbars
    self.menu_path = menu_path
    self.dirty = false
    return toolbars, menu_path
end

function SharedToolbars:scheduleDeferredSanitize()
    if self.sanitize_scheduled then
        return
    end
    self.sanitize_scheduled = true

    reaper.defer(
        function()
            if not self.toolbars then
                return
            end

            local sanitized_disk = false
            for _, toolbar in ipairs(self.toolbars) do
                if CONFIG_MANAGER:persistToolbarConfigSanitize(toolbar) then
                    sanitized_disk = true
                end
            end

            if not sanitized_disk then
                return
            end

            self:invalidate()
            local toolbars, menu_path = self:parseFresh()
            if not toolbars then
                return
            end

            for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
                local controller = controller_data and controller_data.controller
                if controller and controller.loader then
                    controller.loader:attachSharedToolbars(toolbars, menu_path)
                end
            end

            if C.LayoutManager then
                C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
            end
        end
    )
end

function SharedToolbars:ensureLoaded()
    if not self.dirty and self.toolbars then
        return self.toolbars, self.menu_path
    end

    local toolbars, menu_path = self:parseFresh()
    if toolbars then
        self:scheduleDeferredSanitize()
    end
    return toolbars, menu_path
end

return SharedToolbars
