local config = {
    BUTTON_CUSTOM_PROPERTIES = {
        ["40098_File: Clean current project directory..."] = {
            hide_label = true,
            icon_char = "À",
            icon_font = "IconFonts/ProjectManagement_13.ttf",
            name = "Clean\nProject"
        },
        ["40745_Solo Dim"] = {
            name = "Solo\nDim"
        },
        ["40887_Envelope: Reduce number of points..."] = {
            icon_char = "È",
            icon_font = "IconFonts/ProjectManagement_13.ttf",
            name = "Reduce\nEnv Points"
        },
        ["41051_Toggle take reverse"] = {
            custom_color = {
                background = {
                    clicked = "#5C3E3EFF",
                    hover = "#664545FF",
                    normal = "#5E4040FF"
                },
                border = {
                    clicked = "#AD8F8FFF",
                    hover = "#AD8F8FFF",
                    normal = "#AD8F8FFF"
                }
            },
            icon_char = "Å",
            icon_font = "IconFonts/Rating_6.ttf",
            name = "Take\nReverse"
        },
        ["42312_Display Item Ruler"] = {
            custom_color = {
                background = {
                    clicked = "#5C3E3EFF",
                    hover = "#664545FF",
                    normal = "#5E4040FF"
                },
                border = {
                    clicked = "#AD8F8FFF",
                    hover = "#AD8F8FFF",
                    normal = "#AD8F8FFF"
                }
            },
            hide_label = true,
            icon_char = "Ê",
            icon_font = "IconFonts/Tools_17.ttf",
            name = "Item\nRuler"
        },
        ["_FNG_DECREASERATE_SWS: Decrease item rate by ~6% (one semitone) preserving length, clear 'preserve pitch'"] = {
            name = "-100\n"
        },
        ["_FNG_INCREASERATE_SWS: Increase item rate by ~6% (one semitone) preserving length, clear 'preserve pitch'"] = {
            name = "+100\n"
        },
        ["_FNG_NUDGERATEDOWN_SWS: Decrease item rate by ~0.6% (10 cents) preserving length, clear 'preserve pitch'"] = {
            name = "-10\n"
        },
        ["_FNG_NUDGERATEUP_SWS: Increase item rate by ~0.6% (10 cents) preserving length, clear 'preserve pitch'"] = {
            name = "+10\n"
        },
        ["_RS1f5d1e5b0b0564c0702999ffd57d3be3e65c7c6f_Visual Mixer"] = {
            icon_char = "Ï",
            icon_font = "IconFonts/Tools_17.ttf",
            name = "Visual\nMixer"
        },
        _RS3b8d8b2140a32d0bfaa6eda3bd21b06d0b7b215b_ReaNoir = {
            hide_label = true,
            icon_char = "Á",
            icon_font = "IconFonts/Tools_17.ttf"
        },
        ["_RS4d34dda49b57f82c9c06df3d3f8decfc65a05f3e_Script: BuyOne_Create pitch-rate (vari-speed) take envelope and render to new take.lua"] = {
            name = "Vari-speed\n"
        },
        _RS6f013d3ead1bd2f0f6f8ac72d4f173eaff53a985_Glue = {
            custom_color = {
                background = {
                    clicked = "#274E57FF",
                    hover = "#2B5761FF",
                    normal = "#285059FF"
                },
                border = {
                    clicked = "#5092A3FF",
                    hover = "#5092A3FF",
                    normal = "#5092A3FF"
                },
                icon = {
                    clicked = "#5BA2B4FF",
                    hover = "#70C6DCFF",
                    normal = "#70C6DCFF"
                },
                text = {
                    clicked = "#5BA2B4FF",
                    hover = "#70C6DCFF",
                    normal = "#70C6DCFF"
                }
            },
            hide_label = true,
            icon_char = "È",
            icon_font = "IconFonts/Tools_17.ttf"
        },
        ["_RS852f0872789b997921f7f9d40e6f997553bd5147_Update Utility"] = {
            icon_char = "Ë",
            icon_font = "IconFonts/ProjectManagement_13.ttf",
            name = "Update\nUtility"
        },
        ["_RSb5ad9aeb2f82e8c9c3f61ff4c4805598f8629a53_Edit Glue"] = {
            custom_color = {
                background = {
                    clicked = "#274E57FF",
                    hover = "#2B5761FF",
                    normal = "#285059FF"
                },
                border = {
                    clicked = "#5092A3FF",
                    hover = "#5092A3FF",
                    normal = "#5092A3FF"
                },
                icon = {
                    clicked = "#5BA2B4FF",
                    hover = "#70C6DCFF",
                    normal = "#70C6DCFF"
                },
                text = {
                    clicked = "#5BA2B4FF",
                    hover = "#70C6DCFF",
                    normal = "#70C6DCFF"
                }
            },
            name = "Edit\nGlue",
            right_click = "dropdown"
        },
        ["_RSc371be9ea3a5067871a9b94aaf8d9e7219e5f944_Pan Items"] = {
            custom_color = {
                background = {
                    clicked = "#5C3E3EFF",
                    hover = "#664545FF",
                    normal = "#5E4040FF"
                },
                border = {
                    clicked = "#AD8F8FFF",
                    hover = "#AD8F8FFF",
                    normal = "#AD8F8FFF"
                }
            },
            icon_char = "Ã",
            icon_font = "IconFonts/Moving_7.ttf",
            name = "Pan\nItems"
        },
        ["_S&M_CYCLACTION_10_Launch Tags"] = {
            custom_color = {
                background = {
                    clicked = "#343434FF",
                    hover = "#3E3E3EFF",
                    normal = "#6B3636FF"
                },
                border = {
                    clicked = "#8B8B8BFF",
                    hover = "#8B8B8BFF",
                    normal = "#8B8B8BFF"
                }
            },
            dropdown_menu = {
                ["1"] = {
                    action_id = "",
                    name = "New Item"
                },
                ["2"] = {
                    action_id = "",
                    name = "New Item"
                },
                ["3"] = {
                    action_id = "",
                    name = "New Item"
                },
                ["4"] = {
                    action_id = "",
                    name = "New Item"
                },
                ["5"] = {
                    action_id = "",
                    name = "New Item"
                }
            },
            icon_char = "Á",
            icon_font = "IconFonts/EditingAndFiltering_12.ttf",
            name = "Tags\n",
            right_click = "dropdown"
        },
        ["_S&M_CYCLACTION_12_Launch Track Versions"] = {
            custom_color = {
                background = {
                    clicked = "#343434FF",
                    hover = "#3E3E3EFF",
                    normal = "#6B3636FF"
                },
                border = {
                    clicked = "#8B8B8BFF",
                    hover = "#8B8B8BFF",
                    normal = "#8B8B8BFF"
                }
            },
            icon_char = "Â",
            icon_font = "IconFonts/EditingAndFiltering_12.ttf",
            name = "Track\nVersions"
        },
        ["_S&M_CYCLACTION_13_Launch Param History"] = {
            custom_color = {
                background = {
                    clicked = "#343434FF",
                    hover = "#3E3E3EFF",
                    normal = "#6B3636FF"
                },
                border = {
                    clicked = "#8B8B8BFF",
                    hover = "#8B8B8BFF",
                    normal = "#8B8B8BFF"
                }
            },
            dropdown_menu = {
                ["1"] = {
                    is_separator = true
                },
                ["2"] = {
                    action_id = "",
                    name = "New Item"
                },
                ["3"] = {
                    action_id = "",
                    name = "New Item"
                },
                ["4"] = {
                    is_separator = true
                },
                ["5"] = {
                    action_id = "",
                    name = "New Item"
                }
            },
            icon_char = "Ì",
            icon_font = "IconFonts/Music_16.ttf",
            name = "Parameter\nHistory",
            right_click = "dropdown"
        },
        ["_SWS_RESETRATE_SWS: Reset item rate, preserving length, clear 'preserve pitch'"] = {
            name = "Reset\nRate"
        }
    },
    CUSTOM_NAME = "Main Tools",
    TOOLBAR_GROUPS = {
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
        },
        ["7"] = {
            label = {
                text = ""
            }
        },
        ["8"] = {
            label = {
                text = ""
            }
        }
    }
}

return config