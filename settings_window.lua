-- settings_window.lua

local SettingsWindow = {}
SettingsWindow.__index = SettingsWindow

function SettingsWindow.new(reaper, helpers)
    local self = setmetatable({}, SettingsWindow)
    self.r = reaper
    self.helpers = helpers
    return self
end

function SettingsWindow:renderSettingsRow(ctx, label, fn, control_id, value, min, max, format)
    -- Align text and control on same line with consistent spacing
    self.r.ImGui_AlignTextToFramePadding(ctx)
    self.r.ImGui_Text(ctx, label)

    -- Set control width and position
    self.r.ImGui_SameLine(ctx, 200)
    self.r.ImGui_SetNextItemWidth(ctx, 120)

    -- Call the control function with appropriate parameters
    return fn(ctx, control_id, value, min, max, format)
end

function SettingsWindow:render(ctx, saveCallback, toggleColorEditor, toggleEditingMode)
    self.r.ImGui_TextDisabled(ctx, "Settings:")
    self.r.ImGui_Separator(ctx)

    -- Editing mode toggle - ensure we're getting and setting a boolean value
    local is_editing_mode = toggleEditingMode(nil, true)
    if self.r.ImGui_MenuItem(ctx, "Button Editing Mode", nil, is_editing_mode) then
        toggleEditingMode(not is_editing_mode)
    end

    -- Use two columns for settings
    local settings = {
        {
            label = "Button Height",
            control = self.r.ImGui_SliderInt,
            id = "##height",
            value = CONFIG.SIZES.HEIGHT,
            min = 20,
            max = 60,
            config_key = "HEIGHT"
        },
        {
            label = "Button Rounding",
            control = self.r.ImGui_SliderInt,
            id = "##rounding",
            value = CONFIG.SIZES.ROUNDING,
            min = 0,
            max = 30,
            config_key = "ROUNDING"
        },
        {
            label = "Min Button Width",
            control = self.r.ImGui_SliderInt,
            id = "##minwidth",
            value = CONFIG.SIZES.MIN_WIDTH,
            min = 20,
            max = 200,
            config_key = "MIN_WIDTH"
        },
        {
            label = "3D Depth",
            control = self.r.ImGui_SliderInt,
            id = "##depth",
            value = CONFIG.SIZES.DEPTH,
            min = 0,
            max = 6,
            config_key = "DEPTH"
        },
        {
            label = "Button Spacing",
            control = self.r.ImGui_SliderInt,
            id = "##spacing",
            value = CONFIG.SIZES.SPACING,
            min = 0,
            max = 30,
            config_key = "SPACING"
        },
        {
            label = "Separator Width",
            control = self.r.ImGui_SliderInt,
            id = "##separator",
            value = CONFIG.SIZES.SEPARATOR_WIDTH,
            min = 4,
            max = 50,
            config_key = "SEPARATOR_WIDTH"
        },
        {
            label = "Image Icon Scale",
            control = self.r.ImGui_SliderDouble,
            id = "##iconscale",
            value = CONFIG.ICON_FONT.SCALE,
            min = 0.1,
            max = 2.0,
            format = "%.2f",
            config_key = "SCALE",
            in_icon_font = true
        },
        {
            label = "Built-in Icon Size (must restart)",
            control = self.r.ImGui_SliderInt,
            id = "##iconsize",
            value = CONFIG.ICON_FONT.SIZE,
            min = 4,
            max = 18,
            config_key = "SIZE",
            in_icon_font = true
        }
    }

    -- Render all sliders
    for i, setting in ipairs(settings) do
        -- Create two columns
        if i == 5 then -- Start second column after first 4 items
            self.r.ImGui_SameLine(ctx, self.r.ImGui_GetWindowWidth(ctx) / 2 + 20)
            self.r.ImGui_BeginGroup(ctx)
        elseif i == 1 then -- Start first column
            self.r.ImGui_BeginGroup(ctx)
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
            -- Update the appropriate config value
            if setting.in_icon_font then
                CONFIG.ICON_FONT[setting.config_key] = new_value
            else
                CONFIG.SIZES[setting.config_key] = new_value
            end
            saveCallback()
        end

        -- End column groups
        if i == 4 or i == #settings then
            self.r.ImGui_EndGroup(ctx)
        end
    end

    self.r.ImGui_Separator(ctx)

    -- Menu toggles section
    local toggle_options = {
        {label = "Edit Colors", action = function()
                toggleColorEditor(true)
            end},
        {label = "Hide All Button Labels", config = "HIDE_ALL_LABELS", parent = "UI"},
        {label = "Button Grouping", config = "USE_GROUPING", parent = "UI"},
        {label = "Group Labels", config = "USE_GROUP_LABELS", parent = "UI"}
    }

    for _, option in ipairs(toggle_options) do
        if option.config then
            -- Toggle option
            if self.r.ImGui_MenuItem(ctx, option.label, nil, CONFIG[option.parent][option.config]) then
                CONFIG[option.parent][option.config] = not CONFIG[option.parent][option.config]
                saveCallback()
            end
        else
            -- Action option
            if self.r.ImGui_MenuItem(ctx, option.label) then
                option.action()
            end
        end
    end


    if self.r.ImGui_MenuItem(ctx, "Toolbar Editor") then
        self.r.Main_OnCommand(40905, 0)
    end
end

return {
    new = function(reaper, helpers)
        return SettingsWindow.new(reaper, helpers)
    end
}
