local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "options",
  category_label = "Options",
  subcategory_id = "options.all",
  subcategory_label = "All actions",
  group_index = 3,
  group_count = 11,
  group_id = "Show Items Show Show Items",
  group_label = "Options [Show] - Cluster 3 (items_show_show items)",
  prefix_key = "Options",
  prefix_label = "Options",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40507",
      title = "Options: Show overlapping media items in lanes",
      action_key = "Main:40507",
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
      command_id = "41344",
      title = "Options: Show tooltips on media items and envelopes",
      action_key = "Main:41344",
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
