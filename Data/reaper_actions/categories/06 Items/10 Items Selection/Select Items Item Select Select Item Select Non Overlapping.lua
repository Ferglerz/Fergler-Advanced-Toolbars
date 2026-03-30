local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.selection",
  subcategory_label = "Selection and mouse targeting",
  group_index = 2,
  group_count = 6,
  group_id = "Select Items Item Select Select Item Select Non Overlapping",
  group_label = "Cluster 2 (select_items_item select) / Cluster 2 (select_item select_non overlapping)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41127",
      title = "Item: Select next adjacent non-overlapping item",
      action_key = "Main:41127",
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
      command_id = "41128",
      title = "Item: Select previous adjacent non-overlapping item",
      action_key = "Main:41128",
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
