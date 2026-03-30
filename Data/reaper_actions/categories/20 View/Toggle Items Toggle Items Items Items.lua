local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "view",
  category_label = "View",
  subcategory_id = "view.all",
  subcategory_label = "All actions",
  group_index = 8,
  group_count = 16,
  group_id = "Toggle Items Toggle Items Items Items",
  group_label = "View [Toggle] - Cluster 3 (items_toggle items_items items)",
  prefix_key = "View",
  prefix_label = "View",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40258",
      title = "View: Toggle displaying labels above/within media items",
      action_key = "Main:40258",
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
      command_id = "41622",
      title = "View: Toggle zoom to selected items",
      action_key = "Main:41622",
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
