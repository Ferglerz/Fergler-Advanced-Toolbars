local action_chunk = {
  source_file = "Data/reaper_actions/ultraschall_reaper_actions_5.941_sws_2.9.7.txt",
  schema = "File-group of actions for one macro category + subcategory, split by vector similarity where available. Each action includes an editable appearance placeholder block.",
  category_id = "project_and_file",
  category_label = "Project and file",
  subcategory_id = "project_and_file.all",
  subcategory_label = "All actions",
  group_index = 4,
  group_count = 4,
  group_id = "Other Project File New Reaper File Quit Quit Reaper",
  group_label = "File [Other] - Cluster 2 (project_file_new) / Cluster 9 (reaper_file quit_quit reaper)",
  prefix_key = "File",
  prefix_label = "File",
  split_method = "postcolon_presplit_then_semantic+second_pass",
  action_count = 2,
  actions = {
    {
      section = "Main",
      command_id = "40004",
      title = "File: Quit REAPER",
      action_key = "Main:40004",
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
      command_id = "40063",
      title = "File: Spawn new instance of REAPER",
      action_key = "Main:40063",
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
