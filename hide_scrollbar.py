import re

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'r') as f:
    content = f.read()

old_flags = """        local flags = reaper.ImGui_WindowFlags_NoBackground()
        if not is_vertical then
            flags = flags | reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end"""

new_flags = """        local flags = reaper.ImGui_WindowFlags_NoBackground() | reaper.ImGui_WindowFlags_NoScrollbar()
        if not is_vertical then
            flags = flags | reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end"""

content = content.replace(old_flags, new_flags)

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'w') as f:
    f.write(content)
print("Updated scrollbar flags in 01_Toolbar.lua")
