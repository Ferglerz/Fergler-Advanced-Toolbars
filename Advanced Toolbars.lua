r = reaper

-- Get the script path
local info = debug.getinfo(1,'S')
local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]])
script_path = script_path:match("^%?(.*)$") or script_path

-- Add the script's directory to the Lua package path
package.path = script_path .. "?.lua;" .. package.path

-- Current imports
local ButtonSystem = require('button_system')
local Parser = require('toolbar_parser')
local ButtonRenderer = require('button_renderer')
local WindowManager = require('window_manager')
local Helpers = require('helper_functions')
local ButtonGroup = require('button_group')

-- Check for ReaImGui
if not r.APIExists('ImGui_GetVersion') then
    r.ShowMessageBox('Please install ReaImGui extension.', 'Error', 0)
    return
end

-- Load and validate user configuration
local config_path = script_path .. "Advanced Toolbars - User Config.lua"
local f = io.open(config_path, "r")
if f then f:close() end

-- Load the config
local CONFIG, err = loadfile(config_path)
if not CONFIG then
    r.ShowConsoleMsg("Error loading config: " .. tostring(err) .. "\n")
    r.ShowMessageBox("Error loading config: " .. tostring(err), "Error", 0)
    return
end

CONFIG = CONFIG()
if type(CONFIG) ~= "table" then
    r.ShowConsoleMsg("Config did not return a table, got: " .. type(CONFIG) .. "\n")
    r.ShowMessageBox("Advanced Toolbars - User Config.lua did not return a valid configuration table", "Config Error", 0)
    return
end

-- Initialize parser and load menu.ini
local parser = Parser.new(r, ButtonSystem, ButtonGroup)
local menu_content, menu_path = parser:loadMenuIni()
if not menu_content then
    r.ShowMessageBox("Failed to load reaper-menu.ini", "Error", 0)
    return
end

-- Parse toolbars and create button manager
local toolbars, button_manager = parser:parseToolbars(menu_content, CONFIG)
if #toolbars == 0 then
    r.ShowMessageBox("No toolbars found in reaper-menu.ini", "Error", 0)
    return
end

local button_renderer = ButtonRenderer.new(r, CONFIG, button_manager, Helpers)

-- Initialize window manager with ButtonGroup
local window_manager = WindowManager.new(r, CONFIG, script_path, ButtonSystem, ButtonGroup, Helpers)
window_manager:initialize(toolbars, button_manager, button_renderer, menu_path)

-- Set up ImGui context
local ctx = r.ImGui_CreateContext('Dynamic Toolbar')

-- Create and attach main font (using system font)
local font = r.ImGui_CreateFont('Futura', CONFIG.TEXT_SIZE or 14)
r.ImGui_Attach(ctx, font)

-- Load icon font from file
local icon_font_path = script_path .. CONFIG.FONT_ICONS_PATH
local font_icon_size = math.floor(CONFIG.FONT_ICON_SIZE * CONFIG.ICON_SCALE)
local icon_font = r.ImGui_CreateFont(icon_font_path, font_icon_size)
if not icon_font then
    r.ShowMessageBox("Failed to load icon font. Please ensure " .. CONFIG.FONT_ICONS_PATH .. " exists in the script directory.", "Font Loading Error", 0)
    return
end
r.ImGui_Attach(ctx, icon_font)

-- Main loop function
function loop()
    window_manager:render(ctx, font, icon_font)
    
    if window_manager:isOpen() then
        r.defer(loop)
    else
        -- Cleanup resources
        window_manager:cleanup()
        parser:cleanup()
        r.ImGui_DestroyContext(ctx)
    end
end

r.defer(loop)