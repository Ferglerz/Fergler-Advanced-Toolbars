-- Utils/drawing.lua
local Drawing = {}

-- angle: Direction in degrees (0 = up, 90 = right, 180 = down, 270 = left)
function Drawing.triangle(draw_list, center_x, center_y, width, height, color, angle)
    -- Convert angle to radians
    local rad = math.rad(angle)
    
    -- Calculate the three points of the triangle based on the angle
    -- The triangle points in the direction specified by angle
    local point1_x = center_x + math.sin(rad) * (height / 2)
    local point1_y = center_y - math.cos(rad) * (height / 2)
    
    local point2_x = center_x - math.sin(rad + math.pi/2) * (width / 2)
    local point2_y = center_y + math.cos(rad + math.pi/2) * (width / 2)
    
    local point3_x = center_x + math.sin(rad + math.pi/2) * (width / 2)
    local point3_y = center_y - math.cos(rad + math.pi/2) * (width / 2)
    
    -- Draw the triangle
    reaper.ImGui_DrawList_AddTriangleFilled(
        draw_list,
        point1_x, point1_y,  -- Point in the direction of angle
        point2_x, point2_y,  -- Point to the 'left' of the direction
        point3_x, point3_y,  -- Point to the 'right' of the direction
        color
    )
end

Drawing.ANGLE_UP = 0
Drawing.ANGLE_RIGHT = 90
Drawing.ANGLE_DOWN = 180
Drawing.ANGLE_LEFT = 270

local ICON_FONTS_LIB = require("Utils.icon_fonts")



function Drawing.getGlyphArmSize()
    local s = math.floor(CONFIG.SIZES.HEIGHT / 4 + 0.5)
    if s < 4 then s = 4 end
    if s % 2 == 1 then s = s + 1 end
    return s
end

-- Shared edit-mode symbol: draws a rounded + or x with symmetric even-length arms
function Drawing.drawSymbolGlyph(ctx, draw_list, cx, cy, outer_r, color, symbol, is_filled)
    cx = math.floor(cx + 0.5)
    cy = math.floor(cy + 0.5)
    local c = COLOR_UTILS.setAlpha(color, 0xFF)
    local t = is_filled and 2.0 or 1.0

    if is_filled then
        reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, outer_r, c, 24)
        local s = Drawing.getGlyphArmSize()
        local min_inner = s / 2 + 2
        local inner_r = math.max(math.min(outer_r - 1.5, outer_r * 0.58), min_inner)
        reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, inner_r, COLOR_UTILS.toImGuiColor("#FFFFFFFF"), 24)
        
        local black = COLOR_UTILS.toImGuiColor("#000000FF")
        if symbol == "plus" then
            reaper.ImGui_DrawList_AddLine(draw_list, cx - s / 2, cy, cx + s / 2, cy, black, t)
            reaper.ImGui_DrawList_AddLine(draw_list, cx, cy - s / 2, cx, cy + s / 2, black, t)
        else
            reaper.ImGui_DrawList_AddLine(draw_list, cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2, black, t)
            reaper.ImGui_DrawList_AddLine(draw_list, cx + s / 2, cy - s / 2, cx - s / 2, cy + s / 2, black, t)
        end
    else
        -- Outline style for "trailing add"
        reaper.ImGui_DrawList_AddCircle(draw_list, cx, cy, math.max(2, math.floor(outer_r + 0.5)), c, 0, t)
        local s = Drawing.getGlyphArmSize()
        local half = math.min(s / 2, outer_r - 1)
        if half < 2 then half = 2 end
        reaper.ImGui_DrawList_AddLine(draw_list, cx - half, cy, cx + half, cy, c, t)
        reaper.ImGui_DrawList_AddLine(draw_list, cx, cy - half, cx, cy + half, c, t)
    end
end

function Drawing.centeredTextRelY(ctx, rel_y, height, y_offset)
    return rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2 + (y_offset or 0)
end

function Drawing.drawTextRelative(coords, draw_list, rel_x, rel_y, color, text)
    local dx, dy = coords:relativeToDrawList(rel_x, rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, color, text)
end

function Drawing.drawRectFilledRelative(coords, draw_list, rel_x, rel_y, w, h, color, rounding, flags)
    local x1, y1, x2, y2 = coords:relativeRectToDrawList(rel_x, rel_y, w, h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, color, rounding or 0, flags or 0)
end

function Drawing.drawChipBackground(coords, draw_list, rel_x, rel_y, w, h, bg_color, opts)
    opts = opts or {}
    local bg = bg_color
    local border = opts.border_color
    if opts.alpha_factor then
        bg = COLOR_UTILS.applyAlphaFactor(bg, opts.alpha_factor)
        if border then border = COLOR_UTILS.applyAlphaFactor(border, opts.alpha_factor) end
    end
    local x1, y1, x2, y2 = coords:relativeRectToDrawList(rel_x, rel_y, w, h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg, opts.rounding or 3, opts.flags or 0)
    if border then
        reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border, opts.rounding or 3, opts.flags or 0)
    end
end

function Drawing.drawCenteredBandText(ctx, coords, draw_list, rel_x, rel_y, span_width, height, text, color, opts)
    opts = opts or {}
    local text_width = reaper.ImGui_CalcTextSize(ctx, text)
    local text_rel_x = rel_x + (span_width - text_width) / 2
    local text_rel_y = Drawing.centeredTextRelY(ctx, rel_y, height, opts.y_offset or 7)
    local tc = color
    if opts.dim then tc = COLOR_UTILS.dimmedText(color) end
    if opts.alpha_factor then tc = COLOR_UTILS.applyAlphaFactor(tc, opts.alpha_factor) end
    Drawing.drawTextRelative(coords, draw_list, text_rel_x, text_rel_y, tc, text)
end

-- Shared layout for custom display widgets (matches Renderers/Widgets display path)
function Drawing.drawWidgetCenteredValueText(ctx, text, rel_x, rel_y, span_width, height, coords, draw_list, text_color, vertical_offset)
    Drawing.drawCenteredBandText(ctx, coords, draw_list, rel_x, rel_y, span_width, height, text, text_color, { y_offset = vertical_offset })
end

function Drawing.widgetDisplayLabel(widget)
    return (widget.label and widget.label ~= "") and widget.label or widget.title
end

function Drawing.drawWidgetCenteredLabel(ctx, widget, rel_x, rel_y, span_width, coords, draw_list, label_rel_y)
    local label_text = Drawing.widgetDisplayLabel(widget)
    if not label_text or label_text == "" then
        return
    end
    label_rel_y = label_rel_y or (rel_y + 1)
    local label_color = COLOR_UTILS.groupLabelColor()
    local label_width = reaper.ImGui_CalcTextSize(ctx, label_text)
    local label_rel_x = rel_x + (span_width - label_width) / 2
    Drawing.drawTextRelative(coords, draw_list, label_rel_x, label_rel_y, label_color, label_text)
end

function Drawing.drawWidgetLeadingLabel(ctx, widget, rel_x, rel_y, coords, draw_list, lead_x)
    local label_text = Drawing.widgetDisplayLabel(widget)
    if not label_text or label_text == "" then
        return
    end
    lead_x = lead_x or 4
    local label_color = COLOR_UTILS.groupLabelColor()
    local label_rel_x = rel_x + lead_x
    local label_rel_y = rel_y + 1
    Drawing.drawTextRelative(coords, draw_list, label_rel_x, label_rel_y, label_color, label_text)
end



function Drawing.drawWidgetValueWithLabel(ctx, widget, rel_x, rel_y, span_width, height, coords, draw_list, text_color, value_text, opts)
    opts = opts or {}
    local vertical_offset = opts.vertical_offset or 7
    local label_rel_y = opts.label_rel_y or (rel_y + 1)
    local value_color = opts.value_color or text_color
    local display = value_text or ""
    if opts.truncate then
        local pad = opts.truncate_pad or 0
        local span = math.max(20, span_width - pad * 2)
        display = UTILS.trimTextToWidth(ctx, display, span, opts.ellipsis)
    end
    Drawing.drawWidgetCenteredLabel(ctx, widget, rel_x, rel_y, span_width, coords, draw_list, label_rel_y)
    Drawing.drawWidgetCenteredValueText(ctx, display, rel_x, rel_y, span_width, height, coords, draw_list, value_color, vertical_offset)
end

-- Shared text-chip metrics for compact widget/button action pills.
function Drawing.getTextChipMetrics(ctx, text, inset_h, inset_v)
    inset_h = inset_h or 4
    inset_v = inset_v or 3
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local text_w = reaper.ImGui_CalcTextSize(ctx, text or "")
    local chip_w = text_w + inset_h * 2
    local chip_h = line_h + inset_v * 2
    return text_w, line_h, chip_w, chip_h
end

-- Right-aligned chip rectangle inside a button/widget.
function Drawing.getRightAlignedTextChipRect(ctx, rel_x, rel_y, render_width, text, right_pad, inset_h, inset_v)
    right_pad = right_pad or 0
    local _, _, chip_w, chip_h = Drawing.getTextChipMetrics(ctx, text, inset_h, inset_v)
    local chip_x = rel_x + render_width - chip_w - right_pad
    local chip_y = rel_y + (CONFIG.SIZES.HEIGHT - chip_h) / 2
    return chip_x, chip_y, chip_w, chip_h
end

Drawing.CHIP_TEXT_Y_OFFSET = 1

function Drawing.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y, width, height, text, text_color, y_offset)
    y_offset = y_offset or Drawing.CHIP_TEXT_Y_OFFSET
    local tw = reaper.ImGui_CalcTextSize(ctx, text or "")
    local tx = rel_x + (width - tw) / 2
    local ty = Drawing.centeredTextRelY(ctx, rel_y, height, y_offset)
    Drawing.drawTextRelative(coords, draw_list, tx, ty, text_color, text or "")
end

function Drawing.drawCenteredIcon(ctx, coords, draw_list, rel_x, rel_y, width, height, font, icon_char, icon_sz, icon_color, y_offset)
    y_offset = y_offset or 0
    reaper.ImGui_PushFont(ctx, font, icon_sz)
    local tw = reaper.ImGui_CalcTextSize(ctx, icon_char)
    local tx = rel_x + (width - tw) / 2
    local ty = rel_y + height / 2 - icon_sz / 4 + y_offset
    Drawing.drawTextRelative(coords, draw_list, tx, ty, icon_color, icon_char)
    reaper.ImGui_PopFont(ctx)
end

-- Draw a rounded text chip at relative coordinates.
function Drawing.drawTextChip(ctx, coords, draw_list, rel_x, rel_y, width, height, text, style)
    style = style or {}
    Drawing.drawChipBackground(coords, draw_list, rel_x, rel_y, width, height, style.bg_color or 0x00000000, {
        rounding = style.rounding or 3,
        border_color = style.border_color
    })
    Drawing.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y, width, height, text, style.text_color or 0xFFFFFFFF)
end

-- Pill chip using toolbar widgetPillColors (chip = { x, y, w, h }).
function Drawing.drawWidgetPillChip(ctx, coords, draw_list, chip, text, btn_txt, btn_bg, opts)
    opts = opts or {}
    opts.filled = opts.filled ~= false
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, opts)
    local rounding = opts.rounding or 3
    Drawing.drawChipBackground(coords, draw_list, chip.x, chip.y, chip.w, chip.h, bg_col, { rounding = rounding })
    Drawing.drawCenteredText(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, text, text_col, opts.text_y_offset)
end

-- Pill chip with edge arrow + trimmed label (marker prev/next navigation).
function Drawing.drawWidgetPillArrowChip(ctx, coords, draw_list, chip, label, btn_txt, btn_bg, opts)
    opts = opts or {}
    local enabled = opts.enabled ~= false
    local hover = opts.hover == true
    local arrow_left = opts.arrow_left == true
    local rounding = opts.rounding or 3
    local edge_pad = opts.edge_pad or 6
    local arrow = arrow_left and "<" or ">"

    local bg_col, txt_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = false,
        filled = true,
        hover = hover and enabled,
        disabled = not enabled,
        alpha_factor = opts.alpha_factor
    })
    Drawing.drawChipBackground(coords, draw_list, chip.x, chip.y, chip.w, chip.h, bg_col, { rounding = rounding })

    local text_max = math.max(10, chip.w - edge_pad * 4)
    local show_label = label or ""
    if opts.trim ~= false then
        show_label = UTILS.trimTextToWidth(ctx, show_label, text_max, opts.ellipsis or "...")
    end

    local ty = Drawing.centeredTextRelY(ctx, chip.y, chip.h, opts.text_y_offset or Drawing.CHIP_TEXT_Y_OFFSET)
    local tw = reaper.ImGui_CalcTextSize(ctx, show_label)
    local tx
    if arrow_left then
        tx = chip.x + chip.w - tw - edge_pad
    else
        tx = chip.x + edge_pad
    end
    Drawing.drawTextRelative(coords, draw_list, tx, ty, txt_col, show_label)

    local aw = reaper.ImGui_CalcTextSize(ctx, arrow)
    local ax
    if arrow_left then
        ax = chip.x + edge_pad
    else
        ax = chip.x + chip.w - aw - edge_pad
    end
    Drawing.drawTextRelative(coords, draw_list, ax, ty, txt_col, arrow)
end

-- Rounded chip: solid fill + centered icon or fallback text.
function Drawing.drawIconOrTextChip(ctx, coords, draw_list, rel_x, rel_y, width, height, opts)
    opts = opts or {}
    local rounding = opts.rounding or 3
    if opts.bg_color then
        Drawing.drawChipBackground(coords, draw_list, rel_x, rel_y, width, height, opts.bg_color, { rounding = rounding })
    end
    local fg = opts.text_color or 0xFFFFFFFF
    local font = opts.icon_font
    local icon_char = opts.icon_char
    local icon_sz = opts.icon_sz
    if font and icon_char and icon_sz and ensureIconFontAttachedToContext(ctx, font) then
        Drawing.drawCenteredIcon(ctx, coords, draw_list, rel_x, rel_y, width, height, font, icon_char, icon_sz, fg, opts.icon_y_offset)
    else
        Drawing.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y, width, height, opts.fallback_text or "", fg, opts.text_y_offset)
    end
end

-- Pill chip with optional centered icon (else text).
function Drawing.drawWidgetPillIconChip(ctx, coords, draw_list, chip, btn_txt, btn_bg, opts)
    opts = opts or {}
    opts.filled = opts.filled ~= false
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, opts)
    local icon_font = opts.icon_font
    if opts.icon_mode then
        icon_font = opts.icon_mode.use_icons and opts.icon_mode.font or nil
    end
    Drawing.drawIconOrTextChip(ctx, coords, draw_list, chip.x, chip.y, chip.w, chip.h, {
        bg_color = bg_col,
        text_color = text_col,
        rounding = opts.rounding or 3,
        icon_font = icon_font,
        icon_char = opts.icon_char,
        icon_sz = opts.icon_sz,
        fallback_text = opts.fallback_text or opts.text or "",
    })
end

-- Pill chip with optional leading icon + label (e.g. lock settings).
function Drawing.drawWidgetPillChipLeadingIcon(ctx, coords, draw_list, chip, text, btn_txt, btn_bg, opts)
    opts = opts or {}
    opts.filled = opts.filled ~= false
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, opts)
    local rounding = opts.rounding or 3
    Drawing.drawChipBackground(coords, draw_list, chip.x, chip.y, chip.w, chip.h, bg_col, { rounding = rounding })

    local tw = reaper.ImGui_CalcTextSize(ctx, text or "")
    local icon_w = 0
    local icon_sz = opts.icon_sz or 0
    local icon_font = opts.icon_font
    local icon_char = opts.icon_char
    local icon_gap = opts.icon_gap or 4
    if icon_font and icon_char and icon_sz > 0 and ensureIconFontAttachedToContext(ctx, icon_font) then
        reaper.ImGui_PushFont(ctx, icon_font, icon_sz)
        icon_w = math.max(reaper.ImGui_CalcTextSize(ctx, icon_char), icon_sz * 0.65)
        reaper.ImGui_PopFont(ctx)
    end
    local content_w = tw + (icon_w > 0 and (icon_w + icon_gap) or 0)
    local start_x = chip.x + (chip.w - content_w) / 2
    if icon_w > 0 then
        local ix = start_x
        local iy = chip.y + chip.h / 2 - icon_sz / 4
        reaper.ImGui_PushFont(ctx, icon_font, icon_sz)
        Drawing.drawTextRelative(coords, draw_list, ix, iy, text_col, icon_char)
        reaper.ImGui_PopFont(ctx)
        start_x = start_x + icon_w + icon_gap
    end
    local ty = Drawing.centeredTextRelY(ctx, chip.y, chip.h, opts.text_y_offset or Drawing.CHIP_TEXT_Y_OFFSET)
    Drawing.drawTextRelative(coords, draw_list, start_x, ty, text_col, text or "")
end

return Drawing
