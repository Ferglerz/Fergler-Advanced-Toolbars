-- Utils/widget_spinner_slide_out/state.lua

return function(widget, spec, env)
    local MODES = env.MODES
    local mode_by_id = env.mode_by_id

    local function ensure_included(self)
        if not self._included then
            self._included = {}
        end
        if self._show_pitch == nil then
            self._show_pitch = true
        end
        if self._show_spinner == nil then
            self._show_spinner = true
        end
    end

    local function is_included(self, entry)
        ensure_included(self)
        local v = self._included[entry.id]
        if v == nil then
            return entry.default_on
        end
        return v == true
    end

    local function enabled_list(self)
        local list = {}
        for _, e in ipairs(MODES) do
            if is_included(self, e) then
                list[#list + 1] = e
            end
        end
        return list
    end

    local function count_included(self)
        ensure_included(self)
        local n = 0
        for _, e in ipairs(MODES) do
            if is_included(self, e) then
                n = n + 1
            end
        end
        return n
    end

    env.ensure_included = ensure_included
    env.is_included = is_included
    env.enabled_list = enabled_list
    env.count_included = count_included

    function widget.applyPersistedOptions(self, opts)
        ensure_included(self)
        if type(opts) ~= "table" then
            return
        end
        if opts.show_spinner ~= nil then
            self._show_spinner = opts.show_spinner
        end
        if opts.show_pitch ~= nil then
            self._show_pitch = opts.show_pitch
        end
        if type(opts.included) == "table" then
            for k, on in pairs(opts.included) do
                if mode_by_id(k) then
                    self._included[k] = on == true
                end
            end
        end
    end

    function widget.exportPersistedOptions(self)
        ensure_included(self)
        local inc = {}
        for _, e in ipairs(MODES) do
            inc[e.id] = is_included(self, e)
        end
        return { included = inc, show_spinner = self._show_spinner, show_pitch = self._show_pitch }
    end

    function widget.getValue(self)
        if spec.getValue then
            return spec.getValue(self)
        end
        ensure_included(self)
        return self._play_rate
    end
end
