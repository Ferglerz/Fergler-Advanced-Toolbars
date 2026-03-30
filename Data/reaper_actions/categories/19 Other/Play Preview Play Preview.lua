local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "other",
  category_label = "Uncategorized / general",
  subcategory_id = "other.all",
  subcategory_label = "All actions",
  group_index = 45,
  group_count = 56,
  group_id = "Play Preview Play Preview",
  group_label = "Preview - Cluster 7 (play_preview play_preview)",
  prefix_key = "Preview",
  prefix_label = "Preview",
  split_method = "prefix_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Media Explorer",
      command_id = "1008",
      title = "Preview: Play",
      action_key = "Media Explorer:1008",
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
      section = "Media Explorer",
      command_id = "40025",
      title = "Preview: Play/pause",
      action_key = "Media Explorer:40025",
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
