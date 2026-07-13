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

local LN2 = math.log(2)

function M.rateToSemitones(rate)
    rate = UTILS.asNumber(rate, nil)
    if not rate or rate <= 0 then
        return 0
    end
    return 12 * math.log(rate) / LN2
end

function M.semitonesToRate(st, min_rate, max_rate)
    st = UTILS.asNumber(st, 0) or 0
    local r = math.pow(2, st / 12)
    if min_rate then
        r = math.max(min_rate, r)
    end
    if max_rate then
        r = math.min(max_rate, r)
    end
    return r
end

function M.formatSemitonesDisplay(st)
    st = UTILS.asNumber(st, 0) or 0
    if math.abs(st) < 1e-10 then
        return "0st"
    end
    return string.format("%g", st) .. "st"
end

return M
