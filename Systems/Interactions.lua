-- Systems/Interactions.lua
--
-- Singleton contract (C.Interactions is one instance for all toolbar windows):
--   Shared across windows — insert menu, preset browser, dropdowns, and modals that
--   track owner_ctx; cross-toolbar drag/drop lives on C.DragDropManager (not here).
--   Per ImGui context (_per_ctx[ctx]) — hover timers, button-settings tracking,
--   edit-mode group-label hints, and deferred toolbar-settings open. Each toolbar
--   window has its own ctx; that state must not leak between windows.

local Interactions = {}
Interactions.__index = Interactions

local function perCtx(self, ctx)
    if not ctx then
        return nil
    end
    local state = self._per_ctx[ctx]
    if not state then
        state = {
            hover_start_times = {},
            edit_mode_group_label_hover_times = {},
            button_settings_button = nil,
            button_settings_group = nil,
            open_toolbar_settings_deferred = false,
        }
        self._per_ctx[ctx] = state
    end
    return state
end

function Interactions.new()
    local self = setmetatable({}, Interactions)

    self._per_ctx = {}

    self.dropdown_button = nil
    self.dropdown_position = nil

    self.insert_menu_button = nil
    self.insert_menu_owner_ctx = nil
    self.insert_menu_popup_open = false
    self.insert_menu_beginpopup_grace = 0
    self.insert_menu_position = "before"
    self.preset_browser_open = false
    self.preset_browser_target_button = nil
    self.preset_browser_state = {is_open = false, owner_ctx = nil}
    self.preset_browser_path = {}
    self.preset_browser_selected_path = nil
    self.preset_browser_root = nil
    self.preset_browser_chunk_cache = {}
    self.under_mouse_auto_arm_notice_pending = false

    return self
end

require("Systems.Interactions.hover")(Interactions, perCtx)
require("Systems.Interactions.menus")(Interactions, perCtx)
require("Systems.Interactions.insert")(Interactions)

function Interactions:cleanup()
    self._per_ctx = {}
    self.dropdown_button = nil
    self.dropdown_position = nil
    self.insert_menu_button = nil
    self.insert_menu_owner_ctx = nil
    self.insert_menu_popup_open = false
    self.insert_menu_beginpopup_grace = 0
    self.insert_menu_position = "before"
    if self.closePresetBrowser then
        self:closePresetBrowser()
    else
        self.preset_browser_open = false
        self.preset_browser_target_button = nil
        self.preset_browser_path = {}
        self.preset_browser_selected_path = nil
    end
    self.preset_browser_root = nil
    self.preset_browser_chunk_cache = {}
    self.under_mouse_auto_arm_notice_pending = false
end

function Interactions:ensurePresetBrowserLoaded()
    if self._preset_browser_loaded then
        return
    end
    self._preset_browser_loaded = true
    local Interactions_Preset_Browser = require("Systems.Interactions.Preset_Browser")
    for k, v in pairs(Interactions_Preset_Browser) do
        Interactions[k] = v
    end
end

return Interactions
