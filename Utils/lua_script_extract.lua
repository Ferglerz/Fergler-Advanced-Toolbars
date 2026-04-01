-- Utils/lua_script_extract.lua
-- Extract and load global `function Name(...)` blocks from a main ReaScript (or any Lua file)
-- without dofile()ing the whole file — safe for large scripts that register defer/UI at top level.
--
-- Typical workflow for another widget:
--   local X = require("Utils.lua_script_extract")
--   local cache = {}
--   local path = UTILS.joinPath(some_dir, "SomeScript.lua")
--   local fn, err = X.load_global_function_cached(cache, path, "SomeGlobalFn", { source_path = path })
--   X.invalidate_script_cache(cache, path)  -- when the script file or folder changes

local M = {}

local BLOCK_DELTA = {
    ["function"] = 1,
    ["if"] = 1,
    ["while"] = 1,
    ["for"] = 1,
    ["repeat"] = 1,
    ["end"] = -1,
    ["until"] = -1,
}

function M.skip_lua_trivia(s, pos)
    local n = #s
    while pos <= n do
        local b = s:byte(pos)
        if b == 32 or b == 9 or b == 10 or b == 13 then
            pos = pos + 1
        elseif s:sub(pos, pos + 1) == "--" then
            if s:sub(pos, pos + 3) == "--[[" then
                local _, open_end, eq = s:find("%-%-%[(=*)%[", pos)
                if not open_end then return n + 1 end
                eq = eq or ""
                local close = "]" .. eq .. "]"
                local _, cend = s:find(close, open_end + 1, true)
                pos = (cend or n) + 1
            else
                local nl = s:find("\n", pos, true)
                pos = nl and nl + 1 or n + 1
            end
        elseif s:sub(pos, pos) == '"' or s:sub(pos, pos) == "'" then
            local q = s:sub(pos, pos)
            pos = pos + 1
            while pos <= n do
                local c = s:sub(pos, pos)
                if c == "\\" then pos = math.min(n, pos + 2)
                elseif c == q then pos = pos + 1 break
                else pos = pos + 1 end
            end
        elseif s:byte(pos) == 91 then
            local ob, oe, eq = s:find("%[(=*)%[", pos)
            if ob then
                eq = eq or ""
                local close = "]" .. eq .. "]"
                local _, cend = s:find(close, oe + 1, true)
                pos = (cend or n) + 1
            else
                break
            end
        else
            break
        end
    end
    return pos
end

function M.scan_lua_function_block(s, start)
    local depth = 0
    local i = start
    local n = #s
    while i <= n do
        i = M.skip_lua_trivia(s, i)
        if i > n then return nil end
        local c = s:sub(i, i)
        if not c:match("[%a_]") then
            i = i + 1
        else
            local j = i
            while j <= n and s:sub(j, j):match("[%w_]") do j = j + 1 end
            local w = s:sub(i, j - 1)
            local d = BLOCK_DELTA[w]
            if d then
                depth = depth + d
                if depth == 0 then return s:sub(start, j - 1) end
            end
            i = j
        end
    end
    return nil
end

--- Find a top-level global `function name(` ... `end` (not `local function`).
function M.extract_global_function_source(content, name)
    local sig = "function " .. name .. "("
    local from = 1
    local lim = #content
    while from <= lim do
        local start = content:find(sig, from, true)
        if not start then return nil end
        if start > 1 and content:sub(start - 1, start - 1):match("[%w_]") then
            from = start + 1
        else
            local slice = M.scan_lua_function_block(content, start)
            if slice then return slice end
            from = start + 1
        end
    end
    return nil
end

function M.read_script_source(path)
    local fh = io.open(path, "r")
    if not fh then return nil, "io.open failed" end
    local body = fh:read("*a")
    fh:close()
    return body, nil
end

--- Build _ENV for load(): default { math = math } with optional strict or full _G fallback.
local function make_load_env(opts)
    opts = opts or {}
    if opts.env then return opts.env end
    local env = { math = math }
    if opts.inherit_globals then
        setmetatable(env, { __index = _G })
    else
        setmetatable(env, { __index = function() return nil end })
    end
    return env
end

--- Compile a source slice that defines one global function; returns the callable (or nil, errmsg).
function M.load_global_function_from_source(slice, func_name, opts)
    opts = opts or {}
    local env = make_load_env(opts)
    local chunk_name = opts.chunk_name or ("@extracted:" .. tostring(func_name))
    local chunk, load_err = load(slice, chunk_name, "t", env)
    if not chunk then return nil, load_err or "load failed" end
    local ok, pcall_err = pcall(chunk)
    if not ok then return nil, tostring(pcall_err) end
    local fn = env[func_name]
    if type(fn) ~= "function" then return nil, "not a function after load: " .. tostring(func_name) end
    return fn, nil
end

--- Read file, extract global function by name, load slice. opts passed to load_global_function_from_source; add source_path for chunk name.
function M.load_global_function_from_file(script_path, func_name, opts)
    opts = opts or {}
    local body, read_err = M.read_script_source(script_path)
    if not body then return nil, read_err or "read failed" end
    local slice = M.extract_global_function_source(body, func_name)
    if not slice then return nil, "function not found: " .. tostring(func_name) end
    local chunk_opts = {}
    for k, v in pairs(opts) do chunk_opts[k] = v end
    if not chunk_opts.chunk_name and opts.source_path then
        chunk_opts.chunk_name = "@" .. opts.source_path .. ":" .. func_name
    elseif not chunk_opts.chunk_name then
        chunk_opts.chunk_name = "@" .. script_path .. ":" .. func_name
    end
    return M.load_global_function_from_source(slice, func_name, chunk_opts)
end

local function cache_key(script_path, func_name)
    return script_path .. "\0" .. func_name
end

--- cache_tbl[script_path .. "\0" .. name] = function | false (failed). Returns fn or nil, err.
function M.load_global_function_cached(cache_tbl, script_path, func_name, opts)
    local k = cache_key(script_path, func_name)
    local cached = cache_tbl[k]
    if cached ~= nil then return cached ~= false and cached or nil end
    local fn, err = M.load_global_function_from_file(script_path, func_name, opts)
    cache_tbl[k] = fn or false
    return fn, err
end

function M.invalidate_script_cache(cache_tbl, script_path)
    if not script_path then return end
    local prefix = script_path .. "\0"
    for key in pairs(cache_tbl) do
        if key:sub(1, #prefix) == prefix then cache_tbl[key] = nil end
    end
end

return M
