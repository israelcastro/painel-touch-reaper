# Painel Touch Scroll - REAPER

Painel touch interativo para controle do REAPER. Compatível com **Windows** e **macOS**.

---

## 🧩 Extensões Obrigatórias do REAPER

Para que este script funcione corretamente no Windows ou no macOS, você **precisa obrigatoriamente** ter as seguintes extensões instaladas no REAPER:

| Extensão | Função no Script | Como Instalar |
| :--- | :--- | :--- |
| **SWS / S&M Extension** | Manipulação de rotinas internas e listas de projetos | Baixar instalador em [sws-extension.org](https://www.sws-extension.org) |
| **ReaImGui** | Renderização da interface gráfica do painel | Via ReaPack (`Extensions > ReaPack > Browse packages > ReaImGui`) |
| **JS_ReaScriptAPI** | Suporte a mouse e reposicionamento em tela touch | Via ReaPack (`Extensions > ReaPack > Browse packages > js_reascriptapi`) |
| **ReaPack** | Gerenciador de pacotes para instalar scripts e bibliotecas | Baixar instalador em [reapack.com](https://reapack.com) |

> [!IMPORTANT]
> Caso alguma dessas extensões não esteja instalada, a interface do Painel Touch não irá abrir ou apresentará erro de API ausente ao ser executada.

---

## 🚀 Como Instalar o Script via ReaPack (Recomendado)

O **ReaPack** permite instalar e manter o script atualizado automaticamente no **Windows** e **macOS**.

### Passo 1: Instalar o ReaPack, ReaImGui, JS_ReaScriptAPI e SWS
1. Baixe e instale o **SWS Extension** em [sws-extension.org](https://www.sws-extension.org).
2. Baixe e instale o **ReaPack** em [reapack.com](https://reapack.com).
3. No REAPER, abra `Extensions` > `ReaPack` > `Browse packages...`, busque e instale:
   - `ReaImGui: ReaScript API for Dear ImGui`
   - `js_ReaScriptAPI: API functions for ReaScripts`
4. Clique em **Apply** e reinicie o REAPER.

---

### Passo 2: Adicionar este Repositório ao ReaPack
1. No REAPER, abra o menu superior: **Extensions** > **ReaPack** > **Import repositories...**
2. No campo que surgir, cole a seguinte URL:

```text
https://github.com/israelcastro/painel-touch-reaper/raw/MERGE-DE-FUNCOES/index.xml
```

3. Clique em **OK**.

---

### Passo 3: Instalar o Script
1. Vá em **Extensions** > **ReaPack** > **Browse packages...**
2. Na barra de busca, digite: `Painel Touch Scroll`
3. Clique com o botão direito sobre o item **Painel Touch Scroll** e escolha **Install**.
4. Clique no botão **Apply** no canto inferior direito.

Pronto! O script foi baixado com todas as suas dependências e já estará disponível na sua **Action List** (`Actions` > `Show action list...`).

---

## 💻 Compatibilidade

- **Windows**: REAPER v6.0+ ou v7.0+
- **macOS**: REAPER v6.0+ ou v7.0+ (Intel & Apple Silicon)
