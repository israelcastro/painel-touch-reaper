-- modules/actions.lua
local State = require("modules.state")
local Actions = {}

function Actions.btn_play_stop()
  local state = reaper.GetPlayState()
  if state & 1 == 1 then reaper.Main_OnCommand(1016, 0) else reaper.Main_OnCommand(1007, 0) end
end

function Actions.btn_alerta_hold()
  State.hold_ativo = not State.hold_ativo
  if State.hold_ativo then State.autoplay_ativo = false end
  State.salvar_config()
end

function Actions.btn_alerta_autoplay()
  State.autoplay_ativo = not State.autoplay_ativo
  if State.autoplay_ativo then State.hold_ativo = false end
  State.salvar_config()
end

function Actions.btn_anterior()
  reaper.Main_OnCommand(40862, 0) -- previous project
end

function Actions.btn_proximo()
  reaper.Main_OnCommand(40861, 0) -- next project
end

function Actions.btn_loop()
  local tocando = reaper.GetPlayPosition()
  for _, reg in ipairs(State.regioes) do
    if tocando >= reg.pos and tocando < reg.rgnend then
      if not State.loop_ativo then
        reaper.GetSet_LoopTimeRange(true, false, reg.pos, reg.rgnend, false)
        reaper.Main_OnCommand(1068, 0) -- enable loop
        State.loop_ativo = true
      else
        reaper.Main_OnCommand(1068, 0) -- disable loop
        reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)
        State.loop_ativo = false
      end
      break
    end
  end
end

function Actions.process_fades()
  if State.fading_out or State.fading_in then
    local now = reaper.time_precise()
    local progress = math.min((now - State.fade_start_time) / State.fade_duration, 1)
    for i = 0, reaper.CountTracks(0) - 1 do
      local tr = reaper.GetTrack(0, i)
      local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local original_vol = State.volumes_originais[i] or 1.0
      if (name or ""):upper() ~= "02-CLICK" then
        local target = State.fading_out and 0.0 or original_vol
        local start = State.fading_out and original_vol or 0.0
        local vol = start + (target - start) * progress
        reaper.SetMediaTrackInfo_Value(tr, "D_VOL", vol)
      end
    end
    if progress >= 1 then 
      State.fading_out, State.fading_in = false, false 
    end
  end
end

return Actions
