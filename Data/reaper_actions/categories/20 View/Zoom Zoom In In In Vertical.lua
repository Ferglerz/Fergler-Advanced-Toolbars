local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "view",
  category_label = "View",
  subcategory_id = "view.all",
  subcategory_label = "All actions",
  group_index = 12,
  group_count = 16,
  group_id = "Zoom Zoom In In In Vertical",
  group_label = "View [Zoom] - Cluster 2 (zoom in_in_in vertical)",
  prefix_key = "View",
  prefix_label = "View",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "1012",
      title = "View: Zoom in horizontal",
      action_key = "Main:1012",
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
      command_id = "40111",
      title = "View: Zoom in vertical",
      action_key = "Main:40111",
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
