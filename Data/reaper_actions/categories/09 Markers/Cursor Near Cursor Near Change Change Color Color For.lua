local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "markers",
  category_label = "Markers",
  subcategory_id = "markers.all",
  subcategory_label = "All actions",
  group_index = 2,
  group_count = 4,
  group_id = "Cursor Near Cursor Near Change Change Color Color For",
  group_label = "Cluster 1 (cursor_near cursor_near) / Cluster 3 (change_change color_color for)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40304",
      title = "Markers: Change color for marker near cursor...",
      action_key = "Main:40304",
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
      command_id = "40305",
      title = "Markers: Change color for region near cursor...",
      action_key = "Main:40305",
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
