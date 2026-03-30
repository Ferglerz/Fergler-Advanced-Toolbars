local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "other",
  category_label = "Uncategorized / general",
  subcategory_id = "other.all",
  subcategory_label = "All actions",
  group_index = 51,
  group_count = 56,
  group_id = "Select Browser Select Select Select",
  group_label = "Browser - Cluster 1 (select_browser select_select select)",
  prefix_key = "Browser",
  prefix_label = "Browser",
  split_method = "prefix_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Media Explorer",
      command_id = "40041",
      title = "Browser: Select all media files",
      action_key = "Media Explorer:40041",
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
      section = "Media Explorer",
      command_id = "40029",
      title = "Browser: Select previous file in directory",
      action_key = "Media Explorer:40029",
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
