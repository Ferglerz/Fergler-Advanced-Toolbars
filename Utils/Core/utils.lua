-- Utils/utils.lua
local M = {}
local merge_table = require("Utils.Core.merge_table")

merge_table.merge(M, require("Utils.Core.string_utils"))
merge_table.merge(M, require("Utils.Core.table_utils"))
merge_table.merge(M, require("Utils.Core.file_utils"))
merge_table.merge(M, require("Utils.Draw.imgui_utils"))
merge_table.merge(M, require("Utils.Reaper.audio_utils"))
merge_table.merge(M, require("Utils.Reaper.reaper_utils"))

return M
