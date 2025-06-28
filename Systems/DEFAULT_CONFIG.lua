-- DEFAULT_CONFIG.lua
local config = {
    COLORS = {
        ARMED = {
            BG = {
                CLICKED = "#2F2F2FFF",
                HOVER = "#FF0000FF",
                NORMAL = "#FF0000FF"
            },
            BORDER = {
                CLICKED = "#666666FF",
                HOVER = "#666666FF",
                NORMAL = "#666666FF"
            },
            ICON = {
                CLICKED = "#BBBBBBFF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#E3E3E3FF"
            },
            TEXT = {
                CLICKED = "#BBBBBBFF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#E3E3E3FF"
            }
        },
        ARMED_FLASH = {
            BG = {
                CLICKED = "#2F2F2FFF",
                HOVER = "#FF0000FF",
                NORMAL = "#cc0000FF"
            },
            BORDER = {
                CLICKED = "#AA3D00FF",
                HOVER = "#FFA156FF",
                NORMAL = "#FFBDBDFF"
            },
            ICON = {
                CLICKED = "#BA1212FF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#E3E3E3FF"
            },
            TEXT = {
                CLICKED = "#BBBBBBFF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#FFFFFFFF"
            }
        },
        GROUP = {
            DECORATION = "#666666FF",
            LABEL = "#666666FF"
        },
        NORMAL = {
            BG = {
                CLICKED = "#2F2F2FFF",
                HOVER = "#454545FF",
                NORMAL = "#313131FF"
            },
            BORDER = {
                CLICKED = "#666666FF",
                HOVER = "#666666FF",
                NORMAL = "#666666FF"
            },
            ICON = {
                CLICKED = "#BBBBBBFF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#E3E3E3FF"
            },
            TEXT = {
                CLICKED = "#BBBBBBFF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#E3E3E3FF"
            }
        },
        SEPARATOR = {
            BG = {
                CLICKED = "#2A2A2AFF",
                HOVER = "#333333FF",
                NORMAL = "#00000000"  -- Transparent by default
            },
            BORDER = {
                CLICKED = "#666666FF",
                HOVER = "#666666FF",
                NORMAL = "#00000000"  -- Transparent by default
            },
            ICON = {
                CLICKED = "#BBBBBBFF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#666666FF"
            },
            TEXT = {
                CLICKED = "#BBBBBBFF",
                HOVER = "#E3E3E3FF",
                NORMAL = "#666666FF"
            },
            LINE = {
                CLICKED = "#888888FF",
                HOVER = "#AAAAAAFF",
                NORMAL = "#666666FF"
            }
        },
        SHADOW = "#1C1C1C77",
        TOGGLED = {
            BG = {
                CLICKED = "#CFAE29FF",
                HOVER = "#FFE545FF",
                NORMAL = "#CCB600FF"
            },
            BORDER = {
                CLICKED = "#000000FF",
                HOVER = "#666666FF",
                NORMAL = "#FFEBB1FF"
            },
            ICON = {
                CLICKED = "#131313FF",
                HOVER = "#030303FF",
                NORMAL = "#2B2B2BFF"
            },
            TEXT = {
                CLICKED = "#131313FF",
                HOVER = "#030303FF",
                NORMAL = "#2B2B2BFF"
            }
        },
        WINDOW_BG = "#333333FF"
    },
    ICON_FONT = {
        PADDING = 6,
        SIZE = 14,
        WIDTH = 20,
        HEIGHT = 28,
        SCALE = 0.69
    },
    SIZES = {
        DEPTH = 3,
        HEIGHT = 38,
        MIN_WIDTH = 30,
        ROUNDING = 8,
        SEPARATOR_WIDTH = 12,
        SPACING = 2,
        TEXT = 15
    },
    TOOLBAR_CONTROLLERS = {}, 
    UI = {
        FLASH_INTERVAL = 0.5,
        HIDE_ALL_LABELS = false,
        HOVER_DELAY = 0.3,
        USE_GROUPING = true,
        USE_GROUP_LABELS = true
    }
}

return config