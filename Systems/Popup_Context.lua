-- Systems/Popup_Context.lua
local PopupContext = {}

function PopupContext.open(state, owner_ctx)
    if not state then
        return false
    end

    state.is_open = true
    state.owner_ctx = owner_ctx
    return true
end

function PopupContext.close(state)
    if not state then
        return false
    end

    state.is_open = false
    state.owner_ctx = nil
    return true
end

function PopupContext.shouldRender(state, ctx)
    if not state or not state.is_open then
        return false
    end

    if state.owner_ctx and ctx ~= state.owner_ctx then
        return false
    end

    return true
end

return PopupContext
