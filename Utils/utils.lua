-- Utils/utils.lua
local M = {}

local function merge(target, source)
    for k, v in pairs(source) do
        target[k] = v
    end
end

merge(M, require("Utils.string_utils"))
merge(M, require("Utils.table_utils"))
merge(M, require("Utils.file_utils"))
merge(M, require("Utils.imgui_utils"))
merge(M, require("Utils.audio_utils"))
merge(M, require("Utils.reaper_utils"))

return M