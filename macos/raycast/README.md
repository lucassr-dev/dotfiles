# Raycast Configuration

Raycast é um launcher poderoso para macOS que substitui Spotlight/Alfred.

## Instalação de Plugins

Os plugins do Raycast **NÃO** são instalados automaticamente via Homebrew. Após instalar o Raycast, você precisa instalar os plugins manualmente.

### Como Instalar Plugins

1. **Abra o Raycast**
   - Pressione `Cmd + Space` (ou o atalho que você configurou)

2. **Acesse a Raycast Store**
   - Digite "Store" e pressione Enter
   - Ou use o atalho: `Cmd + ,` → Clique em "Extensions"

3. **Instale os Plugins Recomendados:**

#### 🔧 Essenciais
- **Homebrew** - Gerenciar packages diretamente do Raycast
- **Clipboard History** - Histórico de clipboard com preview
- **Window Management** - Controle janelas (alternativa ao Rectangle)
- **Kill Process** - Finalizar processos travados

#### 🔍 Produtividade
- **Google Search** - Buscar no Google rapidamente
- **GitHub** - Acessar repos, issues, PRs
- **Search npm Packages** - Buscar pacotes npm
- **Emoji Search** - Buscar e copiar emojis
- **Color Picker** - Pegar cores da tela

#### 💻 Desenvolvimento
- **Git Repos** - Listar e abrir repositórios Git locais
- **GitHub Gist** - Gerenciar seus gists
- **Docker** - Gerenciar containers Docker
- **VS Code** - Abrir projetos recentes do VS Code

#### 📦 Gerenciamento
- **Brew Services** - Gerenciar serviços do Homebrew
- **System Monitor** - Ver CPU, memória, etc
- **Port Manager** - Ver e matar processos em portas específicas

## Configurações Recomendadas

### Atalho Global
Recomendamos configurar o atalho global do Raycast para `Cmd + Space`, substituindo o Spotlight:

1. **Desabilitar Spotlight:**
   - Preferências do Sistema → Siri & Spotlight
   - Keyboard Shortcuts → Spotlight
   - Desmarque "Show Spotlight search"

2. **Configurar Raycast:**
   - Abra Raycast
   - `Cmd + ,` → General → Raycast Hotkey
   - Defina como `Cmd + Space`

### Aliases Úteis

Configure aliases para comandos frequentes:

- `gh` → GitHub
- `npm` → Search npm Packages
- `brew` → Homebrew
- `clip` → Clipboard History
- `emoji` → Emoji Search
- `kill` → Kill Process
- `color` → Color Picker

### Integrações

Conecte suas contas no Raycast:

1. **GitHub:** Configurações → Extensions → GitHub → Sign in
2. **Google:** Para Google Search com sugestões
3. **Jira/Linear:** Se usar para gerenciamento de projetos

## Window Management via Raycast

Se você instalou o Rectangle separadamente, pode optar por usar o Window Management do Raycast:

**Vantagens do Raycast Window Management:**
- Totalmente integrado no Raycast
- Mesmas funcionalidades do Rectangle
- Menos um app rodando

**Configuração:**
1. Instale o plugin "Window Management"
2. Configure os atalhos em: Raycast → Extensions → Window Management
3. Pode desinstalar o Rectangle se preferir

**Atalhos Recomendados:**
- `Ctrl + Opt + Left` - Meia tela esquerda
- `Ctrl + Opt + Right` - Meia tela direita
- `Ctrl + Opt + Up` - Topo
- `Ctrl + Opt + Down` - Baixo
- `Ctrl + Opt + Enter` - Maximizar
- `Ctrl + Opt + C` - Centralizar

## Dicas e Truques

### 1. Quicklinks
Crie quicklinks para sites que você acessa frequentemente:

- `docs` → https://docs.empresa.com
- `dash` → https://dashboard.empresa.com
- `gh-me` → https://github.com/seu-usuario

### 2. Snippets
Crie snippets para textos frequentes:

- `;email` → seu-email@empresa.com
- `;phone` → seu-telefone
- `;addr` → seu-endereço

### 3. Barra de Menu
Adicione widgets úteis na barra de menu:

- **Clipboard History:** Acesso rápido ao histórico
- **System Monitor:** Ver uso de CPU/RAM
- **Calendar:** Ver próximos eventos

### 4. Scripts Personalizados
Você pode adicionar seus próprios scripts bash/zsh:

1. Raycast → Script Commands → Create Script Command
2. Escreva seu script
3. Use linguagem bash, python, node, etc

Exemplo:
```bash
#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sistema Info
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 💻

echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
echo "IP: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}')"
```

## Exportar/Importar Configurações

Para sincronizar configurações entre máquinas:

1. **Exportar:**
   ```bash
   # Configurações ficam em:
   ~/Library/Application Support/com.raycast.macos/

   # Copie especialmente:
   ~/Library/Application Support/com.raycast.macos/extensions/
   ~/Library/Application Support/com.raycast.macos/preferences/
   ```

2. **Importar:**
   - Copie os arquivos para a nova máquina
   - Reinicie o Raycast

## Recursos

- [Raycast Store](https://www.raycast.com/store)
- [Documentação Oficial](https://developers.raycast.com/)
- [GitHub - Raycast Extensions](https://github.com/raycast/extensions)
