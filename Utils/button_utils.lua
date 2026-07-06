-- Utils/button_utils.lua
-- Facade re-exporting ButtonUtils table

local ButtonUtils = {}
local merge_table = require("Utils.Core.merge_table")

merge_table.merge(ButtonUtils, require("Utils.Core.button.identity"))
merge_table.merge(ButtonUtils, require("Utils.Core.button.layout"))
merge_table.merge(ButtonUtils, require("Utils.Core.button.labels"))
merge_table.merge(ButtonUtils, require("Utils.Core.button.groups"))
merge_table.merge(ButtonUtils, require("Utils.Core.button.drag"))

return ButtonUtils
