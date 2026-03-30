local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.takes_and_lanes",
  subcategory_label = "Takes, lanes, and comping",
  group_index = 16,
  group_count = 16,
  group_id = "Reverse Toggle Toggle Take Take Reverse",
  group_label = "Misc - Cluster 5 (reverse toggle_toggle take_take reverse)",
  prefix_key = "misc",
  prefix_label = "Misc",
  split_method = "prefix_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40437",
      title = "Item properties: Toggle item play all takes",
      action_key = "Main:40437",
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
      command_id = "41051",
      title = "Item properties: Toggle take reverse",
      action_key = "Main:41051",
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
