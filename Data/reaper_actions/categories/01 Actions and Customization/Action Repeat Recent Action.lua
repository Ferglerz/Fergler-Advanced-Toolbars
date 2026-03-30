local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "actions_and_customization",
  category_label = "Actions and customization",
  subcategory_id = "actions_and_customization.all",
  subcategory_label = "All actions",
  group_index = 2,
  group_count = 2,
  group_id = "Action Repeat Recent Action",
  group_label = "Cluster 3 (action_repeat_recent action)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "3000",
      title = "Action: Repeat the action prior to the most recent action",
      action_key = "Main:3000",
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
      command_id = "2999",
      title = "Action: Repeat the most recent action",
      action_key = "Main:2999",
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
