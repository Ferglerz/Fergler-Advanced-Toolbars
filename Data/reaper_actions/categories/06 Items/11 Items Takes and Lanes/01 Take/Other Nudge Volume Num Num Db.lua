local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "items",
  category_label = "Items and takes",
  subcategory_id = "items.takes_and_lanes",
  subcategory_label = "Takes, lanes, and comping",
  group_index = 7,
  group_count = 16,
  group_id = "Other Nudge Volume Num Num Db",
  group_label = "Take [Other] - Cluster 3 (nudge_volume num_num db)",
  prefix_key = "Take",
  prefix_label = "Take",
  split_method = "prefix_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "41927",
      title = "Take: Nudge active takes volume +1dB",
      action_key = "Main:41927",
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
      command_id = "41926",
      title = "Take: Nudge active takes volume -1dB",
      action_key = "Main:41926",
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
