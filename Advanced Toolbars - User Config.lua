local config = {
    COLORS = {
        TOGGLED_COLOR = "#CCCC00FF",
        ARMED2_TOGGLED_COLOR = "#cc0000FF",
        ARMED_HOVER = "#FF0000FF",
        ARMED_TOGGLED_HOVER = "#990000FF",
        GROUP_SEPARATOR = "#1a1a1a00",
        ARMED2_COLOR = "#cc0000FF",
        WINDOW_BG = "#333333FF",
        ARMED2_TOGGLED_HOVER = "#990000FF",
        ARMED2_HOVER = "#FF0000FF",
        ACTIVE = "#2F2F2FFF",
        ARMED_TOGGLED_COLOR = "#FF0000FF",
        SHADOW = "#22222277",
        ARMED_COLOR = "#FF0000FF",
        BORDER = "#494949FFF",
        TOGGLED_TEXT = "#000000FF",
        TOGGLED_HOVER = "#FFFF557F",
        HOVER = "#333333FF",
        TEXT = "#BBBBBBFF",
        NORMAL = "#222222FF"
    },
    FONTS = {
        TEXT_SIZE = 15
    },
    ICON_FONT = {
        SCALE = 0.72,
        PADDING = 6,
        HEIGHT = 28,
        WIDTH = 20,
        GRID_COLS = 16,
        SIZE = 13,
        PATH = "FontIcons.ttf",
        PREVIEW_SIZE = 32
    },
    TOOLBAR_GROUPS = {
        ["Floating toolbar 16"] = {
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
        ["Floating toolbar 5"] = {
            ["1"] = {
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
                    text = "Rawr"
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
        ["Media Explorer toolbar"] = {
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
        ["Floating toolbar 15"] = {
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
        }
    },
    UI = {
        USE_GROUP_LABELS = true,
        USE_GROUPING = true,
        FLASH_INTERVAL = 0.5,
        HIDE_ALL_LABELS = false
    },
    BUTTON_CUSTOM_PROPERTIES = {
        ["_S&M_CYCLACTION_13_Launch Param History"] = {
            hide_label = false,
            icon_char = "5",
            name = "Param\nHistory"
        },
        ["_RS039a5b581f5d9e3ad860d0f7277316868024c917_Refresh Theme"] = {
            hide_label = false,
            icon_char = "@",
            name = "Refresh\nTheme"
        },
        ["_S&M_CYCLACTION_12_Launch Track Versions"] = {
            hide_label = false,
            icon_char = "6",
            name = "Track\nVersions"
        },
        _RS3b8d8b2140a32d0bfaa6eda3bd21b06d0b7b215b_ReaNoir = {
            icon_char = "Z",
            hide_label = false
        },
        ["-1_SEPARATOR"] = {
            hide_label = false
        },
        ["_RS852f0872789b997921f7f9d40e6f997553bd5147_Update Utility"] = {
            hide_label = false,
            icon_char = ":",
            name = "Update\nUtility"
        },
        ["_RS1f5d1e5b0b0564c0702999ffd57d3be3e65c7c6f_Visual Mixer"] = {
            hide_label = false,
            icon_char = "F",
            name = "Visual\nMixer"
        },
        ["41051_Toggle take reverse"] = {
            hide_label = false,
            icon_path = "/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/test.png",
            name = "Take\nReverse"
        },
        ["_RSb5ad9aeb2f82e8c9c3f61ff4c4805598f8629a53_Edit Glue"] = {
            hide_label = false,
            icon_char = "K",
            name = "Edit\nGlue"
        },
        _RS6f013d3ead1bd2f0f6f8ac72d4f173eaff53a985_Glue = {
            hide_label = false,
            icon_char = "C",
            name = "Super\nGlue"
        },
        ["40745_Solo Dim"] = {
            hide_label = false,
            icon_char = "O",
            name = "Solo\nDim"
        },
        ["_S&M_CYCLACTION_10_Launch Tags"] = {
            hide_label = false,
            icon_char = "/",
            name = "Track\nTags"
        },
        ["42312_Display Item Ruler"] = {
            custom_color = {
                hover = "#673737FF",
                active = "#633434FF",
                normal = "#562E2EFF"
            },
            hide_label = false,
            icon_char = "&",
            name = "Item\nRuler"
        },
        ["_RSc371be9ea3a5067871a9b94aaf8d9e7219e5f944_Pan Items"] = {
            hide_label = false,
            icon_char = "#",
            name = "Pan\nItems"
        },
        ["_S&M_CYCLACTION_11_Launch Item Modifiers"] = {
            hide_label = false,
            icon_char = "8",
            name = "Item\nModifiers"
        },
        ["_RS4d34dda49b57f82c9c06df3d3f8decfc65a05f3e_Script: BuyOne_Create pitch-rate (vari-speed) take envelope and render to new take.lua"] = {
            hide_label = false,
            icon_char = "f",
            name = "Pitch Rate\nEnvelope"
        }
    },
    SIZES = {
        COMBO_HEIGHT = 30,
        DEPTH = 4,
        HEIGHT = 38,
        MIN_WIDTH = 72,
        SEPARATOR_WIDTH = 22,
        SPACING = 3,
        GROUP_SEPARATOR_WIDTH = 2,
        ROUNDING = 11
    }
}

return config