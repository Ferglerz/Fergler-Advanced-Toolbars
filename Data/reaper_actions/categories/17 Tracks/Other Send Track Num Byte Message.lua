local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "tracks",
  category_label = "Tracks",
  subcategory_id = "tracks.all",
  subcategory_label = "All actions",
  group_index = 37,
  group_count = 37,
  group_id = "Other Send Track Num Byte Message",
  group_label = "Track [Other] - Cluster 4 (send track_num byte_message)",
  prefix_key = "Track",
  prefix_label = "Track",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41558",
      title = "Track: Send track pan as 2-byte MIDI message",
      action_key = "Main:41558",
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
      command_id = "41557",
      title = "Track: Send track volume as 2-byte MIDI message",
      action_key = "Main:41557",
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
