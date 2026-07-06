-- Advanced Toolbars.lua

_G.USE_PROFILER = false

local info = debug.getinfo(1, "S")
_G.SCRIPT_PATH = info.source:match([[^@?(.*[\/])[^\/]-$]])
SCRIPT_PATH = SCRIPT_PATH:match("^%?(.*)$") or SCRIPT_PATH

package.path = SCRIPT_PATH .. "?.lua;" .. package.path

local _, _, ACTION_SECTION, ACTION_CMD = reaper.get_action_context()
local function set_toolbar_toggle_state(state)
    if ACTION_CMD == nil or ACTION_CMD < 0 then
        return
    end
    reaper.SetToggleCommandState(ACTION_SECTION, ACTION_CMD, state)
    reaper.RefreshToolbar2(ACTION_SECTION, ACTION_CMD)
end

if not reaper.APIExists("ImGui_CreateContext") then
    reaper.ShowMessageBox("Please install ReaImGui extension.", "Error", 0)
    set_toolbar_toggle_state(0)
    return
end

require("Bootstrap.imgui_hooks").install()

_G.UTILS = require("Utils.Core.utils")
_G.REAPER_UI_ANCHOR = require("Utils.Reaper.reaper_ui_anchor")
_G.DRAWING = require("Utils.Draw.drawing")
_G.COLOR_UTILS = require("Utils.color_utils")
_G.COORDINATES = require("Utils.Core.coordinates")
_G.ID_GENERATOR = require("Utils.Core.id_generator")
_G.CACHE_UTILS = require("Utils.Core.cache_utils")
_G.BUTTON_UTILS = require("Utils.button_utils")
_G.CHIP_MULTISWITCH = require("Utils.Chips.chip_multiswitch")
_G.LUA_SCRIPT_EXTRACT = require("Utils.Core.lua_script_extract")
_G.WIDGET_ELEMENTS = require("Utils.Widget.widget_elements")
_G.POPUP_OPEN = false

_G.CONFIG = nil
_G.CONFIG_MANAGER = require("Managers.Config").new()

require("Bootstrap.fonts").scanAndInstallGlobals()
require("Bootstrap.fonts").installGlobalHelpers()

local ModulesFactory = require("Systems.Modules_Factory")
ModulesFactory.createGlobalModules()

local startup_toolbars = ModulesFactory.loadSharedToolbarsAtStartup()
if not startup_toolbars or #startup_toolbars == 0 then
    reaper.ShowMessageBox("No toolbars found in toolbar configs", "Error", 0)
    set_toolbar_toggle_state(0)
    return
end

local GridRulerChip = require("Windows.Grid_Ruler_Chip")
local ControllerHost = require("Bootstrap.controller_host")

local main_ctx = reaper.ImGui_CreateContext("Dynamic Toolbar")
ControllerHost.setMainContext(main_ctx)

_G.TOOLBAR_CONTROLLERS = {}
_G.getActiveToolbarIndices = ControllerHost.getActiveToolbarIndices
_G.anyToolbarInEditMode = ControllerHost.anyToolbarInEditMode
_G.CreateNewToolbar = ControllerHost.createNewToolbar
_G.CreateTempWidgetGalleryToolbar = ControllerHost.createTempWidgetGalleryToolbar

ControllerHost.loadConfiguredToolbars()

function Loop()
    ControllerHost.purgeClosedEphemeralControllers()
    ControllerHost.processPendingToolbarImGuiRestarts()

    _G.FRAME_TIME = reaper.time_precise()

    if C.DragDropManager then
        C.DragDropManager:beginFrameDropTarget()
    end

    if C.ButtonManager then
        C.ButtonManager:updateAllButtonStates()
    end

    local any_open = false

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

    if any_open then
        reaper.defer(Loop)
    else
        if CONFIG_MANAGER then
            CONFIG_MANAGER:flushAllPendingSavesImmediate()
        end
        ControllerHost.cleanupOnShutdown()
        set_toolbar_toggle_state(0)
    end
end

local profiler_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua'
if reaper.file_exists(profiler_path) and USE_PROFILER then
  local profiler = dofile(profiler_path)
  reaper.defer = profiler.defer
  profiler.attachToWorld()
  profiler.run()
end

set_toolbar_toggle_state(1)
if reaper.atexit then
    reaper.atexit(function()
        set_toolbar_toggle_state(0)
    end)
end

reaper.defer(Loop)
