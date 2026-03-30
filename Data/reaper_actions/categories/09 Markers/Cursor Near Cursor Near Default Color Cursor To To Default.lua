local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "markers",
  category_label = "Markers",
  subcategory_id = "markers.all",
  subcategory_label = "All actions",
  group_index = 3,
  group_count = 4,
  group_id = "Cursor Near Cursor Near Default Color Cursor To To Default",
  group_label = "Cluster 1 (cursor_near cursor_near) / Cluster 5 (default color_cursor to_to default)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41897",
      title = "Markers: Set marker near cursor to default color",
      action_key = "Main:41897",
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
      command_id = "41896",
      title = "Markers: Set region near cursor to default color",
      action_key = "Main:41896",
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
