-- Utils/widget_spinner_slide_out/preview.lua

local ROW = require("Utils.Chips.chip_row")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local PREVIEW_FB = require("Utils.Widget.widget_preview_fallback")

return function(widget, spec, env)
    local PREVIEW_IDS = env.PREVIEW_IDS
    local PREVIEW_NAMESPACE = env.PREVIEW_NAMESPACE
    local PREVIEW_SELECTED_ID = env.PREVIEW_SELECTED_ID
    local PREVIEW_TITLE = env.PREVIEW_TITLE
    local mode_by_id = env.mode_by_id
    local multiswitch_layout_opts = env.multiswitch_layout_opts

    local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        local h = CONFIG.SIZES.HEIGHT
        local subset = {}
        for _, pid in ipairs(PREVIEW_IDS) do
            local e = mode_by_id(pid)
            if e then
                subset[#subset + 1] = e
            end
        end
        local mx, my = coords:getRelativeMouse()
        if PREVIEW_FB.when(ctx, #subset < #PREVIEW_IDS, PREVIEW_TITLE, rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
            return
        end
        local chips = ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, subset, multiswitch_layout_opts())
        if chips and #chips > 0 then
            CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
                mx = mx,
                my = my,
                enabled = true,
                mixed = false,
                chip_round = ROW.CHIP_ROUND,
                slide_namespace = PREVIEW_NAMESPACE,
                grid_layout = true,
                is_selected_segment = function(c)
                    return not c.blank and c.mode and c.mode.id == PREVIEW_SELECTED_ID
                end,
            })
        else
            PREVIEW_FB.draw_centered_title(ctx, PREVIEW_TITLE, rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        end
    end

    env.render_preview = render_preview
end
