local config = {
    BUTTON_BORDER = "#494949FFF",
    BUTTON_ARMED2_TOGGLED_HOVER = "#990000FF",
    FONT_ICON_PREVIEW_SIZE = 32,
    FONT_ICONS_PATH = "FontIcons.ttf",
    BUTTON_ARMED_TOGGLED_HOVER = "#990000FF",
    BUTTON_GROUPING = true,
    BUTTON_TOGGLED_HOVER = "#FFFF557F",
    BUTTON_GROUP_SEPARATOR = "#1a1a1a00",
    BUTTON_ACTIVE = "#2F2F2FFF",
    BUTTON_3D_DEPTH = 4,
    ICON_WIDTH = 20,
    BUTTON_SPACING = 1,
    BUTTON_HOVER = "#333333FF",
    COMBO_HEIGHT = 30,
    BUTTON_SEPARATOR_WIDTH = 2,
    BUTTON_ARMED_TOGGLED_COLOR = "#FF0000FF",
    ICON_SCALE = 0.72,
    BUTTON_COLOR = "#222222FF",
    BUTTON_ROUNDING = 9,
    TEXT_SIZE = 15,
    BUTTON_ARMED2_COLOR = "#cc0000FF",
    FONT_ICON_GRID_COLS = 16,
    BUTTON_TOGGLED_COLOR = "#CCCC00FF",
    BUTTON_ARMED2_HOVER = "#FF0000FF",
    BUTTON_ARMED_HOVER = "#FF0000FF",
    WINDOW_BG = "#333333FF",
    FONT_ICON_SIZE = 13,
    BUTTON_ARMED_COLOR = "#FF0000FF",
    HIDE_ALL_LABELS = false,
    BUTTON_HEIGHT = 40,
    ICON_HEIGHT = 28,
    BUTTON_ARMED2_TOGGLED_COLOR = "#cc0000FF",
    USE_GROUP_LABELS = false,
    SEPARATOR_WIDTH = 22,
    BUTTON_ICON_PADDING = 6,
    FLASH_INTERVAL = 0.5,
    BUTTON_SHADOW = "#22222277",
    BUTTON_TOGGLED_TEXT = "#000000FF",
    BUTTON_TEXT = "#BBBBBBFF",
    BUTTON_MIN_WIDTH = 75,

    -- Custom properties for toolbar buttons
    BUTTON_CUSTOM_PROPERTIES = {
        ["40745_Solo Dim"] = {
            name = "Solo\nDim",
            hide_label = false,
            icon_char = "O",
        },
        ["_RS1f5d1e5b0b0564c0702999ffd57d3be3e65c7c6f_Visual Mixer"] = {
            name = "Visual\nMixer",
            hide_label = false,
            icon_char = "F",
        },
        ["-1_SEPARATOR"] = {
            hide_label = false,
        },
        ["_S&M_CYCLACTION_11_Launch Item Modifiers"] = {
            name = "Item\nModifiers",
            hide_label = false,
            icon_char = "8",
        },
        ["_RSc371be9ea3a5067871a9b94aaf8d9e7219e5f944_Pan Items"] = {
            name = "Pan\nItems",
            hide_label = false,
            icon_char = "#",
        },
        ["41051_Toggle take reverse"] = {
            name = "Take\nReverse",
            hide_label = false,
            icon_path = "/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/test.png",
        },
        ["_RS4d34dda49b57f82c9c06df3d3f8decfc65a05f3e_Script: BuyOne_Create pitch-rate (vari-speed) take envelope and render to new take.lua"] = {
            name = "Pitch Rate\nEnvelope",
            hide_label = false,
            icon_char = ",",
        },
        ["42312_Display Item Ruler"] = {
            name = "Item\nRuler",
            hide_label = false,
            icon_char = "&",
            custom_color = {
                normal = "#562E2EFF",
                hover = "#673737FF",
                active = "#633434FF"
            },
        },
        ["-1_SEPARATOR"] = {
            hide_label = false,
        },
        ["_RS6f013d3ead1bd2f0f6f8ac72d4f173eaff53a985_Glue"] = {
            name = "Super\nGlue",
            hide_label = false,
            icon_char = "C",
        },
        ["_RSb5ad9aeb2f82e8c9c3f61ff4c4805598f8629a53_Edit Glue"] = {
            name = "Edit\nGlue",
            hide_label = false,
            icon_char = "K",
        },
        ["-1_SEPARATOR"] = {
            hide_label = false,
        },
        ["_S&M_CYCLACTION_12_Launch Track Versions"] = {
            name = "Track\nVersions",
            hide_label = false,
            icon_char = "6",
        },
        ["_S&M_CYCLACTION_10_Launch Tags"] = {
            name = "Track\nTags",
            hide_label = false,
            icon_char = "/",
        },
        ["_S&M_CYCLACTION_13_Launch Param History"] = {
            name = "Param\nHistory",
            hide_label = false,
            icon_char = "5",
        },
        ["-1_SEPARATOR"] = {
            hide_label = false,
        },
        ["_RS852f0872789b997921f7f9d40e6f997553bd5147_Update Utility"] = {
            name = "Update\nUtility",
            hide_label = false,
            icon_char = ":",
        },
        ["_RS3b8d8b2140a32d0bfaa6eda3bd21b06d0b7b215b_ReaNoir"] = {
            hide_label = false,
            icon_char = "Z",
        },
        ["_RS039a5b581f5d9e3ad860d0f7277316868024c917_Refresh Theme"] = {
            name = "Refresh\nTheme",
            hide_label = false,
            icon_char = "@",
        },
        },

    -- Group configurations

    TOOLBAR_GROUPS = {
        ["Floating Toolbar 1"] = {
            {
                label = { text = "" },
            },
            {
                label = { text = "Rawr" },
            },
            {
                label = { text = "" },
            },
            {
                label = { text = "" },
            },
            {
                label = { text = "" },
            },
        },
        ["Floating toolbar 15"] = {
            {
                label = { text = "" },
            },
        },
        ["Floating toolbar 16"] = {
            {
                label = { text = "" },
            },
        },
        ["Floating toolbar 2"] = {
            {
                label = { text = "" },
            },
        },
        ["Floating toolbar 3"] = {
            {
                label = { text = "" },
            },
        },
        ["Floating toolbar 4"] = {
            {
                label = { text = "" },
            },
            {
                label = { text = "" },
            },
        },
        ["Floating toolbar 5"] = {
            {
                label = { text = "" },
            },
        },
        ["Main toolbar"] = {
            {
                label = { text = "" },
            },
            {
                label = { text = "" },
            },
            {
                label = { text = "" },
            },
            {
                label = { text = "" },
            },
        },
        ["Media Explorer toolbar"] = {
            {
                label = { text = "" },
            },
        },
        ["MIDI piano roll toolbar"] = {
            {
                label = { text = "" },
            },
        },
    },
}

return config