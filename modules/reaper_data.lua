-- modules/reaper_data.lua
local State = require("modules.state")
local ReaperData = {}

function ReaperData.gerarWaveformFake(n)
  local wf = {}
  for i = 1, n do wf[i] = math.random() end
  return wf
end

function ReaperData.montar_grupos_por_cor()
  State.grupos = {}
  if not State.regioes or #State.regioes == 0 then return end
  table.sort(State.regioes, function(a,b) return a.pos < b.pos end)

  local g_ini = State.regioes[1].pos
  local g_fim = State.regioes[1].rgnend
  local g_color = State.regioes[1].color

  for i = 2, #State.regioes do
    local r = State.regioes[i]
    if r.color == g_color and r.pos <= g_fim + 0.0001 then
      g_fim = math.max(g_fim, r.rgnend)
    else
      State.grupos[#State.grupos+1] = {ini=g_ini, fim=g_fim, color=g_color}
      g_ini, g_fim, g_color = r.pos, r.rgnend, r.color
    end
  end
  State.grupos[#State.grupos+1] = {ini=g_ini, fim=g_fim, color=g_color}

  local playpos = reaper.GetPlayPosition()
  local novo = 1
  for i, g in ipairs(State.grupos) do
    if playpos >= g.ini - 1e-6 and playpos < g.fim - 1e-6 then
      novo = i; break
    end
  end
  if playpos >= State.grupos[#State.grupos].fim - 1e-6 then novo = #State.grupos end
  State.idx_grupo_atual = novo
end

function ReaperData.carregarRegioes()
  State.regioes = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  State.duracao = 10
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and isrgn then
      State.regioes[#State.regioes+1] = {pos=pos, rgnend=rgnend, name=name or "", color=color or 0}
      if rgnend > State.duracao then State.duracao = rgnend end
    end
  end
  ReaperData.montar_grupos_por_cor()
end

function ReaperData.encontrarTrackInfoVisual()
  local alvo = State.nome_track_info_visual:upper()
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

function ReaperData.coletarItensInfoVisual()
  local itens = {}
  local tr = ReaperData.encontrarTrackInfoVisual()
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

State.waveform = ReaperData.gerarWaveformFake(1000)
ReaperData.carregarRegioes()

return ReaperData
