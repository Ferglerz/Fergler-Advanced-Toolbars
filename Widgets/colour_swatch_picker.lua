-- Widgets/colour_swatch_picker.lua
-- Add-colour popup (ImGui color picker).

local STATE = require("Widgets.colour_swatch_state")

local M = {}

function M.draw(self, ctx)
    local key = STATE.state_key(self)

    local picker_id = "##colour_swatch_picker_" .. key
    if self._open_picker then
        reaper.ImGui_OpenPopup(ctx, picker_id)
        self._open_picker = false
    end

    C.GlobalStyle.withGlobalStyle(ctx, function()
        if reaper.ImGui_BeginPopup(ctx, picker_id) then
            local flags =
                reaper.ImGui_ColorEditFlags_NoAlpha() |
                reaper.ImGui_ColorEditFlags_NoInputs() |
                reaper.ImGui_ColorEditFlags_PickerHueBar() |
                reaper.ImGui_ColorEditFlags_DisplayRGB() |
                reaper.ImGui_ColorEditFlags_DisplayHex()

            local chg, new_c = reaper.ImGui_ColorPicker4(ctx, "##cp", self._picker_color_imgui, flags)
            if chg then
                self._picker_color_imgui = new_c
            end

            if reaper.ImGui_Button(ctx, "Add to palette") then
                local hex = COLOR_UTILS.toHex(new_c)
                local src_id = self._pending_add_category_id
                local src = STATE.find_category(self, src_id)

                if src and not src.stock then
                    for _, uc in ipairs(self._state.user_categories) do
                        if uc.id == src.id then
                            table.insert(uc.colors, hex)
                            break
                        end
                    end
                    STATE.save_config()
                else
                    local new_colors = src and STATE.deep_copy_colors(src.colors) or {}
                    table.insert(new_colors, hex)

                    local ok, name = reaper.GetUserInputs("New palette name", 1, "Name", "My colours")
                    if ok and name and name ~= "" then
                        table.insert(
                            self._state.user_categories,
                            {
                                id = STATE.next_user_cat_id(self),
                                name = name,
                                colors = new_colors
                            }
                        )
                        self._state.active_category_id = self._state.user_categories[#self._state.user_categories].id
                        STATE.save_config()
                    end
                end
                self._pending_add_category_id = nil
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then
                self._pending_add_category_id = nil
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_EndPopup(ctx)
        end
    end)
end

return M
