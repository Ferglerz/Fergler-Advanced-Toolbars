-- Systems/Dropdown_Preset_Catalog.lua
-- Curated REAPER action bundles: use for dropdown presets and for bulk-inserting toolbar buttons.
-- Numeric IDs = built-in Main section; string IDs starting with _ need SWS or matching extensions.

--[[
  Row types in each preset's `rows`:
    { name = "Label", action_id = "12345" }  -- action row (toolbar button + dropdown entry)
    { is_separator = true }                    -- dropdown only; skipped when inserting toolbar buttons
    { is_heading = true, name = "Section" }  -- dropdown only; skipped when inserting toolbar buttons

  Optional per-preset hint (documentation only for now):
    suggest_widget = "one line: when a dedicated widget fits better than N separate buttons"

  Widget vs many buttons (rule of thumb):
  - Prefer a widget when the list is project-bound (regions, markers, track templates, takes by name,
    recent projects) or unbounded — same reasons as track_templates / region_list widgets.
  - Prefer separate toolbar buttons when actions are few, fixed, muscle-memory targets (transport,
    zoom in/out, mute/solo selection) or when each action has its own toggle/armed state to show.

  Command IDs follow the Ultraschall REAPER 5.941 + SWS 2.9.7 snapshot in Data/reaper_actions/.
]]

local M = {}

M.categories = {
    {
        id = "transport_time",
        label = "Transport & time",
        presets = {
            {
                id = "transport_core",
                label = "Core transport",
                rows = {
                    { is_heading = true, name = "Transport" },
                    { name = "Play", action_id = "1007" },
                    { name = "Stop", action_id = "1016" },
                    { name = "Pause", action_id = "1008" },
                    { name = "Play/pause", action_id = "40073" },
                    { name = "Record", action_id = "1013" },
                    { is_separator = true },
                    { name = "Toggle repeat", action_id = "1068" },
                },
            },
            {
                id = "metronome",
                label = "Metronome",
                rows = {
                    { is_heading = true, name = "Metronome" },
                    { name = "Toggle metronome", action_id = "40364" },
                    { name = "Show metronome / pre-roll settings", action_id = "40363" },
                },
            },
            {
                id = "loop_selection",
                label = "Loop & time selection",
                rows = {
                    { is_heading = true, name = "Loop" },
                    { name = "Copy time selection to loop points", action_id = "40622" },
                    { name = "Copy loop points to time selection", action_id = "40623" },
                    { name = "Toggle loop points linked to time selection", action_id = "40621" },
                    { is_separator = true },
                    { name = "Remove time selection and loop points", action_id = "40020" },
                },
            },
        },
    },
    {
        id = "items_editing",
        label = "Items & takes",
        presets = {
            {
                id = "item_edit_essentials",
                label = "Item editing essentials",
                rows = {
                    { is_heading = true, name = "Edits" },
                    { name = "Split at edit/play cursor", action_id = "40012" },
                    { name = "Glue items (full)", action_id = "40257" },
                    { name = "Heal splits in items", action_id = "40548" },
                    { name = "Remove items", action_id = "40006" },
                    { is_separator = true },
                    { is_heading = true, name = "Options" },
                    { name = "Cycle ripple editing mode", action_id = "1155" },
                    { name = "Toggle snapping", action_id = "1157" },
                },
            },
            {
                id = "pitch_rate",
                label = "Pitch & play rate",
                rows = {
                    { is_heading = true, name = "Pitch" },
                    { name = "Pitch item up 1 semitone", action_id = "40204" },
                    { name = "Pitch item down 1 semitone", action_id = "40205" },
                    { name = "Reset item pitch", action_id = "40653" },
                    { is_separator = true },
                    { is_heading = true, name = "Play rate" },
                    { name = "Set item rate to 1.0", action_id = "40652" },
                },
            },
            {
                id = "item_volume",
                label = "Item volume",
                rows = {
                    { is_heading = true, name = "Volume" },
                    { name = "Reset items volume to +0 dB", action_id = "41923" },
                    { name = "Nudge items volume -1 dB", action_id = "41924" },
                    { name = "Nudge items volume +1 dB", action_id = "41925" },
                },
            },
            {
                id = "takes",
                label = "Takes",
                suggest_widget = "Active take picker listing take names on the selected item(s) scales better than many static buttons.",
                rows = {
                    { is_heading = true, name = "Takes" },
                    { name = "Next take", action_id = "40125" },
                    { name = "Previous take", action_id = "40126" },
                    { name = "Duplicate active take", action_id = "40639" },
                    { name = "Delete active take", action_id = "40129" },
                    { is_separator = true },
                    { name = "Render items to new take (preserve type)", action_id = "40601" },
                },
            },
        },
    },
    {
        id = "tracks_mixer",
        label = "Tracks & mixer",
        presets = {
            {
                id = "track_mute_solo",
                label = "Mute / solo selection",
                rows = {
                    { is_heading = true, name = "Selected tracks" },
                    { name = "Toggle mute", action_id = "6" },
                    { name = "Toggle solo", action_id = "7" },
                    { name = "Toggle record arm", action_id = "9" },
                    { is_separator = true },
                    { name = "Toggle FX bypass", action_id = "8" },
                },
            },
        },
    },
    {
        id = "view_zoom",
        label = "View & zoom",
        presets = {
            {
                id = "horizontal_zoom",
                label = "Horizontal zoom",
                suggest_widget = "Optional: single zoom widget with % readout + drag; buttons stay fine for discrete in/out.",
                rows = {
                    { is_heading = true, name = "Zoom" },
                    { name = "Zoom in horizontal", action_id = "1012" },
                    { name = "Zoom out horizontal", action_id = "1011" },
                    { name = "Zoom out project", action_id = "40295" },
                },
            },
        },
    },
}

--- Action rows only, in order, for creating normal toolbar buttons (skips headings/separators).
function M.collect_action_rows_for_toolbar(rows)
    local out = {}
    if not rows then
        return out
    end
    for _, r in ipairs(rows) do
        if not r.is_separator and not r.is_heading and r.action_id and tostring(r.action_id) ~= "" then
            table.insert(out, {
                name = r.name or "Action",
                action_id = tostring(r.action_id),
            })
        end
    end
    return out
end

--- Deep-copy preset rows into dropdown_menu entries (heading / separator / action).
function M.flatten_preset_rows(rows)
    local out = {}
    if not rows then
        return out
    end
    for _, r in ipairs(rows) do
        if r.is_separator then
            table.insert(out, { is_separator = true })
        elseif r.is_heading then
            table.insert(out, { is_heading = true, name = r.name or "" })
        else
            table.insert(
                out,
                {
                    name = r.name or "Action",
                    action_id = tostring(r.action_id or ""),
                }
            )
        end
    end
    return out
end

return M
