-- Menus/Global_Settings_Menu.lua
-- Global settings menu: implementation split across Menus/Global_Settings/*.lua.

local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")

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

-- Hex #RRGGBBAA — converted via COLOR_UTILS.toImGuiColor (same as toolbar buttons)
local ACCENT_BUTTON_HEX = {
    blue = {
        normal = "#5078C8FF",
        hovered = "#6A92E0FF",
        active = "#4068B8FF",
        text = "#FFFFFFFF",
    },
    red = {
        normal = "#C85858FF",
        hovered = "#D86868FF",
        active = "#B84848FF",
        text = "#FFFFFFFF",
    },
}

local function pushAccentButtonStyle(ctx, variant)
    local c = ACCENT_BUTTON_HEX[variant]
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR_UTILS.toImGuiColor(c.normal))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLOR_UTILS.toImGuiColor(c.hovered))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COLOR_UTILS.toImGuiColor(c.active))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLOR_UTILS.toImGuiColor(c.text))
    return 4
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
})

return GlobalSettingsMenu
