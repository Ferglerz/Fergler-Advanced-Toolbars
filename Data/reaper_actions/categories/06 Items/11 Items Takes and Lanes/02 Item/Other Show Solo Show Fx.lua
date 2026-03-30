local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.takes_and_lanes",
  subcategory_label = "Takes, lanes, and comping",
  group_index = 14,
  group_count = 16,
  group_id = "Other Show Solo Show Fx",
  group_label = "Item [Other] - Cluster 2 (show_solo_show fx)",
  prefix_key = "Item",
  prefix_label = "Item",
  split_method = "prefix_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40638",
      title = "Item: Show FX chain for item take",
      action_key = "Main:40638",
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
      command_id = "40856",
      title = "Item: Solo active take of multitake item within time selection",
      action_key = "Main:40856",
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
