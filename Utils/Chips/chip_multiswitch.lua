-- Utils/chip_multiswitch.lua
-- Grouped track + sliding pill + labels (CodePen-style multiswitch) for widget chip rows.
--
-- Chip entry tables (e.g. MODES): use `label` for the full/human-readable text; optional `short_label`
-- for compact horizontal chips. If only `short_label` is set, call normalize_chip_entry(s) so `label`
-- is copied from `short_label`. Default chip text: short_label if set, else label, else id.

local SLIDE = require("Utils.Chips.chip_multiswitch_slide")
local PILL = require("Utils.Chips.chip_multiswitch_pill")

local M = {}

function M.track_fill_color(btn_bg)
    return COLOR_UTILS.multiswitchTrackFill(btn_bg)
end

--- Chip entry tables use `label` (full / human-readable) and optional `short_label` (compact chip text).
--- If only `short_label` is set, `label` is filled to match (call once after defining entries).
function M.normalize_chip_entry(e)
    if type(e) ~= "table" then
        return e
    end
    if type(e.short_label) == "string" and e.short_label ~= "" and (e.label == nil or e.label == "") then
        e.label = e.short_label
    end
    return e
end

function M.normalize_chip_entries(entries)
    if not entries then
        return entries
    end
    for _, e in ipairs(entries) do
        M.normalize_chip_entry(e)
    end
    return entries
end

--- Text drawn on a chip: prefer short_label, else label, else id.
function M.chip_caption(mode)
    if type(mode) ~= "table" then
        return ""
    end
    if type(mode.short_label) == "string" and mode.short_label ~= "" then
        return mode.short_label
    end
    if type(mode.label) == "string" and mode.label ~= "" then
        return mode.label
    end
    return tostring(mode.id or "")
end

--- Vertical toolbars: use full `label` when it fits; otherwise compact caption.
function M.label_for_orientation(ctx, mode, chip_w, is_vertical, pad)
    pad = pad or 4
    if is_vertical and type(mode) == "table" and type(mode.label) == "string" and mode.label ~= "" then
        local tw = reaper.ImGui_CalcTextSize(ctx, mode.label) or 0
        if tw <= chip_w - pad then
            return mode.label
        end
    end
    return M.chip_caption(mode)
end

function M.bounds(chips)
    if not chips or #chips == 0 then return 0, 0, 0, 0 end
    local x1, y1 = chips[1].x, chips[1].y
    local x2, y2 = x1 + chips[1].w, y1 + chips[1].h
    for i = 2, #chips do
        local c = chips[i]
        x1 = math.min(x1, c.x)
        y1 = math.min(y1, c.y)
        x2 = math.max(x2, c.x + c.w)
        y2 = math.max(y2, c.y + c.h)
    end
    return x1, y1, x2, y2
end

SLIDE.attach(M)
PILL.attach(M, SLIDE)

return M
