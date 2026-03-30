local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "tracks",
  category_label = "Tracks",
  subcategory_id = "tracks.all",
  subcategory_label = "All actions",
  group_index = 21,
  group_count = 37,
  group_id = "Nudge Nudge Down Down Nudge",
  group_label = "Track [Nudge] - Cluster 2 (nudge_down_down nudge)",
  prefix_key = "Track",
  prefix_label = "Track",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40744",
      title = "Track: Nudge master track volume down",
      action_key = "Main:40744",
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
      command_id = "40116",
      title = "Track: Nudge track volume down",
      action_key = "Main:40116",
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
