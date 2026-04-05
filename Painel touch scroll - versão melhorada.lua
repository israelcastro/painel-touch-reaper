--@description Painel touch (scroll por música) + Badges interativos + Doc
--@version 0.3.2
--@author Israel Castro
--@noindex
--@changelog
-- 0.3.2  Cabeçalho documentado + pequenos ajustes de robustez
--@requires ReaImGui v0.9.3.3, JS_ReaScriptAPI
--[[
==============================================================================
PAINEL TOUCH – RESUMO RÁPIDO
------------------------------------------------------------------------------
1) O QUE É
   Painel unificado com:
   - Botões principais (PLAY/STOP, HOLD, AUTO PLAY, ANTERIOR, PRÓXIMO, LOOP,
     SOMENTE CLICK, VOCAL REFERÊNCIA)
   - Faixa “INFORMAÇÃO VISUAL” com badges clicáveis (baseado nos empty items)
   - Waveform + botões de regiões com scroll horizontal por MÚSICA (grupos por cor)
   - Alternância entre Visão Completa e Visão por Música

2) COMO IDENTIFICAMOS CADA MÚSICA
   - Todas as regiões que pertencem à mesma música têm a MESMA COR.
   - O script agrupa regiões contíguas por cor → cada grupo = uma música.

3) REGRAS DO SCROLL
   - Em “Visão por música”: a waveform mostra apenas o intervalo da música atual
     (grupo por cor) e EXIBE SOMENTE os botões das regiões daquela música.
   - Em “Visão completa”: mostra o projeto inteiro e exibe todos os botões.
   - As badges (da faixa “INFORMAÇÃO VISUAL”) permitem navegar visualmente:
     ao clicar em uma badge, a Visão por música muda para a música que cobre
     aquele intervalo (sem mover o cursor de reprodução).

4) PISCAR (indicação visual)
   - Badge da música que está TOCANDO pisca (borda amarela).
   - Botões das regiões tocando/clicadas piscam em vermelho quando tocando.

5) BOTÕES ESPECIAIS
   - SOMENTE CLICK: faz fade out/in de todas as tracks exceto “CLICK”.
   - VOCAL REFERÊNCIA: procura a track com “VOZ REFERENCIA” no nome e mute/unmute.
   - HOLD e AUTO PLAY: comportamentos ao final do projeto (exclusivos entre si).

6) PERSISTÊNCIA (salva em painel_config.ini)
   - usar_dois_cliques, modo_tela_touch, hold_ativo, autoplay_ativo, visao_completa.

7) DICAS
   - Para os badges funcionarem, crie a track chamada exatamente
     “INFORMAÇÃO VISUAL” e use empty items (ou itens com notas).
   - O nome do item (P_NOTES ou take name) vira o texto da badge.
==============================================================================
]]


---------------------------------------
-- CONTEXTO / FONTES
---------------------------------------
local ctx = reaper.ImGui_CreateContext('Painel touch', 0)
local font_bold_path = reaper.GetResourcePath() .. "/Scripts/Fontes/Montserrat-Bold.ttf"
local font_bold = reaper.ImGui_CreateFont(font_bold_path, 16)
reaper.ImGui_Attach(ctx, font_bold)

---------------------------------------
-- ESTADO
---------------------------------------
local usar_dois_cliques = true
local modo_tela_touch = true
local padding_lateral = 20

local botao2_ativo = false
local click_pendente = nil
local tempo_primeiro_click = 0
local tempo_limite_2cliques = 1.2

local regiao_clicada_id = nil
local last_waveform_width = nil
local altura_waveform = 250
local last_project_id = reaper.EnumProjects(-1, "")
local loop_ativo = false
local volumes_originais = {}
local fade_duration = 1
local fade_start_time = nil
local fading_out = false
local fading_in = false
local hold_ativo = false
local play_state_anterior = reaper.GetPlayState()
local autoplay_ativo = false

-- “faixa de INFO VISUAL”
local nome_track_info_visual = "INFORMAÇÃO VISUAL"
local altura_info_lane = 36
local gap_info_lane = 8

-- regiões e “músicas” (grupos por cor contígua)
local regioes = {}
local grupos = {}                 -- { {ini, fim, color}, ... }
local idx_grupo_atual = 1
local auto_scroll_grupos = true
local margem_troca = 0.02         -- seg

-- visão completa (opcional)
local visao_completa = false

---------------------------------------
-- CORES
---------------------------------------
local cor_vermelho   = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1)
local cor_verde      = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.8, 0.2, 1)
local cor_cinza      = reaper.ImGui_ColorConvertDouble4ToU32(0.3, 0.3, 0.3, 1)
local cor_amarelo    = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 0.2, 1)
local cor_branco     = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1)
local cor_preto      = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1)
local cor_reproducao = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1)
local cor_botao_padrao = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Button())
local cor_texto_padrao = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text())

---------------------------------------
-- CONFIG
---------------------------------------
local config_path = reaper.GetResourcePath() .. "/Scripts/painel_config.ini"
local function salvar_config()
  local f = io.open(config_path, "w")
  if f then
    f:write("usar_dois_cliques=" .. (usar_dois_cliques and "1" or "0") .. "\n")
    f:write("modo_tela_touch=" .. (modo_tela_touch and "1" or "0") .. "\n")
    f:write("hold_ativo=" .. (hold_ativo and "1" or "0") .. "\n")
    f:write("autoplay_ativo=" .. (autoplay_ativo and "1" or "0") .. "\n")
    f:write("visao_completa=" .. (visao_completa and "1" or "0") .. "\n")
    f:close()
  end
end
local function carregar_config()
  local f = io.open(config_path, "r")
  if f then
    for line in f:lines() do
      local key, val = line:match("^(.-)=(.-)$")
      if key == "usar_dois_cliques" then
        usar_dois_cliques = val == "1"
      elseif key == "modo_tela_touch" then
        modo_tela_touch = val == "1"
      elseif key == "hold_ativo" then
        hold_ativo = (val == "1")
      elseif key == "autoplay_ativo" then
        autoplay_ativo = (val == "1")
      elseif key == "visao_completa" then
        visao_completa = (val == "1")
      end
    end
    f:close()
  end
end
carregar_config()

---------------------------------------
-- WAVEFORM FAKE (mesmo esquema do seu script)
---------------------------------------
local waveform = {}
local function gerarWaveformFake(n)
  local wf = {}
  for i = 1, n do wf[i] = math.random() end
  return wf
end
local duracao = 10
waveform = gerarWaveformFake(1000)

---------------------------------------
-- REGIÕES / GRUPOS
---------------------------------------
local function montar_grupos_por_cor()
  grupos = {}
  if not regioes or #regioes == 0 then return end
  table.sort(regioes, function(a,b) return a.pos < b.pos end)

  local g_ini = regioes[1].pos
  local g_fim = regioes[1].rgnend
  local g_color = regioes[1].color

  for i = 2, #regioes do
    local r = regioes[i]
    if r.color == g_color and r.pos <= g_fim + 0.0001 then
      g_fim = math.max(g_fim, r.rgnend)
    else
      grupos[#grupos+1] = {ini=g_ini, fim=g_fim, color=g_color}
      g_ini, g_fim, g_color = r.pos, r.rgnend, r.color
    end
  end
  grupos[#grupos+1] = {ini=g_ini, fim=g_fim, color=g_color}

  local playpos = reaper.GetPlayPosition()
  local novo = 1
  for i, g in ipairs(grupos) do
    if playpos >= g.ini - 1e-6 and playpos < g.fim - 1e-6 then
      novo = i; break
    end
  end
  if playpos >= grupos[#grupos].fim - 1e-6 then novo = #grupos end
  idx_grupo_atual = novo
end

local function carregarRegioes()
  regioes = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  duracao = 10
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and isrgn then
      regioes[#regioes+1] = {pos=pos, rgnend=rgnend, name=name or "", color=color or 0}
      if rgnend > duracao then duracao = rgnend end
    end
  end
  montar_grupos_por_cor()
end
carregarRegioes()

---------------------------------------
-- UTIL
---------------------------------------
local function ImGui_ButtonTouch(ctx, id, label, w, h, cor_normal, cor_ativo, acao)
  local agora = reaper.time_precise()
  local cor = cor_normal
  if click_pendente and click_pendente.id == id then
    if agora - tempo_primeiro_click > tempo_limite_2cliques then
      click_pendente = nil
    else
      cor = cor_ativo
    end
  end
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), cor)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), cor)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), cor)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), cor_branco)
  reaper.ImGui_PushFont(ctx, reaper.ImGui_GetFont(ctx))
  local clicked = reaper.ImGui_Button(ctx, label, w, h)
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)
  if clicked then
    if not usar_dois_cliques then
      acao()
      if modo_tela_touch then reaper.JS_Mouse_SetPosition(0, 0) end
    else
      if click_pendente and click_pendente.id == id then
        acao(); click_pendente = nil
      else
        click_pendente = { id = id }
        tempo_primeiro_click = agora
      end
    end
  end
end

-- Botões principais
local function btn_play_stop()
  local state = reaper.GetPlayState()
  if state & 1 == 1 then reaper.Main_OnCommand(1016, 0) else reaper.Main_OnCommand(1007, 0) end
end
local function btn_alerta_hold()
  hold_ativo = not hold_ativo
  if hold_ativo then autoplay_ativo = false end
  salvar_config()
end
local function btn_alerta_autoplay()
  autoplay_ativo = not autoplay_ativo
  if autoplay_ativo then hold_ativo = false end
  salvar_config()
end
local function btn_anterior()
  reaper.Main_OnCommand(40862, 0) -- previous project
end
local function btn_proximo()
  reaper.Main_OnCommand(40861, 0) -- next project
end
local function btn_loop()
  local tocando = reaper.GetPlayPosition()
  for _, reg in ipairs(regioes) do
    if tocando >= reg.pos and tocando < reg.rgnend then
      if not loop_ativo then
        reaper.GetSet_LoopTimeRange(true, false, reg.pos, reg.rgnend, false)
        reaper.Main_OnCommand(1068, 0) -- enable loop
        loop_ativo = true
      else
        reaper.Main_OnCommand(1068, 0) -- disable loop
        reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)
        loop_ativo = false
      end
      break
    end
  end
end

-- “INFORMAÇÃO VISUAL”
local function encontrarTrackInfoVisual()
  local alvo = nome_track_info_visual:upper()
  alvo = alvo:gsub("Ç","C"):gsub("Á","A"):gsub("Ã","A"):gsub("Â","A"):gsub("É","E"):gsub("Ê","E"):gsub("Í","I"):gsub("Ó","O"):gsub("Ô","O"):gsub("Ú","U")
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    local n = (name or ""):upper()
    n = n:gsub("Ç","C"):gsub("Á","A"):gsub("Ã","A"):gsub("Â","A"):gsub("É","E"):gsub("Ê","E"):gsub("Í","I"):gsub("Ó","O"):gsub("Ô","O"):gsub("Ú","U")
    if n == alvo then return tr end
  end
  return nil
end

local function coletarItensInfoVisual()
  local itens, tr = {}, encontrarTrackInfoVisual()
  if not tr then return itens end
  local itemCount = reaper.CountTrackMediaItems(tr)
  for i = 0, itemCount - 1 do
    local it = reaper.GetTrackMediaItem(tr, i)
    local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
    local fim = pos + len
    local ok, notes = reaper.GetSetMediaItemInfo_String(it, "P_NOTES", "", false)
    if not ok then notes = "" end
    if notes == "" then
      local tk = reaper.GetActiveTake(it)
      if tk then
        local _, tkname = reaper.GetSetMediaItemTakeInfo_String(tk, "P_NAME", "", false)
        notes = tkname or ""
      end
    end
    local color = reaper.GetDisplayedMediaItemColor(it) or 0
    local r,g,b
    if color == 0 or color == -1 then r,g,b = 0.20,0.20,0.20
    else
      r = (color & 0xFF) / 255.0
      g = ((color >> 8) & 0xFF) / 255.0
      b = ((color >> 16) & 0xFF) / 255.0
    end
    itens[#itens+1] = {pos=pos, fim=fim, len=len, texto=notes, cor=reaper.ImGui_ColorConvertDouble4ToU32(r,g,b,1)}
  end
  return itens
end

---------------------------------------
-- LOOP
---------------------------------------
local function loop()
  local current_project_id = reaper.EnumProjects(-1, "")
  if current_project_id ~= last_project_id then
    last_project_id = current_project_id
    carregarRegioes()
    last_waveform_width = nil
    regiao_clicada_id = nil
  end

  local visible, open = reaper.ImGui_Begin(ctx, 'Painel touch', true)
  reaper.ImGui_Dummy(ctx, padding_lateral, 0)
  reaper.ImGui_SameLine(ctx)

  if visible then
    -- título
    local _, project_path = reaper.EnumProjects(-1, "")
    local project_name = project_path:match("([^\\/]+)%.rpp$") or "(Projeto sem nome)"
    reaper.ImGui_Text(ctx, "Projeto: " .. project_name)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_NewLine(ctx)

    -- toggles
    do
      local cor_modo_dois = usar_dois_cliques and cor_verde or cor_botao_padrao
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), cor_modo_dois)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), cor_modo_dois)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), cor_modo_dois)
      if reaper.ImGui_Button(ctx, usar_dois_cliques and "Modo: Dois Cliques (Ativo)" or "Modo: Dois Cliques (Desativo)", 300, 30) then
        usar_dois_cliques = not usar_dois_cliques; salvar_config()
      end
      reaper.ImGui_PopStyleColor(ctx, 3)
    end
    reaper.ImGui_SameLine(ctx, nil, 20)
    do
      local cor_modo_touch = modo_tela_touch and cor_verde or cor_botao_padrao
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), cor_modo_touch)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), cor_modo_touch)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), cor_modo_touch)
      if reaper.ImGui_Button(ctx, modo_tela_touch and "Modo: Tela Touch (Ativo)" or "Modo: Tela Touch (Desativo)", 300, 30) then
        modo_tela_touch = not modo_tela_touch; salvar_config()
      end
      reaper.ImGui_PopStyleColor(ctx, 3)
    end

    -- botões 01..08
    local largura, altura, padding = 140, 100, 10
    local cor_hover_sup = cor_amarelo
    ImGui_ButtonTouch(ctx, "btn1", "PLAY/STOP", largura, altura, cor_botao_padrao, cor_hover_sup, btn_play_stop); reaper.ImGui_SameLine(ctx, nil, padding)
    do
      local c = hold_ativo and cor_verde or cor_botao_padrao
      ImGui_ButtonTouch(ctx, "btn2", "HOLD", largura, altura, c, cor_hover_sup, btn_alerta_hold)
    end
    reaper.ImGui_SameLine(ctx, nil, padding)
    do
      local c = autoplay_ativo and cor_verde or cor_botao_padrao
      ImGui_ButtonTouch(ctx, "btn3", "AUTO PLAY", largura, altura, c, cor_hover_sup, btn_alerta_autoplay)
    end
    reaper.ImGui_SameLine(ctx, nil, padding)
    ImGui_ButtonTouch(ctx, "btn4", "ANTERIOR", largura, altura, cor_botao_padrao, cor_hover_sup, btn_anterior); reaper.ImGui_SameLine(ctx, nil, padding)
    ImGui_ButtonTouch(ctx, "btn5", "PRÓXIMO",  largura, altura, cor_botao_padrao, cor_hover_sup, btn_proximo);  reaper.ImGui_SameLine(ctx, nil, padding)
    do
      local alpha = 1; if loop_ativo and (math.floor(os.clock() * 4) % 2 == 0) then alpha = 0.3 end
      local c = loop_ativo and reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.8, 0.2, alpha) or cor_botao_padrao
      ImGui_ButtonTouch(ctx, "btn6", "LOOP", largura, altura, c, cor_hover_sup, btn_loop)
    end
    reaper.ImGui_SameLine(ctx, nil, padding)
    do
      local c_verm = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1)
      local c_dour = reaper.ImGui_ColorConvertDouble4ToU32(1.00, 1.00, 0.30, 0.9)
      local c_normal = (botao2_ativo and (math.floor(os.clock() * 4) % 2 == 0)) and c_dour or c_verm
      ImGui_ButtonTouch(ctx, "btn7", "SOMENTE CLICK", largura, altura, c_normal, cor_amarelo, function()
        botao2_ativo = not botao2_ativo
        fade_start_time = reaper.time_precise()
        if botao2_ativo then
          volumes_originais = {}
          for i = 0, reaper.CountTracks(0) - 1 do
            local tr = reaper.GetTrack(0, i)
            local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            local vol = reaper.GetMediaTrackInfo_Value(tr, "D_VOL")
            volumes_originais[i] = vol
            if (name or ""):upper() ~= "CLICK" then
              reaper.SetMediaTrackInfo_Value(tr, "D_VOL", vol)
            end
          end
          fading_out, fading_in = true, false
        else
          fade_start_time = reaper.time_precise()
          fading_in, fading_out = true, false
        end
      end)
    end
    reaper.ImGui_SameLine(ctx, nil, padding)
    do
      local track_vocal
      for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        local name_upper = (name or ""):upper():gsub("Ê","E")
        if name_upper:find("VOZ REFERENCIA") then track_vocal = tr; break end
      end
      local muteState = track_vocal and reaper.GetMediaTrackInfo_Value(track_vocal, "B_MUTE") or 0
      local c = muteState == 1 and cor_vermelho or cor_verde
      ImGui_ButtonTouch(ctx, "btn8", "VOCAL REFERÊNCIA", largura, altura, c, cor_hover_sup, function()
        if track_vocal then
          reaper.SetMediaTrackInfo_Value(track_vocal, "B_MUTE", muteState == 0 and 1 or 0)
        end
      end)
    end

    -------------------------------------------------------
    -- BADGES “INFORMAÇÃO VISUAL” (clicáveis + piscar do atual)
    -------------------------------------------------------
    do
      local canvas_width_badges = reaper.ImGui_GetContentRegionAvail(ctx) - (padding_lateral * 2)
      local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
      local cur_x, cur_y = reaper.ImGui_GetCursorScreenPos(ctx)
      local pos_x_badge = cur_x + padding_lateral
      local pos_y_badge = cur_y

      -- fundo da faixa
      reaper.ImGui_DrawList_AddRectFilled(draw_list, pos_x_badge, pos_y_badge, pos_x_badge + canvas_width_badges, pos_y_badge + altura_info_lane, reaper.ImGui_ColorConvertDouble4ToU32(0.08,0.08,0.08,1))

      local lista = coletarItensInfoVisual()
      local tocando_now = reaper.GetPlayPosition()
      local is_playing = (reaper.GetPlayState() & 1) == 1
      local blink_on_badge = is_playing and (math.floor(os.clock() * 4) % 2 == 0)

      if #lista > 0 then
        for i, it in ipairs(lista) do
          local ix = pos_x_badge + (it.pos / math.max(0.0001, duracao)) * canvas_width_badges
          local iw = math.max(4, (it.len / math.max(0.0001, duracao)) * canvas_width_badges)
          local rx1, ry1 = ix, pos_y_badge
          local rx2, ry2 = ix + iw, pos_y_badge + altura_info_lane

          -- retângulo base
          reaper.ImGui_DrawList_AddRectFilled(draw_list, rx1, ry1, rx2, ry2, it.cor, 4)
          -- borda leve
          reaper.ImGui_DrawList_AddRect(draw_list, rx1, ry1, rx2, ry2, reaper.ImGui_ColorConvertDouble4ToU32(1,1,1,0.08), 4, 0, 1)

          local is_current_song = (tocando_now >= it.pos and tocando_now < it.fim)
          if is_current_song and blink_on_badge then
            -- borda piscante (amarelo)
            reaper.ImGui_DrawList_AddRect(draw_list, rx1, ry1, rx2, ry2, reaper.ImGui_ColorConvertDouble4ToU32(1.0, 0.9, 0.2, 1.0), 4, 0, 3)
          end

          -- texto
          if it.texto and it.texto ~= "" then
            local tw, th = reaper.ImGui_CalcTextSize(ctx, it.texto)
            local tx = rx1 + (iw - tw) * 0.5
            local ty = ry1 + (altura_info_lane - th) * 0.5
            reaper.ImGui_DrawList_AddText(draw_list, tx+1, ty+1, reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0.75), it.texto)
            reaper.ImGui_DrawList_AddText(draw_list, tx, ty, cor_branco, it.texto)
          end

          -- tornar o badge clicável (InvisibleButton sobre a área do badge)
          reaper.ImGui_SetCursorScreenPos(ctx, rx1, ry1)
          reaper.ImGui_InvisibleButton(ctx, "##badge_"..i, iw, altura_info_lane)
          if reaper.ImGui_IsItemClicked(ctx) then
            -- ao clicar: sair da visão completa e ir para o grupo que cobre o badge (sem mover playhead)
            visao_completa = false
            salvar_config()

            local alvo_ini, alvo_fim = it.pos, it.fim
            local escolhido = idx_grupo_atual
            for gi, g in ipairs(grupos) do
              if not (g.fim <= alvo_ini or g.ini >= alvo_fim) then
                escolhido = gi; break
              end
            end
            idx_grupo_atual = escolhido
            -- importante: NÃO movemos o cursor de reprodução
          end
        end
      end

      -- empurrar layout
      reaper.ImGui_SetCursorScreenPos(ctx, cur_x, pos_y_badge + altura_info_lane)
      reaper.ImGui_Dummy(ctx, 1, 8)

      -- Toggle Visão completa / Voltar por música (antes da waveform)
      local label_visao = visao_completa and "Voltar por música" or "Visão completa"
      if reaper.ImGui_Button(ctx, label_visao, 180, 26) then
        visao_completa = not visao_completa
        salvar_config()
      end
    end

    -------------------------------------------------------
    -- WAVEFORM + REGIÕES
    -------------------------------------------------------
    reaper.ImGui_Separator(ctx)
    local canvas_width = reaper.ImGui_GetContentRegionAvail(ctx) - (padding_lateral * 2)
    local canvas_height = altura_waveform
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
    pos_x = pos_x + padding_lateral

    if not last_waveform_width or last_waveform_width ~= math.floor(canvas_width) then
      waveform = gerarWaveformFake(math.floor(canvas_width))
      last_waveform_width = math.floor(canvas_width)
    end

    reaper.ImGui_DrawList_AddRectFilled(draw_list, pos_x, pos_y, pos_x + canvas_width, pos_y + canvas_height, cor_preto)

    local tocando = reaper.GetPlayPosition()
    local is_playing = reaper.GetPlayState() & 1 == 1

    -- avançar grupo automaticamente (se NÃO estiver em visão completa)
    if (not visao_completa) and auto_scroll_grupos and #grupos > 0 then
      local g = grupos[idx_grupo_atual]
      if     (tocando > (g.fim - margem_troca)) and idx_grupo_atual < #grupos then idx_grupo_atual = idx_grupo_atual + 1
      elseif (tocando < (g.ini + margem_troca)) and idx_grupo_atual > 1 then      idx_grupo_atual = idx_grupo_atual - 1
      else
        for i, gg in ipairs(grupos) do
          if tocando >= gg.ini - 1e-6 and tocando < gg.fim - 1e-6 then idx_grupo_atual = i; break end
        end
      end
    end

    -- range exibido (grupo atual OU projeto inteiro)
    local g_ini, g_fim = 0, duracao
    if (not visao_completa) and #grupos > 0 then
      -- re-sincroniza pelo playhead
      local novo = idx_grupo_atual
      for i, gg in ipairs(grupos) do
        if tocando >= gg.ini - 1e-6 and tocando < gg.fim - 1e-6 then novo = i; break end
      end
      if tocando >= grupos[#grupos].fim - 1e-6 then novo = #grupos end
      idx_grupo_atual = novo
      g_ini, g_fim = grupos[idx_grupo_atual].ini, grupos[idx_grupo_atual].fim
    end
    local cor_grupo_atual = (not visao_completa) and (grupos[idx_grupo_atual] and grupos[idx_grupo_atual].color or nil) or nil
    local g_len = math.max(0.0001, g_fim - g_ini)

    -- limpar seleção/pendências se saíram do grupo/cor (apenas quando não é visão completa)
    local eps = 1e-6
    if (not visao_completa) then
      if regiao_clicada_id then
        local i_sel = tonumber(regiao_clicada_id:match("regiao_(%d+)"))
        local rr = i_sel and regioes[i_sel]
        if (not rr) or rr.color ~= cor_grupo_atual or rr.rgnend <= g_ini + eps or rr.pos >= g_fim - eps then
          regiao_clicada_id = nil
        end
      end
      if click_pendente and click_pendente.id then
        local i_p = tonumber(tostring(click_pendente.id):match("regiao_(%d+)"))
        local rr = i_p and regioes[i_p]
        if (not rr) or rr.color ~= cor_grupo_atual or rr.rgnend <= g_ini + eps or rr.pos >= g_fim - eps then
          click_pendente = nil
        end
      end
    end

    -- waveform (range escolhido)
    for i = 1, math.min(canvas_width, #waveform) do
      local h = waveform[i] * canvas_height
      local x = pos_x + i
      local y = pos_y + (canvas_height - h) / 2
      local t = g_ini + (i / canvas_width) * g_len
      local cor = (t <= tocando) and cor_branco or cor_cinza
      reaper.ImGui_DrawList_AddLine(draw_list, x, y, x, y + h, cor)
    end

    -- “parou?” (hold/autoplay)
    local play_state_atual = reaper.GetPlayState()
    if play_state_anterior == 1 and play_state_atual == 0 then
      local ultima = regioes[#regioes]
      if ultima and (hold_ativo or autoplay_ativo) then
        if tocando >= (ultima.rgnend - 0.3) and tocando < ultima.rgnend then
          if autoplay_ativo then
            reaper.Main_OnCommand(40861, 0)
            reaper.defer(function() reaper.SetEditCurPos(0, true, false); reaper.Main_OnCommand(1007, 0) end)
          elseif hold_ativo then
            reaper.Main_OnCommand(40861, 0)
            reaper.defer(function() reaper.SetEditCurPos(0, true, false) end)
          end
        end
      end
    end
    play_state_anterior = play_state_atual

    local blink_on_region = is_playing and (math.floor(os.clock() * 4) % 2 == 0)

    -- BOTÕES DE REGIÃO (filtra por grupo quando não está em visão completa)
    local altura_botoes = 70
    local offset_altura_superior = 80
    local regiao_tocando_id = nil
    for i, reg in ipairs(regioes) do
      if tocando >= reg.pos and tocando < reg.rgnend then regiao_tocando_id = "regiao_" .. tostring(i); break end
    end

    for i, reg in ipairs(regioes) do
      local id = "regiao_" .. tostring(i)

      -- filtro por range/cor
      local dentro_range = not (reg.rgnend <= g_ini + eps or reg.pos >= g_fim - eps)
      local passa_cor = visao_completa or (cor_grupo_atual and reg.color == cor_grupo_atual)

      if dentro_range and passa_cor then
        local x = pos_x + ((reg.pos - g_ini) / g_len) * canvas_width
        local y_base = pos_y + canvas_height - altura_botoes
        local y = (i % 2 == 0) and y_base or (y_base - offset_altura_superior)

        local b = ((reg.color >> 16) & 0xFF) / 255
        local g = ((reg.color >> 8) & 0xFF) / 255
        local r = (reg.color & 0xFF) / 255
        local cor_rg = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, 1)

        local is_tocando_reg = regiao_tocando_id == id
        local is_clicada = regiao_clicada_id == id
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
        local text_w = reaper.ImGui_CalcTextSize(ctx, nome)
        local w = text_w + 20

        local cor_btn = piscar and reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1)
                      or (mostrar_vermelho_solido and reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1) or cor_rg)

        reaper.ImGui_SetCursorScreenPos(ctx, x, y)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), cor_btn)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), cor_btn)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), cor_btn)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,1))
        reaper.ImGui_PushFont(ctx, font_bold)
        local clicked = reaper.ImGui_Button(ctx, nome .. "##" .. id, w, altura_botoes)
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_PopStyleColor(ctx, 4)

        if clicked then
          if not usar_dois_cliques then
            if regiao_clicada_id == id then
              regiao_clicada_id = nil
              if regiao_tocando_id then
                local idx = tonumber(regiao_tocando_id:match("regiao_(%d+)"))
                if idx and regioes[idx] then reaper.SetEditCurPos(regioes[idx].rgnend, true, true) end
              end
            else
              regiao_clicada_id = id
              reaper.SetEditCurPos(reg.pos, true, true)
            end
            if modo_tela_touch then reaper.JS_Mouse_SetPosition(0, 0) end
          else
            if click_pendente and click_pendente.id == id then
              if regiao_clicada_id == id then
                regiao_clicada_id = nil
                if regiao_tocando_id then
                  local idx = tonumber(regiao_tocando_id:match("regiao_(%d+)"))
                  if idx and regioes[idx] then reaper.SetEditCurPos(regioes[idx].rgnend, true, true) end
                end
              else
                regiao_clicada_id = id
                reaper.SetEditCurPos(reg.pos, true, true)
              end
              click_pendente = nil
              if modo_tela_touch then reaper.JS_Mouse_SetPosition(0, 0) end
            else
              click_pendente = { id = id }
              tempo_primeiro_click = reaper.time_precise()
            end
          end
        end
      end
    end

    -- FADES “SOMENTE CLICK”
    if fading_out or fading_in then
      local now = reaper.time_precise()
      local progress = math.min((now - fade_start_time) / fade_duration, 1)
      for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        local original_vol = volumes_originais[i] or 1.0
        if (name or ""):upper() ~= "CLICK" then
          local target = fading_out and 0.0 or original_vol
          local start = fading_out and original_vol or 0.0
          local vol = start + (target - start) * progress
          reaper.SetMediaTrackInfo_Value(tr, "D_VOL", vol)
        end
      end
      if progress >= 1 then fading_out, fading_in = false, false end
    end

    -- linha de reprodução
    local t_norm = 0
    local g_len = math.max(0.0001, ((not visao_completa) and #grupos > 0) and (grupos[idx_grupo_atual].fim - grupos[idx_grupo_atual].ini) or duracao)
    local g_ini_calc = ((not visao_completa) and #grupos > 0) and grupos[idx_grupo_atual].ini or 0
    t_norm = (reaper.GetPlayPosition() - g_ini_calc) / g_len
    if t_norm < 0 then t_norm = 0 elseif t_norm > 1 then t_norm = 1 end
    local play_x = pos_x + t_norm * canvas_width
    reaper.ImGui_DrawList_AddLine(draw_list, play_x, pos_y, play_x, pos_y + canvas_height, cor_reproducao, 2.0)

    -- empurra o cursor para DEBAIXO do canvas da waveform
    reaper.ImGui_SetCursorScreenPos(ctx, pos_x - padding_lateral, pos_y + canvas_height + 12)
    reaper.ImGui_Dummy(ctx, 1, 1)

    -- Botões 09..11
    local largura_repertorio, altura_repertorio, padding_repertorio = 140, 60, 10
    ImGui_ButtonTouch(ctx, "btn9",  "REPERTÓRIO", largura_repertorio, altura_repertorio, cor_botao_padrao, cor_amarelo, function() reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PROJLIST_OPEN"), 0) end)
    reaper.ImGui_SameLine(ctx, nil, padding_repertorio)
    ImGui_ButtonTouch(ctx, "btn10", "SALVAR", largura_repertorio, altura_repertorio, cor_botao_padrao, cor_amarelo, function() reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PROJLISTSAVE"), 0) end)
    reaper.ImGui_SameLine(ctx, nil, padding_repertorio)
    ImGui_ButtonTouch(ctx, "btn11", "ABRIR",  largura_repertorio, altura_repertorio, cor_botao_padrao, cor_amarelo, function() reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_PROJLISTSOPEN"), 0) end)

    reaper.ImGui_End(ctx)
  end

  if open then reaper.defer(loop) end
end

reaper.defer(loop)
