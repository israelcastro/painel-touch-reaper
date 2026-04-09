-- modules/state.lua
local State = {}

-- Variables globais de estado
State.usar_dois_cliques = true
State.modo_tela_touch = true
State.padding_lateral = 20

-- Parâmetros de largura
State.largura_btn_musica = 160
State.largura_btn_completa = 50

State.botao2_ativo = false
State.click_pendente = nil
State.tempo_primeiro_click = 0
State.tempo_limite_2cliques = 1.2

State.regiao_clicada_id = nil
State.last_waveform_width = nil
State.altura_waveform = 250
State.last_project_id = reaper.EnumProjects(-1, "")
State.loop_ativo = false
State.volumes_originais = {}
State.fade_duration = 1
State.fade_start_time = nil
State.fading_out = false
State.fading_in = false
State.hold_ativo = false
State.play_state_anterior = reaper.GetPlayState()
State.autoplay_ativo = false
State.sos_ativo = false
State.sos_start_time = 0
State.sos_saindo = false
State.sos_start_saindo_time = 0
State.sos_saindo_duration = 0
State.versao_curta_ativo = false
State.pad_triggered_region_id = nil
State.pad_stop_pending = false
State.pad_stop_target_measure = nil
State.pad_fading_out = false
State.pad_fade_start_time = nil
State.pad_proj_fade = nil
State.pad_master_tr = nil
State.pad_master_vol = 1.0
State.pad_fade_duration = 3.0
-- track info visual
State.original_seekmodes = reaper.SNM_GetIntConfigVar("seekmodes", -1)
if State.original_seekmodes ~= -1 then
  reaper.SNM_SetIntConfigVar("seekmodes", State.original_seekmodes | 0x3F)
end

reaper.atexit(function()
  if State.original_seekmodes ~= -1 then
    reaper.SNM_SetIntConfigVar("seekmodes", State.original_seekmodes)
  end
end)

State.nome_track_info_visual = "INFORMAÇÃO VISUAL"
State.altura_info_lane = 36
State.gap_info_lane = 8

-- grupos e dados
State.regioes = {}
State.grupos = {}
State.idx_grupo_atual = 1
State.auto_scroll_grupos = true
State.margem_troca = 0.02
State.visao_completa = false
State.seguir_reproducao = true
State.duracao = 10
State.waveform = {}

-- Config persistence
local config_path = reaper.GetResourcePath() .. "/Scripts/painel_config.ini"
function State.salvar_config()
  local f = io.open(config_path, "w")
  if f then
    f:write("usar_dois_cliques=" .. (State.usar_dois_cliques and "1" or "0") .. "\n")
    f:write("modo_tela_touch=" .. (State.modo_tela_touch and "1" or "0") .. "\n")
    f:write("hold_ativo=" .. (State.hold_ativo and "1" or "0") .. "\n")
    f:write("autoplay_ativo=" .. (State.autoplay_ativo and "1" or "0") .. "\n")
    f:write("visao_completa=" .. (State.visao_completa and "1" or "0") .. "\n")
    f:close()
  end
end

function State.carregar_config()
  local f = io.open(config_path, "r")
  if f then
    for line in f:lines() do
      local key, val = line:match("^(.-)=(.-)$")
      if key == "usar_dois_cliques" then State.usar_dois_cliques = val == "1"
      elseif key == "modo_tela_touch" then State.modo_tela_touch = val == "1"
      elseif key == "hold_ativo" then State.hold_ativo = (val == "1")
      elseif key == "autoplay_ativo" then State.autoplay_ativo = (val == "1")
      elseif key == "visao_completa" then State.visao_completa = (val == "1")
      end
    end
    f:close()
  end
end
State.carregar_config()

-- Contexto ImGui e Fontes
State.ctx = reaper.ImGui_CreateContext('Painel touch Na Janela Band', 0)
local font_bold_path = reaper.GetResourcePath() .. "/Scripts/Fontes/Montserrat-Bold.ttf"
State.font_bold = reaper.ImGui_CreateFont(font_bold_path, 16)
reaper.ImGui_Attach(State.ctx, State.font_bold)
State.font_huge = reaper.ImGui_CreateFont(font_bold_path, 40)
reaper.ImGui_Attach(State.ctx, State.font_huge)

-- Cores Base
State.cor_vermelho   = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.2, 0.2, 1)
State.cor_verde      = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.8, 0.2, 1)
State.cor_cinza      = reaper.ImGui_ColorConvertDouble4ToU32(0.3, 0.3, 0.3, 1)
State.cor_amarelo    = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 0.2, 1)
State.cor_branco     = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1)
State.cor_preto      = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1)
State.cor_reproducao = reaper.ImGui_ColorConvertDouble4ToU32(1, 0, 0, 1)
State.cor_botao_padrao = reaper.ImGui_GetColor(State.ctx, reaper.ImGui_Col_Button())
State.cor_texto_padrao = reaper.ImGui_GetColor(State.ctx, reaper.ImGui_Col_Text())

return State
