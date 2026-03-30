local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "toolbars",
  category_label = "Toolbars",
  subcategory_id = "toolbars.all",
  subcategory_label = "All actions",
  group_index = 2,
  group_count = 2,
  group_id = "Show Toolbar Show Show",
  group_label = "Cluster 1 (show_toolbar_show show)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41297",
      title = "Toolbar: Show/hide toolbar at top of main window",
      action_key = "Main:41297",
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
      command_id = "41084",
      title = "Toolbar: Show/hide toolbar docker",
      action_key = "Main:41084",
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
