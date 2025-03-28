-- Advanced Toolbars.lua

-- Get the script path
local info = debug.getinfo(1, "S")
_G.SCRIPT_PATH = info.source:match([[^@?(.*[\/])[^\/]-$]])
SCRIPT_PATH = SCRIPT_PATH:match("^%?(.*)$") or SCRIPT_PATH

-- Add the script's directory to the Lua package path
package.path = SCRIPT_PATH .. "?.lua;" .. package.path

-- Check for ReaImGui
if not reaper.APIExists("ImGui_GetVersion") then
    reaper.ShowMessageBox("Please install ReaImGui extension.", "Error", 0)
    return
end

-- Define CONFIG as a global variable
_G.CONFIG = nil

-- Create systems factory
local ModulesFactory = require("Systems.Modules_Factory")
local ToolbarController, ToolbarRenderer = ModulesFactory.createModules()

-- Use the toolbar loader module to load toolbars
local success = C.ToolbarLoader:loadToolbars(ToolbarController)
if not success then
    return
end

-- Set up ImGui context
local ctx = reaper.ImGui_CreateContext("Dynamic Toolbar")

-- Create and attach main system font with fallback to default
local font
local font_size = CONFIG.SIZES.TEXT or 14
local system_fonts = {"Futura", "Arial", "Helvetica", "Segoe UI", "Verdana"}

for _, font_name in ipairs(system_fonts) do
    font = reaper.ImGui_CreateFont(font_name, font_size)
    if
        font and
            pcall(
                function()
                    reaper.ImGui_Attach(ctx, font)
                end
            )
     then
        break
    end
    font = nil
    reaper.ShowConsoleMsg("Warning: Using default ImGui font.\n")
end

function Loop()
    -- Check for menu.ini file changes once per frame
    if C.ToolbarLoader:checkForFileChanges() then
        C.ToolbarLoader:loadToolbars()
    end
    
    ToolbarRenderer:render(ctx, font)

    if ToolbarController.is_open then
        reaper.defer(Loop)
    else
        ToolbarController:cleanup()
        reaper.ImGui_DestroyContext(ctx)
    end
end

reaper.defer(Loop)
