local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.selection",
  subcategory_label = "Selection and mouse targeting",
  group_index = 5,
  group_count = 6,
  group_id = "Items Items Items Selected Area",
  group_label = "Cluster 1 (items_items items_selected area)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41296",
      title = "Item: Duplicate selected area of items",
      action_key = "Main:41296",
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
      command_id = "40312",
      title = "Item: Remove selected area of items",
      action_key = "Main:40312",
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
