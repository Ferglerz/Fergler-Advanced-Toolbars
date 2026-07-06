-- Utils/anim.lua
-- Shared slide-out animation math used by Grid_Ruler_Chip and slide_out_manager.
local M = {}

-- Smoothstep easing (ease-in, ease-out).
function M.ease_in_out(t)
    return t * t * (3 - 2 * t)
end

-- Fade factor that ramps in over the second half of expand and out over the first half of collapse.
function M.fade_alpha(t)
    return math.max(0.0, (t - 0.5) / 0.5)
end

-- Per-element staggered progress: clamps (overall_t - delay) / duration to [0, 1].
function M.staggered_t(overall_t, delay, duration)
    local v = (overall_t - delay) / duration
    if v < 0.0 then return 0.0 end
    if v > 1.0 then return 1.0 end
    return v
end

-- Computes frame delta, seeding/advancing state.last_frame_time. Returns dt, now.
function M.frame_dt(state)
    local now = reaper.time_precise()
    if not state.last_frame_time or state.last_frame_time == 0.0 then
        state.last_frame_time = now
    end
    local dt = now - state.last_frame_time
    state.last_frame_time = now
    return dt, now
end

-- Advances slide progress toward open (hovered) or closed.
-- state: table with .t, .hovered, .last_hover_time
-- hold: seconds to wait after un-hover before collapsing (default 0.5)
-- dur: slide duration in seconds, both directions (default 0.2)
function M.advance_t(state, hovered, dt, now, hold, dur)
    hold = hold or 0.5
    dur = dur or 0.2
    if hovered then
        state.hovered = true
        state.last_hover_time = now
        state.t = math.min(1.0, state.t + dt / dur)
    else
        state.hovered = false
        if now - (state.last_hover_time or 0.0) >= hold then
            state.t = math.max(0.0, state.t - dt / dur)
        end
    end
end

return M
