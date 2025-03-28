-- global_style.lua

local GlobalStyle = {}

-- Define style configurations
GlobalStyle.colors = {
  -- Window colors
  windowBg = 0x333333FF,
  popupBg = 0x2D2D2DFF,
  menuBarBg = 0x2D2D2DFF,
  
  -- Button colors
  button = 0x444444FF,
  buttonHovered = 0x555555FF,
  buttonActive = 0x666666FF,
  
  -- Frame colors
  frameBg = 0x3A3A3AFF,
  frameBgHovered = 0x444444FF,
  frameBgActive = 0x555555FF,
  
  -- Header colors
  header = 0x444444FF,
  headerHovered = 0x555555FF,
  headerActive = 0x666666FF,
  
  -- Title colors
  titleBg = 0x2A2A2AFF,
  titleBgActive = 0x444444FF,
  titleBgCollapsed = 0x222222FF,
  
  -- Tab colors
  tab = 0x333333FF,
  tabHovered = 0x555555FF,
  
  -- Text colors
  text = 0xEEEEEEFF,
  textDisabled = 0x888888FF,
  
  -- Border colors
  border = 0x555555FF,
  
  -- Slider colors
  sliderGrab = 0x666666FF,
  sliderGrabActive = 0x888888FF,
  
  -- Checkbox
  checkMark = 0xCCCCCCFF
}

GlobalStyle.styles = {
  -- Window styling
  windowRounding = 4.0,
  frameRounding = 4.0,
  grabRounding = 3.0,
  tabRounding = 4.0,
  windowBorderSize = 1.0,
  frameBorderSize = 1.0,
  
  -- Spacing
  itemSpacingX = 8,
  itemSpacingY = 4,
  itemInnerSpacingX = 4,
  itemInnerSpacingY = 4,
  windowPaddingX = 8,
  windowPaddingY = 8
}

function GlobalStyle.applyColors(ctx)
  local colorMap = {
    {reaper.ImGui_Col_WindowBg(), GlobalStyle.colors.windowBg},
    {reaper.ImGui_Col_PopupBg(), GlobalStyle.colors.popupBg},
    {reaper.ImGui_Col_MenuBarBg(), GlobalStyle.colors.menuBarBg},
    {reaper.ImGui_Col_Button(), GlobalStyle.colors.button},
    {reaper.ImGui_Col_ButtonHovered(), GlobalStyle.colors.buttonHovered},
    {reaper.ImGui_Col_ButtonActive(), GlobalStyle.colors.buttonActive},
    {reaper.ImGui_Col_FrameBg(), GlobalStyle.colors.frameBg},
    {reaper.ImGui_Col_FrameBgHovered(), GlobalStyle.colors.frameBgHovered},
    {reaper.ImGui_Col_FrameBgActive(), GlobalStyle.colors.frameBgActive},
    {reaper.ImGui_Col_Header(), GlobalStyle.colors.header},
    {reaper.ImGui_Col_HeaderHovered(), GlobalStyle.colors.headerHovered},
    {reaper.ImGui_Col_HeaderActive(), GlobalStyle.colors.headerActive},
    {reaper.ImGui_Col_TitleBg(), GlobalStyle.colors.titleBg},
    {reaper.ImGui_Col_TitleBgActive(), GlobalStyle.colors.titleBgActive},
    {reaper.ImGui_Col_TitleBgCollapsed(), GlobalStyle.colors.titleBgCollapsed},
    {reaper.ImGui_Col_Tab(), GlobalStyle.colors.tab},
    {reaper.ImGui_Col_TabHovered(), GlobalStyle.colors.tabHovered},
    {reaper.ImGui_Col_Text(), GlobalStyle.colors.text},
    {reaper.ImGui_Col_TextDisabled(), GlobalStyle.colors.textDisabled},
    {reaper.ImGui_Col_Border(), GlobalStyle.colors.border},
    {reaper.ImGui_Col_SliderGrab(), GlobalStyle.colors.sliderGrab},
    {reaper.ImGui_Col_SliderGrabActive(), GlobalStyle.colors.sliderGrabActive},
    {reaper.ImGui_Col_CheckMark(), GlobalStyle.colors.checkMark}
  }
  
  return #colorMap, function(idx)
    reaper.ImGui_PushStyleColor(ctx, colorMap[idx][1], colorMap[idx][2])
  end
end

function GlobalStyle.applyStyles(ctx)
  local styleMap = {
    {reaper.ImGui_StyleVar_WindowRounding(), GlobalStyle.styles.windowRounding},
    {reaper.ImGui_StyleVar_FrameRounding(), GlobalStyle.styles.frameRounding},
    {reaper.ImGui_StyleVar_GrabRounding(), GlobalStyle.styles.grabRounding},
    {reaper.ImGui_StyleVar_TabRounding(), GlobalStyle.styles.tabRounding},
    {reaper.ImGui_StyleVar_WindowBorderSize(), GlobalStyle.styles.windowBorderSize},
    {reaper.ImGui_StyleVar_FrameBorderSize(), GlobalStyle.styles.frameBorderSize},
    {reaper.ImGui_StyleVar_ItemSpacing(), GlobalStyle.styles.itemSpacingX, GlobalStyle.styles.itemSpacingY},
    {reaper.ImGui_StyleVar_ItemInnerSpacing(), GlobalStyle.styles.itemInnerSpacingX, GlobalStyle.styles.itemInnerSpacingY},
    {reaper.ImGui_StyleVar_WindowPadding(), GlobalStyle.styles.windowPaddingX, GlobalStyle.styles.windowPaddingY}
  }
  
  return #styleMap, function(idx)
    local style = styleMap[idx]
    if #style == 2 then
      reaper.ImGui_PushStyleVar(ctx, style[1], style[2])
    else
      reaper.ImGui_PushStyleVar(ctx, style[1], style[2], style[3])
    end
  end
end

function GlobalStyle.apply(ctx, options)
  options = options or {}
  local colorCount, styleCount = 0, 0
  local colorFunc, styleFunc
  
  if options.colors ~= false then
    colorCount, colorFunc = GlobalStyle.applyColors(ctx)
    for i=1, colorCount do colorFunc(i) end
  end
  
  if options.styles ~= false then
    styleCount, styleFunc = GlobalStyle.applyStyles(ctx)
    for i=1, styleCount do styleFunc(i) end
  end
  
  return colorCount, styleCount
end

function GlobalStyle.reset(ctx, colorCount, styleCount)
  if colorCount and colorCount > 0 then
    reaper.ImGui_PopStyleColor(ctx, colorCount)
  end
  
  if styleCount and styleCount > 0 then
    reaper.ImGui_PopStyleVar(ctx, styleCount)
  end
end

return GlobalStyle