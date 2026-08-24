-- @description Painel Touch Scroll
-- @version 1.0
-- @author Israel Castro
-- @about
--   Painel touch interativo para controle do REAPER.
--   Suporta Windows e macOS.
-- @depends
--   reaper_imgui >= 0.8
--   js_reascriptapi >= 1.000
-- @provides
--   [main] . > Painel touch scroll - 1.0.lua
--   modules/*.lua
--   modules/shortcuts/*.lua
--   Fontes/*

-- Garante compatibilidade de versão com o ReaImGui
if reaper.ImGui_GetBuiltinPath then
  local imgui_path = reaper.ImGui_GetBuiltinPath()
  if imgui_path and imgui_path ~= "" then
    package.path = imgui_path .. "/?.lua;" .. package.path
    local ok, imgui_loader = pcall(require, 'imgui')
    if ok and type(imgui_loader) == 'function' then
      pcall(imgui_loader, '0.8.7')
    end
  end
end

local script_path = debug.getinfo(1,"S").source:match([[^@?(.*[\/])[^\/]-$]])
if script_path then
  package.path = script_path .. "?.lua;" .. package.path
end

local State = require("modules.state")
local ReaperData = require("modules.reaper_data")
local Actions = require("modules.actions")
local Gui = require("modules.gui")

Actions.init_shortcuts()

local function loop()
  local open = Gui.Loop()
  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
