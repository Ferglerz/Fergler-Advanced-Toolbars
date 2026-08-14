-- Bootstrap/imgui_hooks.lua
-- ImGui tooltip hooks for consistent rounding and multiline wrapping

local M = {}

function M.install()
    local orig_BeginTooltip = reaper.ImGui_BeginTooltip
    local orig_EndTooltip = reaper.ImGui_EndTooltip
    local tooltip_style_pushed = {}

    function reaper.ImGui_BeginTooltip(ctx)
        local rounding = 3.0
        local pad_x, pad_y = 8, 8
        if _G.C and _G.C.GlobalStyle and _G.C.GlobalStyle.styles then
            local styles = _G.C.GlobalStyle.styles
            if styles.popupRounding then
                rounding = styles.popupRounding
            end
            if styles.windowPaddingX then
                pad_x = styles.windowPaddingX
            end
            if styles.windowPaddingY then
                pad_y = styles.windowPaddingY
            end
        end
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), rounding)
        if reaper.ImGui_StyleVar_WindowPadding then
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), pad_x, pad_y)
        end

        local ret = orig_BeginTooltip(ctx)

        local font_size = 14
        if reaper.ImGui_GetFontSize then
            font_size = reaper.ImGui_GetFontSize(ctx)
        end
        reaper.ImGui_PushTextWrapPos(ctx, font_size * 25.0)

        tooltip_style_pushed[ctx] = (tooltip_style_pushed[ctx] or 0) + 1

        return ret
    end

    function reaper.ImGui_EndTooltip(ctx)
        if tooltip_style_pushed[ctx] and tooltip_style_pushed[ctx] > 0 then
            reaper.ImGui_PopTextWrapPos(ctx)
            orig_EndTooltip(ctx)

            local style_var_count = reaper.ImGui_StyleVar_WindowPadding and 2 or 1
            reaper.ImGui_PopStyleVar(ctx, style_var_count)

            tooltip_style_pushed[ctx] = tooltip_style_pushed[ctx] - 1
            if tooltip_style_pushed[ctx] <= 0 then
                tooltip_style_pushed[ctx] = nil
            end
        else
            orig_EndTooltip(ctx)
        end
    end

    function reaper.ImGui_SetTooltip(ctx, text)
        if reaper.ImGui_BeginTooltip(ctx) then
            reaper.ImGui_Text(ctx, tostring(text or ""))
            reaper.ImGui_EndTooltip(ctx)
        end
    end
end

return M
