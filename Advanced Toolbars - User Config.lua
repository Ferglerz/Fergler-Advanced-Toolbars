local config = {
    COLORS = {
        BORDER = "#494949FFF",
        GROUP_SEPARATOR = "#1a1a1a00",
        ARMED = {
            HOVER = "#FF0000FF",
            COLOR = "#FF0000FF",
            TOGGLED_HOVER = "#990000FF",
            TOGGLED_COLOR = "#FF0000FF"
        },
        WINDOW_BG = "#333333FF",
        ARMED_FLASH = {
            HOVER = "#FF0000FF",
            COLOR = "#cc0000FF",
            TOGGLED_HOVER = "#990000FF",
            TOGGLED_COLOR = "#cc0000FF"
        },
        NORMAL = {
            HOVER = "#333333FF",
            COLOR = "#222222FF",
            ACTIVE = "#2F2F2FFF",
            TEXT = "#BBBBBBFF"
        },
        TOGGLED = {
            HOVER = "#FFFF557F",
            COLOR = "#CCCC00FF",
            TEXT = "#000000FF"
        },
        SHADOW = "#22222277"
    },
    SIZES = {
        HEIGHT = 38,
        SPACING = 3,
        COMBO_HEIGHT = 30,
        DEPTH = 4,
        SEPARATOR_WIDTH = 22,
        ROUNDING = 11,
        GROUP_SEPARATOR_WIDTH = 2,
        MIN_WIDTH = 74
    },
    BUTTON_CUSTOM_PROPERTIES = {
        ["_RS1f5d1e5b0b0564c0702999ffd57d3be3e65c7c6f_Visual Mixer"] = {
            icon_char = "F",
            hide_label = false,
            name = "Visual\nMixer"
        },
        ["_RS4d34dda49b57f82c9c06df3d3f8decfc65a05f3e_Script: BuyOne_Create pitch-rate (vari-speed) take envelope and render to new take.lua"] = {
            icon_char = "f",
            hide_label = false,
            name = "Pitch Rate\nEnvelope"
        },
        ["_RS039a5b581f5d9e3ad860d0f7277316868024c917_Refresh Theme"] = {
            icon_char = "@",
            hide_label = false,
            name = "Refresh\nTheme"
        },
        _RS3b8d8b2140a32d0bfaa6eda3bd21b06d0b7b215b_ReaNoir = {
            hide_label = false,
            icon_char = "Z"
        },
        _RS6f013d3ead1bd2f0f6f8ac72d4f173eaff53a985_Glue = {
            icon_char = "C",
            hide_label = false,
            name = "Super\nGlue"
        },
        ["_RSb5ad9aeb2f82e8c9c3f61ff4c4805598f8629a53_Edit Glue"] = {
            icon_char = "K",
            hide_label = false,
            name = "Edit\nGlue"
        },
        ["_S&M_CYCLACTION_13_Launch Param History"] = {
            icon_char = "5",
            hide_label = false,
            name = "Param\nHistory"
        },
        ["_S&M_CYCLACTION_10_Launch Tags"] = {
            icon_char = "/",
            hide_label = false,
            name = "Track\nTags"
        },
        ["_S&M_CYCLACTION_12_Launch Track Versions"] = {
            icon_char = "6",
            hide_label = false,
            name = "Track\nVersions"
        },
        ["40745_Solo Dim"] = {
            icon_char = "O",
            hide_label = false,
            name = "Solo\nDim"
        },
        ["_S&M_CYCLACTION_11_Launch Item Modifiers"] = {
            icon_char = "8",
            hide_label = false,
            name = "Item\nModifiers"
        },
        ["_RS852f0872789b997921f7f9d40e6f997553bd5147_Update Utility"] = {
            icon_char = ":",
            hide_label = false,
            name = "Update\nUtility"
        },
        ["-1_SEPARATOR"] = {
            hide_label = false
        },
        ["42312_Display Item Ruler"] = {
            icon_char = "&",
            hide_label = false,
            name = "Item\nRuler"
        },
        ["_RSc371be9ea3a5067871a9b94aaf8d9e7219e5f944_Pan Items"] = {
            icon_char = "#",
            hide_label = false,
            name = "Pan\nItems"
        },
        ["41051_Toggle take reverse"] = {
            icon_path = "/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/test.png",
            hide_label = false,
            name = "Take\nReverse"
        }
    },
    FONTS = {
        TEXT_SIZE = 15
    },
    UI = {
        FLASH_INTERVAL = 0.5,
        USE_GROUP_LABELS = true,
        USE_GROUPING = true,
        HIDE_ALL_LABELS = false
    },
    ICON_FONT = {
        PADDING = 6,
        PREVIEW_SIZE = 32,
        PATH = "FontIcons.ttf",
        WIDTH = 20,
        SCALE = 0.72,
        GRID_COLS = 16,
        HEIGHT = 28,
        SIZE = 13
    },
    TOOLBAR_GROUPS = {
        ["MIDI piano roll toolbar"] = {
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
        ["Floating toolbar 2"] = {
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
            }
        },
        ["Floating toolbar 16"] = {
            ["1"] = {
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
        ["Floating toolbar 15"] = {
            ["1"] = {
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
        }
    }
}

return config