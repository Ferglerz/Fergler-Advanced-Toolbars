local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.takes_and_lanes",
  subcategory_label = "Takes, lanes, and comping",
  group_index = 13,
  group_count = 16,
  group_id = "Other Glue Glue Items Items",
  group_label = "Item [Other] - Cluster 1 (glue_glue items_items)",
  prefix_key = "Item",
  prefix_label = "Item",
  split_method = "prefix_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "42009",
      title = "Item: Glue items (auto-increase channel count with take FX)",
      action_key = "Main:42009",
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
      command_id = "42008",
      title = "Item: Glue items, ignoring time selection (auto-increase channel count with take FX)",
      action_key = "Main:42008",
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
