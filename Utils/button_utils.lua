-- Utils/button_utils.lua
-- Utility functions for button property checks and common operations

local ButtonUtils = {}

function ButtonUtils.resolveActionCommandId(action_id)
    if type(action_id) == "string" and action_id:match("^_") then
        return reaper.NamedCommandLookup(action_id)
    end
    return tonumber(action_id)
end

function ButtonUtils.actionSupportsToggle(command_id)
    if not command_id or command_id <= 0 then
        return false
    end
    return reaper.GetToggleCommandState(command_id) >= 0
end

-- Check if button has an icon (either character or path)
function ButtonUtils.hasIcon(button)
    return button and (button.icon_char or button.icon_path)
end

-- Check if button has a widget
function ButtonUtils.hasWidget(button)
    return button and button.widget ~= nil
end

function ButtonUtils.isKnobWidget(widget)
    if not widget or widget.type ~= "slider" then
        return false
    end
    local style = widget.slider_style
    return style == "knob" or style == "simple_knob"
end

--- True if custom_color carries at least one stored slot (not an empty table).
function ButtonUtils.customColorHasConcreteVisual(custom_color)
    if type(custom_color) ~= "table" then
        return false
    end
    local function slot(tab)
        return tab and tab.normal ~= nil
    end
    if slot(custom_color.background) or slot(custom_color.border) or slot(custom_color.text) or slot(custom_color.icon) then
        return true
    end
    local h = custom_color.hover
    if h and (h.background ~= nil or h.border ~= nil) then
        return true
    end
    local a = custom_color.active
    if a and (a.background ~= nil or a.border ~= nil) then
        return true
    end
    return false
end

--- True if this button has explicit colors worth copying for insert / snapshot (avoids empty {} custom_color).
function ButtonUtils.hasInheritedStyleSource(button)
    if not button then
        return false
    end
    if button.user_colors and type(button.user_colors) == "table" and next(button.user_colors) ~= nil then
        return true
    end
    return ButtonUtils.customColorHasConcreteVisual(button.custom_color)
end

-- Check if button has a widget with a width specified (fixed or computed per frame)
function ButtonUtils.hasWidgetWithWidth(button)
    local w = button and button.widget
    return w and (w.width ~= nil or w.getLayoutWidth ~= nil)
end

-- Check if button widget is a slider
function ButtonUtils.isWidgetSlider(button)
    return button and button.widget and button.widget.type == "slider"
end

function ButtonUtils.isWidgetDropdown(button)
    return button and button.widget and button.widget.type == "dropdown"
end

function ButtonUtils.isWidgetColourSwatch(button)
    return button and button.widget and button.widget.type == "colour_swatch"
end

--- Chip-style widgets draw their own hover/active; suppress toolbar button bg/border hover & click tint.
function ButtonUtils.widgetUsesChipChrome(button)
    return button and button.widget and button.widget.chip_widget == true
end

--- Mouse key for COLOR_UTILS.getButtonColors (chip widgets use fixed NORMAL).
function ButtonUtils.colorMouseKeyForButton(button, mouse_key)
    if ButtonUtils.widgetUsesChipChrome(button) then
        return "NORMAL"
    end
    return mouse_key
end

-- Check if button widget has a name
function ButtonUtils.hasWidgetName(button)
    return button and button.widget and button.widget.name
end

-- Check if button widget has a description
function ButtonUtils.hasWidgetDescription(button)
    return button and button.widget and button.widget.description and button.widget.description ~= ""
end

--- When true, hover shows no tooltip (no description and no action-name fallback).
function ButtonUtils.shouldSuppressWidgetTooltip(button)
    return button and button.widget and button.widget.suppress_tooltip == true
end

-- Get separator height from cache or default
function ButtonUtils.getSeparatorHeight(button, is_vertical)
    if not button then
        return CONFIG.SIZES.SEPARATOR_SIZE
    end
    
    if is_vertical then
        return (button.cache and button.cache.layout and button.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
    else
        return CONFIG.SIZES.HEIGHT
    end
end

-- Get extra padding from cached width
function ButtonUtils.getExtraPadding(button)
    if not button then
        return 0
    end
    return (button.cached_width and button.cached_width.extra_padding) or 0
end

--- Button strip width inside a vertical column child (margins match LayoutManager:calculateMargins).
function ButtonUtils.liveVerticalStripWidth(ctx, toolbar_layout)
    if not ctx or not toolbar_layout or not toolbar_layout.is_vertical then
        return nil
    end
    if not reaper.ImGui_GetWindowWidth then
        return nil
    end
    local win_w = reaper.ImGui_GetWindowWidth(ctx)
    if not win_w or win_w <= 0 then
        return nil
    end
    local pad = math.max(1, math.floor((CONFIG.SIZES.PADDING or 6) / 2))
    return math.max(CONFIG.SIZES.MIN_WIDTH or 30, win_w - 2 * pad)
end

--- Live body height for widget buttons (layout cache can lag CONFIG.SIZES.HEIGHT / width).
function ButtonUtils.widgetBodyHeight(button, layout, ctx, is_vertical)
    local toolbar_layout = layout
    local hit_w = (layout and layout.width) or CONFIG.SIZES.MIN_WIDTH or 30
    if is_vertical and ctx then
        local live_w = ButtonUtils.liveVerticalStripWidth(ctx, toolbar_layout)
        if live_w then
            hit_w = live_w
        end
    end
    local title_h = (layout and layout.title_height) or 0
    local body_h = (layout and layout.height) or CONFIG.SIZES.HEIGHT
    if is_vertical and title_h > 0 then
        body_h = body_h - title_h
    end
    if layout then
        local chip_row = require("Renderers.Widgets.chip_row")
        body_h = math.max(body_h, chip_row.widget_body_height(layout))
    end
    if button and button.widget and button.widget.getLayoutHeight and ctx then
        local inner_w = math.max(1, hit_w - ButtonUtils.getExtraPadding(button))
        local ok, h = pcall(button.widget.getLayoutHeight, button.widget, ctx, inner_w, is_vertical == true)
        if ok and type(h) == "number" and h > 0 then
            body_h = h
        end
    end
    return body_h, title_h
end

--- Screen-space hover rect for a toolbar button (title strip + widget body).
--- Uses layout pass dimensions only — live per-frame mutation caused group y gaps on resize.
function ButtonUtils.computeHitRect(button, layout, ctx, rel_x, rel_y, is_vertical)
    if not layout then
        return rel_x, rel_y, CONFIG.SIZES.MIN_WIDTH or 30, CONFIG.SIZES.HEIGHT
    end
    local hit_w = layout.width or CONFIG.SIZES.MIN_WIDTH or 30
    local hit_h = layout.height or CONFIG.SIZES.HEIGHT
    local hit_x, hit_y = rel_x, rel_y
    if ButtonUtils.hasWidget(button) then
        local title_h = layout.title_height or 0
        if title_h > 0 and not is_vertical then
            hit_y = rel_y - title_h
            hit_h = hit_h + title_h
        end
    end
    return hit_x, hit_y, hit_w, hit_h
end

-- Check if button should display text
function ButtonUtils.shouldDisplayText(button)
    if not button then
        return false
    end
    return not button.hide_label and 
           button.display_text and 
           button.display_text ~= "" and 
           button.display_text ~= "SEPARATOR"
end

-- Check if text should be shown (accounting for global hide setting)
function ButtonUtils.shouldShowText(button)
    if not button then
        return false
    end
    return not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
end

-- Collapse whitespace for comparing stored label vs action name (display-only logic).
local function normalize_label_ws(s)
    if not s or s == "" then
        return ""
    end
    s = s:gsub("\\n", " ")
    return (s:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")) or ""
end

-- Split a single line at the space that best balances the two parts (shorter long line wins; ties → split closer to middle).
local function balanced_space_split(line, max_chars)
    if not line or #line <= max_chars then
        return line
    end
    local best_pos, best_score, best_mid_dist = nil, math.huge, math.huge
    local mid = #line / 2
    for pos = 1, #line do
        if line:byte(pos) == 32 then
            local left = (line:sub(1, pos - 1):gsub("%s+$", ""))
            local right = (line:sub(pos + 1):gsub("^%s+", ""))
            if #left > 0 and #right > 0 then
                local score = math.abs(#left - #right)
                local mid_dist = math.abs(pos - mid)
                if score < best_score or (score == best_score and mid_dist < best_mid_dist) then
                    best_score = score
                    best_mid_dist = mid_dist
                    best_pos = pos
                end
            end
        end
    end
    if not best_pos then
        return line
    end
    local left = line:sub(1, best_pos - 1):gsub("%s+$", "")
    local right = line:sub(best_pos + 1):gsub("^%s+", "")
    return left .. "\n" .. right
end

function ButtonUtils.balancedSpaceSplitLine(line, max_chars)
    return balanced_space_split(line, max_chars)
end

--- Up to two lines: single line if it fits; else balanced space split (action-name style), then per-line width trim.
function ButtonUtils.fitTextTwoLinesForWidth(ctx, text, max_width)
    if not text or text == "" then
        return {}
    end
    if not ctx or not max_width or max_width < 4 then
        return { text }
    end
    if reaper.ImGui_CalcTextSize(ctx, text) <= max_width then
        return { text }
    end
    local probe = "ABCDEFGHIJKLMNO"
    local char_w = reaper.ImGui_CalcTextSize(ctx, probe) / #probe
    local max_chars = math.max(4, math.floor(max_width / math.max(char_w, 1)))
    local split = balanced_space_split(text, max_chars)
    local lines = {}
    for line in tostring(split):gmatch("[^\n]+") do
        if line ~= "" then
            table.insert(lines, UTILS.trimTextToWidth(ctx, line, max_width))
        end
    end
    if #lines < 1 then
        return { UTILS.trimTextToWidth(ctx, text, max_width) }
    end
    if #lines > 2 then
        return { lines[1], lines[2] }
    end
    return lines
end

--- Text drawn on the button (may insert a display-only newline for long action names). Does not change stored display_text / tooltips / INI.
function ButtonUtils.getButtonLabelTextForRender(button)
    if not button then
        return ""
    end
    local raw = button.display_text or ""
    raw = raw:gsub("\\n", "\n")
    if raw:find("\n", 1, true) then
        return raw
    end
    if button.is_separator then
        return raw
    end
    local disp_n = normalize_label_ws(raw)
    local orig_n = normalize_label_ws(button.original_text or "")
    if orig_n == "" or disp_n ~= orig_n then
        return raw
    end
    local maxc = (CONFIG.SIZES and CONFIG.SIZES.ACTION_NAME_FALLBACK_MAX_LINE_CHARS) or 14
    return balanced_space_split(raw, maxc)
end

-- Check if button is first in group
function ButtonUtils.isFirstButtonInGroup(button)
    if not button or not button.parent_group then
        return false
    end
    return button.parent_group.buttons[1] == button
end

-- Check if color has alpha (is not transparent)
function ButtonUtils.hasAlpha(color)
    return color and (color & 0xFF) > 0
end

-- Check if group has valid label
function ButtonUtils.hasValidGroupLabel(group)
    return CONFIG.UI.USE_GROUP_LABELS and 
           group and 
           group.group_label and 
           group.group_label.text and 
           #group.group_label.text > 0
end

-- Label row: real label, or edit-mode placeholder ("GROUP") for unlabeled groups.
function ButtonUtils.shouldShowGroupLabelRow(editing_mode, group)
    if ButtonUtils.hasValidGroupLabel(group) then
        return true
    end
    return editing_mode == true
end

function ButtonUtils.getGroupLabelTextForRender(editing_mode, group)
    if ButtonUtils.hasValidGroupLabel(group) then
        return group.group_label.text or ""
    end
    if editing_mode then
        return "GROUP"
    end
    return ""
end

-- Check if should skip separator in vertical mode with label
function ButtonUtils.shouldSkipSeparatorInVerticalMode(button, is_vertical, has_visible_label)
    return is_vertical and 
           has_visible_label and 
           button:isSeparator() and 
           button.is_section_end
end

-- Check if can start drag operation
function ButtonUtils.canStartDrag(drag_cache, mouse_dragging)
    return drag_cache and 
           drag_cache.mouse_down_on_button and 
           mouse_dragging and 
           not drag_cache.was_dragging_last_frame and 
           not C.DragDropManager:isDragging()
end

-- Check if can start separator drag
function ButtonUtils.canStartSeparatorDrag(drag_cache, mouse_dragging, current_time)
    if not drag_cache or not drag_cache.mouse_down_on_button then
        return false
    end
    
    if C.DragDropManager:isDragging() or drag_cache.was_dragging_last_frame then
        return false
    end
    
    -- Start drag immediately for separators (no delay) or after minimal movement
    return mouse_dragging or 
           (drag_cache.drag_start_time and current_time - drag_cache.drag_start_time > 0.05)
end

-- Get group label text safely
function ButtonUtils.getGroupLabelText(group)
    if not group or not group.group_label then
        return ""
    end
    return group.group_label.text or ""
end

-- Check if group has separator
function ButtonUtils.groupHasSeparator(group)
    if not group or not group.buttons then
        return false
    end
    
    for _, button in ipairs(group.buttons) do
        if button:isSeparator() then
            return true
        end
    end
    
    return false
end

-- Group-local layout for drag-drop ghost (relative x/y within group, same space as button_layout.*)
function ButtonUtils.computeDragGhostGroupLayout(source_button, target_button_layout, toolbar_layout)
    local spacing = CONFIG.SIZES.SPACING or 0
    local is_vert = toolbar_layout.is_vertical
    local drop_after = C.DragDropManager.drop_position == "after"
    local gw, gh

    if source_button:isSeparator() then
        if is_vert then
            gw = target_button_layout.width
            gh = (source_button.cache.layout and source_button.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
        else
            gw = (source_button.cache.layout and source_button.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
            gh = CONFIG.SIZES.HEIGHT
        end
    else
        gw = (source_button.cached_width and source_button.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
        gh = CONFIG.SIZES.HEIGHT
        if is_vert then
            gw = target_button_layout.width
        end
    end

    local gx, gy
    if is_vert then
        gx = target_button_layout.x
        if drop_after then
            gy = target_button_layout.y + target_button_layout.height + spacing
        else
            gy = target_button_layout.y - gh - spacing
        end
    else
        gy = target_button_layout.y
        if drop_after then
            gx = target_button_layout.x + target_button_layout.width + spacing
        else
            gx = target_button_layout.x - gw - spacing
        end
    end

    return { x = gx, y = gy, width = gw, height = gh, is_vertical = is_vert }
end

return ButtonUtils

