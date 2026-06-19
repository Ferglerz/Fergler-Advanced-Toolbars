-- Advanced Toolbars.lua

_G.USE_PROFILER = false

-- Get the script path
local info = debug.getinfo(1, "S")
_G.SCRIPT_PATH = info.source:match([[^@?(.*[\/])[^\/]-$]])
SCRIPT_PATH = SCRIPT_PATH:match("^%?(.*)$") or SCRIPT_PATH

-- Add the script's directory to the Lua package path
package.path = SCRIPT_PATH .. "?.lua;" .. package.path

--- Toolbar toggle for this action: is_new_value, filename, section_id, cmd_id, ...
local _, _, ACTION_SECTION, ACTION_CMD = reaper.get_action_context()
local function set_toolbar_toggle_state(state)
    if ACTION_CMD == nil or ACTION_CMD < 0 then
        return
    end
    reaper.SetToggleCommandState(ACTION_SECTION, ACTION_CMD, state)
    reaper.RefreshToolbar2(ACTION_SECTION, ACTION_CMD)
end

-- Check for ReaImGui
if not reaper.APIExists("ImGui_CreateContext") then
    reaper.ShowMessageBox("Please install ReaImGui extension.", "Error", 0)
    set_toolbar_toggle_state(0)
    return
end

_G.UTILS = require("Utils.utils")
_G.REAPER_UI_ANCHOR = require("Utils.reaper_ui_anchor")
_G.DRAWING = require("Utils.drawing")
_G.COLOR_UTILS = require("Utils.color_utils")
_G.COORDINATES = require("Utils.coordinates")
_G.ID_GENERATOR = require("Utils.id_generator")
_G.CACHE_UTILS = require("Utils.cache_utils")
_G.BUTTON_UTILS = require("Utils.button_utils")
_G.CHIP_MULTISWITCH = require("Utils.chip_multiswitch")
_G.LUA_SCRIPT_EXTRACT = require("Utils.lua_script_extract")
_G.POPUP_OPEN = false

_G.CONFIG = nil

_G.CONFIG_MANAGER = require("Managers.Config").new()

local ICON_FONTS_LIB = require("Utils.icon_fonts")
_G.ICON_FONTS = ICON_FONTS_LIB.scanIconFonts(SCRIPT_PATH, UTILS)
_G.ICON_FONTS.path_index = ICON_FONTS_LIB.path_index

--- @return boolean
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

-- Weak keys: ctx GC drops per-context attach bookkeeping.
local icon_font_attach_cache = setmetatable({}, { __mode = "k" })

--- Create ImGui font from disk for one ICON_FONTS row (lazy; safe after a context that used fonts was destroyed).
function _G.resolveIconFontEntryFont(entry)
    if not entry or not entry.path then
        return nil
    end
    if entry.font then
        if imgui_ptr_ok(entry.font, "ImGui_Font*") then
            return entry.font
        end
        entry.font = nil
    end
    local root = tostring(SCRIPT_PATH or ""):gsub("[\\/]*$", "")
    local rel = UTILS.normalizeSlashes(tostring(entry.path or "")):gsub("^/*", "")
    local full_path = root .. "/" .. rel
    if not reaper.file_exists(full_path) then
        return nil
    end
    local f = reaper.ImGui_CreateFontFromFile(full_path)
    if not f then
        return nil
    end
    entry.font = f
    return entry.font
end

--- ImFont* dies with its ImGui context; call after DestroyContext so handles are not reused.
function _G.invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
    for i = 1, #ICON_FONTS do
        ICON_FONTS[i].font = nil
    end
    for k in pairs(icon_font_attach_cache) do
        icon_font_attach_cache[k] = nil
    end
    _G._adv_tb_icon_font_rev = (_G._adv_tb_icon_font_rev or 0) + 1
end

--- Attach an icon font handle to ctx once. Bulk-attaching all ICON_FONTS exhausts the ImGui atlas.
--- @return boolean
function _G.ensureIconFontAttachedToContext(ctx, font)
    if not ctx or not font then
        return false
    end
    if not imgui_ptr_ok(ctx, "ImGui_Context*") then
        return false
    end
    if not imgui_ptr_ok(font, "ImGui_Font*") then
        invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
        return false
    end
    local sub = icon_font_attach_cache[ctx]
    if not sub then
        -- Plain table: weak keys were unsafe — font userdata could detach from bookkeeping while
        -- handle was still reused, leading to bogus re-Attach or stale state.
        sub = {}
        icon_font_attach_cache[ctx] = sub
    end
    if sub[font] then
        if not imgui_ptr_ok(font, "ImGui_Font*") then
            sub[font] = nil
            invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
            return false
        end
        return true
    end
    local ok = pcall(function()
        reaper.ImGui_Attach(ctx, font)
    end)
    if ok then
        sub[font] = true
    else
        -- Atlas full or mismatched backend state — drop cached handles so next frame recreates cleanly.
        invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
    end
    return ok
end

local ModulesFactory = require("Systems.Modules_Factory")
ModulesFactory.createGlobalModules()

local startup_toolbars = ModulesFactory.loadSharedToolbarsAtStartup()
if not startup_toolbars or #startup_toolbars == 0 then
    reaper.ShowMessageBox("No toolbars found in toolbar configs", "Error", 0)
    set_toolbar_toggle_state(0)
    return
end

local GridRulerChip = require("Windows.Grid_Ruler_Chip")

-- Set up main ImGui context for the first toolbar
local main_ctx = reaper.ImGui_CreateContext("Dynamic Toolbar")
_G.MAIN_IMGUI_CTX = main_ctx

_G.TOOLBAR_CONTROLLERS = {}

-- Get the set of toolbar indices currently in use by active toolbar controllers
_G.getActiveToolbarIndices = function()
    local active_indices = {}
    if _G.TOOLBAR_CONTROLLERS then
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            if controller_data.controller and 
               controller_data.controller.is_open and 
               controller_data.controller.toolbars and
               controller_data.controller.currentToolbarIndex then
                local index = controller_data.controller.currentToolbarIndex
                active_indices[index] = true
                -- Also mark extra row toolbar indices as active
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

-- Used by IniManager to avoid reloading reaper-menu.ini while REAPER may rewrite the same file
_G.anyToolbarInEditMode = function()
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

-- Next CONFIG.TOOLBAR_CONTROLLERS.order (max existing + 1; not controller count).
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

-- Find the next available toolbar index that's not currently active
local function findNextAvailableToolbarIndex(toolbars)
    if not toolbars or #toolbars == 0 then
        return 1
    end
    
    local active_indices = getActiveToolbarIndices()
    
    -- Find the first index that's not active
    for i = 1, #toolbars do
        if not active_indices[i] then
            return i
        end
    end
    
    -- If all are active, return the first one anyway
    return 1
end

local function createAndAttachFont(ctx)
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

function CreateToolbar(toolbar_id, use_main_context)
    -- Generate a unique ID if not provided
    toolbar_id = toolbar_id or ID_GENERATOR.generateToolbarId()
    
    -- Set up context
    local ctx
    
    if use_main_context then
        ctx = main_ctx
    else
        -- Create a new context for this toolbar
        ctx = reaper.ImGui_CreateContext("Toolbar " .. toolbar_id)
    end
    
    -- Create and attach font
    local font = createAndAttachFont(ctx)
    
    -- Create controller and renderer
    local controller, renderer = ModulesFactory.createToolbar(toolbar_id)
    
    -- Icon .ttf handles are created lazily via resolveIconFontEntryFont (see Renderers/04_Content.lua).

    -- Add to global list
    table.insert(
        _G.TOOLBAR_CONTROLLERS,
        {
            controller = controller,
            renderer = renderer,
            ctx = ctx,
            font = font
        }
    )
    
    -- Config entry for this toolbar is created in controller:initialize()
    
    return controller, renderer
end

_G.CreateNewToolbar = function()
    -- Create a new toolbar with a unique ID
    local new_id = ID_GENERATOR.ensureUniqueId(
        ID_GENERATOR.generateToolbarId(),
        CONFIG.TOOLBAR_CONTROLLERS,
        ID_GENERATOR.generateToolbarId
    )
    
    -- Create the toolbar with the unique ID
    local controller, renderer = CreateToolbar(new_id, false)
    
    -- Find next available toolbar index (not currently active)
    if controller.toolbars and #controller.toolbars > 0 then
        local next_index = findNextAvailableToolbarIndex(controller.toolbars)
        controller.currentToolbarIndex = next_index
        
        -- Save the toolbar index to config
        local toolbar_id_str = tostring(new_id)
        if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
            CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index = next_index
        end
    end
    
    -- Set the order property to place it at the end
    CONFIG.TOOLBAR_CONTROLLERS[tostring(new_id)].order = nextToolbarControllerOrder()
    
    -- Save the configuration
    CONFIG_MANAGER:saveMainConfigImmediate()
    
    return controller, renderer
end

if CONFIG and CONFIG.TOOLBAR_CONTROLLERS and next(CONFIG.TOOLBAR_CONTROLLERS) then
    -- Load toolbars in order
    local first = true
    for _, toolbar_info in ipairs(orderedToolbarControllers()) do
        if first then
            -- First toolbar uses the main context
            CreateToolbar(toolbar_info.id, true)
            first = false
        else
            -- Other toolbars get their own contexts
            CreateToolbar(toolbar_info.id, false)
        end
    end
else
    -- Create a default controller if none exist
    CreateToolbar(nil, true)
end

local function detachIconFontsFromContext(ctx)
    if not ctx then
        return
    end
    local sub = icon_font_attach_cache[ctx]
    if not sub then
        return
    end
    -- Copy keys first: detach may mutate weak-key bookkeeping.
    local list = {}
    for font in pairs(sub) do
        list[#list + 1] = font
    end
    for i = 1, #list do
        local f = list[i]
        pcall(
            function()
                reaper.ImGui_Detach(ctx, f)
            end
        )
        sub[f] = nil
    end
    icon_font_attach_cache[ctx] = nil
end

local function attachIconFontsToContext(_ctx)
    -- Intentionally empty: attaching every ICON_FONTS entry fills the atlas; fonts attach on demand.
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
        pcall(
            function()
                reaper.ImGui_Detach(old_ctx, entry.font)
            end
        )
    end
    detachIconFontsFromContext(old_ctx)
    pcall(
        function()
            reaper.ImGui_DestroyContext(old_ctx)
        end
    )
    invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()

    if use_main then
        main_ctx = reaper.ImGui_CreateContext("Dynamic Toolbar")
        _G.MAIN_IMGUI_CTX = main_ctx
        entry.ctx = main_ctx
        entry.font = createAndAttachFont(main_ctx)
        attachIconFontsToContext(main_ctx)
    else
        entry.ctx = reaper.ImGui_CreateContext("Toolbar " .. tostring(saved_id))
        entry.font = createAndAttachFont(entry.ctx)
        attachIconFontsToContext(entry.ctx)
    end

    local controller, renderer = ModulesFactory.createToolbar(saved_id)
    entry.controller = controller
    entry.renderer = renderer
    controller.is_open = true
end

local function processPendingToolbarImGuiRestarts()
    for i, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        local ctl = cd.controller
        if ctl and ctl._imgui_window_restart_pending then
            ctl._imgui_window_restart_pending = false
            restartToolbarControllerAtIndex(i)
        end
    end
end

function Loop()
    processPendingToolbarImGuiRestarts()

    _G.FRAME_TIME = reaper.time_precise()

    if C.DragDropManager then
        C.DragDropManager:beginFrameDropTarget()
    end

    -- Runtime toolbars are now sourced from User store; no frame-by-frame INI reload.

    if C.ButtonManager then
        C.ButtonManager:updateAllButtonStates()
    end

    -- Track if any toolbars are still open
    local any_open = false

    -- Render each toolbar
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
        if controller_data.controller and controller_data.controller.is_open then
            controller_data.renderer:render(controller_data.ctx, controller_data.font)
            any_open = true
        end
    end

    if C.LayoutManager then
        C.LayoutManager:endFrame()
    end

    if CONFIG_MANAGER then
        CONFIG_MANAGER:flushPendingSaves()
    end

    local mctx = _G.MAIN_IMGUI_CTX
    if mctx and CONFIG and CONFIG.UI and CONFIG.UI.ENABLE_GRID_RULER_CHIP == true then
        local main_font
        for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
            if cd.ctx == mctx and cd.font then
                main_font = cd.font
                break
            end
        end
        GridRulerChip.render(mctx, main_font)
    end

    if C.DragDropManager and C.DragDropManager:isDragging() then
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
            local ctx = controller_data.ctx
            if ctx and controller_data.controller and controller_data.controller.is_open then
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
                    C.DragDropManager:endDrag()
                    break
                end
            end
        end
    end

    if C.DragDropManager then
        C.DragDropManager:finishFrameDragDrop()
    end

    -- Continue loop if any toolbars are still open
    if any_open then
        reaper.defer(Loop)
    else
        if CONFIG_MANAGER then
            CONFIG_MANAGER:flushAllPendingSavesImmediate()
        end
        -- Clean up all controllers and contexts
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            if controller_data.controller then
                controller_data.controller:cleanup()
            end
        end

        if C.ButtonManager then
            C.ButtonManager:cleanup()
        end

        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            -- Clean up context if it's not the main context
            if controller_data.ctx and controller_data.ctx ~= main_ctx then
                -- Detach font first if it exists
                if controller_data.font then
                    pcall(
                        function()
                            reaper.ImGui_Detach(controller_data.ctx, controller_data.font)
                        end
                    )
                end
                detachIconFontsFromContext(controller_data.ctx)
                pcall(function()
                    reaper.ImGui_DestroyContext(controller_data.ctx)
                end)
            end
        end

        invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()

        -- Detach font resources from the main context if they exist
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            if controller_data.ctx == main_ctx and controller_data.font then
                pcall(
                    function()
                        reaper.ImGui_Detach(main_ctx, controller_data.font)
                    end
                )
                break -- Only need to do this once
            end
        end

        -- Set context to nil to allow garbage collection
        main_ctx = nil
        set_toolbar_toggle_state(0)
    end
end

local profiler_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua'
if reaper.file_exists(profiler_path) and USE_PROFILER then
  local profiler = dofile(profiler_path)
  reaper.defer = profiler.defer
  profiler.attachToWorld() -- after all functions have been defined
  profiler.run()
end

set_toolbar_toggle_state(1)
if reaper.atexit then
    reaper.atexit(function()
        set_toolbar_toggle_state(0)
    end)
end

reaper.defer(Loop)