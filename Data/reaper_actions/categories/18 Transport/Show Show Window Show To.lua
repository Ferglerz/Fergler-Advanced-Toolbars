local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "transport",
  category_label = "Transport",
  subcategory_id = "transport.all",
  subcategory_label = "All actions",
  group_index = 2,
  group_count = 13,
  group_id = "Show Show Window Show To",
  group_label = "Transport [Show] - Cluster 2 (show_window show_to)",
  prefix_key = "Transport",
  prefix_label = "Transport",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41605",
      title = "Transport: Show transport docked to bottom of main window",
      action_key = "Main:41605",
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
      command_id = "41606",
      title = "Transport: Show transport docked to top of main window",
      action_key = "Main:41606",
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
