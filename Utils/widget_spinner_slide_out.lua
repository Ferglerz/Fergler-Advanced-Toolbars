-- Utils/widget_spinner_slide_out.lua
-- Spinner toolbar (+ optional pitch chip) with preset multiswitch in slide-out.
-- Use only when cloning playback_rate-style layout; most widgets should use CHIP_MODE or plain display.
-- Plumbing (hit-test prefixes, namespaces) derived from spec.widget_id or name initials — do not set unless debugging.
-- Override: spec.renderCustom, spec.hitTestSubcontrols, … on the spec.

local M = {}
require("Utils.widget_spinner_slide_out.layout")(M)
require("Utils.widget_spinner_slide_out.factory")(M)
return M
