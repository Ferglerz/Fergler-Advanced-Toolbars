local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.fades_and_crossfades",
  subcategory_label = "Fades, crossfades, and snap offset",
  group_index = 5,
  group_count = 6,
  group_id = "Fade Items Items Fade",
  group_label = "Cluster 6 (fade items_items_fade)",
  prefix_key = "all",
  prefix_label = "All",
  split_method = "vector_tfidf_kmeans",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40509",
      title = "Item: Fade items in to cursor",
      action_key = "Main:40509",
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
      command_id = "40510",
      title = "Item: Fade items out from cursor",
      action_key = "Main:40510",
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
