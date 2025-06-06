-- Advanced Toolbars.lua

_G.USE_PROFILER = false

-- Get the script path
local info = debug.getinfo(1, "S")
_G.SCRIPT_PATH = info.source:match([[^@?(.*[\/])[^\/]-$]])
SCRIPT_PATH = SCRIPT_PATH:match("^%?(.*)$") or SCRIPT_PATH

-- Add the script's directory to the Lua package path
package.path = SCRIPT_PATH .. "?.lua;" .. package.path

-- Check for ReaImGui
if not reaper.APIExists("ImGui_CreateContext") then
    reaper.ShowMessageBox("Please install ReaImGui extension.", "Error", 0)
    return
end

_G.UTILS = require("Utils.utils")
_G.DRAWING = require("Utils.drawing")
_G.COLOR_UTILS = require("Utils.color_utils")
_G.POPUP_OPEN = false

_G.CONFIG = nil

_G.CONFIG_MANAGER = require("Systems.Config_Manager").new()

_G.ICON_FONTS = {}
local icon_fonts_dir = UTILS.joinPath(SCRIPT_PATH, "IconFonts")
local files = UTILS.getFilesInDirectory(icon_fonts_dir)

for _, file in ipairs(files) do
    local count = tonumber(file:match("_(%d+)%.ttf$")) or 10
    local start_code = 0x00C0 -- from À character
    local end_code = math.min(start_code + count - 1, 0x10FFFF)
    local font_path = UTILS.normalizeSlashes("IconFonts/" .. file)
    table.insert(
        ICON_FONTS,
        {
            path = font_path,
            display_name = UTILS.formatFontName(file:gsub("%.ttf$", "")),
            icon_range = {{start = start_code, laFin = end_code}}
        }
    )
end

local ModulesFactory = require("Systems.Modules_Factory")
ModulesFactory.createGlobalModules()

-- Set up main ImGui context for the first toolbar
local main_ctx = reaper.ImGui_CreateContext("Dynamic Toolbar")

_G.TOOLBAR_CONTROLLERS = {}

local function createAndAttachFont(ctx)
    if not ctx then
        return nil
    end

    local font_size = CONFIG.SIZES.TEXT or 14
    local system_fonts = {"Futura", "Arial", "Helvetica", "Segoe UI", "Verdana"}
    local font = nil

    for _, font_name in ipairs(system_fonts) do
        font = reaper.ImGui_CreateFont(font_name, font_size)
        if font then
            local success =
                pcall(
                function()
                    reaper.ImGui_Attach(ctx, font)
                end
            )
            if success then
                break
            else
                font = nil
            end
        end
    end

    return font
end

function CreateToolbar(toolbar_id, use_main_context)
    -- Generate a unique ID if not provided
    toolbar_id = toolbar_id or math.random(100000, 999999)
    
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
    
    -- Load icon font maps
    for i = 1, #ICON_FONTS do
        local full_path = SCRIPT_PATH .. ICON_FONTS[i].path
        local font_size = math.floor(CONFIG.ICON_FONT.SIZE * CONFIG.ICON_FONT.SCALE)
        local icon_font = ICON_FONTS[i].font or reaper.ImGui_CreateFont(full_path, font_size)
        if icon_font then
            reaper.ImGui_Attach(ctx, icon_font)
            ICON_FONTS[i].font = icon_font
        end
    end
    
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
    -- Get the number of existing toolbar controllers
    local toolbar_count = 0
    for _ in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
        toolbar_count = toolbar_count + 1
    end
    
    -- Create a new toolbar with a unique ID
    local new_id = math.random(100000, 999999)
    
    -- Make sure the ID doesn't already exist in CONFIG.TOOLBAR_CONTROLLERS
    while CONFIG.TOOLBAR_CONTROLLERS[tostring(new_id)] do
        new_id = math.random(100000, 999999)
    end
    
    -- Create the toolbar with the unique ID
    local controller, renderer = CreateToolbar(new_id, false)
    
    -- Set the order property to place it at the end
    CONFIG.TOOLBAR_CONTROLLERS[tostring(new_id)].order = toolbar_count + 1
    
    -- Save the configuration
    CONFIG_MANAGER:saveMainConfig()
    
    return controller, renderer
end

if CONFIG and CONFIG.TOOLBAR_CONTROLLERS and next(CONFIG.TOOLBAR_CONTROLLERS) then
    -- Create a sorted list of toolbar controllers by their order
    local ordered_toolbars = {}
    for toolbar_id_str, controller_data in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
        table.insert(ordered_toolbars, {
            id = tonumber(toolbar_id_str),
            order = controller_data.order or 0  -- Default to 0 if no order
        })
    end
    
    -- Sort by order
    table.sort(ordered_toolbars, function(a, b) return a.order < b.order end)
    
    -- Load toolbars in order
    local first = true
    for _, toolbar_info in ipairs(ordered_toolbars) do
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

function Loop()
    -- Check for menu.ini file changes once per frame using consolidated IniManager
    local file_changed = false
    if _G.TOOLBAR_CONTROLLERS and #_G.TOOLBAR_CONTROLLERS > 0 then
        file_changed = C.IniManager:hasFileChanged()
    end

    if file_changed then
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            controller_data.controller.loader:loadToolbars()
        end
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

    -- Continue loop if any toolbars are still open
    if any_open then
        reaper.defer(Loop)
    else
        -- Clean up all controllers and contexts
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            if controller_data.controller then
                controller_data.controller:cleanup()
            end

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
                reaper.ImGui_DestroyContext(controller_data.ctx)
            end
        end

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
    end
end

local profiler_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua'
if reaper.file_exists(profiler_path) and USE_PROFILER then
  local profiler = dofile(profiler_path)
  reaper.defer = profiler.defer
  profiler.attachToWorld() -- after all functions have been defined
  profiler.run()
end

reaper.defer(Loop)
