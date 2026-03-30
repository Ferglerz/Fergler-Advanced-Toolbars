local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "automation",
  category_label = "Automation",
  subcategory_id = "automation.all",
  subcategory_label = "All actions",
  group_index = 4,
  group_count = 4,
  group_id = "Automation Lane Increase Increase Active",
  group_label = "Misc - Cluster 2 (automation_lane increase_increase active)",
  prefix_key = "misc",
  prefix_label = "Misc",
  split_method = "prefix_presplit_then_semantic",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40858",
      title = "Automation lane: Decrease active fader a little bit",
      action_key = "Main:40858",
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
      command_id = "40857",
      title = "Automation lane: Increase active fader a little bit",
      action_key = "Main:40857",
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
