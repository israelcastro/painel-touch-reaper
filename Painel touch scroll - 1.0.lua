--@description Painel touch Na Janela Band
--@version 0.2
--@noindex

local script_path = debug.getinfo(1,"S").source:match([[^@?(.*[\/])[^\/]-$]])
if script_path then
  package.path = script_path .. "?.lua;" .. package.path
end

local State = require("modules.state")
local ReaperData = require("modules.reaper_data")
local Actions = require("modules.actions")
local Gui = require("modules.gui")

local function loop()
  local open = Gui.Loop()
  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
