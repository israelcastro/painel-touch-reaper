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

## 🚀 Como Instalar via ReaPack em Repositório Privado

Como o repositório é privado, você precisará de um **Token de Acesso Pessoal (PAT)** do GitHub para que o ReaPack possa acessar os arquivos nos seus computadores (Windows ou Mac).

### Passo 1: Gerar o Token no GitHub (Fazer apenas 1 vez)
1. No GitHub, clique na sua foto de perfil (canto superior direito) e vá em **Settings**.
2. No menu lateral esquerdo, selecione **Developer Settings** (no final da lista).
3. Vá em **Personal access tokens** > **Tokens (classic)**.
4. Clique em **Generate new token (classic)**.
5. Digite um nome (ex: `ReaPack Painel Touch`) e em *Expiration* escolha `No expiration` (ou o prazo desejado).
6. Marque a opção **`repo`** (Full control of private repositories).
7. Clique no botão verde **Generate token** e copie a chave gerada (ela começa com `ghp_...`).

---

### Passo 2: Importar a URL no ReaPack
1. No REAPER (seja no Windows ou Mac), vá em **Extensions** > **ReaPack** > **Import repositories...**
2. Cole a URL no seguinte formato (substituindo `SEU_TOKEN_AQUI` pelo token copiado):

```text
https://SEU_TOKEN_AQUI@raw.githubusercontent.com/israelcastro/painel-touch-reaper/MERGE-DE-FUNCOES/index.xml
```

3. Clique em **OK**.

---

### Passo 3: Instalar o Script no REAPER
1. Vá em **Extensions** > **ReaPack** > **Browse packages...**
2. Na barra de busca, digite: `Painel Touch Scroll`
3. Clique com o botão direito sobre o item **Painel Touch Scroll** e escolha **Install**.
4. Clique em **Apply** no canto inferior direito.

Pronto! O script e todos os seus módulos serão instalados automaticamente e estarão prontos na sua **Action List** (`Actions` > `Show action list...`).

---

## 💻 Compatibilidade

- **Windows**: REAPER v6.0+ ou v7.0+
- **macOS**: REAPER v6.0+ ou v7.0+ (Intel & Apple Silicon)
