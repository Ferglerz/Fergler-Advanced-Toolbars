local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "grid",
  category_label = "Grid",
  subcategory_id = "grid.all",
  subcategory_label = "All actions",
  group_index = 6,
  group_count = 6,
  group_id = "Other Num Num Grid Set To Grid Set To Grid Set To",
  group_label = "Grid [Other] - Cluster 1 (num num_grid_set_to_grid_set_to grid_set_to)",
  prefix_key = "Grid",
  prefix_label = "Grid",
  split_method = "postcolon_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "42002",
      title = "Grid: Set to 1/10 (1/8 quintuplet)",
      action_key = "Main:42002",
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
      command_id = "42005",
      title = "Grid: Set to 1/5 (1/4 quintuplet)",
      action_key = "Main:42005",
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
