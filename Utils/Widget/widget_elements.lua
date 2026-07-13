-- Utils/Widget/widget_elements.lua
-- Facade: unified widget component library (display, slider, knob, button, etc.).

local DISPLAY = require("Utils.Widget.elements_display")
local SLIDER = require("Utils.Widget.elements_slider")
local KNOB = require("Utils.Widget.elements_knob")
local MISC = require("Utils.Widget.elements_misc")

local M = {}

M.drawSliderValueReadout = SLIDER.drawSliderValueReadout
M.drawSliderWidgetValueAndLabel = SLIDER.drawSliderWidgetValueAndLabel
M.display = DISPLAY.display
M.dropdown = DISPLAY.dropdown
M.slider = SLIDER.slider
M.knob = KNOB.knob
M.button = MISC.button
M.multiswitch = MISC.multiswitch
M.colour_swatch = MISC.colour_swatch

return M
