local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.editing_edges",
  subcategory_label = "Trim edges (grow/shrink item bounds)",
  group_index = 3,
  group_count = 4,
  group_id = "Trim Trim Right Trim Right",
  group_label = "Item edit [Trim] - Cluster 2 (trim_right_trim right)",
  prefix_key = "Item Edit",
  prefix_label = "Item edit",
  split_method = "postcolon_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41311",
      title = "Item edit: Trim right edge of item to edit cursor",
      action_key = "Main:41311",
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
      command_id = "41310",
      title = "Item edit: Trim right edge of item under mouse to edit cursor",
      action_key = "Main:41310",
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
