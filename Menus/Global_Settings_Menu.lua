-- Menus/Global_Settings_Menu.lua
-- Global settings menu: implementation split across Menus/Global_Settings/*.lua.

local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")
local COLOR = require("Utils.Core.color.convert")

local GlobalSettingsMenu = {}
GlobalSettingsMenu.__index = GlobalSettingsMenu

local POPUP_TOOLBAR_LIST = "##atb_menu_toolbar_list"
local POPUP_UI_ANCHOR = "##atb_menu_ui_anchor"
local POPUP_UI_ALIGN = "##atb_menu_ui_align"

local UI_ANCHOR_OPTIONS = {
    { id = "tcp_corner", label = "TCP Menu Area (left of ruler)" },
    { id = "arrange", label = "Arrange (below ruler)" },
    { id = "transport", label = "Transport bar" },
}

local UI_ALIGN_OPTIONS = {
    { id = "left", label = "Left" },
    { id = "center", label = "Center" },
    { id = "right", label = "Right" },
}

local function pushAccentButtonStyle(ctx, variant)
    return C.GlobalStyle.pushAccentButtonStyle(ctx, variant == "red")
end

-- Derive menu surfaces from the live theme, including light themes.
local function mixMenuColor(a, b, amount)
    local ar, ag, ab = COLOR.extractChannels(a)
    local br, bg, bb = COLOR.extractChannels(b)
    return COLOR._packChannels(
        math.floor(ar + (br - ar) * amount + 0.5),
        math.floor(ag + (bg - ag) * amount + 0.5),
        math.floor(ab + (bb - ab) * amount + 0.5), 255)
end

function GlobalSettingsMenu.new()
    local self = setmetatable({}, GlobalSettingsMenu)
    -- [toolbar_id] = { x = string, y = string } for pin offset text fields
    self._pin_offset_text = {}
    -- [popup_id] = { x, y } screen position when opening menu-style popups at the cursor
    self._menu_popup_anchors = {}
    -- Defer OpenPopup until menuPopupPrepareFrame (required after ImGui tables; ReaImGui timing).
    self._menu_popup_pending = {}
    self._menu_popup_grace = {}
    return self
end

FRAGMENT_LOADER.loadFragments("GlobalSettingsMenu", GlobalSettingsMenu, {
    "Menus.Global_Settings.main",
    "Menus.Global_Settings.toolbar_selector",
    "Menus.Global_Settings.pin_settings",
    "Menus.Global_Settings.visual_settings",
    "Menus.Global_Settings.colors_tab",
    "Menus.Global_Settings.special_widgets",
}, {
    POPUP_TOOLBAR_LIST = POPUP_TOOLBAR_LIST,
    POPUP_UI_ANCHOR = POPUP_UI_ANCHOR,
    POPUP_UI_ALIGN = POPUP_UI_ALIGN,
    UI_ANCHOR_OPTIONS = UI_ANCHOR_OPTIONS,
    UI_ALIGN_OPTIONS = UI_ALIGN_OPTIONS,
    pushAccentButtonStyle = pushAccentButtonStyle,
    mixMenuColor = mixMenuColor,
})

return GlobalSettingsMenu
