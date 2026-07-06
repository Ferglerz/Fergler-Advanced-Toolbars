local FlexLayout = {}

-- groups is an array of arrays of items.
-- item must have { w = number, id = string, ... }
-- Returns lines = { { items = {item1, item2}, h = max_h, w = total_w }, ... }
function FlexLayout.wrap_groups(groups, max_w, gap_x, gap_y)
    local lines = {}
    local current_line = { items = {}, w = 0, h = 0 }
    
    for _, group in ipairs(groups) do
        -- compute group width
        local gw = 0
        local gh = 0
        for i, item in ipairs(group) do
            gw = gw + (item.w or 0)
            if i > 1 then gw = gw + gap_x end
            gh = math.max(gh, item.h or 0)
        end
        
        -- if group fits on current line
        local needs_gap = #current_line.items > 0
        local add_w = gw + (needs_gap and gap_x or 0)
        
        if current_line.w + add_w <= max_w or #current_line.items == 0 then
            -- add group items to current line
            for _, item in ipairs(group) do
                if #current_line.items > 0 then
                    current_line.w = current_line.w + gap_x
                end
                table.insert(current_line.items, item)
                current_line.w = current_line.w + (item.w or 0)
                current_line.h = math.max(current_line.h, item.h or 0)
            end
        else
            -- push line, start new
            table.insert(lines, current_line)
            current_line = { items = {}, w = 0, h = 0 }
            
            -- what if the group is wider than max_w? we should split the group itself
            for _, item in ipairs(group) do
                local item_needs_gap = #current_line.items > 0
                local item_add_w = (item.w or 0) + (item_needs_gap and gap_x or 0)
                
                if current_line.w + item_add_w <= max_w or #current_line.items == 0 then
                    if item_needs_gap then
                        current_line.w = current_line.w + gap_x
                    end
                    table.insert(current_line.items, item)
                    current_line.w = current_line.w + (item.w or 0)
                    current_line.h = math.max(current_line.h, item.h or 0)
                else
                    table.insert(lines, current_line)
                    current_line = { items = {item}, w = item.w or 0, h = item.h or 0 }
                end
            end
        end
    end
    
    if #current_line.items > 0 then
        table.insert(lines, current_line)
    end
    
    return lines
end

return FlexLayout
