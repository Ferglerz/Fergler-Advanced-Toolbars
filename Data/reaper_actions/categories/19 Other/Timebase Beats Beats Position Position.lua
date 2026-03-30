local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "other",
  category_label = "Uncategorized / general",
  subcategory_id = "other.all",
  subcategory_label = "All actions",
  group_index = 20,
  group_count = 56,
  group_id = "Timebase Beats Beats Position Position",
  group_label = "Misc [Timebase] - Cluster 3 (beats_beats position_position)",
  prefix_key = "misc",
  prefix_label = "Misc",
  split_method = "prefix_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40489",
      title = "Track properties: Set track timebase to beats (position only)",
      action_key = "Main:40489",
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
      command_id = "40488",
      title = "Track properties: Set track timebase to beats (position, length, rate)",
      action_key = "Main:40488",
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
