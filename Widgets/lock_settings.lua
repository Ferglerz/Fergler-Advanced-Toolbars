local WIDGET = require("Utils.Widget.widget_factory")
local OPT = WIDGET.OPTIONS_SLIDE_OUT

local CHIP_ROUND = WIDGET.CHIP_ROW.CHIP_ROUND
local ICON_NAME_GAP = 4
local DEFAULT_CHIP_LABEL = "Lock"
local LABEL_INPUT_HINT = "Chip name"

local LOCK_ICON_REL_OPEN = "icons/Tools/Lock Open.ttf"
local LOCK_ICON_REL_CLOSED = "icons/Tools/Lock Closed.ttf"
local LOCK_GLYPH = utf8.char(WIDGET.ICON_FONTS.ICON_CODEPOINT)

local CMD_MASTER = 1135

local TIME_LOOP = {
    { id = "time", short_label = "Time", label = "Time selection", cmd = 40573 },
    { id = "loop", short_label = "Loop", label = "Loop points", cmd = 40629 },
}

local ITEMS = {
    { id = "item_full", short_label = "Full", label = "Items (full)", cmd = 40576 },
    { id = "item_edge", short_label = "Edge", label = "Item edges", cmd = 40597 },
    { id = "item_lr", short_label = "L/R", label = "Items (prevent left/right movement)", cmd = 40579 },
    { id = "item_ud", short_label = "U/D", label = "Items (prevent up/down movement)", cmd = 40582 },
    { id = "item_fade", short_label = "Fade", label = "Item fade/volume handles", cmd = 40600 },
    { id = "item_stretch", short_label = "Str", label = "Item stretch markers", cmd = 41854 },
}

local ENVS = {
    { id = "take_env", short_label = "Take", label = "Take envelopes", cmd = 41851 },
    { id = "track_env", short_label = "Trk", label = "Track envelopes", cmd = 40585 },
}

local MARKS = {
    { id = "region", short_label = "Rgn", label = "Regions", cmd = 40588 },
    { id = "marker", short_label = "Mrk", label = "Markers", cmd = 40591 },
    { id = "tsig", short_label = "Tsig", label = "Time signature markers", cmd = 40594 },
}

local ALL_ORDER = {}
for _, t in ipairs({ TIME_LOOP, ITEMS, ENVS, MARKS }) do
    for _, e in ipairs(t) do
        ALL_ORDER[#ALL_ORDER + 1] = e
    end
end

local function lock_icon_bundle()
    local open = WIDGET.ICON_FONTS.resolveToolbarIcon(LOCK_ICON_REL_OPEN)
    local closed = WIDGET.ICON_FONTS.resolveToolbarIcon(LOCK_ICON_REL_CLOSED)
    if open.use_icons and closed.use_icons then
        return { use_icons = true, font_open = open.font, font_closed = closed.font }
    end
    return { use_icons = false }
end

local function lock_icon_glyph_column_width_approx(ctx)
    if not ctx then return 0 end
    local icon_sz = WIDGET.CHIP_ROW.magnet_icon_size(ctx)
    return math.max(icon_sz * 0.65, icon_sz)
end

local function toggle_on(cmd)
    return OPT.toggle_command_state(cmd)
end

local function lock_click(entries, chip_id)
    OPT.click_entry_by_id(entries, chip_id)
end

local function lock_on(self, chip_id)
    return self._on[chip_id] == true
end

return WIDGET.Segmented(OPT.with_slide_out({
    name = "Lock Settings",
    category = "Project & surfaces",
    update_interval = 0,
    width = 96,
    description = "One chip toggles project locking (Main:1135). Hover for lock-mode toggles. Right-click: icon and chip label.",
    state = {
        _chip_label = nil,
        _show_lock_icon = true,
        _chip_label_edit = "",
        _on = {},
    },

    init = function(self)
        self.chip_display_text = function(self)
            local s = self._chip_label
            if type(s) == "string" then
                s = (s:gsub("^%s+", ""):gsub("%s+$", ""))
                if s ~= "" then
                    return s
                end
            end
            return DEFAULT_CHIP_LABEL
        end

        self.applyPersistedOptions = function(self, opts)
            if type(opts) ~= "table" then return end
            if type(opts.chip_label) == "string" then
                self._chip_label = opts.chip_label
            end
            if opts.show_lock_icon == true then
                self._show_lock_icon = true
            elseif opts.show_lock_icon == false then
                self._show_lock_icon = false
            end
        end

        self.exportPersistedOptions = function(self)
            return {
                chip_label = type(self._chip_label) == "string" and self._chip_label or "",
                show_lock_icon = self._show_lock_icon == true,
            }
        end
    end,

    on_update = function(self)
        if self._preview_mode then
            self._master_on = true
            self._on = {
                time = false, loop = false, item_full = false, item_lr = true, item_ud = false,
                item_edge = false, item_fade = false, item_stretch = false, take_env = false,
                track_env = false, region = true, marker = true, tsig = false,
            }
            return
        end
        self._master_on = toggle_on(CMD_MASTER)
        for _, e in ipairs(ALL_ORDER) do
            self._on[e.id] = toggle_on(e.cmd)
        end
    end,

    rows = {
        OPT.host_labeled_toggle(DEFAULT_CHIP_LABEL, function(self) return self._master_on end, function()
            reaper.Main_OnCommand(CMD_MASTER, 0)
        end, {
            get_label = function(self)
                return (self._preview_mode and "Time Lock") or self:chip_display_text()
            end,
            get_width = function(self, ctx)
                local txt = (self._preview_mode and "Time Lock") or self:chip_display_text()
                local tw = reaper.ImGui_CalcTextSize(ctx, txt)
                local bundle = lock_icon_bundle()
                local show_glyph = (self._show_lock_icon or self._preview_mode) and bundle.use_icons
                local extra = 0
                if show_glyph then
                    extra = lock_icon_glyph_column_width_approx(ctx) + ICON_NAME_GAP
                end
                return math.max(36, tw + extra + OPT.TOGGLE_PAD_H * 2)
            end,
            render_custom_chip = function(self, ctx, coords, draw_list, rect, label, hover, btn_txt, btn_bg)
                local bundle = lock_icon_bundle()
                local show_glyph = (self._show_lock_icon or self._preview_mode) and bundle.use_icons
                OPT.draw_icon_leading_toggle(ctx, coords, draw_list, rect, label, hover, btn_txt, btn_bg, {
                    active = self._master_on,
                    icon_bundle = bundle,
                    icon_char = LOCK_GLYPH,
                    show_icon = show_glyph,
                    icon_font = show_glyph and (self._master_on and bundle.font_closed or bundle.font_open) or nil,
                    icon_gap = ICON_NAME_GAP,
                    rounding = CHIP_ROUND,
                    alpha_factor = self._slide_alpha_factor,
                })
            end,
        }),
        OPT.slide_multi_toggle(TIME_LOOP, lock_on, function(self, chip_id)
            lock_click(TIME_LOOP, chip_id)
        end, { min_chip_w = 36 }),
        OPT.slide_multi_toggle(ITEMS, lock_on, function(self, chip_id)
            lock_click(ITEMS, chip_id)
        end, { min_chip_w = 32, rows = 2 }),
        OPT.slide_multi_toggle(ENVS, lock_on, function(self, chip_id)
            lock_click(ENVS, chip_id)
        end, { min_chip_w = 36 }),
        OPT.slide_multi_toggle(MARKS, lock_on, function(self, chip_id)
            lock_click(MARKS, chip_id)
        end, { min_chip_w = 32 }),
    },

    settings_menu = function(self, ctx, button)
        OPT.chip_label_settings(self, ctx, button, {
            default_label = DEFAULT_CHIP_LABEL,
            hint = LABEL_INPUT_HINT,
            show_icon_field = "_show_lock_icon",
            icon_bundle_fn = lock_icon_bundle,
            show_icon_label = "Show lock icon",
        })
    end,
}))
