local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "regions",
  category_label = "Regions",
  subcategory_id = "regions.all",
  subcategory_label = "All actions",
  group_index = 2,
  group_count = 2,
  group_id = "Region Go Finishes Playing",
  group_label = "Cluster 2 (region_go_finishes playing)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41802",
      title = "Regions: Go to next region after current region finishes playing (smooth seek)",
      action_key = "Main:41802",
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
      command_id = "41801",
      title = "Regions: Go to previous region after current region finishes playing (smooth seek)",
      action_key = "Main:41801",
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
