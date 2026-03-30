local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "grid",
  category_label = "Grid",
  subcategory_id = "grid.all",
  subcategory_label = "All actions",
  group_index = 5,
  group_count = 6,
  group_id = "Other Grid Toggle Toggle Toggle Grid",
  group_label = "Grid [Other] - Cluster 3 (grid toggle_toggle toggle_grid)",
  prefix_key = "Grid",
  prefix_label = "Grid",
  split_method = "postcolon_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41885",
      title = "Grid: Toggle framerate grid",
      action_key = "Main:41885",
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
      command_id = "40725",
      title = "Grid: Toggle measure grid",
      action_key = "Main:40725",
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
