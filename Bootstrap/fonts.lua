-- Bootstrap/fonts.lua
-- Icon font lifecycle and shared ImGui font attachment

local ControllerHost = require("Bootstrap.controller_host")

local M = {}

function M.scanAndInstallGlobals()
    local ICON_FONTS_LIB = require("Utils.Core.icon_fonts")
    _G.ICON_FONTS = ICON_FONTS_LIB.scanIconFonts(SCRIPT_PATH, UTILS)
    _G.ICON_FONTS.path_index = ICON_FONTS_LIB.path_index
    return ICON_FONTS_LIB
end

function M.installGlobalHelpers()
    local icon_font_attach_cache = ControllerHost.getIconFontAttachCache()

    function _G.resolveIconFontEntryFont(entry)
        if not entry or not entry.path then
            return nil
        end
        if entry.font then
            if ControllerHost.imguiPtrOk(entry.font, "ImGui_Font*") then
                return entry.font
            end
            entry.font = nil
        end
        local root = tostring(SCRIPT_PATH or ""):gsub("[\\/]*$", "")
        local rel = UTILS.normalizeSlashes(tostring(entry.path or "")):gsub("^/*", "")
        local full_path = root .. "/" .. rel
        if not reaper.file_exists(full_path) then
            return nil
        end
        local f = reaper.ImGui_CreateFontFromFile(full_path)
        if not f then
            return nil
        end
        entry.font = f
        return entry.font
    end

    function _G.invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
        for i = 1, #ICON_FONTS do
            ICON_FONTS[i].font = nil
        end
        for k in pairs(icon_font_attach_cache) do
            icon_font_attach_cache[k] = nil
        end
        _G._adv_tb_icon_font_rev = (_G._adv_tb_icon_font_rev or 0) + 1
    end

    function _G.ensureIconFontAttachedToContext(ctx, font)
        if not ctx or not font then
            return false
        end
        if not ControllerHost.imguiPtrOk(ctx, "ImGui_Context*") then
            return false
        end
        if not ControllerHost.imguiPtrOk(font, "ImGui_Font*") then
            invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
            return false
        end
        local sub = icon_font_attach_cache[ctx]
        if not sub then
            sub = {}
            icon_font_attach_cache[ctx] = sub
        end
        if sub[font] then
            if not ControllerHost.imguiPtrOk(font, "ImGui_Font*") then
                sub[font] = nil
                invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
                return false
            end
            return true
        end
        local ok = pcall(function()
            reaper.ImGui_Attach(ctx, font)
        end)
        if ok then
            sub[font] = true
        else
            invalidateSharedIconFontHandlesAfterImGuiContextDestroyed()
        end
        return ok
    end
end

return M
