-- modules/actions.lua
local State = require("modules.state")
local Actions = {}

function Actions.btn_play_stop()
  local state = reaper.GetPlayState()
  if state & 1 == 1 then reaper.Main_OnCommand(1016, 0) else reaper.Main_OnCommand(1007, 0) end
end

function Actions.btn_pedal()
  reaper.Main_OnCommand(1016, 0) -- Stop
  Actions.set_loop(false)
  State.regiao_clicada_id = nil
  reaper.SetEditCurPos(0, true, false)
  reaper.Main_OnCommand(1007, 0) -- Play
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

function Actions.instant_jump(target_pos, target_id)
  if target_id then State.regiao_clicada_id = target_id end
  reaper.SetEditCurPos(target_pos, true, true)
end

function Actions.execute_sos_jump()
  local target_pos
  local target_id
  if State.regiao_clicada_id then
    local idx = tonumber(State.regiao_clicada_id:match("regiao_(%d+)"))
    if idx and State.regioes[idx] then
      target_pos = State.regioes[idx].pos
      target_id = State.regiao_clicada_id
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
      target_id = "regiao_" .. tostring(i+1)
    end
  end
  
  Actions.set_loop(false)
  
  if target_pos then Actions.instant_jump(target_pos, target_id) end
  
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

function Actions.is_autoplay_blocked_for_project(proj)
  if not proj then return false end
  
  -- 1. Check Project ExtState
  local retval, val = reaper.GetProjExtState(proj, "PainelTouch", "NoAutoplay")
  if retval and retval > 0 then
    if val == "1" then
      return true
    elseif val == "0" then
      return false
    end
  end
  
  -- 2. Check filename/path
  local path = ""
  local idx = 0
  while true do
    local p, p_path = reaper.EnumProjects(idx, "")
    if not p then break end
    if p == proj then
      path = p_path
      break
    end
    idx = idx + 1
  end
  
  if path and path ~= "" then
    local filename = path:match("[^\\/]+$") or ""
    local fn_lower = filename:lower()
    if fn_lower:find("noautoplay") or fn_lower:find("no_autoplay") or fn_lower:find("no%-autoplay") then
      return true
    end
  end
  
  return false
end

function Actions.get_next_project(proj)
  if not proj then return nil end
  local idx = 0
  local curr_idx = -1
  while true do
    local p = reaper.EnumProjects(idx, "")
    if not p then break end
    if p == proj then curr_idx = idx end
    idx = idx + 1
  end
  if curr_idx ~= -1 then
    return reaper.EnumProjects(curr_idx + 1, "")
  end
  return nil
end

function Actions.toggle_project_autoplay(proj)
  if not proj then return end
  local is_blocked = Actions.is_autoplay_blocked_for_project(proj)
  if is_blocked then
    reaper.SetProjExtState(proj, "PainelTouch", "NoAutoplay", "0")
  else
    reaper.SetProjExtState(proj, "PainelTouch", "NoAutoplay", "1")
  end
  reaper.MarkProjectDirty(proj)
end

function Actions.trigger_troca()
  local curr_proj = reaper.EnumProjects(-1, "")
  local idx = 0
  local curr_idx = -1
  while true do
    local p = reaper.EnumProjects(idx, "")
    if not p then break end
    if p == curr_proj then curr_idx = idx end
    idx = idx + 1
  end

  if curr_idx ~= -1 then
    local next_proj = reaper.EnumProjects(curr_idx + 1, "")
    if next_proj then
      local current_blocks = Actions.is_autoplay_blocked_for_project(curr_proj)
      local next_blocks = Actions.is_autoplay_blocked_for_project(next_proj)
      
      reaper.SelectProjectInstance(next_proj)
      reaper.SetEditCurPos(0, true, false)
      if not current_blocks and not next_blocks then
        if reaper.GetPlayState() & 1 == 0 then
          reaper.Main_OnCommand(1007, 0) -- Play
        end
      end
    end
  end
end

function Actions.trigger_pad_continuo()
  local curr_proj = reaper.EnumProjects(-1, "")
  if not curr_proj then return end

  -- Find current project index and next project
  local idx = 0
  local curr_idx = -1
  while true do
    local p = reaper.EnumProjects(idx, "")
    if not p then break end
    if p == curr_proj then curr_idx = idx end
    idx = idx + 1
  end

  if curr_idx == -1 then return end
  
  local next_proj = reaper.EnumProjects(curr_idx + 1, "")
  if not next_proj then return end

  -- Extract tonality from next project's first region
  local tonality = nil
  local m_idx = 0
  while true do
    local ret, isrgn, pos, rgnend, name, markrgnidx, color = reaper.EnumProjectMarkers3(next_proj, m_idx)
    if ret == 0 then break end
    if isrgn then
      tonality = name:match("%[(.-)%]")
      if tonality then break end
    end
    m_idx = m_idx + 1
  end

  if not tonality then return end

  -- Find PAD CONTINUO project
  local pad_proj = nil
  local p_idx = 0
  while true do
    local p, p_path = reaper.EnumProjects(p_idx, "")
    if not p then break end
    if p_path:upper():match("PAD CONTINUO") then
      pad_proj = p
      break
    end
    p_idx = p_idx + 1
  end

  if not pad_proj then return end

  -- Mute/unmute tracks in PAD CONTINUO
  local count = reaper.CountTracks(pad_proj)
  for i = 0, count - 1 do
    local tr = reaper.GetTrack(pad_proj, i)
    local _, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    local name_upper = tr_name:upper()
    local target_upper = tonality:upper()
    if name_upper == target_upper or name_upper:match("%[" .. target_upper .. "%]") then
      reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 0)
    else
      reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 1)
    end
  end

  -- Background play PAD CONTINUO
  reaper.PreventUIRefresh(1)
  reaper.SelectProjectInstance(pad_proj)
  reaper.SetEditCurPos(0, false, false)
  if reaper.GetPlayState() & 1 == 0 then
    reaper.Main_OnCommand(1007, 0) -- Play
  end
  reaper.SelectProjectInstance(curr_proj)
  reaper.PreventUIRefresh(-1)
end

function Actions.start_pad_fade()
  State.pad_fading_out = true
  State.pad_fade_start_time = reaper.time_precise()
  State.pad_stop_pending = false
      
  State.pad_proj_fade = nil
  local p_idx = 0
  while true do
    local p, p_path = reaper.EnumProjects(p_idx, "")
    if not p then break end
    if p_path:upper():match("PAD CONTINUO") then
      State.pad_proj_fade = p
      State.pad_master_tr = reaper.GetMasterTrack(p)
      State.pad_master_vol = reaper.GetMediaTrackInfo_Value(State.pad_master_tr, "D_VOL")
      break
    end
    p_idx = p_idx + 1
  end
end

function Actions.process_pad_fade()
  if State.pad_fading_out and State.pad_proj_fade then
    local now = reaper.time_precise()
    local progress = math.min((now - State.pad_fade_start_time) / State.pad_fade_duration, 1)
    local vol = State.pad_master_vol * (1 - progress)
    reaper.SetMediaTrackInfo_Value(State.pad_master_tr, "D_VOL", vol)

    if progress >= 1 then
      State.pad_fading_out = false
      
      local curr_proj = reaper.EnumProjects(-1, "")
      reaper.PreventUIRefresh(1)
      reaper.SelectProjectInstance(State.pad_proj_fade)
      reaper.Main_OnCommand(1016, 0) -- Stop
      reaper.SelectProjectInstance(curr_proj)
      reaper.PreventUIRefresh(-1)
      
      -- Restore master volume
      reaper.SetMediaTrackInfo_Value(State.pad_master_tr, "D_VOL", State.pad_master_vol)
      State.pad_proj_fade = nil
      State.pad_master_tr = nil
    end
  end
end

function Actions.init_shortcuts()
  local main_path = reaper.GetResourcePath() .. "/Scripts/Painel Touch"
  local shortcuts_dir = main_path .. "/modules/shortcuts"
  reaper.RecursiveCreateDirectory(shortcuts_dir, 0)
  
  State.shortcut_cmds = {}
  
  local buttons_id = {
    "btn1", "btn2", "btn3", "btn4", "btn5", "btn6", "btn7", "btn8", "btn_curta", "btn_pedal", "btn9", "btn10", "btn11"
  }
  
  for i, id in ipairs(buttons_id) do
    local file_path = shortcuts_dir .. "/" .. id .. ".lua"
    local f = io.open(file_path, "w")
    if f then
      f:write('-- Painel Touch Shortcut Helper\n')
      f:write('reaper.SetExtState("PainelTouchShortcuts", "trigger_' .. id .. '", "1", false)\n')
      f:close()
    end
    
    local commit = (i == #buttons_id)
    local cmd_id = reaper.AddRemoveReaScript(true, 0, file_path, commit)
    if cmd_id and cmd_id > 0 then
      State.shortcut_cmds[id] = cmd_id
    end
  end
end

function Actions.trigger_button_by_id(id)
  if id == "btn1" then Actions.btn_play_stop()
  elseif id == "btn2" then Actions.btn_alerta_hold()
  elseif id == "btn3" then Actions.btn_alerta_autoplay()
  elseif id == "btn4" then Actions.btn_anterior()
  elseif id == "btn5" then Actions.btn_proximo()
  elseif id == "btn6" then Actions.btn_loop()
  elseif id == "btn7" then Actions.toggle_somente_click()
  elseif id == "btn8" then
    local track_vocal
    for i = 0, reaper.CountTracks(0) - 1 do
      local tr = reaper.GetTrack(0, i)
      local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local name_upper = (name or ""):upper():gsub("Ê","E")
      if name_upper:find("VOZ REFERENCIA") then track_vocal = tr; break end
    end
    if track_vocal then
      local muteState = reaper.GetMediaTrackInfo_Value(track_vocal, "B_MUTE")
      reaper.SetMediaTrackInfo_Value(track_vocal, "B_MUTE", muteState == 0 and 1 or 0)
    end
  elseif id == "btn_curta" then
    State.versao_curta_ativo = not State.versao_curta_ativo
  elseif id == "btn_pedal" then
    Actions.btn_pedal()
  elseif id == "btn9" then
    local cmd = reaper.NamedCommandLookup("_SWS_PROJLIST_OPEN")
    if cmd and cmd > 0 then reaper.Main_OnCommand(cmd, 0) end
  elseif id == "btn10" then
    local cmd = reaper.NamedCommandLookup("_SWS_PROJLISTSAVE")
    if cmd and cmd > 0 then reaper.Main_OnCommand(cmd, 0) end
  elseif id == "btn11" then
    local cmd = reaper.NamedCommandLookup("_SWS_PROJLISTSOPEN")
    if cmd and cmd > 0 then reaper.Main_OnCommand(cmd, 0) end
  end
end

function Actions.tick()
  Actions.process_fades()
  Actions.process_pad_fade()
  
  -- Poll shortcuts
  if State.shortcut_cmds then
    local buttons_id = {
      "btn1", "btn2", "btn3", "btn4", "btn5", "btn6", "btn7", "btn8", "btn_curta", "btn_pedal", "btn9", "btn10", "btn11"
    }
    for _, id in ipairs(buttons_id) do
      local val = reaper.GetExtState("PainelTouchShortcuts", "trigger_" .. id)
      if val == "1" then
        reaper.SetExtState("PainelTouchShortcuts", "trigger_" .. id, "", false)
        Actions.trigger_button_by_id(id)
      end
    end
  end
  
  local play_state = reaper.GetPlayState()
  local is_playing = (play_state & 1 == 1)

  local curr_proj = reaper.EnumProjects(-1, "")
  if State.last_project_id_actions ~= curr_proj then
    State.last_project_id_actions = curr_proj
    local _, p_path = reaper.EnumProjects(-1, "")
    if p_path and not p_path:upper():match("PAD CONTINUO") then
      State.pad_stop_pending = true
      State.pad_stop_target_measure = nil
    end
  end

  if State.pad_stop_pending and is_playing then
    local _, measures = reaper.TimeMap2_timeToBeats(curr_proj, reaper.GetPlayPosition())
    if not State.pad_stop_target_measure then
      -- Target equals current measure + 4 full measures
      State.pad_stop_target_measure = measures + 4
    elseif measures >= State.pad_stop_target_measure then
      Actions.start_pad_fade()
    end
  end

  if State.sos_saindo and is_playing then
    local elapsed = reaper.time_precise() - State.sos_start_saindo_time
    if elapsed >= State.sos_saindo_duration then Actions.execute_sos_jump() end
  end


  if is_playing then
    local tocando = reaper.GetPlayPosition()
    local curr_rgn
    for i, reg in ipairs(State.regioes) do
      if tocando >= reg.pos and tocando < reg.rgnend then
        curr_rgn = reg
        break
      end
    end

    if curr_rgn then
      if curr_rgn.name:upper() == "TROCA" or curr_rgn.name:upper():match("TROCA") then
        local rgn_id = "regiao_" .. tostring(curr_rgn.pos)
        if State.troca_triggered_region_id ~= rgn_id then
          if State.autoplay_ativo then
            State.troca_triggered_region_id = rgn_id
            Actions.trigger_troca()
          end
        end
      else
        State.troca_triggered_region_id = nil
      end

      if curr_rgn.name:upper() == "PAD" or curr_rgn.name:upper():match("PAD") then
        local rgn_id = "regiao_" .. tostring(curr_rgn.pos)
        if State.pad_triggered_region_id ~= rgn_id then
          State.pad_triggered_region_id = rgn_id
          Actions.trigger_pad_continuo()
        end
      else
        State.pad_triggered_region_id = nil
      end
    else
      State.troca_triggered_region_id = nil
      State.pad_triggered_region_id = nil
    end
  end

  if State.versao_curta_ativo and is_playing then
    local tocando = reaper.GetPlayPosition()
    for i, reg in ipairs(State.regioes) do
      if tocando >= reg.pos and tocando < reg.rgnend then
        
        if reg.name:match("%*$") then
          -- Inside skipped region. Jump to escape
          if not State.curta_jump_in_progress then
            State.curta_jump_in_progress = true
            local target_pos, target_id
            for j = i + 1, #State.regioes do
              if not State.regioes[j].name:match("%*$") then
                target_pos = State.regioes[j].pos
                target_id = "regiao_" .. tostring(j)
                break
              end
            end
            if target_pos then Actions.instant_jump(target_pos, target_id) end
          end
        else
          -- Inside valid region. Resets escape flag.
          State.curta_jump_in_progress = false

          -- Look ahead for next region
          local next_reg = State.regioes[i+1]
          if next_reg and next_reg.name:match("%*$") then
            -- Queue jump 0.5s before hitting the skipped region for seamless branching
            if tocando >= (reg.rgnend - 0.5) then
              if not State.curta_queue_triggered then
                State.curta_queue_triggered = true
                local target_pos, target_id
                for j = i + 2, #State.regioes do
                  if not State.regioes[j].name:match("%*$") then
                    target_pos = State.regioes[j].pos
                    target_id = "regiao_" .. tostring(j)
                    break
                  end
                end
                if target_pos then Actions.instant_jump(target_pos, target_id) end
              end
            else
              State.curta_queue_triggered = false
            end
          else
            State.curta_queue_triggered = false
          end

        end
        break
      end
    end
  end
end

return Actions
