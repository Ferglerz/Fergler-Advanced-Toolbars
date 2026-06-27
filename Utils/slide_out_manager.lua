-- Utils/slide_out_manager.lua
local SlideOutManager = {}

local COORDINATES = require("Utils.coordinates")
local DRAWING = require("Utils.drawing")
local COLOR_UTILS = require("Utils.color_utils")
local UTILS = require("Utils.utils")
local DRAWING = require("Utils.drawing")

local function ease_in_out(t)
    return t * t * (3 - 2 * t)
end

-- Matches Grid_Ruler_Chip: slide uses full t; fade ramps in the second half of expand
-- and out in the first half of collapse.
local function fade_alpha_for_t(t)
    return math.max(0.0, (t - 0.5) / 0.5)
end

-- Toolbar buttons/widgets are shared across controller windows and extra rows; isolate slide-out per placement.
local slide_states = {}
local active_slide_key = nil

local function close_slide_state(st)
    if not st then
        return
    end
    st.t = 0.0
    st.hovered = false
    st.hover_inside = false
    st.last_hover_time = 0.0
end

local function close_other_slides(except_key)
    for key, st in pairs(slide_states) do
        if key ~= except_key and st.t > 0.0 then
            close_slide_state(st)
        end
    end
end

local function slide_state_key(host_button)
    if not host_button then
        return nil
    end
    local cid = host_button.atb_controller_id
    local bid = host_button.instance_id
    if not cid or not bid then
        return nil
    end
    local rid = host_button.atb_row_index or 0
    return tostring(cid) .. ":" .. tostring(rid) .. ":" .. tostring(bid)
end

local function get_slide_state(host_button)
    local key = slide_state_key(host_button)
    if not key then
        return nil, nil
    end
    if not slide_states[key] then
        slide_states[key] = {
            t = 0.0,
            hovered = false,
            last_hover_time = 0.0,
            last_frame_time = 0.0,
            hover_inside = false,
            host_w = nil,
            host_h = nil,
            panel_w = nil,
            panel_h = nil,
        }
    end
    return slide_states[key], key
end

local function mirror_state_to_widget(widget, st)
    if not widget or not st then
        return
    end
    widget._slide_t = st.t
    widget._slide_hovered = st.hovered
    widget._slide_last_hover_time = st.last_hover_time
    widget._slide_last_frame_time = st.last_frame_time
    widget._slide_hover_inside = st.hover_inside
    widget._slide_host_w = st.host_w
    widget._slide_host_h = st.host_h
    widget._slide_panel_w = st.panel_w
    widget._slide_panel_h = st.panel_h
end

local function sync_widget_dims_to_state(widget, st)
    if not widget or not st then
        return
    end
    st.host_w = widget._slide_host_w
    st.host_h = widget._slide_host_h
    st.panel_w = widget._slide_panel_w
    st.panel_h = widget._slide_panel_h
    st.hover_inside = widget._slide_hover_inside
end

-- Tracks and updates animation state
function SlideOutManager.update_animation(widget, host_button, main_hovered)
    local st, state_key = get_slide_state(host_button)
    if not st then
        return
    end

    local now = reaper.time_precise()
    if not st.last_frame_time or st.last_frame_time == 0.0 then
        st.last_frame_time = now
    end
    local dt = now - st.last_frame_time
    st.last_frame_time = now

    mirror_state_to_widget(widget, st)

    if active_slide_key and active_slide_key ~= state_key and st.t > 0.0 then
        close_slide_state(st)
        mirror_state_to_widget(widget, st)
        return
    end

    -- Combine hover triggers: main button, popup menus, and text fields
    local popup_open = reaper.ImGui_IsPopupOpen(widget._host_button and widget._host_button.widget and widget._host_button.widget.ctx or _G.MAIN_IMGUI_CTX, "##grid_dropdown_popup")
    local is_hovered = not not (main_hovered or st.hover_inside or widget._st_overlay_focused or popup_open)

    if is_hovered then
        if state_key ~= active_slide_key then
            close_other_slides(state_key)
            active_slide_key = state_key
        end
        st.hovered = true
        st.last_hover_time = now
        st.t = math.min(1.0, st.t + dt / 0.2) -- 200ms slide-in
    else
        st.hovered = false
        if now - st.last_hover_time >= 0.5 then
            st.t = math.max(0.0, st.t - dt / 0.2) -- 200ms slide-out
            if st.t <= 0.0 and active_slide_key == state_key then
                active_slide_key = nil
            end
        end
    end

    mirror_state_to_widget(widget, st)
end

local function call_slide_dim(widget, method, ctx, host_w, host_h, layout)
    local fn = widget and widget[method]
    if type(fn) ~= "function" then
        return nil
    end
    return fn(widget, ctx, host_w, host_h, layout)
end

-- Renders the slide-out duplicate button and routes interactions
function SlideOutManager.render(ctx, widget, host_button, rel_x, rel_y, render_width, render_height, coords, draw_list, text_color, bg_color, border_color, layout, render_contents_callback)
    local st, state_key = get_slide_state(host_button)
    if active_slide_key and state_key and state_key ~= active_slide_key then
        return
    end
    if not widget or not st or st.t <= 0.0 then
        if st then
            st.hover_inside = false
            mirror_state_to_widget(widget, st)
        end
        return
    end

    mirror_state_to_widget(widget, st)

    -- 1. Determine screen rectangle of host button (accounting for scroll offsets to fix positioning)
    local is_vert = layout and layout.is_vertical
    local title_h = (is_vert and layout.title_height) or 0
    local adj_rel_y = rel_y - title_h
    local adj_render_height = render_height

    local bx1, by1 = coords:toScreen(rel_x, adj_rel_y)
    local bx2 = bx1 + render_width
    local by2 = by1 + adj_render_height

    local host_w = render_width
    local host_h = adj_render_height
    widget._slide_host_w = host_w
    widget._slide_host_h = host_h

    -- 2. Determine target dimensions for slide-out (fixed axis matches host; other axis from content plan)
    local W_slideout, H_slideout

    if is_vert then
        H_slideout = host_h
        W_slideout = call_slide_dim(widget, "slide_width", ctx, host_w, host_h, layout) or host_w
    else
        W_slideout = host_w
        H_slideout = call_slide_dim(widget, "slide_height", ctx, host_w, host_h, layout)
            or widget.height
            or CONFIG.SIZES.HEIGHT
            or 28
    end

    widget._slide_panel_w = W_slideout
    widget._slide_panel_h = H_slideout
    sync_widget_dims_to_state(widget, st)

    -- 3. Screen boundary and docking checks with standard gaps
    local vp = reaper.ImGui_GetMainViewport(ctx)
    local vpx, vpy = reaper.ImGui_Viewport_GetWorkPos(vp)
    local vpw, vph = reaper.ImGui_Viewport_GetWorkSize(vp)

    local direction = "below"
    local win_x, win_y = 0, 0
    local GAP = (CONFIG.SIZES and CONFIG.SIZES.SEPARATOR_SIZE) or 12

    if is_vert then
        -- Default to right
        if bx2 + GAP + W_slideout <= vpx + vpw then
            direction = "right"
            win_x = bx2 + GAP
        else
            direction = "left"
            win_x = bx1 - W_slideout - GAP
        end
        -- Align vertical Y position of the slide-out identical to the source Y
        win_y = by1
        win_y = math.max(vpy, math.min(win_y, vpy + vph - H_slideout))
    else
        -- Default to below
        if by2 + GAP + H_slideout <= vpy + vph then
            direction = "below"
            win_y = by2 + GAP
        else
            direction = "above"
            win_y = by1 - H_slideout - GAP
        end
        win_x = math.max(vpx, math.min(bx1, vpx + vpw - W_slideout))
    end

    -- 4. Track mouse position for hovering the slide-out window
    local mx, my = reaper.ImGui_GetMousePos(ctx)
    widget._slide_hover_inside = (mx >= win_x and mx <= win_x + W_slideout and my >= win_y and my <= win_y + H_slideout)
    sync_widget_dims_to_state(widget, st)

    -- 5. Positioning and sizing
    reaper.ImGui_SetNextWindowPos(ctx, win_x, win_y, reaper.ImGui_Cond_Always())
    reaper.ImGui_SetNextWindowSize(ctx, W_slideout, H_slideout, reaper.ImGui_Cond_Always())

    local flags = reaper.ImGui_WindowFlags_NoTitleBar()
        | reaper.ImGui_WindowFlags_NoCollapse()
        | reaper.ImGui_WindowFlags_NoResize()
        | reaper.ImGui_WindowFlags_NoMove()
        | reaper.ImGui_WindowFlags_NoScrollbar()
        | reaper.ImGui_WindowFlags_NoFocusOnAppearing()
        | reaper.ImGui_WindowFlags_NoBackground()
    if reaper.ImGui_WindowFlags_NoDocking then flags = flags | reaper.ImGui_WindowFlags_NoDocking() end

    local eased_t = ease_in_out(st.t)
    local fade_alpha = fade_alpha_for_t(st.t)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)

    local visible = select(1, reaper.ImGui_Begin(ctx, "##slide_out_" .. (state_key or widget.name or "widget"), true, flags))
    if visible then
        local w_min_x, w_min_y = reaper.ImGui_GetWindowPos(ctx)
        local w_dl = reaper.ImGui_GetWindowDrawList(ctx)

        -- Create coordinate helper for the new window context
        local slide_coords = COORDINATES.new(ctx)

        -- Calculate slide offsets
        local slide_x, slide_y = 0, 0

        if direction == "below" then
            slide_y = (eased_t - 1) * H_slideout
        elseif direction == "above" then
            slide_y = (1 - eased_t) * H_slideout
        elseif direction == "right" then
            slide_x = (eased_t - 1) * W_slideout
        elseif direction == "left" then
            slide_x = (1 - eased_t) * W_slideout
        end

        if fade_alpha > 0.0 then
            -- Draw duplicate button background
            local button_rounding = (CONFIG.SIZES and CONFIG.SIZES.ROUNDING) or 3
            DRAWING.drawChipBackground(slide_coords, w_dl, slide_x, slide_y, W_slideout, H_slideout, bg_color, { 
                rounding = button_rounding, 
                border_color = border_color, 
                alpha_factor = fade_alpha 
            })

            render_contents_callback(ctx, widget, slide_x, slide_y, W_slideout, slide_coords, w_dl, text_color, layout, bg_color, fade_alpha)
        end

        -- 6. Interaction handling (only when animation is fully open)
        if st.t == 1.0 then
            local mouse_clicked = reaper.ImGui_IsMouseClicked(ctx, 0) or reaper.ImGui_IsMouseClicked(ctx, 1)
            if mouse_clicked and st.hover_inside then
                if widget.hitTestSubcontrols then
                    local sub_hit = widget:hitTestSubcontrols(ctx, slide_coords, slide_x, slide_y, W_slideout, layout, true)
                    if sub_hit and widget.onSubcontrolClick then
                        local ok, handled = pcall(widget.onSubcontrolClick, widget, sub_hit)
                        if ok and handled ~= false and widget.getValue then
                            pcall(widget.getValue, widget)
                        end
                    end
                end
            end
        end
    end

    reaper.ImGui_End(ctx)
    reaper.ImGui_PopStyleVar(ctx, 2)
end

return SlideOutManager
