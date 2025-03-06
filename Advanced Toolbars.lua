R = reaper

-- Get the script path
local info = debug.getinfo(1, "S")
_G.SCRIPT_PATH = info.source:match([[^@?(.*[\/])[^\/]-$]])
SCRIPT_PATH = SCRIPT_PATH:match("^%?(.*)$") or SCRIPT_PATH

-- Add the script's directory to the Lua package path
package.path = SCRIPT_PATH .. "?.lua;" .. package.path

-- Check for ReaImGui
if not R.APIExists("ImGui_GetVersion") then
    R.ShowMessageBox("Please install ReaImGui extension.", "Error", 0)
    return
end

-- Define CONFIG as a global variable
_G.CONFIG = nil

local ConfigManager = require("config_manager")
local Helpers = require("helper_functions")

-- Helper function to check if a value exists in a table (needed for font_icon_selector)
if not table.contains then
    function table.contains(tbl, value)
        for _, v in ipairs(tbl) do
            if v == value then
                return true
            end
        end
        return false
    end
end

-- Initialize config manager
local config_manager = ConfigManager.new(R)

-- Load and validate user configuration
local config_path = SCRIPT_PATH .. "Advanced Toolbars - User Config.lua"
local f = io.open(config_path, "r")
if not f then
    R.ShowMessageBox("Config file not found", "Error", 0)
    -- Create default config if it doesn't exist
    local default_config = require("DEFAULT_CONFIG")
    local file = io.open(config_path, "w")

    if file then
        file:write("local config = " .. config_manager:serializeTable(default_config, "     ") .. "\n\nreturn config")
        file:close()
    else
        R.ShowMessageBox("Failed to create default config file", "Error", 0)
        return
    end
else
    f:close()
end

-- Load the config before imports
local config_loader, err = loadfile(config_path)
if not config_loader then
    R.ShowConsoleMsg("Error loading config: " .. tostring(err) .. "\n")
    R.ShowMessageBox("Error loading config: " .. tostring(err), "Error", 0)
    return
end

-- Set the global CONFIG variable
_G.CONFIG = config_loader()
if type(CONFIG) ~= "table" then
    R.ShowConsoleMsg("Config did not return a table, got: " .. type(CONFIG) .. "\n")
    R.ShowMessageBox(
        "Advanced Toolbars - User Config.lua did not return a valid configuration table. Investigate the file, and if it is present but not working try backing it up to another folder and deleting it.",
        "Config Error",
        0
    )
    return
end

local ButtonSystem = require("button_system")
local ButtonStateManager = require("button_state_manager")
local Parser = require("toolbar_parser")
local ButtonRenderer = require("button_renderer")
local WindowManager = require("window_manager")
local ButtonGroup = require("button_group")


local ButtonStateManager = ButtonStateManager.new(R)

-- Initialize parser with the state manager
local parser = Parser.new(R, ButtonSystem, ButtonGroup, ButtonStateManager)
local menu_content, menu_path = parser:loadMenuIni()
if not menu_content then
    R.ShowMessageBox("Failed to load reaper-menu.ini", "Error", 0)
    return
end

-- Parse toolbars and get state manager
local toolbars, state_manager = parser:parseToolbars(menu_content)
if #toolbars == 0 then
    R.ShowMessageBox("No toolbars found in reaper-menu.ini", "Error", 0)
    return
end

-- Create button renderer using the state manager
local button_renderer = ButtonRenderer.new(R, state_manager, Helpers)

-- Initialize window manager with the state manager
local window_manager = WindowManager.new(R, ButtonSystem, ButtonGroup, Helpers)
window_manager:initialize(toolbars, state_manager, button_renderer, menu_path, CONFIG)

-- Set up ImGui context
local ctx = R.ImGui_CreateContext("Dynamic Toolbar")
_G.TOOLBAR = ctx

-- Create and attach main system font with fallback to default
local font
local font_size = CONFIG.SIZES.TEXT or 14
local system_fonts = {"Futura", "Arial", "Helvetica", "Segoe UI", "Verdana"}

-- Try each system font in order until one works
for _, font_name in ipairs(system_fonts) do
    font = R.ImGui_CreateFont(font_name, font_size)
end

-- If all system fonts fail, use the built-in font
if not font then
    R.ShowConsoleMsg("Warning: Could not load any system fonts. Using default ImGui font.\n")
    font = nil  -- ImGui will use its default font
else
    -- Attach font to context if we loaded one
    local success, err = pcall(function()
        R.ImGui_Attach(ctx, font)
    end)
    
    if not success then
        R.ShowConsoleMsg("Error attaching font: " .. tostring(err) .. "\n")
        font = nil  -- Use default font if attachment fails
    end
end

function Loop()
    window_manager:render(ctx, font)

    if window_manager:isOpen() then
        R.defer(Loop)
    else
        window_manager:cleanup()
        parser:cleanup()
        R.ImGui_DestroyContext(ctx)
    end
end

R.defer(Loop)