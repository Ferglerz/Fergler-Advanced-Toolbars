local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "view",
  category_label = "View",
  subcategory_id = "view.all",
  subcategory_label = "All actions",
  group_index = 4,
  group_count = 16,
  group_id = "Show Show Matrix Matrix Window",
  group_label = "View [Show] - Cluster 5 (show_matrix_matrix window)",
  prefix_key = "View",
  prefix_label = "View",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41888",
      title = "View: Show region render matrix window",
      action_key = "Main:41888",
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
      command_id = "40251",
      title = "View: Show routing matrix window",
      action_key = "Main:40251",
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
