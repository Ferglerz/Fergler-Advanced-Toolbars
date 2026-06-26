-- Managers/Config_Backup.lua
local MAX_USER_CONFIG_BACKUPS = 30
return function(ConfigManager)
local function configBackupDirForSource(source_abs_path)
    local user_dir = UTILS.normalizeSlashes(UTILS.joinPath(SCRIPT_PATH, "User"))
    local norm = UTILS.normalizeSlashes(source_abs_path)
    if norm:sub(1, #user_dir) ~= user_dir then
        return UTILS.joinPath(SCRIPT_PATH, "User/config_backups/_other")
    end
    local rel = norm:sub(#user_dir + 1)
    if rel:sub(1, 1) == "/" then
        rel = rel:sub(2)
    end
    if rel:sub(1, #"config_backups/") == "config_backups/" then
        return nil
    end
    local dir_part, file = rel:match("^(.+)/([^/]+)$")
    if not file then
        file = rel
        dir_part = ""
    end
    local base = file:gsub("%.lua$", "")
    local root = UTILS.joinPath(SCRIPT_PATH, "User/config_backups")
    if dir_part ~= "" then
        return UTILS.joinPath(root, dir_part, base)
    end
    return UTILS.joinPath(root, base)
end

local function listBackupLuaFiles(backup_dir)
    local files = UTILS.getFilesInDirectory(backup_dir) or {}
    local lua_files = {}
    for _, name in ipairs(files) do
        if type(name) == "string" and name:match("%.lua$") then
            table.insert(lua_files, name)
        end
    end
    table.sort(lua_files)
    return lua_files
end

local function pruneConfigBackups(backup_dir)
    local names = listBackupLuaFiles(backup_dir)
    while #names > MAX_USER_CONFIG_BACKUPS do
        os.remove(UTILS.joinPath(backup_dir, names[1]))
        table.remove(names, 1)
    end
end

-- Snapshot existing user config on disk before overwrite; keeps newest MAX_USER_CONFIG_BACKUPS per file.
function ConfigManager:backupUserConfigFileBeforeWrite(source_abs_path)
    local norm = UTILS.normalizeSlashes(source_abs_path)
    local src = io.open(norm, "r")
    if not src then
        return true
    end
    local content = src:read("*a")
    src:close()
    if not content or content:match("^%s*$") then
        return true
    end

    local backup_dir = configBackupDirForSource(norm)
    if not backup_dir then
        return true
    end
    if not UTILS.ensureDirectoryExists(backup_dir) then
        return false
    end

    local ts = os.date("%Y%m%d_%H%M%S")
    local backup_name = ts .. ".lua"
    local backup_path = UTILS.joinPath(backup_dir, backup_name)
    local n = 1
    while true do
        local probe = io.open(backup_path, "r")
        if not probe then
            break
        end
        probe:close()
        n = n + 1
        backup_name = ts .. "_" .. n .. ".lua"
        backup_path = UTILS.joinPath(backup_dir, backup_name)
    end

    local out = io.open(backup_path, "w")
    if not out then
        return false
    end
    out:write(content)
    out:close()

    pruneConfigBackups(backup_dir)
    return true
end


end
