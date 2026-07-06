-- Sliding-pill animation state keys (per-window / per-row isolation).

local M = {}

M.PILL_INSET = 1
M.SLIDE_TAU = 0.065
M.MAX_DT = 0.05

local function slide_axis_key(axis, ns)
    axis = axis or "x"
    local base = axis == "y" and "_slide_y" or "_slide_x"
    if ns and ns ~= "" then
        return base .. "_" .. ns
    end
    return base
end

local function slide_last_time_key(ns)
    if ns and ns ~= "" then
        return "_slide_last_time_" .. ns
    end
    return "_slide_last_time"
end

-- Toolbar buttons (and widgets) are shared across controller windows; isolate pill animation per window.
function M.resolve_slide_namespace(self, opts)
    local base = (opts and opts.slide_namespace) or ""
    local cid = self and self._atb_controller_id
    local bid = self and self._button_instance_id
    if cid and bid then
        local suffix = tostring(cid) .. "_" .. tostring(bid)
        if base ~= "" then
            return base .. "_" .. suffix
        end
        return suffix
    end
    if base ~= "" then
        return base
    end
    return nil
end

--- axis: "x" (default) or "y". Updates self._slide_x / self._slide_y; returns current pill edge or nil.
--- ns: optional suffix so multiple chip rows on one widget do not share slide state (e.g. "rec", "lane").
function M.advance_slide(self, target, show_pill, axis, ns)
    axis = axis or "x"
    local key = slide_axis_key(axis, ns)
    local other_axis = axis == "y" and "x" or "y"
    local other = slide_axis_key(other_axis, ns)
    self[other] = nil

    local now = _G.FRAME_TIME or reaper.time_precise()
    local ltk = slide_last_time_key(ns)
    local last = self[ltk] or now
    local dt = math.min(math.max(now - last, 0), M.MAX_DT)
    self[ltk] = now

    if not show_pill or target == nil then
        self[key] = nil
        return nil
    end

    if self[key] == nil then
        self[key] = target
        return self[key]
    end

    local k = 1 - math.exp(-dt / M.SLIDE_TAU)
    self[key] = self[key] + (target - self[key]) * k
    if math.abs(self[key] - target) < 0.35 then
        self[key] = target
    end
    return self[key]
end

--- Independent horizontal + vertical slide keys (for grid multiswitch); does not clear the other axis.
function M.advance_slide_xy(self, target_x, target_y, show_pill, ns)
    ns = ns or ""
    local kx = "_slide_grid_x_" .. ns
    local ky = "_slide_grid_y_" .. ns
    local ltk = "_slide_grid_last_" .. ns

    local now = _G.FRAME_TIME or reaper.time_precise()
    local last = self[ltk] or now
    local dt = math.min(math.max(now - last, 0), M.MAX_DT)
    self[ltk] = now

    if not show_pill or target_x == nil or target_y == nil then
        self[kx] = nil
        self[ky] = nil
        return nil, nil
    end

    if self[kx] == nil then
        self[kx] = target_x
    end
    if self[ky] == nil then
        self[ky] = target_y
    end

    local k = 1 - math.exp(-dt / M.SLIDE_TAU)
    self[kx] = self[kx] + (target_x - self[kx]) * k
    self[ky] = self[ky] + (target_y - self[ky]) * k
    if math.abs(self[kx] - target_x) < 0.35 then
        self[kx] = target_x
    end
    if math.abs(self[ky] - target_y) < 0.35 then
        self[ky] = target_y
    end

    return self[kx], self[ky]
end

function M.attach(parent)
    parent.PILL_INSET = M.PILL_INSET
    parent.SLIDE_TAU = M.SLIDE_TAU
    parent.MAX_DT = M.MAX_DT
    parent.advance_slide = M.advance_slide
    parent.advance_slide_xy = M.advance_slide_xy
end

return M
