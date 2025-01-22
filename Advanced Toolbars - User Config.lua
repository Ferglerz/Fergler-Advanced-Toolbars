local config = {
    BUTTON_CUSTOM_PROPERTIES = {
        ["40745_Solo Dim"] = {
            icon_char = "O",
            name = "Solo\nDim"
        },
        ["41051_Toggle take reverse"] = {
            custom_color = {
                clicked = "#422F42FF",
                hover = "#422F42FF",
                normal = "#422F42FF"
            },
            icon_path = "/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/test.png",
            name = "Take\nReverse"
        },
        ["42312_Display Item Ruler"] = {
            custom_color = {
                clicked = "#422F42FF",
                hover = "#422F42FF",
                normal = "#422F42FF"
            },
            icon_char = "&",
            name = "Item\nRuler"
        },
        ["_FNG_DECREASERATE_SWS: Decrease item rate by ~6% (one semitone) preserving length, clear 'preserve pitch'"] = {
            name = "-100"
        },
        ["_FNG_INCREASERATE_SWS: Increase item rate by ~6% (one semitone) preserving length, clear 'preserve pitch'"] = {
            name = "+100"
        },
        ["_FNG_NUDGERATEDOWN_SWS: Decrease item rate by ~0.6% (10 cents) preserving length, clear 'preserve pitch'"] = {
            name = "-10"
        },
        ["_FNG_NUDGERATEUP_SWS: Increase item rate by ~0.6% (10 cents) preserving length, clear 'preserve pitch'"] = {
            name = "+10"
        },
        ["_RS039a5b581f5d9e3ad860d0f7277316868024c917_Refresh Theme"] = {
            icon_char = "@",
            name = "Refresh\nTheme"
        },
        ["_RS1f5d1e5b0b0564c0702999ffd57d3be3e65c7c6f_Visual Mixer"] = {
            icon_char = "F",
            name = "Visual\nMixer"
        },
        _RS3b8d8b2140a32d0bfaa6eda3bd21b06d0b7b215b_ReaNoir = {
            hide_label = true,
            icon_char = "Z"
        },
        ["_RS4d34dda49b57f82c9c06df3d3f8decfc65a05f3e_Script: BuyOne_Create pitch-rate (vari-speed) take envelope and render to new take.lua"] = {
            custom_color = {
                clicked = "#865F5FFF",
                hover = "#865F5FFF",
                normal = "#865F5FFF"
            },
            icon_char = "f",
            name = "Pitch Rate\nEnvelope"
        },
        _RS6f013d3ead1bd2f0f6f8ac72d4f173eaff53a985_Glue = {
            icon_char = "C",
            name = "Super\nGlue"
        },
        ["_RS852f0872789b997921f7f9d40e6f997553bd5147_Update Utility"] = {
            icon_char = ":",
            name = "Update\nUtility"
        },
        ["_RSb5ad9aeb2f82e8c9c3f61ff4c4805598f8629a53_Edit Glue"] = {
            icon_char = "K",
            name = "Edit\nGlue"
        },
        ["_RSc371be9ea3a5067871a9b94aaf8d9e7219e5f944_Pan Items"] = {
            custom_color = {
                clicked = "#422F42FF",
                hover = "#422F42FF",
                normal = "#422F42FF"
            },
            icon_char = "#",
            name = "Pan\nItems"
        },
        ["_S&M_CYCLACTION_10_Launch Tags"] = {
            hide_label = true,
            icon_char = "/",
            name = "Track\nTags"
        },
        ["_S&M_CYCLACTION_12_Launch Track Versions"] = {
            hide_label = true,
            icon_char = "6",
            name = "Track\nVersions"
        },
        ["_S&M_CYCLACTION_13_Launch Param History"] = {
            hide_label = true,
            icon_char = "5",
            name = "Param\nHistory"
        },
        ["_SWS_RESETRATE_SWS: Reset item rate, preserving length, clear 'preserve pitch'"] = {
            name = "Reset\nRate"
        }
    },
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
                HOVER = "#393939FF",
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
        GRID_COLS = 16,
        HEIGHT = 28,
        PADDING = 6,
        PATH = "FontIcons.ttf",
        PREVIEW_SIZE = 32,
        SCALE = 0.73,
        SIZE = 12,
        WIDTH = 20
    },
    SIZES = {
        DEPTH = 3,
        HEIGHT = 38,
        MIN_WIDTH = 20,
        ROUNDING = 7,
        SEPARATOR_WIDTH = 12,
        SPACING = 2,
        TEXT = 15
    },
    TOOLBAR_GROUPS = {
        ["Floating Toolbar 1"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            },
            ["2"] = {
                label = {
                    text = ""
                }
            },
            ["3"] = {
                label = {
                    text = ""
                }
            },
            ["4"] = {
                label = {
                    text = ""
                }
            },
            ["5"] = {
                label = {
                    text = ""
                }
            },
            ["6"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Floating toolbar 15"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Floating toolbar 16"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Floating toolbar 2"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Floating toolbar 3"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Floating toolbar 4"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            },
            ["2"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Floating toolbar 5"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            }
        },
        ["MIDI piano roll toolbar"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Main toolbar"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            },
            ["2"] = {
                label = {
                    text = ""
                }
            },
            ["3"] = {
                label = {
                    text = ""
                }
            },
            ["4"] = {
                label = {
                    text = ""
                }
            }
        },
        ["Media Explorer toolbar"] = {
            ["1"] = {
                label = {
                    text = ""
                }
            }
        }
    },
    UI = {
        FLASH_INTERVAL = 0.5,
        HIDE_ALL_LABELS = false,
        HOVER_DELAY = 0.3,
        USE_GROUPING = true,
        USE_GROUP_LABELS = true
    }
}

return config