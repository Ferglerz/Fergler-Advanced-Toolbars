-- Utils/color_utils.lua
-- Facade re-exporting ColorUtils table

local ColorUtils = {}
local merge_table = require("Utils.Core.merge_table")

merge_table.merge(ColorUtils, require("Utils.Core.color.convert"), { skip_underscore_keys = true })
merge_table.merge(ColorUtils, require("Utils.Core.color.theme"), { skip_underscore_keys = true })
merge_table.merge(ColorUtils, require("Utils.Core.color.widget"), { skip_underscore_keys = true })

return ColorUtils
