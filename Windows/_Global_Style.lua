-- global_style.lua

local GlobalStyle = {}
local COLOR = require("Utils.Core.color.convert")
local EMPTY = {}

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
  windowRounding = 6.0,
  frameRounding = 4.0,
  grabRounding = 3.0,
  tabRounding = 4.0,
  windowBorderSize = 1.0,
  frameBorderSize = 1.0,
  popupRounding = 6.0,
  
  -- Spacing
  itemSpacingX = 8,
  itemSpacingY = 6,
  itemInnerSpacingX = 4,
  itemInnerSpacingY = 4,
  windowPaddingX = 10,
  windowPaddingY = 8,
  framePaddingX = 8,
  framePaddingY = 4
}

-- Resolve live theme edits without rebuilding style maps each frame.
local converted = {}
local function themeColor(key, value, fallback)
  if type(value) == "number" then return value end
  if type(value) ~= "string" then return fallback end
  local cached = converted[key]
  if cached and cached.value == value then return cached.color end
  local hex = value:match("^#(%x+)$")
  if not hex or (#hex ~= 6 and #hex ~= 8) then return fallback end
  local color = tonumber(#hex == 6 and hex .. "FF" or hex, 16)
  converted[key] = {value = value, color = color}
  return color
end

local function blend(a, b, amount)
  local ar, ag, ab = COLOR.extractChannels(a)
  local br, bg, bb = COLOR.extractChannels(b)
  return COLOR._packChannels(
    math.floor(ar + (br - ar) * amount + 0.5),
    math.floor(ag + (bg - ag) * amount + 0.5),
    math.floor(ab + (bb - ab) * amount + 0.5), 255)
end

function GlobalStyle.syncTheme()
  local theme = (_G.CONFIG and CONFIG.COLORS) or EMPTY
  local normal = theme.NORMAL or EMPTY
  local bg, text, border = normal.BG or EMPTY, normal.TEXT or EMPTY, normal.BORDER or EMPTY
  local toggled, armed = theme.TOGGLED or EMPTY, theme.ARMED or EMPTY
  local c = GlobalStyle.colors
  local surface = themeColor("surface", theme.WINDOW_BG, 0x333333FF) | 0xFF
  local fg = themeColor("text", text.NORMAL, 0xEEEEEEFF) | 0xFF
  local fill = themeColor("fill", bg.NORMAL, 0x444444FF) | 0xFF
  local hover = themeColor("hover", bg.HOVER, 0x555555FF) | 0xFF
  local active = themeColor("active", bg.CLICKED, 0x666666FF) | 0xFF
  c.accent = themeColor("accent", (toggled.BG or EMPTY).NORMAL, 0x6A92E0FF) | 0xFF
  c.danger = themeColor("danger", (armed.BG or EMPTY).NORMAL, 0xD86868FF) | 0xFF
  c.windowBg, c.popupBg, c.menuBarBg = surface, surface, surface
  c.button, c.buttonHovered, c.buttonActive = fill, hover, active
  c.frameBg, c.frameBgHovered, c.frameBgActive = blend(surface, fg, 0.035), hover, active
  c.header, c.headerHovered, c.headerActive = blend(surface, c.accent, 0.20), hover, active
  c.titleBg, c.titleBgActive, c.titleBgCollapsed = fill, hover, surface
  c.tab, c.tabHovered = fill, hover
  c.text, c.textDisabled = fg, blend(surface, fg, 0.55)
  c.dangerText = blend(c.danger, fg, 0.35)
  c.border = themeColor("border", border.NORMAL, 0x555555FF)
  c.sliderGrab, c.sliderGrabActive, c.checkMark = blend(surface, fg, 0.6), c.accent, c.accent
end

function GlobalStyle.getColor(name)
  GlobalStyle.syncTheme()
  return GlobalStyle.colors[name]
end

function GlobalStyle.pushAccentButtonStyle(ctx, destructive)
  GlobalStyle.syncTheme()
  local c = GlobalStyle.colors
  local fill = destructive and c.danger or c.accent
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), fill)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), blend(fill, c.text, 0.15))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), blend(fill, c.windowBg, 0.20))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLOR.smartTextOnFill(fill))
  return 4
end

local COLOR_MAP = {
  {"WindowBg", "windowBg"}, {"PopupBg", "popupBg"}, {"MenuBarBg", "menuBarBg"},
  {"Button", "button"}, {"ButtonHovered", "buttonHovered"}, {"ButtonActive", "buttonActive"},
  {"FrameBg", "frameBg"}, {"FrameBgHovered", "frameBgHovered"}, {"FrameBgActive", "frameBgActive"},
  {"Header", "header"}, {"HeaderHovered", "headerHovered"}, {"HeaderActive", "headerActive"},
  {"TitleBg", "titleBg"}, {"TitleBgActive", "titleBgActive"}, {"TitleBgCollapsed", "titleBgCollapsed"},
  {"Tab", "tab"}, {"TabHovered", "tabHovered"}, {"Text", "text"}, {"TextDisabled", "textDisabled"},
  {"Border", "border"}, {"SliderGrab", "sliderGrab"}, {"SliderGrabActive", "sliderGrabActive"},
  {"CheckMark", "checkMark"},
  {"TabSelected", "header", "TabActive"}, {"TabDimmed", "tab", "TabUnfocused"},
  {"TabDimmedSelected", "header", "TabUnfocusedActive"}, {"TabSelectedOverline", "accent"},
  {"TextSelectedBg", "header"}, {"Separator", "border"},
  {"SeparatorHovered", "buttonHovered"}, {"SeparatorActive", "accent"},
  {"ResizeGrip", "border"}, {"ResizeGripHovered", "buttonHovered"}, {"ResizeGripActive", "accent"},
  {"ScrollbarBg", "windowBg"}, {"ScrollbarGrab", "border"},
  {"ScrollbarGrabHovered", "buttonHovered"}, {"ScrollbarGrabActive", "accent"},
  {"NavCursor", "accent", "NavHighlight"},
}
local STYLE_MAP = {
  {"WindowRounding", "windowRounding"}, {"FrameRounding", "frameRounding"},
  {"GrabRounding", "grabRounding"}, {"TabRounding", "tabRounding"},
  {"WindowBorderSize", "windowBorderSize"}, {"FrameBorderSize", "frameBorderSize"},
  {"PopupRounding", "popupRounding"}, {"ItemSpacing", "itemSpacingX", "itemSpacingY"},
  {"ItemInnerSpacing", "itemInnerSpacingX", "itemInnerSpacingY"},
  {"WindowPadding", "windowPaddingX", "windowPaddingY"},
  {"FramePadding", "framePaddingX", "framePaddingY"},
}

function GlobalStyle.applyColors(ctx)
  GlobalStyle.syncTheme()
  local count = 0
  for _, entry in ipairs(COLOR_MAP) do
    local enum = reaper["ImGui_Col_" .. entry[1]]
      or (entry[3] and reaper["ImGui_Col_" .. entry[3]])
    if enum then
      reaper.ImGui_PushStyleColor(ctx, enum(), GlobalStyle.colors[entry[2]])
      count = count + 1
    end
  end
  return count
end

function GlobalStyle.applyStyles(ctx)
  for _, entry in ipairs(STYLE_MAP) do
    local id = reaper["ImGui_StyleVar_" .. entry[1]]()
    if entry[3] then
      reaper.ImGui_PushStyleVar(ctx, id, GlobalStyle.styles[entry[2]], GlobalStyle.styles[entry[3]])
    else
      reaper.ImGui_PushStyleVar(ctx, id, GlobalStyle.styles[entry[2]])
    end
  end
  return #STYLE_MAP
end

function GlobalStyle.apply(ctx, options)
  options = options or EMPTY
  local colors = options.colors ~= false and GlobalStyle.applyColors(ctx) or 0
  local styles = options.styles ~= false and GlobalStyle.applyStyles(ctx) or 0
  return colors, styles
end

function GlobalStyle.reset(ctx, colorCount, styleCount)
  if colorCount and colorCount > 0 then
    reaper.ImGui_PopStyleColor(ctx, colorCount)
  end
  
  if styleCount and styleCount > 0 then
    reaper.ImGui_PopStyleVar(ctx, styleCount)
  end
end

function GlobalStyle.withGlobalStyle(ctx, fn, options)
  local colorCount, styleCount = GlobalStyle.apply(ctx, options)
  local ok, a, b, c, d = pcall(fn)
  GlobalStyle.reset(ctx, colorCount, styleCount)
  if not ok then
    error(a)
  end
  return a, b, c, d
end

return GlobalStyle
