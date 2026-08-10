-- modules/gui.lua
local State = require("modules.state")
local ReaperData = require("modules.reaper_data")
local Actions = require("modules.actions")

local Gui = {}

local is_imgui_v9 = false
if reaper.ImGui_GetVersion then
  local ver = reaper.ImGui_GetVersion()
  local major, minor = ver:match("(%d+)%.(%d+)")
  if major and (tonumber(major) > 0 or tonumber(minor) >= 9) then
    is_imgui_v9 = true
  end
end

function Gui.PushFont(ctx, font, size)
  if not font then return end
  if is_imgui_v9 then
    reaper.ImGui_PushFont(ctx, font, size or 16)
  else
    reaper.ImGui_PushFont(ctx, font)
  end
end

function Gui.PopFont(ctx)
  if not ctx then return end
  reaper.ImGui_PopFont(ctx)
end

function Gui.ImGui_ButtonTouch(ctx, id, label, w, h, cor_normal, cor_ativo, acao)
  local agora = reaper.time_precise()
  local cor = cor_normal
  if State.click_pendente and State.click_pendente.id == id then
    if agora - State.tempo_primeiro_click > State.tempo_limite_2cliques then
      State.click_pendente = nil
    else
      cor = cor_ativo
    end
  end
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), cor)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), cor)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), cor)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), State.cor_branco)
  Gui.PushFont(ctx, State.font_bold, 16)
  local clicked = reaper.ImGui_Button(ctx, label, w, h)
  Gui.PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)

  if reaper.ImGui_BeginPopupContextItem(ctx, "popup_" .. id) then
    local cmd_id = State.shortcut_cmds and State.shortcut_cmds[id]
    if cmd_id then
      local section = reaper.SectionFromUniqueID(0)
      local count = reaper.CountActionShortcuts(section, cmd_id)
      
      if reaper.ImGui_MenuItem(ctx, "Atalho: (incluir)") then
        reaper.DoActionShortcutDialog(reaper.GetMainHwnd(), section, cmd_id, -1)
      end
      
      reaper.ImGui_BeginDisabled(ctx, count == 0)
      if reaper.ImGui_MenuItem(ctx, "Excluir") then
        for idx = count - 1, 0, -1 do
          reaper.DeleteActionShortcut(section, cmd_id, idx)
        end
      end
      reaper.ImGui_EndDisabled(ctx)
    else
      reaper.ImGui_Text(ctx, "Erro: Comando não registrado")
    end
    reaper.ImGui_EndPopup(ctx)
  end

  if clicked then
    if not State.usar_dois_cliques then
      acao()
      if State.modo_tela_touch then reaper.JS_Mouse_SetPosition(0, 0) end
    else
      if State.click_pendente and State.click_pendente.id == id then
        acao()
        State.click_pendente = nil
      else
        State.click_pendente = { id = id }
        State.tempo_primeiro_click = agora
      end
    end
  end
end

function Gui.Loop()
  local current_project_id = reaper.EnumProjects(-1, "")
  if current_project_id ~= State.last_project_id then
    State.last_project_id = current_project_id
    ReaperData.carregarRegioes()
    State.last_waveform_width = nil
    State.regiao_clicada_id = nil
  end

  local visible, open = reaper.ImGui_Begin(State.ctx, 'Painel touch Na Janela Band', true)
  
  if visible then
    reaper.ImGui_Dummy(State.ctx, State.padding_lateral, 0)
    reaper.ImGui_SameLine(State.ctx)
    local _, project_path = reaper.EnumProjects(-1, "")
    local project_name = project_path:match("([^\\/]+)%.rpp$") or "(Projeto sem nome)"
    reaper.ImGui_Text(State.ctx, "Projeto: " .. project_name)
    reaper.ImGui_Separator(State.ctx)
    reaper.ImGui_NewLine(State.ctx)

    do
      local cor_modo_dois = State.usar_dois_cliques and State.cor_verde or State.cor_botao_padrao
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_Button(), cor_modo_dois)
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonHovered(), cor_modo_dois)
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonActive(), cor_modo_dois)
      if reaper.ImGui_Button(State.ctx, State.usar_dois_cliques and "Modo: Dois Cliques (Ativo)" or "Modo: Dois Cliques (Desativo)", 300, 30) then
        State.usar_dois_cliques = not State.usar_dois_cliques; State.salvar_config()
      end
      reaper.ImGui_PopStyleColor(State.ctx, 3)
    end
    reaper.ImGui_SameLine(State.ctx, nil, 20)
    do
      local cor_modo_touch = State.modo_tela_touch and State.cor_verde or State.cor_botao_padrao
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_Button(), cor_modo_touch)
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonHovered(), cor_modo_touch)
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonActive(), cor_modo_touch)
      if reaper.ImGui_Button(State.ctx, State.modo_tela_touch and "Modo: Tela Touch (Ativo)" or "Modo: Tela Touch (Desativo)", 300, 30) then
        State.modo_tela_touch = not State.modo_tela_touch; State.salvar_config()
      end
      reaper.ImGui_PopStyleColor(State.ctx, 3)
    end

    local largura, altura, padding = 140, 100, 10
    local cor_hover_sup = State.cor_amarelo
    Gui.ImGui_ButtonTouch(State.ctx, "btn1", "PLAY/STOP", largura, altura, State.cor_botao_padrao, cor_hover_sup, Actions.btn_play_stop); reaper.ImGui_SameLine(State.ctx, nil, padding)
    do
      local c = State.hold_ativo and State.cor_verde or State.cor_botao_padrao
      Gui.ImGui_ButtonTouch(State.ctx, "btn2", "HOLD", largura, altura, c, cor_hover_sup, Actions.btn_alerta_hold)
    end
    reaper.ImGui_SameLine(State.ctx, nil, padding)
    do
      local c = State.autoplay_ativo and State.cor_verde or State.cor_botao_padrao
      Gui.ImGui_ButtonTouch(State.ctx, "btn3", "AUTO PLAY", largura, altura, c, cor_hover_sup, Actions.btn_alerta_autoplay)
    end
    reaper.ImGui_SameLine(State.ctx, nil, padding)
    Gui.ImGui_ButtonTouch(State.ctx, "btn4", "ANTERIOR", largura, altura, State.cor_botao_padrao, cor_hover_sup, Actions.btn_anterior); reaper.ImGui_SameLine(State.ctx, nil, padding)
    Gui.ImGui_ButtonTouch(State.ctx, "btn5", "PRÓXIMO",  largura, altura, State.cor_botao_padrao, cor_hover_sup, Actions.btn_proximo);  reaper.ImGui_SameLine(State.ctx, nil, padding)
    do
      local alpha = 1; if State.loop_ativo and (math.floor(os.clock() * 4) % 2 == 0) then alpha = 0.3 end
      local c = State.loop_ativo and reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.8, 0.2, alpha) or State.cor_botao_padrao
      Gui.ImGui_ButtonTouch(State.ctx, "btn6", "LOOP", largura, altura, c, cor_hover_sup, Actions.btn_loop)
    end
    reaper.ImGui_SameLine(State.ctx, nil, padding)
    do
      local c_verm = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1)
      local c_dour = reaper.ImGui_ColorConvertDouble4ToU32(1.00, 1.00, 0.30, 0.9)
      local c_normal = (State.botao2_ativo and (math.floor(os.clock() * 4) % 2 == 0)) and c_dour or c_verm
      Gui.ImGui_ButtonTouch(State.ctx, "btn7", "SOMENTE CLICK", largura, altura, c_normal, State.cor_amarelo, function()
        Actions.toggle_somente_click()
      end)
    end
    reaper.ImGui_SameLine(State.ctx, nil, padding)
    do
      local track_vocal
      for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        local name_upper = (name or ""):upper():gsub("Ê","E")
        if name_upper:find("VOZ REFERENCIA") then track_vocal = tr; break end
      end
      local muteState = track_vocal and reaper.GetMediaTrackInfo_Value(track_vocal, "B_MUTE") or 0
      local c = muteState == 1 and State.cor_vermelho or State.cor_verde
      Gui.ImGui_ButtonTouch(State.ctx, "btn8", "VOCAL REFERÊNCIA", largura, altura, c, cor_hover_sup, function()
        if track_vocal then
          reaper.SetMediaTrackInfo_Value(track_vocal, "B_MUTE", muteState == 0 and 1 or 0)
        end
      end)
    end
    reaper.ImGui_SameLine(State.ctx, nil, padding)
    do
      -- local c_sos = State.sos_ativo and State.cor_vermelho or State.cor_botao_padrao
      -- Gui.ImGui_ButtonTouch(State.ctx, "btn_sos", "SOS", largura, altura, c_sos, cor_hover_sup, Actions.btn_sos)
      
      -- reaper.ImGui_SameLine(State.ctx, nil, padding)
      local c_curta = State.versao_curta_ativo and State.cor_verde or State.cor_botao_padrao
      Gui.ImGui_ButtonTouch(State.ctx, "btn_curta", "VERSÃO CURTA", largura, altura, c_curta, cor_hover_sup, function()
        State.versao_curta_ativo = not State.versao_curta_ativo
      end)
      
      reaper.ImGui_SameLine(State.ctx, nil, padding)
      Gui.ImGui_ButtonTouch(State.ctx, "btn_pedal", "PEDAL", largura, altura, State.cor_botao_padrao, cor_hover_sup, Actions.btn_pedal)
      
      if State.sos_ativo then
        reaper.ImGui_SameLine(State.ctx, nil, padding)
        local cur_beat = 1

        if reaper.GetPlayState() & 1 == 1 then
          if State.sos_saindo then
            local elapsed = reaper.time_precise() - State.sos_start_saindo_time
            local bpm = reaper.TimeMap_GetDividedBpmAtTime(0, reaper.GetPlayPosition())
            if bpm <= 0 then bpm = 120 end
            local beats_elapsed = elapsed * (bpm / 60.0)
            local remaining = 4.0 - beats_elapsed
            if remaining < 0 then remaining = 0 end
            cur_beat = 4 - math.floor(remaining)
            if cur_beat < 1 then cur_beat = 1 end
            if cur_beat > 4 then cur_beat = 4 end
          else
            local retval, _, _, _, _ = reaper.TimeMap2_timeToBeats(0, reaper.GetPlayPosition())
            cur_beat = math.floor(retval) + 1
          end
        else
          local bpm = reaper.TimeMap_GetDividedBpmAtTime(0, reaper.GetCursorPosition())
          if bpm <= 0 then bpm = 120 end
          local elapsed = reaper.time_precise() - State.sos_start_time
          local beats_elapsed = elapsed * (bpm / 60.0)
          cur_beat = math.floor(beats_elapsed) % 4 + 1
        end

        local bg_color = (cur_beat == 1) and State.cor_vermelho or State.cor_branco
        local text_color = (cur_beat == 1) and State.cor_branco or State.cor_preto

        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_Button(), bg_color)
        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonHovered(), bg_color)
        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonActive(), bg_color)
        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_Text(), text_color)
        Gui.PushFont(State.ctx, State.font_huge, 40)
        
        reaper.ImGui_Button(State.ctx, tostring(cur_beat) .. "##sos_metro", largura, altura)
        
        Gui.PopFont(State.ctx)
        reaper.ImGui_PopStyleColor(State.ctx, 4)
      end
    end

    -------------------------------------------------------
    -- BADGES
    -------------------------------------------------------
    do
      local canvas_width_badges = reaper.ImGui_GetContentRegionAvail(State.ctx) - (State.padding_lateral * 2)
      local draw_list = reaper.ImGui_GetWindowDrawList(State.ctx)
      local cur_x, cur_y = reaper.ImGui_GetCursorScreenPos(State.ctx)
      local pos_x_badge = cur_x + State.padding_lateral
      local pos_y_badge = cur_y

      reaper.ImGui_DrawList_AddRectFilled(draw_list, pos_x_badge, pos_y_badge, pos_x_badge + canvas_width_badges, pos_y_badge + State.altura_info_lane, reaper.ImGui_ColorConvertDouble4ToU32(0.08,0.08,0.08,1))

      local lista = ReaperData.coletarItensInfoVisual()
      local tocando_now = reaper.GetPlayPosition()
      local is_playing = (reaper.GetPlayState() & 1) == 1
      local blink_on_badge = is_playing and (math.floor(os.clock() * 4) % 2 == 0)

      if #lista > 0 then
        for i, it in ipairs(lista) do
          local ix = pos_x_badge + (it.pos / math.max(0.0001, State.duracao)) * canvas_width_badges
          local iw = math.max(4, (it.len / math.max(0.0001, State.duracao)) * canvas_width_badges)
          local rx1, ry1 = ix, pos_y_badge
          local rx2, ry2 = ix + iw, pos_y_badge + State.altura_info_lane

          local is_skipping = State.versao_curta_ativo and (it.texto or ""):match("%*$") ~= nil
          local cor_final = is_skipping and reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1) or it.cor
          reaper.ImGui_DrawList_AddRectFilled(draw_list, rx1, ry1, rx2, ry2, cor_final, 4)
          reaper.ImGui_DrawList_AddRect(draw_list, rx1, ry1, rx2, ry2, reaper.ImGui_ColorConvertDouble4ToU32(1,1,1,0.08), 4, 0, 1)

          local is_current_song = (tocando_now >= it.pos and tocando_now < it.fim)
          if is_current_song and blink_on_badge then
            reaper.ImGui_DrawList_AddRect(draw_list, rx1, ry1, rx2, ry2, reaper.ImGui_ColorConvertDouble4ToU32(1.0, 0.9, 0.2, 1.0), 4, 0, 3)
          end

          if it.texto and it.texto ~= "" then
            local tw, th = reaper.ImGui_CalcTextSize(State.ctx, it.texto)
            local tx = rx1 + (iw - tw) * 0.5
            local ty = ry1 + (State.altura_info_lane - th) * 0.5
            reaper.ImGui_DrawList_AddText(draw_list, tx+1, ty+1, reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0.75), it.texto)
            reaper.ImGui_DrawList_AddText(draw_list, tx, ty, State.cor_branco, it.texto)
          end

          reaper.ImGui_SetCursorScreenPos(State.ctx, rx1, ry1)
          reaper.ImGui_InvisibleButton(State.ctx, "##badge_"..i, iw, State.altura_info_lane)
          if reaper.ImGui_IsItemClicked(State.ctx) then
            State.visao_completa = false
            State.salvar_config()
            local alvo_ini, alvo_fim = it.pos, it.fim
            local escolhido = State.idx_grupo_atual
            for gi, g in ipairs(State.grupos) do
              if not (g.fim <= alvo_ini or g.ini >= alvo_fim) then
                escolhido = gi; break
              end
            end
            State.idx_grupo_atual = escolhido
            State.seguir_reproducao = false
          end
        end
      end

      reaper.ImGui_SetCursorScreenPos(State.ctx, cur_x, pos_y_badge + State.altura_info_lane)
      reaper.ImGui_Dummy(State.ctx, 1, 8)
      local label_visao = State.visao_completa and "Voltar por música" or "Visão completa"
      if reaper.ImGui_Button(State.ctx, label_visao, 180, 26) then
        State.visao_completa = not State.visao_completa
        State.salvar_config()
      end

      reaper.ImGui_SameLine(State.ctx, nil, 12)
      local lbl_seg = State.seguir_reproducao and "Travar visão" or "Seguir reprodução"
      if reaper.ImGui_Button(State.ctx, lbl_seg, 160, 26) then
        State.seguir_reproducao = not State.seguir_reproducao
      end

      reaper.ImGui_SameLine(State.ctx, nil, 12)
      local is_blocked = Actions.is_autoplay_blocked_for_project(current_project_id)
      local lbl_auto = is_blocked and "Autoplay no Proj: BLOQUEADO" or "Autoplay no Proj: LIBERADO"
      local cor_btn = is_blocked and State.cor_vermelho or State.cor_verde
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_Button(), cor_btn)
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonHovered(), cor_btn)
      reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonActive(), cor_btn)
      if reaper.ImGui_Button(State.ctx, lbl_auto, 240, 26) then
        Actions.toggle_project_autoplay(current_project_id)
      end
      reaper.ImGui_PopStyleColor(State.ctx, 3)
    end

    -------------------------------------------------------
    -- WAVEFORM
    -------------------------------------------------------
    reaper.ImGui_Separator(State.ctx)
    local canvas_width = reaper.ImGui_GetContentRegionAvail(State.ctx) - (State.padding_lateral * 2)
    local canvas_height = State.altura_waveform
    local draw_list = reaper.ImGui_GetWindowDrawList(State.ctx)
    local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(State.ctx)
    pos_x = pos_x + State.padding_lateral

    if not State.last_waveform_width or State.last_waveform_width ~= math.floor(canvas_width) then
      State.waveform = ReaperData.gerarWaveformFake(math.floor(canvas_width))
      State.last_waveform_width = math.floor(canvas_width)
    end

    reaper.ImGui_DrawList_AddRectFilled(draw_list, pos_x, pos_y, pos_x + canvas_width, pos_y + canvas_height, State.cor_preto)

    local tocando = reaper.GetPlayPosition()
    local is_playing = reaper.GetPlayState() & 1 == 1

    if (not State.visao_completa) and State.auto_scroll_grupos and State.seguir_reproducao and #State.grupos > 0 then
      local g = State.grupos[State.idx_grupo_atual]
      if     (tocando > (g.fim - State.margem_troca)) and State.idx_grupo_atual < #State.grupos then State.idx_grupo_atual = State.idx_grupo_atual + 1
      elseif (tocando < (g.ini + State.margem_troca)) and State.idx_grupo_atual > 1 then      State.idx_grupo_atual = State.idx_grupo_atual - 1
      else
        for i, gg in ipairs(State.grupos) do
          if tocando >= gg.ini - 1e-6 and tocando < gg.fim - 1e-6 then State.idx_grupo_atual = i; break end
        end
      end
    end

    local g_ini, g_fim = 0, State.duracao
    if (not State.visao_completa) and #State.grupos > 0 then
      if State.seguir_reproducao then
        local novo = State.idx_grupo_atual
        for i, gg in ipairs(State.grupos) do
          if tocando >= gg.ini - 1e-6 and tocando < gg.fim - 1e-6 then novo = i; break end
        end
        if tocando >= State.grupos[#State.grupos].fim - 1e-6 then novo = #State.grupos end
        State.idx_grupo_atual = novo
      end
      g_ini, g_fim = State.grupos[State.idx_grupo_atual].ini, State.grupos[State.idx_grupo_atual].fim
    end
    local cor_grupo_atual = (not State.visao_completa) and (State.grupos[State.idx_grupo_atual] and State.grupos[State.idx_grupo_atual].color or nil) or nil
    local g_len = math.max(0.0001, g_fim - g_ini)

    local eps = 1e-6
    if (not State.visao_completa) then
      if State.regiao_clicada_id then
        local i_sel = tonumber(State.regiao_clicada_id:match("regiao_(%d+)"))
        local rr = i_sel and State.regioes[i_sel]
        if (not rr) or rr.color ~= cor_grupo_atual or rr.rgnend <= g_ini + eps or rr.pos >= g_fim - eps or (tocando >= rr.pos and tocando < rr.rgnend) then
          State.regiao_clicada_id = nil
        end
      end
      if State.click_pendente and State.click_pendente.id then
        local i_p = tonumber(tostring(State.click_pendente.id):match("regiao_(%d+)"))
        local rr = i_p and State.regioes[i_p]
        if (not rr) or rr.color ~= cor_grupo_atual or rr.rgnend <= g_ini + eps or rr.pos >= g_fim - eps then
          State.click_pendente = nil
        end
      end
    end

    for i = 1, math.min(canvas_width, #State.waveform) do
      local h = State.waveform[i] * canvas_height
      local x = pos_x + i
      local y = pos_y + (canvas_height - h) / 2
      local t = g_ini + (i / canvas_width) * g_len
      local cor = (t <= tocando) and State.cor_branco or State.cor_cinza
      reaper.ImGui_DrawList_AddLine(draw_list, x, y, x, y + h, cor)
    end

    local play_state_atual = reaper.GetPlayState()
    if State.play_state_anterior == 1 and play_state_atual == 0 then
      local ultima = State.regioes[#State.regioes]
      if ultima and (State.hold_ativo or State.autoplay_ativo) then
        if tocando >= (ultima.rgnend - 0.3) and tocando < ultima.rgnend then
          if State.autoplay_ativo then
            local current_blocks = Actions.is_autoplay_blocked_for_project(current_project_id)
            local next_proj = Actions.get_next_project(current_project_id)
            local next_blocks = next_proj and Actions.is_autoplay_blocked_for_project(next_proj) or false
            
            if current_blocks or next_blocks then
              reaper.Main_OnCommand(40861, 0)
              reaper.defer(function() reaper.SetEditCurPos(0, true, false) end)
            else
              reaper.Main_OnCommand(40861, 0)
              reaper.defer(function() reaper.SetEditCurPos(0, true, false); reaper.Main_OnCommand(1007, 0) end)
            end
          elseif State.hold_ativo then
            reaper.Main_OnCommand(40861, 0)
            reaper.defer(function() reaper.SetEditCurPos(0, true, false) end)
          end
        end
      end
    end
    State.play_state_anterior = play_state_atual

    local blink_on_region = is_playing and (math.floor(os.clock() * 4) % 2 == 0)

    local altura_botoes = 70
    local offset_altura_superior = 80
    local regiao_tocando_id = nil
    for i, reg in ipairs(State.regioes) do
      if tocando >= reg.pos and tocando < reg.rgnend then regiao_tocando_id = "regiao_" .. tostring(i); break end
    end

    for i, reg in ipairs(State.regioes) do
      local id = "regiao_" .. tostring(i)
      local dentro_range = not (reg.rgnend <= g_ini + eps or reg.pos >= g_fim - eps)
      local passa_cor = State.visao_completa or (cor_grupo_atual and reg.color == cor_grupo_atual)

      if dentro_range and passa_cor then
        local x = pos_x + ((reg.pos - g_ini) / g_len) * canvas_width
        local y_base = pos_y + canvas_height - altura_botoes
        local y = (i % 2 == 0) and y_base or (y_base - offset_altura_superior)

        local b = ((reg.color >> 16) & 0xFF) / 255
        local g = ((reg.color >> 8) & 0xFF) / 255
        local r = (reg.color & 0xFF) / 255
        local cor_rg = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, 1)

        local is_tocando_reg = regiao_tocando_id == id
        local is_clicada = State.regiao_clicada_id == id
        local tocando_flag = reaper.GetPlayState() & 1 == 1

        local piscar = (is_tocando_reg or is_clicada) and tocando_flag and blink_on_region
        local mostrar_vermelho_solido = is_clicada and not tocando_flag

        local cor_linha = cor_rg
        if piscar or mostrar_vermelho_solido then
          cor_linha = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1)
        end
        for off = -1, 1 do
          reaper.ImGui_DrawList_AddLine(draw_list, x + off, y + altura_botoes, x + off, pos_y, cor_linha)
        end

        local nome = reg.name ~= "" and reg.name or "Região"
        local text_w = reaper.ImGui_CalcTextSize(State.ctx, nome)
        local base_w = text_w + 20
        local min_w  = (not State.visao_completa) and State.largura_btn_musica or State.largura_btn_completa
        local w = math.max(base_w, min_w)

        local is_skipping = State.versao_curta_ativo and nome:match("%*$") ~= nil
        local cor_btn = piscar and reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1) or (mostrar_vermelho_solido and reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1) or cor_rg)
        if is_skipping then cor_btn = reaper.ImGui_ColorConvertDouble4ToU32(0.15, 0.15, 0.15, 1) end

        reaper.ImGui_SetCursorScreenPos(State.ctx, x, y)
        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_Button(), cor_btn)
        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonHovered(), cor_btn)
        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_ButtonActive(), cor_btn)
        reaper.ImGui_PushStyleColor(State.ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,1))
        Gui.PushFont(State.ctx, State.font_bold, 16)
        local clicked = reaper.ImGui_Button(State.ctx, nome .. "##" .. id, w, altura_botoes)
        Gui.PopFont(State.ctx)
        reaper.ImGui_PopStyleColor(State.ctx, 4)

        if clicked then
          if not State.usar_dois_cliques then
            if State.regiao_clicada_id == id then
              State.regiao_clicada_id = nil
              if regiao_tocando_id then
                local idx = tonumber(regiao_tocando_id:match("regiao_(%d+)"))
                if idx and State.regioes[idx] then reaper.SetEditCurPos(State.regioes[idx].rgnend, true, true) end
              end
            else
              State.regiao_clicada_id = id
              reaper.SetEditCurPos(reg.pos, true, true)
            end
            if State.modo_tela_touch then reaper.JS_Mouse_SetPosition(0, 0) end
          else
            if State.click_pendente and State.click_pendente.id == id then
              if State.regiao_clicada_id == id then
                State.regiao_clicada_id = nil
                if regiao_tocando_id then
                  local idx = tonumber(regiao_tocando_id:match("regiao_(%d+)"))
                  if idx and State.regioes[idx] then reaper.SetEditCurPos(State.regioes[idx].rgnend, true, true) end
                end
              else
                State.regiao_clicada_id = id
                reaper.SetEditCurPos(reg.pos, true, true)
              end
              State.click_pendente = nil
              if State.modo_tela_touch then reaper.JS_Mouse_SetPosition(0, 0) end
            else
              State.click_pendente = { id = id }
              State.tempo_primeiro_click = reaper.time_precise()
            end
          end
        end
      end
    end

    Actions.tick()

    local t_norm = (tocando - g_ini) / g_len
    if t_norm < 0 then t_norm = 0 elseif t_norm > 1 then t_norm = 1 end
    local play_x = pos_x + t_norm * canvas_width
    reaper.ImGui_DrawList_AddLine(draw_list, play_x, pos_y, play_x, pos_y + canvas_height, State.cor_reproducao, 2.0)

    reaper.ImGui_SetCursorScreenPos(State.ctx, pos_x - State.padding_lateral, pos_y + canvas_height + 12)
    reaper.ImGui_Dummy(State.ctx, 1, 1)

    local largura_repertorio, altura_repertorio, padding_repertorio = 140, 60, 10
    Gui.ImGui_ButtonTouch(State.ctx, "btn9",  "REPERTÓRIO", largura_repertorio, altura_repertorio, State.cor_botao_padrao, State.cor_amarelo, function() reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PROJLIST_OPEN"), 0) end)
    reaper.ImGui_SameLine(State.ctx, nil, padding_repertorio)
    Gui.ImGui_ButtonTouch(State.ctx, "btn10", "SALVAR", largura_repertorio, altura_repertorio, State.cor_botao_padrao, State.cor_amarelo, function() reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PROJLISTSAVE"), 0) end)
    reaper.ImGui_SameLine(State.ctx, nil, padding_repertorio)
    Gui.ImGui_ButtonTouch(State.ctx, "btn11", "ABRIR",  largura_repertorio, altura_repertorio, State.cor_botao_padrao, State.cor_amarelo, function() reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PROJLISTSOPEN"), 0) end)

    reaper.ImGui_End(State.ctx)
  end
  return open
end

return Gui
