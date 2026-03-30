local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "tracks",
  category_label = "Tracks",
  subcategory_id = "tracks.all",
  subcategory_label = "All actions",
  group_index = 20,
  group_count = 37,
  group_id = "Insert Show Show Show Insert Show",
  group_label = "Track [Insert] - Cluster 2 (show_show show_insert show)",
  prefix_key = "Track",
  prefix_label = "Track",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40907",
      title = "Track: Insert/show reaControlMIDI (MIDI track control)",
      action_key = "Main:40907",
      appearance = {
        custom_name = nil,
        icon_char = nil,
        icon_font = nil,
        icon_path = nil,
        custom_color = nil,
        hide_label = false,
      },
    },
    {
      section = "Main",
      command_id = "41757",
      title = "Track: Insert/show reaEQ (track EQ)",
      action_key = "Main:41757",
      appearance = {
        custom_name = nil,
        icon_char = nil,
        icon_font = nil,
        icon_path = nil,
        custom_color = nil,
        hide_label = false,
      },
    },
  },
}

return action_chunk
