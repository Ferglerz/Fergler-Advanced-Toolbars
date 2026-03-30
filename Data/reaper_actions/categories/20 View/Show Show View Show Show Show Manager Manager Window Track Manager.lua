local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "view",
  category_label = "View",
  subcategory_id = "view.all",
  subcategory_label = "All actions",
  group_index = 3,
  group_count = 16,
  group_id = "Show Show View Show Show Show Manager Manager Window Track Manager",
  group_label = "View [Show] - Cluster 4 (show_view show_show show) / Cluster 2 (manager_manager window_track manager)",
  prefix_key = "View",
  prefix_label = "View",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40326",
      title = "View: Show region/marker manager window",
      action_key = "Main:40326",
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
      command_id = "40906",
      title = "View: Show track manager window",
      action_key = "Main:40906",
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
