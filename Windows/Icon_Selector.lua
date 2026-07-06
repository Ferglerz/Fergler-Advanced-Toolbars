-- Windows/Icon_Selector.lua
local PopupContext = require("Systems.Popup_Context")
local IconSelectorHeader = require("Windows.icon_selector_header")
local IconSelectorGrids = require("Windows.icon_selector_grids")
local REAPER_ICONS = require("Utils.Core.reaper_toolbar_icons")
local REAPER_TRACK_ICONS = require("Utils.Core.reaper_track_icons")

local IconSelector = {}
IconSelector.__index = IconSelector

function IconSelector.new()
    local self = setmetatable({}, IconSelector)

    self.is_open = false
    self.current_button = nil
    self.owner_ctx = nil
    self.font_maps = {}
    self.close_requested = false
    self.icon_filter = ""
    self.reaper_icon_filter = ""
    self.track_icon_filter = ""
    self.icon_category_index = 1
    self.icon_picker_tab = "reaper"
    self.reaper_icons = {}
    self.track_icons = {}

    self:scanIconFonts()

    return self
end

function IconSelector:scanIconFonts()
    self.font_maps = ICON_FONTS
end

function IconSelector:scanReaperIcons()
    self.reaper_icons = REAPER_ICONS.scan()
end

function IconSelector:scanTrackIcons()
    self.track_icons = REAPER_TRACK_ICONS.scan()
end

local function clearButtonIcons(button)
    button.icon_path = nil
    button.reaper_icon_path = nil
    button.reaper_track_icon_path = nil
    button.icon_char = nil
    button.icon_font = nil
end

local function refreshButtonIconLayout(button)
    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
    if C.ButtonManager and C.ButtonManager.clearIconCache then
        C.ButtonManager:clearIconCache()
    end
end

function IconSelector:show(button, owner_ctx)
    self.current_button = button
    PopupContext.openOrFallback(self, owner_ctx)
    self.previous_icon = {
        icon_char = button.icon_char,
        icon_path = button.icon_path,
        reaper_icon_path = button.reaper_icon_path,
        reaper_track_icon_path = button.reaper_track_icon_path,
        icon_font = button.icon_font
    }

    self.previous_display_text = button.display_text
    self.previous_hide_label = button.hide_label
    local disp = (button.display_text or ""):gsub("\\n", "\n")
    local nl = disp:find("\n", 1, true)
    if nl then
        self.name_top_buf = disp:sub(1, nl - 1)
        self.name_bottom_buf = disp:sub(nl + 1)
    else
        self.name_top_buf = disp
        self.name_bottom_buf = ""
    end

    self.icon_filter = ""
    self.reaper_icon_filter = ""
    self.track_icon_filter = ""
    self.close_requested = false
    self:scanReaperIcons()
    self:scanTrackIcons()

    if button.reaper_track_icon_path then
        self.icon_picker_tab = "track"
    elseif button.reaper_icon_path then
        self.icon_picker_tab = "reaper"
    elseif button.icon_font or button.icon_char then
        self.icon_picker_tab = "fonts"
    else
        self.icon_picker_tab = "reaper"
    end

    local cats = IconSelectorGrids.sortedCategories(self.font_maps)
    self.icon_category_index = 1
    if button.icon_font then
        local norm = UTILS.normalizeSlashes(button.icon_font)
        local cat_from_path = norm:match("IconFonts/icons/([^/]+)/")
        if cat_from_path then
            for i, c in ipairs(cats) do
                if c == cat_from_path then
                    self.icon_category_index = i
                    break
                end
            end
        end
    end
end

local function trim_input(s)
    if not s or s == "" then
        return ""
    end
    return (s:match("^%s*(.-)%s*$")) or ""
end

local function applyDisplayTextFromBuffers(selector)
    local button = selector.current_button
    if not button then
        return
    end
    local new_top = trim_input(selector.name_top_buf or "")
    local new_bot = trim_input(selector.name_bottom_buf or "")

    if new_top == "" and new_bot == "" then
        button.display_text = button.original_text or button.id or ""
        button.hide_label = true
    else
        if new_bot == "" then
            button.display_text = new_top
        elseif new_top == "" then
            button.display_text = "\n" .. new_bot
        else
            button.display_text = new_top .. "\n" .. new_bot
        end
    end
    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
end

function IconSelector:revertButtonState()
    local button = self.current_button
    if not button then
        return
    end
    if self.previous_icon then
        button.icon_char = self.previous_icon.icon_char
        button.icon_path = self.previous_icon.icon_path
        button.reaper_icon_path = self.previous_icon.reaper_icon_path
        button.reaper_track_icon_path = self.previous_icon.reaper_track_icon_path
        button.icon_font = self.previous_icon.icon_font
    end
    if self.previous_display_text ~= nil then
        button.display_text = self.previous_display_text
    end
    if self.previous_hide_label ~= nil then
        button.hide_label = self.previous_hide_label
    end
end

function IconSelector:renderGrid(ctx)
    if not PopupContext.guardRender(self, ctx) or not self.current_button then
        return false
    end

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    local fixed_w = 720
    reaper.ImGui_SetNextWindowPos(ctx, 100, 100, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSize(ctx, fixed_w, 620, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, fixed_w, 400, fixed_w, 4000)

    local render_result = false
    PopupContext.withGlobalStyle(ctx, function()
        local visible, should_continue = reaper.ImGui_Begin(ctx, "Name and Icon", true, window_flags)
        UTILS.snapWindowToMinimum(ctx, 0, 0, true)

        if not should_continue or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            self:revertButtonState()

            self.close_requested = true
            if C.PopupContext then
                C.PopupContext.close(self)
            else
                self.is_open = false
            end

            reaper.ImGui_End(ctx)

            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
                UTILS.focusArrangeWindow(true)
            end
            render_result = false
            return
        end

        if visible then
            local button = self.current_button
            local shared_opts = {
                fixed_w = fixed_w,
                applyDisplayText = applyDisplayTextFromBuffers,
                clearButtonIcons = clearButtonIcons,
                refreshButtonIconLayout = refreshButtonIconLayout,
            }

            local content_w = IconSelectorHeader.render(ctx, self, shared_opts)

            local _, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
            avail_h = tonumber(avail_h) or 400
            local footer_h = 44
            local grid_view_h = math.max(240, avail_h - footer_h)
            local child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0

            local grid_opts = {
                selector = self,
                button = button,
                content_w = content_w,
                grid_view_h = grid_view_h,
                child_flags = child_flags,
                applyDisplayText = applyDisplayTextFromBuffers,
                clearButtonIcons = clearButtonIcons,
                refreshButtonIconLayout = refreshButtonIconLayout,
            }

            IconSelectorGrids.renderIconPickerTabs(ctx, self, grid_opts)

            reaper.ImGui_Spacing(ctx)
            local sp_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
            local btn_width = (reaper.ImGui_GetWindowWidth(ctx) - 20 - sp_x) / 2
            if reaper.ImGui_Button(ctx, "OK", btn_width, 0) then
                applyDisplayTextFromBuffers(self)
                self.current_button:saveChanges()
                if C.PopupContext then
                    C.PopupContext.close(self)
                else
                    self.is_open = false
                end
            end
            reaper.ImGui_SameLine(ctx, 0, sp_x)
            if reaper.ImGui_Button(ctx, "Cancel", btn_width, 0) then
                self:revertButtonState()
                PopupContext.closeOrFallback(self)
            end
        end

        reaper.ImGui_End(ctx)
        render_result = self.is_open
    end)

    return render_result
end

function IconSelector:cleanup()
    PopupContext.closeOrFallback(self)
    self.current_button = nil
    self.close_requested = false
end

return IconSelector
