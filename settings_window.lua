-- settings_window.lua

local SettingsWindow = {}
SettingsWindow.__index = SettingsWindow

function SettingsWindow.new(reaper, helpers)
    local self = setmetatable({}, SettingsWindow)
    self.r = reaper
    self.helpers = helpers
    return self
end

function SettingsWindow:renderSettingsRow(ctx, label, fn, ...)
    self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_ItemSpacing(), 5, 5)

    -- Text label
    self.r.ImGui_AlignTextToFramePadding(ctx)
    self.r.ImGui_Text(ctx, label)

    -- Calculate positioning
    local window_width = self.r.ImGui_GetWindowWidth(ctx)
    local slider_width = 120
    local text_width = (window_width - 40) / 2 - slider_width - 10

    -- Right-align the slider
    self.r.ImGui_SameLine(ctx, text_width)
    self.r.ImGui_SetNextItemWidth(ctx, slider_width)

    -- Call the actual control function
    local result = {fn(ctx, ...)}
    self.r.ImGui_PopStyleVar(ctx)
    return table.unpack(result)
end

function SettingsWindow:render(ctx, saveCallback, toggleColorEditor, toggleDocking, toggleEditingMode)
    self.r.ImGui_TextDisabled(ctx, "Settings:")
    self.r.ImGui_Separator(ctx)

    -- Calculate column widths
    local window_width = self.r.ImGui_GetWindowWidth(ctx)
    local column_width = (window_width - 40) / 2

    if self.r.ImGui_MenuItem(ctx, "Button Editing Mode", nil, toggleEditingMode(nil, true)) then
        toggleEditingMode(not toggleEditingMode(nil, true))
    end

    -- First column
    self.r.ImGui_BeginGroup(ctx)

    

    local height_changed, new_height =
        self:renderSettingsRow(ctx, "Button Height", self.r.ImGui_SliderInt, "##height", CONFIG.SIZES.HEIGHT, 20, 60)
    if height_changed then
        CONFIG.SIZES.HEIGHT = new_height
        saveCallback()
    end

    local rounding_changed, new_rounding =
        self:renderSettingsRow(
        ctx,
        "Button Rounding",
        self.r.ImGui_SliderInt,
        "##rounding",
        CONFIG.SIZES.ROUNDING,
        0,
        30
    )
    if rounding_changed then
        CONFIG.SIZES.ROUNDING = new_rounding
        saveCallback()
    end

    local width_changed, new_width =
        self:renderSettingsRow(
        ctx,
        "Min Button Width",
        self.r.ImGui_SliderInt,
        "##minwidth",
        CONFIG.SIZES.MIN_WIDTH,
        20,
        200
    )
    if width_changed then
        CONFIG.SIZES.MIN_WIDTH = new_width
        saveCallback()
    end

    local depth_changed, new_depth =
        self:renderSettingsRow(ctx, "3D Depth", self.r.ImGui_SliderInt, "##depth", CONFIG.SIZES.DEPTH, 0, 6)
    if depth_changed then
        CONFIG.SIZES.DEPTH = new_depth
        saveCallback()
    end

    self.r.ImGui_EndGroup(ctx)

    -- Second column
    self.r.ImGui_SameLine(ctx, column_width + 20)
    self.r.ImGui_BeginGroup(ctx)

    local spacing_changed, new_spacing =
        self:renderSettingsRow(ctx, "Button Spacing", self.r.ImGui_SliderInt, "##spacing", CONFIG.SIZES.SPACING, 0, 30)
    if spacing_changed then
        CONFIG.SIZES.SPACING = new_spacing
        saveCallback()
    end

    local separator_changed, new_separator_width =
        self:renderSettingsRow(
        ctx,
        "Separator Width",
        self.r.ImGui_SliderInt,
        "##separator",
        CONFIG.SIZES.SEPARATOR_WIDTH,
        4,
        50
    )
    if separator_changed then
        CONFIG.SIZES.SEPARATOR_WIDTH = new_separator_width
        saveCallback()
    end

    local scale_changed, new_scale =
        self:renderSettingsRow(
        ctx,
        "Image Icon Scale",
        self.r.ImGui_SliderDouble,
        "##iconscale",
        CONFIG.ICON_FONT.SCALE,
        0.1,
        2.0,
        "%.2f"
    )
    if scale_changed then
        CONFIG.ICON_FONT.SCALE = new_scale
        saveCallback()
    end

    local size_changed, new_size =
        self:renderSettingsRow(
        ctx,
        "Built-in Icon Size (must restart)",
        self.r.ImGui_SliderInt,
        "##iconsize",
        CONFIG.ICON_FONT.SIZE,
        4,
        18
    )
    if size_changed then
        CONFIG.ICON_FONT.SIZE = new_size
        saveCallback()
    end

    self.r.ImGui_EndGroup(ctx)

    self.r.ImGui_Separator(ctx)

    -- Menu items
    if self.r.ImGui_MenuItem(ctx, "Edit Colors") then
        toggleColorEditor(true)
    end

    CONFIG.UI.HIDE_ALL_LABELS = CONFIG.UI.HIDE_ALL_LABELS or false
    if self.r.ImGui_MenuItem(ctx, "Hide All Button Labels", nil, CONFIG.UI.HIDE_ALL_LABELS) then
        CONFIG.UI.HIDE_ALL_LABELS = not CONFIG.UI.HIDE_ALL_LABELS
        saveCallback()
    end

    if self.r.ImGui_MenuItem(ctx, "Button Grouping", nil, CONFIG.UI.USE_GROUPING) then
        CONFIG.UI.USE_GROUPING = not CONFIG.UI.USE_GROUPING
        saveCallback()
    end

    if self.r.ImGui_MenuItem(ctx, "Group Labels", nil, CONFIG.UI.USE_GROUP_LABELS) then
        CONFIG.UI.USE_GROUP_LABELS = not CONFIG.UI.USE_GROUP_LABELS
        saveCallback()
    end

    local current_dock = self.r.ImGui_GetWindowDockID(ctx)
    local is_docked = current_dock ~= 0
    if self.r.ImGui_MenuItem(ctx, "Docked", nil, is_docked) then
        toggleDocking(current_dock, is_docked)
    end
end

return {
    new = function(reaper, helpers)
        return SettingsWindow.new(reaper, helpers)
    end
}
