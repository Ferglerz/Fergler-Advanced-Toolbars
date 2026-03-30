local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.editing_edges",
  subcategory_label = "Trim edges (grow/shrink item bounds)",
  group_index = 2,
  group_count = 4,
  group_id = "Trim Trim Left Trim Left",
  group_label = "Item edit [Trim] - Cluster 1 (trim_left_trim left)",
  prefix_key = "Item Edit",
  prefix_label = "Item edit",
  split_method = "postcolon_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41305",
      title = "Item edit: Trim left edge of item to edit cursor",
      action_key = "Main:41305",
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
      command_id = "41300",
      title = "Item edit: Trim left edge of item under mouse to edit cursor",
      action_key = "Main:41300",
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
