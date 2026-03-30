local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "transport",
  category_label = "Transport",
  subcategory_id = "transport.all",
  subcategory_label = "All actions",
  group_index = 10,
  group_count = 13,
  group_id = "Other Transport Transport Stop Stop Apply Playrate Current Bpm",
  group_label = "Transport [Other] - Cluster 3 (transport_transport stop_stop) / Cluster 3 (apply_playrate_current bpm)",
  prefix_key = "Transport",
  prefix_label = "Transport",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40672",
      title = "Transport: Apply playrate to current BPM",
      action_key = "Main:40672",
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
      command_id = "40526",
      title = "Transport: Apply playrate to current BPM (no reset playrate)",
      action_key = "Main:40526",
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
