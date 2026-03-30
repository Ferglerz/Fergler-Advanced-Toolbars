local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "transport",
  category_label = "Transport",
  subcategory_id = "transport.all",
  subcategory_label = "All actions",
  group_index = 12,
  group_count = 13,
  group_id = "Other Cc Relative Relative Scrub",
  group_label = "Transport [Other] - Cluster 4 (cc relative_relative_scrub)",
  prefix_key = "Transport",
  prefix_label = "Transport",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "992",
      title = "Transport: Scrub/jog (MIDI CC relative/absolute only)",
      action_key = "Main:992",
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
      command_id = "974",
      title = "Transport: Scrub/jog fine control (MIDI CC relative only)",
      action_key = "Main:974",
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
