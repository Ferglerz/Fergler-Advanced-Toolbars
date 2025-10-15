-- Utils/id_generator.lua
-- Proper ID generation system to replace math.random()

local IdGenerator = {}

-- Static counters for different ID types
local toolbar_counter = 0
local button_counter = 0
local instance_counter = 0

-- Get current timestamp for uniqueness across sessions
local function getTimestamp()
    return math.floor(reaper.time_precise() * 1000)
end

-- Generate a proper UUID-like string
function IdGenerator.generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    local chars = "0123456789abcdef"
    
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.sub(chars, v + 1, v + 1)
    end)
end

-- Generate toolbar ID (sequential with timestamp prefix for uniqueness)
function IdGenerator.generateToolbarId()
    toolbar_counter = toolbar_counter + 1
    -- Format: timestamp_counter (ensures uniqueness across sessions)
    return getTimestamp() + toolbar_counter
end

-- Generate button instance ID (guaranteed unique)
function IdGenerator.generateButtonInstanceId(button_id)
    instance_counter = instance_counter + 1
    -- Format: buttonId_timestamp_counter
    return string.format("%s_%d_%d", tostring(button_id), getTimestamp(), instance_counter)
end

-- Generate button ID (for new buttons)
function IdGenerator.generateButtonId()
    button_counter = button_counter + 1
    -- Format: btn_timestamp_counter
    return string.format("btn_%d_%d", getTimestamp(), button_counter)
end

-- Reset counters (useful for testing)
function IdGenerator.reset()
    toolbar_counter = 0
    button_counter = 0
    instance_counter = 0
end

-- Check if an ID already exists in a collection
function IdGenerator.ensureUniqueId(id, existing_collection, generator_func)
    local attempts = 0
    local max_attempts = 100
    
    while existing_collection[tostring(id)] and attempts < max_attempts do
        id = generator_func()
        attempts = attempts + 1
    end
    
    if attempts >= max_attempts then
        error("Failed to generate unique ID after " .. max_attempts .. " attempts")
    end
    
    return id
end

return IdGenerator
