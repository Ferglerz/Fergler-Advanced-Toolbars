-- Utils/audio_utils.lua
local M = {}

function M.linearGainToDb(gain)
    if not gain or gain <= 0 then
        return -150
    end
    return 20 * math.log(gain, 10)
end

function M.dbToLinearGain(db)
    return 10 ^ (db / 20)
end

function M.getSelectedTrackVolumeDb()
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        return nil
    end
    local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
    return M.linearGainToDb(vol)
end

function M.peakLinearToDb(linear, floor_db)
    floor_db = floor_db or -60
    if not linear or linear <= 0 then
        return floor_db
    end
    return 20 * math.log(linear, 10)
end

return M
