-- Widgets/colour_swatch_state.lua
-- Persistence, categories, stock palette, swatch scale.

local LAYOUT = require("Widgets.colour_swatch_layout")

local M = {}

local STOCK_CATEGORIES = {
    {
        id = "stock_primary",
        name = "Primary",
        colors = {
            "#E6194BFF", "#3CB44BFF", "#FFE119FF", "#4363D8FF", "#F58231FF",
            "#911EB4FF", "#46F0F0FF", "#F032E6FF", "#BCF60CFF", "#FABEBEFF"
        }
    },
    {
        id = "stock_pastel",
        name = "Pastel",
        colors = {
            "#FFB3BAFF", "#FFDFBAFF", "#FFFFBAFF", "#BAFFC9FF", "#BAE1FFFF",
            "#E8BAFFFF", "#D4A574FF", "#C7CEEAFF", "#B5EAD7FF", "#FFDAC1FF"
        }
    },
    {
        id = "stock_muted",
        name = "Muted",
        colors = {
            "#5C4B51FF", "#8CBEB2FF", "#F2EBBFFF", "#F3B562FF", "#F06060FF",
            "#4A6FA5FF", "#6B4226FF", "#789262FF", "#C06C84FF", "#6C5B7BFF"
        }
    }
}

function M.state_key(self)
    return tostring(self._button_instance_id or self.name or "default")
end

local function ensure_saved_table()
    if not CONFIG.WIDGET_SAVED_STATES then
        CONFIG.WIDGET_SAVED_STATES = {}
    end
    if type(CONFIG.WIDGET_SAVED_STATES.colour_swatch) ~= "table" then
        CONFIG.WIDGET_SAVED_STATES.colour_swatch = {}
    end
    return CONFIG.WIDGET_SAVED_STATES.colour_swatch
end

function M.load_state(self)
    local key = M.state_key(self)
    local store = ensure_saved_table()
    local st = store[key]
    if type(st) ~= "table" then
        st = {
            active_category_id = nil,
            user_categories = {},
            swatch_scale = 1.0
        }
        store[key] = st
    end
    if st.swatch_scale == nil then
        st.swatch_scale = 1.0
    end
    if type(st.user_categories) ~= "table" then
        st.user_categories = {}
    end
    self._state = st
    return st
end

function M.stock_categories(self)
    local out = {}
    for _, c in ipairs(STOCK_CATEGORIES) do
        if type(c) == "table" and c.id and type(c.colors) == "table" then
            local colors = {}
            for _, hex in ipairs(c.colors) do
                table.insert(colors, hex)
            end
            table.insert(
                out,
                {
                    id = c.id,
                    name = c.name or c.id,
                    colors = colors
                }
            )
        end
    end
    return out
end

function M.deep_copy_colors(t)
    local out = {}
    if type(t) == "table" then
        for _, c in ipairs(t) do
            table.insert(out, c)
        end
    end
    return out
end

function M.all_categories(self)
    local out = {}
    for _, c in ipairs(M.stock_categories(self)) do
        if type(c) == "table" and c.id and type(c.colors) == "table" then
            table.insert(out, { id = c.id, name = c.name or c.id, colors = c.colors, stock = true })
        end
    end
    for _, c in ipairs(self._state.user_categories) do
        if type(c) == "table" and c.id and type(c.colors) == "table" then
            table.insert(out, { id = c.id, name = c.name or c.id, colors = c.colors, stock = false })
        end
    end
    return out
end

function M.find_category(self, id)
    if not id then
        return nil
    end
    for _, c in ipairs(M.all_categories(self)) do
        if c.id == id then
            return c
        end
    end
    return nil
end

function M.active_palette(self)
    local st = self._state
    local cat = M.find_category(self, st.active_category_id)
    if cat then
        return cat.colors
    end
    local stock = M.stock_categories(self)
    if stock[1] and type(stock[1].colors) == "table" then
        st.active_category_id = stock[1].id
        return stock[1].colors
    end
    return {}
end

function M.save_config()
    if CONFIG_MANAGER and CONFIG_MANAGER.requestSaveWidgetSavedStates then
        CONFIG_MANAGER:requestSaveWidgetSavedStates()
    end
end

-- Scale 0.5–1.5 multiplies stock MIN/MAX cell bounds for this button instance.
function M.swatch_bounds(self)
    M.load_state(self)
    local scale = tonumber(self._state.swatch_scale) or 1.0
    scale = math.max(0.5, math.min(1.5, scale))
    local min_c = math.max(10, LAYOUT.MIN_CELL * scale)
    local max_c = math.max(min_c + 1, LAYOUT.MAX_CELL * scale)
    return min_c, max_c
end

function M.next_user_cat_id(self)
    local prefix = "user_" .. M.state_key(self):gsub("[^%w]", "_") .. "_"
    local used = {}
    for _, category in ipairs(self._state.user_categories or {}) do
        if type(category) == "table" and category.id then
            used[category.id] = true
        end
    end
    repeat
        self._cat_seq = (self._cat_seq or 0) + 1
    until not used[prefix .. self._cat_seq]
    return prefix .. self._cat_seq
end

return M
