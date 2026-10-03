-- Run from the repository root with Lua 5.4.
package.path = './?.lua;' .. package.path
local tables = require('Utils.Core.table_utils')
UTILS = require('Utils.Core.string_utils')
UTILS.serializeTable = tables.serializeTable
local notices, registered, deferred = {}, {}, {}
local native_reads, allow_native_read, native_content = 0, false, nil
reaper = {
    GetOS = function() return 'OSX64' end,
    time_precise = function() return 10 end,
    ShowConsoleMsg = function(message) notices[#notices + 1] = message end,
    ShowMessageBox = function(message) notices[#notices + 1] = message end,
    defer = function(fn) deferred[#deferred + 1] = fn end,
    GetResourcePath = function()
        assert(allow_native_read, 'normal toolbar operations must not access REAPER toolbar definitions')
        return '/native-toolbar-fixture'
    end,
}
ID_GENERATOR = require('Utils.Core.id_generator')
CONFIG = { SIZES = { MIN_WIDTH = 30, HEIGHT = 28, SPACING = 1 }, TOOLBAR_CONTROLLERS = {} }
C = {
    ButtonDefinition = require('Systems.Button_Definition'),
    ParseGrouping = require('Parsing.Parse_Grouping'),
    ButtonManager = {
        getCommandID = function(_, id) return tonumber(id) end,
        isToggleCommand = function() return false end,
        registerButton = function(_, b) registered[b.instance_id] = b end,
        unregisterButton = function(_, b) registered[b.instance_id] = nil end,
        markAllButtonStatesDirty = function() end,
    },
}
local prefix = os.tmpname()
os.remove(prefix)
local paths, sections = {}, {}
local shared = {
    SAVE_DEBOUNCE_SEC = 0.4, toolbar_config_cache = {},
    getToolbarConfigPath = function(section)
        local path = prefix .. '_' .. UTILS.getSafeFilename(section) .. '.lua'
        paths[path] = true
        return path
    end,
}
local Manager = {}
require('Managers.Config.Migration')(Manager)
require('Managers.Config.StructureItems')(Manager)
require('Managers.Config.ToolbarStore')(Manager)
require('Managers.Config.ButtonProperties')(Manager)
require('Managers.Config.ToolbarRegistry')(Manager, shared)
require('Managers.Config.Persistence')(Manager, shared)
function Manager:getToolbarConfigSections()
    local out = {}
    for section in pairs(sections) do
        local cfg = self:loadToolbarConfig(section)
        out[#out + 1] = { section = section, order = cfg.ORDER or 0 }
    end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end
function Manager:backupUserConfigFileBeforeWrite() return true end
local write = Manager.writeToolbarConfig
function Manager:writeToolbarConfig(section, cfg)
    local ok = write(self, section, cfg)
    if ok then sections[section] = true end
    return ok
end
CONFIG_MANAGER = setmetatable({ _pending_toolbar_saves = {} }, { __index = Manager })
C.ParseToolbars = require('Parsing.Parse_Toolbars').new()
C.SharedToolbars = require('Parsing.Shared_Toolbars').new()
C.ToolbarEditor = require('Managers.ToolbarEditor').new()
TOOLBAR_CONTROLLERS = {}

-- A fresh store starts blank, independent of REAPER; startup is idempotent.
local first = assert(C.SharedToolbars:ensureLoaded())
assert(#first == 1 and #first[1].buttons == 0 and first[1].name == 'New Toolbar')
local first_section = first[1].section
assert(first_section:match('^toolbar_'))
assert(CONFIG_MANAGER:ensureToolbarStructureStoreInitialized())
assert(#CONFIG_MANAGER:getToolbarConfigSections() == 1)
C.SharedToolbars:invalidate()
assert(C.SharedToolbars:ensureLoaded()[1].section == first_section)

-- Edits save to our files and survive cache invalidation/restart.
assert(C.ToolbarEditor:insertFirstButtonInSection(first_section,
    C.ButtonDefinition.createButton('40001', 'Line one\nLine two', '0')))
CONFIG_MANAGER:invalidateToolbarConfigCache()
local loaded = assert(C.SharedToolbars:parseFresh())[1]
assert(#loaded.buttons == 1 and loaded.buttons[1].original_text == 'Line one\nLine two',
    'loading document data directly must preserve multiline labels')
loaded:updateName('My own toolbar')
loaded.buttons[1].display_text = 'Custom label'
loaded.buttons[1].custom_color = '#112233FF'
assert(CONFIG_MANAGER:saveToolbarConfig(loaded))
CONFIG_MANAGER:invalidateToolbarConfigCache()
loaded = assert(C.SharedToolbars:parseFresh())[1]
assert(loaded.name == 'My own toolbar' and loaded.buttons[1].display_text == 'Custom label')
assert(loaded.buttons[1].custom_color == '#112233FF')

local real_open = io.open
io.open = function(path, mode)
    if path == '/native-toolbar-fixture/reaper-menu.ini' then
        assert(allow_native_read and mode == 'r', 'native toolbars are read-only and import-only')
        native_reads = native_reads + 1
        if not native_content then return nil end
        return { read = function() return native_content end, close = function() end }
    end
    return real_open(path, mode)
end
local Import = require('Managers.ToolbarImport')
native_content = [[
[Main toolbar]
item_3=40002 Last
item_1=40001 Duplicate
item_2=-1
item_0=40001 Duplicate
icon_1=toolbar_second.png
icon_0=toolbar_first.png
title=Native tools
[Track control panel context]
item_0=40003 Context
[Floating Toolbar 2]
item_0=_CUSTOM Named action
[MIDI piano roll toolbar]
item_0=40100 MIDI
[Floating MIDI toolbar 1]
item_0=40200 Floating MIDI
[Media Explorer toolbar]
item_0=40300 Media
]]
allow_native_read = true
local templates = Import.read()
allow_native_read = false
assert(#templates == 5, 'context menus must not appear as toolbar templates')
local imported_section = assert(Import.create(templates[1]))
local second_import = assert(Import.create(templates[1]))
assert(imported_section ~= second_import and imported_section ~= 'Main toolbar')
assert(CONFIG_MANAGER:loadToolbarConfig(second_import).CUSTOM_NAME == 'Native tools (2)')
assert(templates[1].items[1].instance_id == nil, 'imports must not mutate source templates')
local imported = CONFIG_MANAGER:loadToolbarConfig(imported_section)
assert(imported.STRUCTURE.items[3].id == '-1' and imported.STRUCTURE.items[4].id == '40002')
local properties = imported.BUTTON_CUSTOM_PROPERTIES
assert(properties['40001_Duplicate_pos0'].reaper_icon_path == 'toolbar_first.png')
assert(properties['40001_Duplicate_pos1'].reaper_icon_path == 'toolbar_second.png')
local original_identity = imported.STRUCTURE.items[1].instance_id
assert(original_identity ~= CONFIG_MANAGER:loadToolbarConfig(second_import).STRUCTURE.items[1].instance_id)
native_content = nil
CONFIG_MANAGER:invalidateToolbarConfigCache()
local all = assert(C.SharedToolbars:parseFresh())
assert(#all == 3 and #all[2].buttons == 4 and all[2].buttons[1].instance_id == original_identity,
    'imported toolbars must reload even after the native definitions disappear')
assert(all[2].buttons[1].reaper_icon_path == 'toolbar_first.png')
assert(#all[2].groups == 2)
assert(native_reads == 1)

-- Reorder duplicate actions: stable row IDs keep styles with their own buttons.
local cfg = CONFIG_MANAGER:loadToolbarConfig(imported_section)
cfg.STRUCTURE.items[1], cfg.STRUCTURE.items[2] = cfg.STRUCTURE.items[2], cfg.STRUCTURE.items[1]
CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
assert(CONFIG_MANAGER:writeToolbarConfig(imported_section, cfg))
all = assert(C.SharedToolbars:parseFresh())
assert(all[2].buttons[1].reaper_icon_path == 'toolbar_second.png')
assert(all[2].buttons[2].instance_id == original_identity)

-- The switcher lists local toolbars and explicit creation actions without INI I/O.
local Controller = require('Systems.Toolbar_Controller')
local controller = Controller.new('one')
controller.toolbars, controller.currentToolbarIndex = all, 1
controller.enable_toolbar_switch = false
controller.ctx = 'owner'
controller.loader = require('Parsing.Load_Toolbar').new(controller)
TOOLBAR_CONTROLLERS = {{ controller = controller }}
CONFIG.TOOLBAR_CONTROLLERS.one = { last_toolbar_index = 1, enable_toolbar_switch = false }
local switcher = dofile('Widgets/toolbars_list.lua')
switcher._atb_controller_id = 'one'
switcher:scanMenuItems()
assert(#switcher.dropdown_menu == 6)
assert(switcher.dropdown_menu[5].menu_role == 'new' and switcher.dropdown_menu[6].menu_role == 'import')
assert(native_reads == 1)
CONFIG_MANAGER.saveMainConfig = function() return true end
switcher:onSelect(switcher.dropdown_menu[5])
assert(#controller.toolbars == 4 and #controller:getCurrentToolbar().buttons == 0)
assert(CONFIG.TOOLBAR_CONTROLLERS.one.last_toolbar_index == 4)

-- Import UI reads only on opening/refresh, belongs to one window, and reports missing files.
C.GlobalStyle = { withGlobalStyle = function(_, fn) fn() end }
C.ToolbarImport = require('Windows.Toolbar_Import').new()
allow_native_read = true
switcher:scanMenuItems()
switcher:onSelect(switcher.dropdown_menu[#switcher.dropdown_menu])
allow_native_read = false
assert(C.ToolbarImport.is_open and C.ToolbarImport.error and native_reads == 2)
assert(not C.ToolbarImport:render('other'))
local messages, chosen = {}, false
reaper.ImGui_SetNextWindowSize = function() end
reaper.ImGui_Cond_FirstUseEver = function() return 0 end
reaper.ImGui_Begin = function() return true, true end
reaper.ImGui_End = function() end
reaper.ImGui_TextWrapped = function(_, message) messages[#messages + 1] = message end
reaper.ImGui_Button = function() return false end
reaper.ImGui_Separator = function() end
reaper.ImGui_IsItemHovered = function() return false end
reaper.ImGui_Selectable = function() return chosen end
assert(C.ToolbarImport:render('owner'))
assert(#messages == 2 and messages[2] == C.ToolbarImport.error and native_reads == 2)
native_content = '[Main toolbar]\nitem_0=40010 Updated\ntitle=Updated native toolbar'
allow_native_read = true
C.ToolbarImport:refresh()
allow_native_read = false
assert(C.ToolbarImport.templates[1].items[1].id == '40010' and native_reads == 3)
chosen = true
assert(not C.ToolbarImport:render('owner'))
assert(controller:getCurrentToolbar().buttons[1].id == '40010')
assert(#controller.toolbars == 5 and native_reads == 3)

-- Save failures do not create phantom toolbars or replace pending edited objects.
local current = controller:getCurrentToolbar()
CONFIG_MANAGER:requestSaveToolbarConfig(current)
local real_write = CONFIG_MANAGER.writeToolbarConfig
CONFIG_MANAGER.writeToolbarConfig = function() return false end
assert(not controller:createBlankToolbar())
assert(controller:getCurrentToolbar() == current and #CONFIG_MANAGER:getToolbarConfigSections() == 5)
CONFIG_MANAGER._pending_toolbar_saves = {}
assert(not controller:createBlankToolbar())
assert(#CONFIG_MANAGER:getToolbarConfigSections() == 5)
CONFIG_MANAGER.writeToolbarConfig = real_write

-- Incomplete old configs are not silently overwritten with empty/native contents.
assert(CONFIG_MANAGER:writeToolbarConfig('legacy', { SECTION = 'legacy', ORDER = 99, CUSTOM_NAME = 'Keep me' }))
assert(C.ParseToolbars:parseToolbarConfigs() == nil)
assert(CONFIG_MANAGER:loadToolbarConfig('legacy').STRUCTURE == nil)
assert(native_reads == 3)
io.open = real_open
for path in pairs(paths) do os.remove(path) end
print('Toolbar independence regressions passed')
