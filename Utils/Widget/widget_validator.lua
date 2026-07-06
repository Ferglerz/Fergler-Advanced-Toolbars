-- Utils/widget_validator.lua
-- Dev-time checks when widgets load. Warns only; does not block loading.

local M = {}

local ALLOWED_TYPES = {
    display = true,
    slider = true,
    dropdown = true,
    colour_swatch = true,
}

local DISPLAY_STYLES = {
    value_label = true,
    centered = true,
    meter_strip = true,
}

local WIRED_HOOKS = {
    getValue = true,
    setValue = true,
    renderCustom = true,
    display_text = true,
    display_value_color = true,
    getLayoutWidth = true,
    getLayoutHeight = true,
    hitTestSubcontrols = true,
    onSubcontrolClick = true,
    onSubcontrolRightClick = true,
    onClick = true,
    onRightClick = true,
    onSelect = true,
    onHover = true,
    onMouseWheel = true,
    onSettingsMenu = true,
    onWidgetFrame = true,
    slide_width = true,
    slide_height = true,
    applyPersistedOptions = true,
    exportPersistedOptions = true,
    scanRegions = true,
    scanTemplates = true,
    scanToolbars = true,
    scanMenuItems = true,
    init = true,
    col_primary = true,
    is_disabled = true,
    slide_out_can_interact = true,
    renderColourSwatch = true,
}

function M.validate(widget, widget_key)
    if type(widget) ~= "table" then
        return
    end

    local label = widget.name or widget_key or "?"

    if not widget.name then
        reaper.ShowConsoleMsg("Advanced Toolbars: widget '" .. tostring(widget_key) .. "' missing name\n")
    end

    if not widget.type then
        reaper.ShowConsoleMsg("Advanced Toolbars: widget '" .. label .. "' missing type\n")
    elseif not ALLOWED_TYPES[widget.type] then
        reaper.ShowConsoleMsg("Advanced Toolbars: widget '" .. label .. "' unknown type '" .. tostring(widget.type) .. "'\n")
    end

    if widget.display_style and not DISPLAY_STYLES[widget.display_style] then
        reaper.ShowConsoleMsg(
            "Advanced Toolbars: widget '"
                .. label
                .. "' unknown display_style '"
                .. tostring(widget.display_style)
                .. "' (use value_label, centered, meter_strip)\n"
        )
    end

    if widget._slide_out_mode then
        if type(widget.slide_width) ~= "function" then
            reaper.ShowConsoleMsg(
                "Advanced Toolbars: widget '" .. label .. "' has slide-out enabled but no slide_width\n"
            )
        end
        if type(widget.slide_height) ~= "function" then
            reaper.ShowConsoleMsg(
                "Advanced Toolbars: widget '" .. label .. "' has slide-out enabled but no slide_height\n"
            )
        end
    end

    for key, value in pairs(widget) do
        if type(key) == "string" and type(value) == "function" then
            if key:match("^on[A-Z]") and not WIRED_HOOKS[key] then
                reaper.ShowConsoleMsg(
                    "Advanced Toolbars: widget '"
                        .. label
                        .. "' hook '"
                        .. key
                        .. "' is not wired by the renderer\n"
                )
            elseif not WIRED_HOOKS[key] and not key:match("^__") then
                if key == "format" or key == "display_text" or key == "display_value_color" then
                elseif key:match("^[a-z_]+$") and key:find("_") and not WIRED_HOOKS[key] then
                    -- skip lowercase helpers on widget table
                end
            end
        end
    end
end

return M
