local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.selection",
  subcategory_label = "Selection and mouse targeting",
  group_index = 6,
  group_count = 6,
  group_id = "Selected Media Media Set Selected",
  group_label = "Cluster 4 (selected media_media_set selected)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40440",
      title = "Item: Set selected media offline",
      action_key = "Main:40440",
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
      command_id = "40439",
      title = "Item: Set selected media online",
      action_key = "Main:40439",
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
