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
        SEPARATOR_SIZE = 12,
        PADDING = 12,
        SPACING = 2,
        TEXT = 12,
        -- Action-name fallback labels: two lines only when longer than this (display only); split at the space that best balances line lengths.
        ACTION_NAME_FALLBACK_MAX_LINE_CHARS = 14,
        -- Space for edit-mode insertion triangles (horizontal: above row, vertical: left gutter)
        EDIT_MODE_EDGE_PADDING = 20
    },
    TOOLBAR_CONTROLLERS = {}, 
    UI = {
        FLASH_INTERVAL = 0.5,
        HIDE_ALL_LABELS = false,
        HOVER_DELAY = 0.3,
        USE_GROUPING = true,
        USE_GROUP_LABELS = true,
        -- Prepends the Toolbars List widget on every Advanced Toolbar window (same row / column as the menu toolbar)
        ENABLE_TOOLBAR_SWITCH_WIDGET = true
    },
    
    -- Global color settings for UI preferences
    COLOR_SETTINGS = {
        APPLY_TO_GROUP = true,
        LINK_BG_BORDER = true,
        LINK_TEXT_ICON = true
    },

    -- Default colour palettes for the Colour Swatch widget (stock categories). User edits live in CONFIG.WIDGET_SAVED_STATES.
    COLOUR_SWATCH_DEFAULTS = {
        track = {
            {
                id = "stock_tracks_primary",
                name = "Tracks — primary",
                colors = {
                    "#E6194BFF", "#3CB44BFF", "#FFE119FF", "#4363D8FF", "#F58231FF",
                    "#911EB4FF", "#46F0F0FF", "#F032E6FF", "#BCF60CFF", "#FABEBEFF",
                    "#008080FF", "#E6BEFFFF", "#9A6324FF", "#FFFAC8FF", "#800000FF",
                    "#AAFFC3FF", "#808000FF", "#FFD8B1FF", "#000075FF", "#808080FF"
                }
            },
            {
                id = "stock_tracks_pastel",
                name = "Tracks — pastel",
                colors = {
                    "#FFB3BAFF", "#FFDFBAFF", "#FFFFBAFF", "#BAFFC9FF", "#BAE1FFFF",
                    "#E8BAFFFF", "#D4A574FF", "#C7CEEAFF", "#B5EAD7FF", "#FFDAC1FF"
                }
            }
        },
        item = {
            {
                id = "stock_items_primary",
                name = "Items — primary",
                colors = {
                    "#E6194BFF", "#3CB44BFF", "#FFE119FF", "#4363D8FF", "#F58231FF",
                    "#911EB4FF", "#46F0F0FF", "#F032E6FF", "#BCF60CFF", "#FABEBEFF",
                    "#008080FF", "#E6BEFFFF", "#9A6324FF", "#FFFAC8FF", "#800000FF"
                }
            },
            {
                id = "stock_items_muted",
                name = "Items — muted",
                colors = {
                    "#5C4B51FF", "#8CBEB2FF", "#F2EBBFFF", "#F3B562FF", "#F06060FF",
                    "#4A6FA5FF", "#6B4226FF", "#789262FF", "#C06C84FF", "#6C5B7BFF"
                }
            }
        }
    },

    -- Per-widget persistent state (keyed by widget kind, then button instance_id)
    WIDGET_SAVED_STATES = {
        colour_swatch = {}
    }
}

return config