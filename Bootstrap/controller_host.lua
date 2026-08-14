-- Bootstrap/controller_host.lua
-- Toolbar controller registry, restart, temp toolbars

local ModulesFactory = require("Systems.Modules_Factory")

local M = {}

local main_ctx
local icon_font_attach_cache = setmetatable({}, { __mode = "k" })

local function imgui_ptr_ok(ptr, type_name)
    if not ptr then
        return false
    end
    if not reaper.APIExists("ImGui_ValidatePtr") then
        return true
    end
    local ok, v = pcall(reaper.ImGui_ValidatePtr, ptr, type_name)
    return ok and v == true
end

function M.setMainContext(ctx)
    main_ctx = ctx
    _G.MAIN_IMGUI_CTX = ctx
end

function M.getMainContext()
    return main_ctx
end

function M.getIconFontAttachCache()
    return icon_font_attach_cache
end

function M.imguiPtrOk(ptr, type_name)
    return imgui_ptr_ok(ptr, type_name)
end

function M.getActiveToolbarIndices()
    local active_indices = {}
    if _G.TOOLBAR_CONTROLLERS then
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            if controller_data.controller and
               controller_data.controller.is_open and
               controller_data.controller.toolbars and
               controller_data.controller.currentToolbarIndex then
                local index = controller_data.controller.currentToolbarIndex
                active_indices[index] = true
                if controller_data.controller.extra_rows then
                    for _, row in ipairs(controller_data.controller.extra_rows) do
                        if type(row) == "table" and row.toolbar_index then
                            active_indices[row.toolbar_index] = true
                        end
                    end
                end
            end
        end
    end
    return active_indices
end

function M.anyToolbarInEditMode()
    if not _G.TOOLBAR_CONTROLLERS then
        return false
    end
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
        if controller_data.controller and controller_data.controller.button_editing_mode then
            return true
        end
    end
    return false
end

local function nextToolbarControllerOrder()
    local max_order = 0
    if CONFIG and CONFIG.TOOLBAR_CONTROLLERS then
        for _, controller_data in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
            max_order = math.max(max_order, tonumber(controller_data.order) or 0)
        end
    end
    return max_order + 1
end

local function orderedToolbarControllers()
    local ordered = {}
    if not CONFIG or not CONFIG.TOOLBAR_CONTROLLERS then
        return ordered
    end
    for toolbar_id_str, controller_data in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
        table.insert(ordered, {
            id = tonumber(toolbar_id_str),
            order = tonumber(controller_data.order) or 0,
        })
    end
    table.sort(ordered, function(a, b)
        if a.order == b.order then
            return (a.id or 0) < (b.id or 0)
        end
        return a.order < b.order
    end)
    return ordered
end

local function findNextAvailableToolbarIndex(toolbars)
    if not toolbars or #toolbars == 0 then
        return 1
    end

    local active_indices = M.getActiveToolbarIndices()

    for i = 1, #toolbars do
        if not active_indices[i] then
            return i
        end
    end

    return 1
end

function M.createAndAttachFont(ctx)
    if not ctx then
        return nil
    end

    local system_fonts = {"Futura", "Arial", "Helvetica", "Segoe UI", "Verdana"}
    local text_size = CONFIG and CONFIG.SIZES and CONFIG.SIZES.TEXT or nil

    local function tryFont(font_name)
        local f = reaper.ImGui_CreateFont(font_name, text_size)
        if not f then
            return nil
        end
        local ok = pcall(function()
            reaper.ImGui_Attach(ctx, f)
        end)
        if ok then
            _G._adv_tb_cached_system_font_name = font_name
            return f
        end
        return nil
    end

    if _G._adv_tb_cached_system_font_name then
        local cached = tryFont(_G._adv_tb_cached_system_font_name)
        if cached then
            return cached
        end
        _G._adv_tb_cached_system_font_name = nil
    end

    for _, font_name in ipairs(system_fonts) do
        local font = tryFont(font_name)
        if font then
            return font
        end
    end

    return nil
end

function M.createToolbar(toolbar_id, use_main_context)
    toolbar_id = toolbar_id or ID_GENERATOR.generateToolbarId()

    local ctx
    if use_main_context then
        ctx = main_ctx
    else
        ctx = reaper.ImGui_CreateContext("Toolbar " .. toolbar_id)
    end

    local font = M.createAndAttachFont(ctx)
    local controller, renderer = ModulesFactory.createToolbar(toolbar_id)

    table.insert(
        _G.TOOLBAR_CONTROLLERS,
        {
            controller = controller,
            renderer = renderer,
            ctx = ctx,
            font = font
        }
    )

    return controller, renderer
end

function M.createNewToolbar()
    local new_id = ID_GENERATOR.ensureUniqueId(
        ID_GENERATOR.generateToolbarId(),
        CONFIG.TOOLBAR_CONTROLLERS,
        ID_GENERATOR.generateToolbarId
    )

    local controller, renderer = M.createToolbar(new_id, false)

    if controller.toolbars and #controller.toolbars > 0 then
        local next_index = findNextAvailableToolbarIndex(controller.toolbars)
        controller.currentToolbarIndex = next_index

        local toolbar_id_str = tostring(new_id)
        if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
            CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index = next_index
        end
    end

    CONFIG.TOOLBAR_CONTROLLERS[tostring(new_id)].order = nextToolbarControllerOrder()
    CONFIG_MANAGER:saveMainConfigImmediate()

    return controller, renderer
end

function M.createTempWidgetGalleryToolbar()
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        local ctl = controller_data.controller
        if ctl and ctl.is_ephemeral and ctl.is_widget_gallery then
            ctl:setOpen(true)
            return ctl, controller_data.renderer
        end
    end

    local new_id = ID_GENERATOR.generateToolbarId()
    local ctx = reaper.ImGui_CreateContext("Widget Gallery " .. tostring(new_id))
    local font = M.createAndAttachFont(ctx)

    local controller = C.ToolbarController.new(new_id)
    controller.is_ephemeral = true
    controller.is_widget_gallery = true
    local renderer = C.ToolbarRenderer.new(controller)
    controller.loader = C.ToolbarLoader.new(controller)

    if not controller.loader:loadEphemeralWidgetGallery() then
        pcall(function()
            reaper.ImGui_DestroyContext(ctx)
        end)
        return nil, nil
    end

    table.insert(
        _G.TOOLBAR_CONTROLLERS,
        {
            controller = controller,
            renderer = renderer,
            ctx = ctx,
            font = font
        }
    )

    return controller, renderer
end

function M.loadConfiguredToolbars()
    if CONFIG and CONFIG.TOOLBAR_CONTROLLERS and next(CONFIG.TOOLBAR_CONTROLLERS) then
        local first = true
        for _, toolbar_info in ipairs(orderedToolbarControllers()) do
            if first then
                M.createToolbar(toolbar_info.id, true)
                first = false
            else
                M.createToolbar(toolbar_info.id, false)
            end
        end
    else
        M.createToolbar(nil, true)
    end
end

function M.detachIconFontsFromContext(ctx)
    if not ctx then
        return
    end
    local sub = icon_font_attach_cache[ctx]
    if not sub then
        return
    end
    local list = {}
    for font in pairs(sub) do
        list[#list + 1] = font
    end
    for i = 1, #list do
        local f = list[i]
        pcall(function()
            reaper.ImGui_Detach(ctx, f)
        end)
        sub[f] = nil
    end
    icon_font_attach_cache[ctx] = nil
end

local function disposeToolbarControllerEntry(entry)
    if not entry then
        return
    end
    if entry.controller then
        entry.controller:unregisterAllButtons()
        entry.controller:setOpen(false)
    end
    if entry.ctx and entry.ctx ~= main_ctx then
        if entry.font then
            pcall(function()
                reaper.ImGui_Detach(entry.ctx, entry.font)
            end)
        end
        M.detachIconFontsFromContext(entry.ctx)
        if C.Interactions and C.Interactions.releaseContext then
            C.Interactions:releaseContext(entry.ctx)
        end
        pcall(function()
            reaper.ImGui_DestroyContext(entry.ctx)
        end)
    end
end

function M.purgeClosedEphemeralControllers()
    local list = _G.TOOLBAR_CONTROLLERS
    if not list then
        return
    end
    for i = #list, 1, -1 do
        local entry = list[i]
        local ctl = entry and entry.controller
        if ctl and ctl.is_ephemeral and not ctl.is_open then
            disposeToolbarControllerEntry(entry)
            table.remove(list, i)
        end
    end
end

local function restartToolbarControllerAtIndex(index)
    local list = _G.TOOLBAR_CONTROLLERS
    local entry = list[index]
    if not entry or not entry.controller then
        return
    end

    if C.DragDropManager and C.DragDropManager:isDragging() then
        C.DragDropManager:endDrag()
    end

    local saved_id = entry.controller.toolbar_id
    local old_ctx = entry.ctx
    local use_main = old_ctx == main_ctx

    entry.controller:disposeForImGuiRestart()

    if entry.font then
        pcall(function()
            reaper.ImGui_Detach(old_ctx, entry.font)
        end)
    end
    M.detachIconFontsFromContext(old_ctx)
    if C.Interactions and C.Interactions.releaseContext then
        C.Interactions:releaseContext(old_ctx)
    end
    pcall(function()
        reaper.ImGui_DestroyContext(old_ctx)
    end)
    _G.invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()

    if use_main then
        main_ctx = reaper.ImGui_CreateContext("Dynamic Toolbar")
        _G.MAIN_IMGUI_CTX = main_ctx
        entry.ctx = main_ctx
        entry.font = M.createAndAttachFont(main_ctx)
    else
        entry.ctx = reaper.ImGui_CreateContext("Toolbar " .. tostring(saved_id))
        entry.font = M.createAndAttachFont(entry.ctx)
    end

    local controller, renderer = ModulesFactory.createToolbar(saved_id)
    entry.controller = controller
    entry.renderer = renderer
    controller.is_open = true
end

function M.processPendingToolbarImGuiRestarts()
    for i, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        local ctl = cd.controller
        if ctl and ctl._imgui_window_restart_pending then
            ctl._imgui_window_restart_pending = false
            restartToolbarControllerAtIndex(i)
        end
    end
end

function M.cleanupOnShutdown()
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
        if controller_data.controller then
            controller_data.controller:cleanup()
        end
    end

    if C.ButtonManager then
        C.ButtonManager:cleanup()
    end

    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
        if controller_data.ctx and controller_data.ctx ~= main_ctx then
            if controller_data.font then
                pcall(function()
                    reaper.ImGui_Detach(controller_data.ctx, controller_data.font)
                end)
            end
            M.detachIconFontsFromContext(controller_data.ctx)
            if C.Interactions and C.Interactions.releaseContext then
                C.Interactions:releaseContext(controller_data.ctx)
            end
            pcall(function()
                reaper.ImGui_DestroyContext(controller_data.ctx)
            end)
        end
    end

    _G.invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()

    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
        if controller_data.ctx == main_ctx and controller_data.font then
            pcall(function()
                reaper.ImGui_Detach(main_ctx, controller_data.font)
            end)
            break
        end
    end

    main_ctx = nil
end

return M
