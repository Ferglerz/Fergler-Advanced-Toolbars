local IMPORT = require("Managers.ToolbarImport")
local ToolbarImport = {}
ToolbarImport.__index = ToolbarImport

function ToolbarImport.new()
    return setmetatable({ is_open = false }, ToolbarImport)
end

function ToolbarImport:refresh()
    self.templates, self.error = IMPORT.read()
end

function ToolbarImport:show(controller)
    self.controller = controller
    self.owner_ctx = controller.ctx
    self.is_open = true
    self:refresh()
end

function ToolbarImport:render(ctx)
    if not self.is_open or ctx ~= self.owner_ctx then
        return false
    end
    if not self.controller or not self.controller.is_open then
        self.is_open = false
        return false
    end

    C.GlobalStyle.withGlobalStyle(ctx, function()
        reaper.ImGui_SetNextWindowSize(ctx, 420, 360, reaper.ImGui_Cond_FirstUseEver())
        local visible, open = reaper.ImGui_Begin(ctx, "Import REAPER Toolbar", self.is_open)
        self.is_open = open
        if visible then
            reaper.ImGui_TextWrapped(ctx, "Choose a toolbar to copy into a new Advanced Toolbar. The copy can be edited independently; later changes in REAPER will not sync.")
            if reaper.ImGui_Button(ctx, "Refresh") then
                self:refresh()
            end
            reaper.ImGui_Separator(ctx)
            if self.error then
                reaper.ImGui_TextWrapped(ctx, self.error)
            elseif #self.templates == 0 then
                reaper.ImGui_TextWrapped(ctx, "No customized REAPER toolbars found. Save a customized toolbar in REAPER, then refresh.")
            end
            for i, template in ipairs(self.templates) do
                local name = template.title and template.title ~= "" and template.title or template.section
                if reaper.ImGui_Selectable(ctx, name .. "##import_toolbar_" .. i) then
                    if self.controller:importToolbar(template) then
                        self.is_open = false
                    end
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, template.section .. " — " .. #template.items .. " items")
                end
            end
            reaper.ImGui_End(ctx)
        end
    end)
    return self.is_open
end

return ToolbarImport
