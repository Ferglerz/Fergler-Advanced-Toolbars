local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "other",
  category_label = "Uncategorized / general",
  subcategory_id = "other.all",
  subcategory_label = "All actions",
  group_index = 34,
  group_count = 56,
  group_id = "Other Time From Time Measure",
  group_label = "Misc [Other] - Cluster 10 (time_from time_measure)",
  prefix_key = "misc",
  prefix_label = "Misc",
  split_method = "prefix_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40338",
      title = "Create measure from time selection (detect tempo)",
      action_key = "Main:40338",
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
      command_id = "40801",
      title = "Create measure from time selection (new time signature)...",
      action_key = "Main:40801",
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
