R = reaper

-- Get the script path
local info = debug.getinfo(1, "S")
SCRIPT_PATH = info.source:match([[^@?(.*[\/])[^\/]-$]])
SCRIPT_PATH = SCRIPT_PATH:match("^%?(.*)$") or SCRIPT_PATH

-- Add the script's directory to the Lua package path
package.path = SCRIPT_PATH .. "?.lua;" .. package.path



-- Check for ReaImGui
if not R.APIExists("ImGui_GetVersion") then
    R.ShowMessageBox("Please install ReaImGui extension.", "Error", 0)
    return
end

local ConfigManager = require("config_manager")
local Helpers = require("helper_functions")

-- Initialize config manager
local config_manager = ConfigManager.new(R, SCRIPT_PATH)

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
local CONFIG, err = loadfile(config_path)
if not CONFIG then
    R.ShowConsoleMsg("Error loading config: " .. tostring(err) .. "\n")
    R.ShowMessageBox("Error loading config: " .. tostring(err), "Error", 0)
    return
end

CONFIG = CONFIG()
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
local Parser = require("toolbar_parser")
local ButtonRenderer = require("button_renderer")
local WindowManager = require("window_manager")
local ButtonGroup = require("button_group")


-- Initialize parser and load menu.ini
local parser = Parser.new(R, ButtonSystem, ButtonGroup)
local menu_content, menu_path = parser:loadMenuIni()
if not menu_content then
    R.ShowMessageBox("Failed to load reaper-menu.ini", "Error", 0)
    return
end

-- Parse toolbars and create button manager
local toolbars, button_manager = parser:parseToolbars(menu_content)
if #toolbars == 0 then
    R.ShowMessageBox("No toolbars found in reaper-menu.ini", "Error", 0)
    return
end

local button_renderer = ButtonRenderer.new(R, button_manager, Helpers)

-- Initialize window manager with ButtonGroup
local window_manager = WindowManager.new(R, ButtonSystem, ButtonGroup, Helpers)
window_manager:initialize(toolbars, button_manager, button_renderer, menu_path, CONFIG)

-- Set up ImGui context
local ctx = R.ImGui_CreateContext("Dynamic Toolbar")

-- Create and attach main font (using system font)
local font = R.ImGui_CreateFont("Futura", CONFIG.SIZES.TEXT or 14)
R.ImGui_Attach(ctx, font)

-- Load icon font from file
local icon_font_path = SCRIPT_PATH .. CONFIG.ICON_FONT.PATH
local font_icon_size = math.floor(CONFIG.ICON_FONT.SIZE * CONFIG.ICON_FONT.SCALE)
local icon_font = R.ImGui_CreateFont(icon_font_path, font_icon_size)
if not icon_font then
    R.ShowMessageBox(
        "Failed to load icon font. Please ensure " .. CONFIG.ICON_FONT.PATH .. " exists in the script directory.",
        "Font Loading Error",
        0
    )
    return
end
R.ImGui_Attach(ctx, icon_font)

-- Main loop function
function Loop()
    window_manager:render(ctx, font, icon_font)

    if window_manager:isOpen() then
        R.defer(Loop)
    else
        -- Cleanup resources
        window_manager:cleanup()
        parser:cleanup()
        R.ImGui_DestroyContext(ctx)
    end
end

R.defer(Loop)