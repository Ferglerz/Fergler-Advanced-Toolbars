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

local function lighten_rgba_trail(c, delta)
    if not c then
        return c
    end
    local a = c & 0xFF
    local r = (c >> 24) & 0xFF
    local g = (c >> 16) & 0xFF
    local b = (c >> 8) & 0xFF
    r = math.min(255, r + delta)
    g = math.min(255, g + delta)
    b = math.min(255, b + delta)
    return (r << 24) | (g << 16) | (b << 8) | a
end

local _plus_font_resolved
local _font_cache_rev

local function icon_mode()
    local rev = _G._adv_tb_icon_font_rev or 0
    if _font_cache_rev ~= rev then
        _font_cache_rev = rev
        _plus_font_resolved = nil
    end
    if _plus_font_resolved ~= nil then return _plus_font_resolved end

    local resolved = { use_icons = false }
    if not SCRIPT_PATH or SCRIPT_PATH == "" or not C or not C.ButtonContent then
        _plus_font_resolved = resolved
        return resolved
    end

    local p = UTILS.joinPath(SCRIPT_PATH, "IconFonts", "icons", "Math and Code", "Plus.ttf")
    if not reaper.file_exists(p) then
        _plus_font_resolved = resolved
        return resolved
    end

    local f = C.ButtonContent:loadIconFont(UTILS.normalizeSlashes("IconFonts/icons/Math and Code/Plus.ttf"))
    if not f then
        _plus_font_resolved = resolved
        return resolved
    end

    resolved = { use_icons = true, font = f }
    _plus_font_resolved = resolved
    return resolved
end

-- Edit-mode trailing "add": thin circle + plus (outline style), brighter when hovered/active.
-- Integer pixel center, integer radius, even-length arms so strokes are not biased (matches insertionGlyph idea).
function Drawing.toolbarEndAddGlyph(ctx, draw_list, cx, cy, outer_r, base_color, hovered_or_active)
    local icx = math.floor(cx + 0.5)
    local icy = math.floor(cy + 0.5)
    local ir = math.max(2, math.floor(outer_r + 0.5))
    local c = hovered_or_active and lighten_rgba_trail(base_color, 40) or base_color
    c = (c & 0xFFFFFF00) | 0xFF
    local line_t = 1.0

    local mode = icon_mode()
    if mode.use_icons and ensureIconFontAttachedToContext(ctx, mode.font) then
        local icon_sz = 18
        local ICON_FONTS_LIB = require("Utils.icon_fonts")
        reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
        local tw = reaper.ImGui_CalcTextSize(ctx, utf8.char(ICON_FONTS_LIB.ICON_CODEPOINT))
        local tx = icx - tw / 2
        local ty = icy - reaper.ImGui_GetTextLineHeight(ctx) / 2
        reaper.ImGui_DrawList_AddText(draw_list, tx, ty, c, utf8.char(ICON_FONTS_LIB.ICON_CODEPOINT))
        reaper.ImGui_PopFont(ctx)
        return
    end

    reaper.ImGui_DrawList_AddCircle(draw_list, icx, icy, ir, c, 0, line_t)

    local s = math.floor(CONFIG.SIZES.HEIGHT / 4 + 0.5)
    if s < 4 then
        s = 4
    end
    if s % 2 == 1 then
        s = s + 1
    end
    local half = s / 2
    half = math.min(half, ir - 1)
    if half < 2 then
        half = 2
    end
    reaper.ImGui_DrawList_AddLine(draw_list, icx - half, icy, icx + half, icy, c, line_t)
    reaper.ImGui_DrawList_AddLine(draw_list, icx, icy - half, icx, icy + half, c, line_t)
end

-- Edit-mode insertion chip: outer disk = toolbar text color, inner white, line-drawn + / ×.
function Drawing.insertionGlyph(ctx, draw_list, cx, cy, outer_r, outer_color, symbol)
    -- Integer pixel center so circles and thick strokes align (avoids lopsided +).
    cx = math.floor(cx + 0.5)
    cy = math.floor(cy + 0.5)

    local oc = (outer_color & 0xFFFFFF00) | 0xFF
    local black = COLOR_UTILS.toImGuiColor("#000000FF")

    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, outer_r, oc, 24)

    -- Even arm length so horizontal/vertical bars are symmetric about cx, cy
    local s = math.floor(CONFIG.SIZES.HEIGHT / 4 + 0.5)
    if s < 4 then
        s = 4
    end
    if s % 2 == 1 then
        s = s + 1
    end
    local t = 2.0
    local min_inner = s / 2 + 2
    local inner_r = math.min(outer_r - 1.5, math.max(outer_r * 0.58, min_inner))
    if inner_r < 2 then
        inner_r = 2
    end
    if inner_r >= outer_r then
        inner_r = outer_r - 1.5
    end
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, inner_r, COLOR_UTILS.toImGuiColor("#FFFFFFFF"), 24)

    if symbol == "plus" then
        reaper.ImGui_DrawList_AddLine(draw_list, cx - s / 2, cy, cx + s / 2, cy, black, t)
        reaper.ImGui_DrawList_AddLine(draw_list, cx, cy - s / 2, cx, cy + s / 2, black, t)
    else
        reaper.ImGui_DrawList_AddLine(draw_list, cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2, black, t)
        reaper.ImGui_DrawList_AddLine(draw_list, cx + s / 2, cy - s / 2, cx - s / 2, cy + s / 2, black, t)
    end
end

-- Shared layout for custom display widgets (matches Renderers/_Widgets display path)
function Drawing.drawWidgetCenteredValueText(ctx, text, rel_x, rel_y, span_width, height, coords, draw_list, text_color, vertical_offset)
    vertical_offset = vertical_offset or 7
    local text_width = reaper.ImGui_CalcTextSize(ctx, text)
    local text_rel_x = rel_x + (span_width - text_width) / 2
    local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2 + vertical_offset
    local tx, ty = coords:relativeToDrawList(text_rel_x, text_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_color, text)
end

function Drawing.drawWidgetCenteredLabel(ctx, widget, rel_x, rel_y, span_width, coords, draw_list, label_rel_y)
    if not widget.label or widget.label == "" then
        return
    end
    label_rel_y = label_rel_y or (rel_y + 1)
    local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
    local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
    local label_rel_x = rel_x + (span_width - label_width) / 2
    local lx, ly = coords:relativeToDrawList(label_rel_x, label_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, lx, ly, label_color, widget.label)
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
    local ty = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2 + y_offset
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_color, text or "")
end

function Drawing.drawCenteredIcon(ctx, coords, draw_list, rel_x, rel_y, width, height, font, icon_char, icon_sz, icon_color, y_offset)
    y_offset = y_offset or 0
    reaper.ImGui_PushFont(ctx, font, icon_sz)
    local tw = reaper.ImGui_CalcTextSize(ctx, icon_char)
    local tx = rel_x + (width - tw) / 2
    local ty = rel_y + height / 2 - icon_sz / 4 + y_offset
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, icon_color, icon_char)
    reaper.ImGui_PopFont(ctx)
end

-- Draw a rounded text chip at relative coordinates.
function Drawing.drawTextChip(ctx, coords, draw_list, rel_x, rel_y, width, height, text, style)
    style = style or {}
    local rounding = style.rounding or 3
    local text_color = style.text_color or 0xFFFFFFFF
    local bg_color = style.bg_color or 0x00000000
    local border_color = style.border_color

    local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
    local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + height)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, rounding)
    if border_color then
        reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, rounding)
    end

    Drawing.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y, width, height, text, text_color)
end

return Drawing
