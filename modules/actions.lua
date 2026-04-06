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

function Actions.set_loop(enable, pos, rgnend)
  if enable then
    reaper.GetSet_LoopTimeRange(true, false, pos, rgnend, false)
    reaper.GetSetRepeat(1)
    State.loop_ativo = true
  else
    reaper.GetSetRepeat(0)
    reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)
    State.loop_ativo = false
  end
end

function Actions.enable_loop_current_region()
  local tocando = reaper.GetPlayPosition()
  for i, reg in ipairs(State.regioes) do
    if tocando >= reg.pos and tocando <= reg.rgnend then
      Actions.set_loop(true, reg.pos, reg.rgnend)
      State.sos_locked_region_idx = i
      return
    end
  end
  for i, reg in ipairs(State.regioes) do
    if tocando < reg.rgnend then
      Actions.set_loop(true, reg.pos, reg.rgnend)
      State.sos_locked_region_idx = i
      return
    end
  end
end

function Actions.btn_loop()
  if State.loop_ativo then
    Actions.set_loop(false)
  else
    Actions.enable_loop_current_region()
  end
end

function Actions.toggle_somente_click(force_val)
  if force_val ~= nil then
    if State.botao2_ativo == force_val then return end
    State.botao2_ativo = force_val
  else
    State.botao2_ativo = not State.botao2_ativo
  end
  State.fade_start_time = reaper.time_precise()
  if State.botao2_ativo then
    State.volumes_originais = {}
    for i = 0, reaper.CountTracks(0) - 1 do
      local tr = reaper.GetTrack(0, i)
      local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local vol = reaper.GetMediaTrackInfo_Value(tr, "D_VOL")
      State.volumes_originais[i] = vol
      if (name or ""):upper() ~= "02-CLICK" then
        reaper.SetMediaTrackInfo_Value(tr, "D_VOL", vol)
      end
    end
    State.fading_out, State.fading_in = true, false
  else
    State.fade_start_time = reaper.time_precise()
    State.fading_in, State.fading_out = true, false
  end
end

function Actions.execute_sos_jump()
  local target_pos
  if State.regiao_clicada_id then
    local idx = tonumber(State.regiao_clicada_id:match("regiao_(%d+)"))
    if idx and State.regioes[idx] then
      target_pos = State.regioes[idx].pos
    end
  else
    local i = State.sos_locked_region_idx
    if not i then
       local tocando = reaper.GetPlayPosition()
       for idx, reg in ipairs(State.regioes) do
         if tocando < reg.rgnend then i = idx; break; end
       end
    end
    if i and State.regioes[i+1] then
      target_pos = State.regioes[i+1].pos
    end
  end
  
  Actions.set_loop(false)
  
  if target_pos then
    local playing = (reaper.GetPlayState() & 1 == 1)
    if playing then reaper.Main_OnCommand(1008, 0) end -- Pause

    local smooth_seek_on = reaper.GetToggleCommandStateEx(0, 40600) == 1
    if smooth_seek_on then reaper.Main_OnCommand(40600, 0) end
    
    reaper.SetEditCurPos(target_pos, true, true)
    
    if smooth_seek_on then reaper.Main_OnCommand(40600, 0) end

    if playing then reaper.Main_OnCommand(1007, 0) end -- Play
  end
  
  if State.botao2_ativo then Actions.toggle_somente_click(false) end
  State.sos_ativo = false
  State.sos_saindo = false
  State.regiao_clicada_id = nil
  State.sos_locked_region_idx = nil
end

function Actions.btn_sos()
  if State.sos_ativo then
    if reaper.GetPlayState() & 1 == 1 then
      State.sos_saindo = true
      local bpm = reaper.TimeMap_GetDividedBpmAtTime(0, reaper.GetPlayPosition())
      if bpm <= 0 then bpm = 120 end
      State.sos_saindo_duration = (60.0 / bpm) * 4
      State.sos_start_saindo_time = reaper.time_precise()
    else
      Actions.execute_sos_jump()
    end
  else
    State.sos_ativo = true
    State.sos_saindo = false
    Actions.enable_loop_current_region()
    if not State.botao2_ativo then Actions.toggle_somente_click(true) end
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

function Actions.tick()
  Actions.process_fades()
  if State.sos_saindo and (reaper.GetPlayState() & 1 == 1) then
    local elapsed = reaper.time_precise() - State.sos_start_saindo_time
    if elapsed >= State.sos_saindo_duration then Actions.execute_sos_jump() end
  end
end

return Actions
