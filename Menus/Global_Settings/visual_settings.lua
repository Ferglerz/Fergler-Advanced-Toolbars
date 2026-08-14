function GlobalSettingsMenu:renderToolbarVisualSettings(ctx, saveCallback)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Spacing(ctx)

    reaper.ImGui_TextDisabled(ctx, "Settings:")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    local settings = {
        {
            label = "Button Height",
            control = reaper.ImGui_SliderInt,
            id = "##height",
            value = CONFIG.SIZES.HEIGHT,
            min = CONFIG.SIZES.MIN_HEIGHT,
            max = 60,
            config_key = "HEIGHT"
        },
        {
            label = "Button Rounding",
            control = reaper.ImGui_SliderInt,
            id = "##rounding",
            value = CONFIG.SIZES.ROUNDING,
            min = 0,
            max = 30,
            config_key = "ROUNDING"
        },
        {
            label = "Min Button Width",
            control = reaper.ImGui_SliderInt,
            id = "##minwidth",
            value = CONFIG.SIZES.MIN_WIDTH,
            min = 20,
            max = 200,
            config_key = "MIN_WIDTH"
        },
        {
            label = "3D Depth",
            control = reaper.ImGui_SliderInt,
            id = "##depth",
            value = CONFIG.SIZES.DEPTH,
            min = 0,
            max = 6,
            config_key = "DEPTH"
        },
        {
            label = "Padding",
            control = reaper.ImGui_SliderInt,
            id = "##padding",
            value = CONFIG.SIZES.PADDING,
            min = 0,
            max = 50,
            config_key = "PADDING"
        },
        {
            label = "Button Spacing",
            control = reaper.ImGui_SliderInt,
            id = "##spacing",
            value = CONFIG.SIZES.SPACING,
            min = 0,
            max = 30,
            config_key = "SPACING"
        },
        {
            label = "Separator Size",
            control = reaper.ImGui_SliderInt,
            id = "##separator",
            value = CONFIG.SIZES.SEPARATOR_SIZE,
            min = 4,
            max = 50,
            config_key = "SEPARATOR_SIZE"
        },
        {
            label = "Text Size",
            control = reaper.ImGui_SliderInt,
            id = "##textsize",
            value = CONFIG.SIZES.TEXT,
            min = 8,
            max = 24,
            config_key = "TEXT"
        },
        {
            label = "Titles Text Size",
            control = reaper.ImGui_SliderInt,
            id = "##titlestextsize",
            value = CONFIG.SIZES.TITLES_TEXT,
            min = 6,
            max = 24,
            config_key = "TITLES_TEXT",
            invalidate_layout = true
        },
        {
            label = "Image Icon Scale",
            control = reaper.ImGui_SliderDouble,
            id = "##iconscale",
            value = CONFIG.ICON_FONT.SCALE,
            min = 0.1,
            max = 2.0,
            format = "%.2f",
            config_key = "SCALE",
            in_icon_font = true
        },
        {
            label = "Built-in Icon Size",
            control = reaper.ImGui_SliderInt,
            id = "##iconsize",
            value = CONFIG.ICON_FONT.SIZE,
            min = 4,
            max = 30,
            config_key = "SIZE",
            in_icon_font = true
        }
    }

    for i, setting in ipairs(settings) do
        if i == 6 then
            reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) / 2 + 10)
            reaper.ImGui_BeginGroup(ctx)
        elseif i == 1 then
            reaper.ImGui_BeginGroup(ctx)
        end

        local changed, new_value =
            self:renderSettingsRow(
            ctx,
            setting.label,
            setting.control,
            setting.id,
            setting.value,
            setting.min,
            setting.max,
            setting.format
        )

        if changed then
            if setting.in_icon_font then
                CONFIG.ICON_FONT[setting.config_key] = new_value
                if setting.config_key == "SIZE" then
                    self:invalidateButtonCache()
                end
            else
                CONFIG.SIZES[setting.config_key] = new_value
                if setting.config_key == "TEXT" then
                    self:invalidateButtonCache()
                end
            end
            saveCallback()
            if setting.invalidate_layout and C.LayoutManager then
                C.LayoutManager:invalidateCache()
            end
            if not setting.in_icon_font and setting.config_key == "HEIGHT" and C.IniManager and C.IniManager.reloadToolbarsNow
                and reaper.ImGui_IsItemDeactivatedAfterEdit and reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then
                C.IniManager:reloadToolbarsNow()
            end
        end

        if i == 5 or i == #settings then
            reaper.ImGui_EndGroup(ctx)
        end
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Spacing(ctx)

    local toggle_options = {
        {label = "Horizontal Widget Titles", config = "SHOW_WIDGET_TITLES_HORIZONTAL", parent = "UI", strict_on = true, invalidate_layout = true},
        {label = "Vertical Widget Titles", config = "SHOW_WIDGET_TITLES_VERTICAL", parent = "UI", default_on = true, invalidate_layout = true},
        {label = "Visually Merge Grouped Buttons", config = "USE_GROUPING", parent = "UI"},
        {label = "Group Labels", config = "USE_GROUP_LABELS", parent = "UI"},
        {label = "Show Separators", config = "SHOW_SEPARATORS", parent = "UI", default_on = true}
    }

    for _, option in ipairs(toggle_options) do
        if option.config then
            local val = CONFIG[option.parent][option.config]
            local checked
            if option.strict_on then
                checked = val == true
            elseif option.default_on then
                checked = val ~= false
            else
                checked = val
            end
            local changed, new_checked = reaper.ImGui_Checkbox(ctx, option.label, checked)
            if changed then
                CONFIG[option.parent][option.config] = new_checked
                saveCallback()
                if option.invalidate_layout and C.LayoutManager then
                    C.LayoutManager:invalidateCache()
                end
            end
        else
            if reaper.ImGui_MenuItem(ctx, option.label) then
                option.action()
            end
        end
    end
end

