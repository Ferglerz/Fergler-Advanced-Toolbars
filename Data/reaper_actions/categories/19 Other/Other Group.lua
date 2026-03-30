local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "other",
  category_label = "Uncategorized / general",
  subcategory_id = "other.all",
  subcategory_label = "All actions",
  group_index = 37,
  group_count = 56,
  group_id = "Other Group",
  group_label = "Tempo envelope [Other] - Cluster 1",
  prefix_key = "Tempo Envelope",
  prefix_label = "Tempo envelope",
  split_method = "prefix_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40256",
      title = "Tempo envelope: Insert tempo/time signature change marker at edit cursor...",
      action_key = "Main:40256",
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
      command_id = "42330",
      title = "Tempo envelope: Insert tempo marker at edit cursor, without opening tempo edit dialog",
      action_key = "Main:42330",
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
