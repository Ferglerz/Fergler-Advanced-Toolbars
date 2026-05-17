-- Parse prefixed subcontrol ids from ROW.hit_test_chips (e.g. "ptb_time" -> "time").

local M = {}

--- If sub_id starts with prefix, return rest; else nil.
function M.strip(prefix, sub_id)
    if type(sub_id) ~= "string" or type(prefix) ~= "string" then
        return nil
    end
    local pl = #prefix
    if sub_id:sub(1, pl) ~= prefix then
        return nil
    end
    return sub_id:sub(pl + 1)
end

return M
