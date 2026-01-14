#!/usr/bin/env bash
# Seleção e instalação de Neovim distributions e tmux

# ══════════════════════════════════════════════════════════════════════════════
# VARIÁVEIS GLOBAIS
# ══════════════════════════════════════════════════════════════════════════════
INSTALL_NEOVIM=0
INSTALL_TMUX=0
SELECTED_NVIM_DISTRO=""
SELECTED_NVIM_AI=()
SELECTED_NVIM_DEVOPS=()
SELECTED_TMUX_CONFIG=""

# URLs das distribuições Neovim
declare -A NVIM_DISTRO_REPOS=(
  ["lazyvim"]="https://github.com/LazyVim/starter"
  ["nvchad"]="https://github.com/NvChad/starter"
  ["astrovim"]="https://github.com/AstroNvim/template"
  ["kickstart"]="https://github.com/nvim-lua/kickstart.nvim"
)

# ══════════════════════════════════════════════════════════════════════════════
# SELEÇÃO DE EDITOR/IDE
# ══════════════════════════════════════════════════════════════════════════════
ask_editors() {
  clear_screen
  show_section_header "📝 EDITOR/IDE - Neovim & Tmux"

  msg "Configure seu ambiente de desenvolvimento com Neovim e tmux."
  msg ""
  msg "💡 Esta seção configura:"
  msg "   • Neovim com distribuições pré-configuradas (LazyVim, NvChad, etc.)"
  msg "   • Integrações de IA (Copilot, Codeium, avante.nvim)"
  msg "   • Suporte DevOps (Terraform, K8s, Docker, Ansible)"
  msg "   • tmux com temas e plugins"
  msg ""

  if ! ask_yes_no "Deseja configurar Neovim e/ou tmux?"; then
    INSTALL_NEOVIM=0
    INSTALL_TMUX=0
    msg ""
    msg "  ⏭️  Pulando configuração de editor/IDE"
    msg ""
    return 0
  fi

  # Neovim
  ask_neovim_setup

  # Tmux
  ask_tmux_setup
}

# ══════════════════════════════════════════════════════════════════════════════
# NEOVIM SETUP
# ══════════════════════════════════════════════════════════════════════════════
ask_neovim_setup() {
  clear_screen
  show_section_header "📝 NEOVIM - Distribuição"

  msg "Escolha uma distribuição de Neovim pré-configurada."
  msg ""
  msg "📊 Comparativo:"
  msg ""
  msg "  ${BANNER_CYAN}LazyVim${BANNER_RESET} (Recomendado)"
  msg "     • IDE completa pronta para uso"
  msg "     • LSP, formatters, linters pré-configurados"
  msg "     • Fácil de customizar via 'extras'"
  msg "     • Baseado no post do devaslife"
  msg ""
  msg "  ${BANNER_GREEN}NvChad${BANNER_RESET}"
  msg "     • UI muito polida (base46 themes)"
  msg "     • Performance extrema"
  msg "     • Requer mais configuração manual"
  msg ""
  msg "  ${BANNER_YELLOW}AstroNvim${BANNER_RESET}"
  msg "     • Mais completo out-of-the-box"
  msg "     • Modular e altamente configurável"
  msg "     • Comunidade ativa (astrocommunity)"
  msg ""
  msg "  ${BANNER_MAGENTA}kickstart.nvim${BANNER_RESET}"
  msg "     • Ponto de partida minimalista"
  msg "     • Ideal para aprender Neovim/Lua"
  msg "     • Base para config própria"
  msg ""

  local nvim_options=(
    "LazyVim           IDE completa, fácil de usar (Recomendado)"
    "NvChad            UI polida, performance extrema"
    "AstroNvim         Completo e modular"
    "kickstart.nvim    Minimalista, para aprendizado"
    "Nenhum            Não instalar distribuição"
  )

  local selected=""
  select_single_item "Escolha a distribuição Neovim" selected "${nvim_options[@]}"

  case "$selected" in
    *LazyVim*)
      INSTALL_NEOVIM=1
      SELECTED_NVIM_DISTRO="lazyvim"
      ;;
    *NvChad*)
      INSTALL_NEOVIM=1
      SELECTED_NVIM_DISTRO="nvchad"
      ;;
    *AstroNvim*)
      INSTALL_NEOVIM=1
      SELECTED_NVIM_DISTRO="astrovim"
      ;;
    *kickstart*)
      INSTALL_NEOVIM=1
      SELECTED_NVIM_DISTRO="kickstart"
      ;;
    *)
      INSTALL_NEOVIM=0
      SELECTED_NVIM_DISTRO=""
      return 0
      ;;
  esac

  # Perguntar sobre integrações de IA
  ask_neovim_ai

  # Perguntar sobre extras DevOps
  ask_neovim_devops
}

ask_neovim_ai() {
  [[ $INSTALL_NEOVIM -eq 0 ]] && return 0

  clear_screen
  show_section_header "🤖 NEOVIM - Integrações de IA"

  msg "Adicione assistentes de IA ao seu Neovim."
  msg ""
  msg "💡 Opções disponíveis:"
  msg ""
  msg "  ${BANNER_CYAN}GitHub Copilot${BANNER_RESET}"
  msg "     • Autocompletar inteligente"
  msg "     • Chat integrado (CopilotChat.nvim)"
  msg "     • Requer assinatura GitHub Copilot"
  msg ""
  msg "  ${BANNER_GREEN}Codeium (Windsurf)${BANNER_RESET}"
  msg "     • Gratuito para indivíduos"
  msg "     • Autocompletar similar ao Copilot"
  msg "     • Suporta múltiplas linguagens"
  msg ""
  msg "  ${BANNER_YELLOW}avante.nvim${BANNER_RESET}"
  msg "     • Experiência tipo Cursor IDE"
  msg "     • Suporta múltiplos modelos (Claude, GPT, Gemini)"
  msg "     • Chat e edição de código assistida"
  msg ""

  local ai_options=(
    "copilot          GitHub Copilot (requer assinatura)"
    "codeium          Codeium/Windsurf (gratuito)"
    "avante           avante.nvim (multi-modelo, tipo Cursor)"
  )

  SELECTED_NVIM_AI=()
  local selected_ai=()
  select_multiple_items "🤖 Selecione integrações de IA" selected_ai "${ai_options[@]}"

  for item in "${selected_ai[@]}"; do
    local ai_id
    ai_id=$(echo "$item" | awk '{print $1}')
    SELECTED_NVIM_AI+=("$ai_id")
  done
}

ask_neovim_devops() {
  [[ $INSTALL_NEOVIM -eq 0 ]] && return 0

  clear_screen
  show_section_header "🛠️ NEOVIM - Extras DevOps"

  msg "Adicione suporte a ferramentas DevOps."
  msg ""
  msg "💡 Inclui LSP, snippets e formatação para:"
  msg ""

  local devops_options=(
    "terraform        Terraform/OpenTofu (HCL, tfvars)"
    "kubernetes       Kubernetes (YAML schemas, Helm)"
    "docker           Docker (Dockerfile, compose)"
    "ansible          Ansible (playbooks, roles)"
    "yaml-schemas     YAML avançado (JSON schemas, CRDs)"
  )

  SELECTED_NVIM_DEVOPS=()
  local selected_devops=()
  select_multiple_items "🛠️ Selecione extras DevOps" selected_devops "${devops_options[@]}"

  for item in "${selected_devops[@]}"; do
    local devops_id
    devops_id=$(echo "$item" | awk '{print $1}')
    SELECTED_NVIM_DEVOPS+=("$devops_id")
  done
}

# ══════════════════════════════════════════════════════════════════════════════
# TMUX SETUP
# ══════════════════════════════════════════════════════════════════════════════
ask_tmux_setup() {
  clear_screen
  show_section_header "🖥️ TMUX - Multiplexador de Terminal"

  msg "Configure o tmux para gerenciar múltiplas sessões de terminal."
  msg ""
  msg "💡 Benefícios do tmux:"
  msg "   • Sessões persistentes (sobrevivem a desconexões)"
  msg "   • Múltiplos painéis e janelas"
  msg "   • Integração com Neovim (vim-tmux-navigator)"
  msg "   • Personalização completa"
  msg ""

  if ! ask_yes_no "Deseja configurar o tmux?"; then
    INSTALL_TMUX=0
    SELECTED_TMUX_CONFIG=""
    return 0
  fi

  INSTALL_TMUX=1

  msg ""
  msg "📊 Configurações disponíveis:"
  msg ""
  msg "  ${BANNER_CYAN}Catppuccin${BANNER_RESET} (Recomendado)"
  msg "     • Tema Catppuccin (Mocha/Macchiato/Frappe/Latte)"
  msg "     • TPM (Tmux Plugin Manager)"
  msg "     • Plugins: resurrect, continuum, vim-tmux-navigator"
  msg "     • Prefix: Ctrl+a"
  msg ""
  msg "  ${BANNER_GREEN}Dracula${BANNER_RESET}"
  msg "     • Tema Dracula"
  msg "     • TPM com plugins essenciais"
  msg "     • Status bar informativa"
  msg ""
  msg "  ${BANNER_YELLOW}Oh My Tmux${BANNER_RESET}"
  msg "     • Configuração completa do gpakosz"
  msg "     • Powerline-like theme"
  msg "     • Muitas customizações prontas"
  msg ""
  msg "  ${BANNER_MAGENTA}Minimalista${BANNER_RESET}"
  msg "     • Configuração básica otimizada"
  msg "     • TPM para adicionar plugins depois"
  msg "     • Base limpa para personalizar"
  msg ""

  local tmux_options=(
    "catppuccin       Tema Catppuccin + plugins essenciais (Recomendado)"
    "dracula          Tema Dracula + plugins essenciais"
    "oh-my-tmux       Oh My Tmux (gpakosz/.tmux)"
    "minimal          Configuração minimalista + TPM"
  )

  local selected=""
  select_single_item "Escolha a configuração do tmux" selected "${tmux_options[@]}"

  SELECTED_TMUX_CONFIG=$(echo "$selected" | awk '{print $1}')
}

# ══════════════════════════════════════════════════════════════════════════════
# INSTALAÇÃO
# ══════════════════════════════════════════════════════════════════════════════
install_selected_editors() {
  install_neovim_distro
  install_tmux_config
}

install_neovim_distro() {
  [[ $INSTALL_NEOVIM -eq 0 ]] && return 0
  [[ -z "$SELECTED_NVIM_DISTRO" ]] && return 0

  msg ""
  msg "▶ Configurando Neovim ($SELECTED_NVIM_DISTRO)"

  # Instalar Neovim se não estiver instalado
  if ! has_cmd nvim; then
    msg "  📦 Instalando Neovim..."
    case "$TARGET_OS" in
      linux|wsl2)
        case "$LINUX_PKG_MANAGER" in
          apt)
            # Neovim do apt pode ser antigo, usar AppImage ou PPA
            install_neovim_linux_modern
            ;;
          dnf)
            run_with_sudo dnf install -y neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
            ;;
          pacman)
            run_with_sudo pacman -S --noconfirm neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
            ;;
          zypper)
            run_with_sudo zypper install -y neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
            ;;
        esac
        ;;
      macos)
        brew install neovim >/dev/null 2>&1 || record_failure "optional" "Falha ao instalar Neovim"
        ;;
    esac
  fi

  if ! has_cmd nvim; then
    record_failure "optional" "Neovim não disponível; pulando configuração"
    return 0
  fi

  # Verificar versão do Neovim (precisa ser >= 0.10 para avante.nvim)
  local nvim_version
  nvim_version=$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  msg "  ℹ️  Neovim versão: $nvim_version"

  # Backup de config existente
  if [[ -d "$HOME/.config/nvim" ]]; then
    msg "  📦 Backup da configuração existente..."
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  fi
  rm -rf "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim" 2>/dev/null || true

  # Instalar distribuição escolhida
  local repo_url="${NVIM_DISTRO_REPOS[$SELECTED_NVIM_DISTRO]:-}"

  case "$SELECTED_NVIM_DISTRO" in
    lazyvim)
      msg "  📦 Instalando LazyVim..."
      git clone "$repo_url" "$HOME/.config/nvim" >/dev/null 2>&1 || {
        record_failure "optional" "Falha ao clonar LazyVim"
        return 0
      }
      rm -rf "$HOME/.config/nvim/.git"
      configure_lazyvim_extras
      ;;
    nvchad)
      msg "  📦 Instalando NvChad..."
      git clone "$repo_url" "$HOME/.config/nvim" >/dev/null 2>&1 || {
        record_failure "optional" "Falha ao clonar NvChad"
        return 0
      }
      rm -rf "$HOME/.config/nvim/.git"
      configure_nvchad_extras
      ;;
    astrovim)
      msg "  📦 Instalando AstroNvim..."
      git clone --depth 1 https://github.com/AstroNvim/AstroNvim "$HOME/.config/nvim" >/dev/null 2>&1 || {
        record_failure "optional" "Falha ao clonar AstroNvim"
        return 0
      }
      git clone "$repo_url" "$HOME/.config/nvim/lua/user" >/dev/null 2>&1 || true
      rm -rf "$HOME/.config/nvim/.git" "$HOME/.config/nvim/lua/user/.git"
      configure_astrovim_extras
      ;;
    kickstart)
      msg "  📦 Instalando kickstart.nvim..."
      git clone "$repo_url" "$HOME/.config/nvim" >/dev/null 2>&1 || {
        record_failure "optional" "Falha ao clonar kickstart.nvim"
        return 0
      }
      rm -rf "$HOME/.config/nvim/.git"
      ;;
  esac

  INSTALLED_MISC+=("Neovim ($SELECTED_NVIM_DISTRO)")

  # Inicializar plugins (primeiro start)
  msg "  🔄 Inicializando plugins (isso pode demorar)..."
  nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true

  msg "  ✅ Neovim configurado com $SELECTED_NVIM_DISTRO"
}

install_neovim_linux_modern() {
  # Tentar instalar versão moderna do Neovim no Ubuntu/Debian
  # Opção 1: PPA unstable (mais recente)
  if has_cmd add-apt-repository; then
    msg "    Adicionando PPA do Neovim..."
    run_with_sudo add-apt-repository -y ppa:neovim-ppa/unstable >/dev/null 2>&1 || true
    run_with_sudo apt update >/dev/null 2>&1 || true
    run_with_sudo apt install -y neovim >/dev/null 2>&1 && return 0
  fi

  # Opção 2: AppImage
  msg "    Instalando Neovim via AppImage..."
  local nvim_appimage="$HOME/.local/bin/nvim"
  mkdir -p "$HOME/.local/bin"
  curl -sLo "$nvim_appimage" "https://github.com/neovim/neovim/releases/latest/download/nvim.appimage" || {
    record_failure "optional" "Falha ao baixar Neovim AppImage"
    return 1
  }
  chmod +x "$nvim_appimage"

  # Verificar se AppImage funciona (pode precisar de FUSE)
  if ! "$nvim_appimage" --version >/dev/null 2>&1; then
    msg "    Extraindo AppImage (FUSE não disponível)..."
    (
      cd "$HOME/.local/bin" || exit 1
      "$nvim_appimage" --appimage-extract >/dev/null 2>&1 || exit 1
    ) || {
      record_failure "optional" "Falha ao extrair Neovim AppImage"
      return 1
    }
    rm -f "$nvim_appimage"
    ln -sf "$HOME/.local/bin/squashfs-root/AppRun" "$nvim_appimage"
  fi
}

configure_lazyvim_extras() {
  local extras_file="$HOME/.config/nvim/lua/config/lazy.lua"

  # Criar arquivo de extras customizado
  mkdir -p "$HOME/.config/nvim/lua/plugins"

  # Adicionar plugins de IA
  if [[ ${#SELECTED_NVIM_AI[@]} -gt 0 ]]; then
    msg "  🤖 Configurando integrações de IA..."
    create_lazyvim_ai_config
  fi

  # Adicionar extras DevOps
  if [[ ${#SELECTED_NVIM_DEVOPS[@]} -gt 0 ]]; then
    msg "  🛠️  Configurando extras DevOps..."
    create_lazyvim_devops_config
  fi
}

create_lazyvim_ai_config() {
  local ai_config="$HOME/.config/nvim/lua/plugins/ai.lua"

  cat > "$ai_config" << 'AIEOF'
-- Integrações de IA para Neovim
-- Gerado automaticamente pelo instalador de dotfiles

return {
AIEOF

  for ai in "${SELECTED_NVIM_AI[@]}"; do
    case "$ai" in
      copilot)
        cat >> "$ai_config" << 'COPILOTEOF'
  -- GitHub Copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<Tab>",
          accept_word = "<C-Right>",
          accept_line = "<C-End>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = true,
      },
    },
  },
  -- CopilotChat para conversas
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    opts = {
      debug = false,
      show_help = true,
      window = {
        layout = "vertical",
        width = 0.4,
      },
    },
    keys = {
      { "<leader>cc", "<cmd>CopilotChatToggle<cr>", desc = "Toggle Copilot Chat" },
      { "<leader>ce", "<cmd>CopilotChatExplain<cr>", desc = "Explain code", mode = { "n", "v" } },
      { "<leader>cr", "<cmd>CopilotChatReview<cr>", desc = "Review code", mode = { "n", "v" } },
      { "<leader>cf", "<cmd>CopilotChatFix<cr>", desc = "Fix code", mode = { "n", "v" } },
      { "<leader>cd", "<cmd>CopilotChatDocs<cr>", desc = "Generate docs", mode = { "n", "v" } },
      { "<leader>ct", "<cmd>CopilotChatTests<cr>", desc = "Generate tests", mode = { "n", "v" } },
    },
  },
COPILOTEOF
        ;;
      codeium)
        cat >> "$ai_config" << 'CODEIUMEOF'
  -- Codeium (gratuito)
  {
    "Exafunction/codeium.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",
    },
    config = function()
      require("codeium").setup({})
    end,
  },
CODEIUMEOF
        ;;
      avante)
        cat >> "$ai_config" << 'AVANTEEOF'
  -- avante.nvim (experiência tipo Cursor)
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false,
    build = "make",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "zbirenbaum/copilot.lua", -- para usar copilot como provider
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = { insert_mode = true },
          },
        },
      },
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = { file_types = { "markdown", "Avante" } },
        ft = { "markdown", "Avante" },
      },
    },
    opts = {
      provider = "copilot", -- ou "claude", "openai", "gemini"
      auto_suggestions_provider = "copilot",
      copilot = {
        model = "gpt-4o", -- ou "claude-3.5-sonnet"
      },
      behaviour = {
        auto_suggestions = false,
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false,
        support_paste_from_clipboard = false,
      },
      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",
        diff = {
          ours = "co",
          theirs = "ct",
          all_theirs = "ca",
          both = "cb",
          cursor = "cc",
          next = "]x",
          prev = "[x",
        },
        jump = {
          next = "]]",
          prev = "[[",
        },
        submit = {
          normal = "<CR>",
          insert = "<C-s>",
        },
        toggle = {
          debug = "<leader>ad",
          hint = "<leader>ah",
        },
      },
      hints = { enabled = true },
      windows = {
        position = "right",
        wrap = true,
        width = 30,
        sidebar_header = {
          align = "center",
          rounded = true,
        },
      },
    },
  },
AVANTEEOF
        ;;
    esac
  done

  echo "}" >> "$ai_config"
}

create_lazyvim_devops_config() {
  local devops_config="$HOME/.config/nvim/lua/plugins/devops.lua"

  cat > "$devops_config" << 'DEVOPSEOF'
-- Extras DevOps para Neovim
-- Gerado automaticamente pelo instalador de dotfiles

return {
  -- Mason para instalar LSPs automaticamente
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
DEVOPSEOF

  # Adicionar LSPs conforme seleção
  for devops in "${SELECTED_NVIM_DEVOPS[@]}"; do
    case "$devops" in
      terraform)
        cat >> "$devops_config" << 'EOF'
        "terraform-ls",
        "tflint",
EOF
        ;;
      kubernetes)
        cat >> "$devops_config" << 'EOF'
        "helm-ls",
        "yaml-language-server",
EOF
        ;;
      docker)
        cat >> "$devops_config" << 'EOF'
        "dockerfile-language-server",
        "docker-compose-language-service",
EOF
        ;;
      ansible)
        cat >> "$devops_config" << 'EOF'
        "ansible-language-server",
        "ansible-lint",
EOF
        ;;
      yaml-schemas)
        cat >> "$devops_config" << 'EOF'
        "yaml-language-server",
EOF
        ;;
    esac
  done

  cat >> "$devops_config" << 'EOF'
      })
    end,
  },

EOF

  # Adicionar configurações específicas
  for devops in "${SELECTED_NVIM_DEVOPS[@]}"; do
    case "$devops" in
      terraform)
        cat >> "$devops_config" << 'TFEOF'
  -- Terraform
  {
    "hashivim/vim-terraform",
    ft = { "terraform", "tf", "hcl" },
    config = function()
      vim.g.terraform_fmt_on_save = 1
      vim.g.terraform_align = 1
    end,
  },
TFEOF
        ;;
      kubernetes)
        cat >> "$devops_config" << 'K8SEOF'
  -- Kubernetes YAML com schemas
  {
    "someone-stole-my-name/yaml-companion.nvim",
    ft = { "yaml" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("telescope").load_extension("yaml_schema")
      local cfg = require("yaml-companion").setup({
        builtin_matchers = {
          kubernetes = { enabled = true },
          cloud_init = { enabled = true },
        },
        schemas = {
          {
            name = "Kubernetes",
            uri = "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/v1.29.0-standalone-strict/all.json",
          },
        },
        lspconfig = {
          settings = {
            yaml = {
              validate = true,
              schemaStore = {
                enable = false,
                url = "",
              },
            },
          },
        },
      })
      require("lspconfig")["yamlls"].setup(cfg)
    end,
  },
  -- Helm
  {
    "towolf/vim-helm",
    ft = { "helm", "yaml" },
  },
K8SEOF
        ;;
      docker)
        cat >> "$devops_config" << 'DOCKEREOF'
  -- Docker
  {
    "ekalinin/Dockerfile.vim",
    ft = { "dockerfile" },
  },
DOCKEREOF
        ;;
      ansible)
        cat >> "$devops_config" << 'ANSIBLEEOF'
  -- Ansible
  {
    "pearofducks/ansible-vim",
    ft = { "yaml.ansible", "ansible" },
    config = function()
      vim.g.ansible_unindent_after_newline = 1
      vim.g.ansible_attribute_highlight = "ob"
      vim.g.ansible_name_highlight = "d"
    end,
  },
ANSIBLEEOF
        ;;
    esac
  done

  echo "}" >> "$devops_config"
}

configure_nvchad_extras() {
  # NvChad usa estrutura diferente
  local custom_dir="$HOME/.config/nvim/lua/custom"
  mkdir -p "$custom_dir"

  # Criar chadrc.lua base
  cat > "$custom_dir/chadrc.lua" << 'CHADRCEOF'
---@type ChadrcConfig
local M = {}

M.ui = {
  theme = "catppuccin",
  theme_toggle = { "catppuccin", "one_light" },

  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
  },
}

M.plugins = "custom.plugins"
M.mappings = require("custom.mappings")

return M
CHADRCEOF

  # Criar plugins.lua
  create_nvchad_plugins
}

create_nvchad_plugins() {
  local plugins_file="$HOME/.config/nvim/lua/custom/plugins.lua"

  cat > "$plugins_file" << 'PLUGINSEOF'
local plugins = {
  -- LSP
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("plugins.configs.lspconfig")
      require("custom.configs.lspconfig")
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
PLUGINSEOF

  # Adicionar LSPs conforme seleção DevOps
  for devops in "${SELECTED_NVIM_DEVOPS[@]}"; do
    case "$devops" in
      terraform) echo '        "terraform-ls", "tflint",' >> "$plugins_file" ;;
      kubernetes) echo '        "helm-ls", "yaml-language-server",' >> "$plugins_file" ;;
      docker) echo '        "dockerfile-language-server",' >> "$plugins_file" ;;
      ansible) echo '        "ansible-language-server",' >> "$plugins_file" ;;
    esac
  done

  cat >> "$plugins_file" << 'EOF'
      },
    },
  },
EOF

  # Adicionar plugins de IA
  for ai in "${SELECTED_NVIM_AI[@]}"; do
    case "$ai" in
      copilot)
        cat >> "$plugins_file" << 'EOF'
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = true, auto_trigger = true },
    },
  },
EOF
        ;;
      codeium)
        cat >> "$plugins_file" << 'EOF'
  {
    "Exafunction/codeium.nvim",
    event = "InsertEnter",
    config = true,
  },
EOF
        ;;
    esac
  done

  echo "}" >> "$plugins_file"
  echo "" >> "$plugins_file"
  echo "return plugins" >> "$plugins_file"

  # Criar mappings.lua
  cat > "$HOME/.config/nvim/lua/custom/mappings.lua" << 'MAPPINGSEOF'
local M = {}

M.general = {
  n = {
    ["<leader>cc"] = { "<cmd>CopilotChatToggle<CR>", "Toggle Copilot Chat" },
  },
}

return M
MAPPINGSEOF

  # Criar configs/lspconfig.lua
  mkdir -p "$HOME/.config/nvim/lua/custom/configs"
  cat > "$HOME/.config/nvim/lua/custom/configs/lspconfig.lua" << 'LSPCONFIGEOF'
local on_attach = require("plugins.configs.lspconfig").on_attach
local capabilities = require("plugins.configs.lspconfig").capabilities
local lspconfig = require("lspconfig")

local servers = { "html", "cssls", "tsserver", "tailwindcss" }

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup({
    on_attach = on_attach,
    capabilities = capabilities,
  })
end
LSPCONFIGEOF
}

configure_astrovim_extras() {
  # AstroNvim usa astrocommunity para plugins
  msg "  ℹ️  AstroNvim configurado. Use :AstroUpdate para atualizar."
  msg "  💡 Adicione plugins via astrocommunity em lua/community.lua"
}

# ══════════════════════════════════════════════════════════════════════════════
# TMUX INSTALLATION
# ══════════════════════════════════════════════════════════════════════════════
install_tmux_config() {
  [[ $INSTALL_TMUX -eq 0 ]] && return 0
  [[ -z "$SELECTED_TMUX_CONFIG" ]] && return 0

  msg ""
  msg "▶ Configurando tmux ($SELECTED_TMUX_CONFIG)"

  # Instalar tmux se não estiver instalado
  if ! has_cmd tmux; then
    msg "  📦 Instalando tmux..."
    case "$TARGET_OS" in
      linux|wsl2)
        case "$LINUX_PKG_MANAGER" in
          apt) run_with_sudo apt install -y tmux >/dev/null 2>&1 ;;
          dnf) run_with_sudo dnf install -y tmux >/dev/null 2>&1 ;;
          pacman) run_with_sudo pacman -S --noconfirm tmux >/dev/null 2>&1 ;;
          zypper) run_with_sudo zypper install -y tmux >/dev/null 2>&1 ;;
        esac
        ;;
      macos)
        brew install tmux >/dev/null 2>&1
        ;;
    esac
  fi

  if ! has_cmd tmux; then
    record_failure "optional" "tmux não disponível; pulando configuração"
    return 0
  fi

  # Backup de config existente
  [[ -f "$HOME/.tmux.conf" ]] && mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  [[ -d "$HOME/.tmux" ]] && mv "$HOME/.tmux" "$HOME/.tmux.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true

  # Instalar TPM (Tmux Plugin Manager)
  msg "  📦 Instalando TPM (Tmux Plugin Manager)..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" >/dev/null 2>&1 || {
    record_failure "optional" "Falha ao instalar TPM"
    return 0
  }

  # Criar configuração conforme seleção
  case "$SELECTED_TMUX_CONFIG" in
    catppuccin)
      create_tmux_catppuccin_config
      ;;
    dracula)
      create_tmux_dracula_config
      ;;
    oh-my-tmux)
      install_oh_my_tmux
      ;;
    minimal)
      create_tmux_minimal_config
      ;;
  esac

  # Instalar plugins do TPM
  msg "  🔄 Instalando plugins do tmux..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true

  INSTALLED_MISC+=("tmux ($SELECTED_TMUX_CONFIG)")
  msg "  ✅ tmux configurado com tema $SELECTED_TMUX_CONFIG"
}

create_tmux_catppuccin_config() {
  cat > "$HOME/.tmux.conf" << 'CATPPUCCINEOF'
# ══════════════════════════════════════════════════════════════════════════════
# TMUX Configuration - Catppuccin Theme
# Gerado automaticamente pelo instalador de dotfiles
# ══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURAÇÕES BÁSICAS
# ─────────────────────────────────────────────────────────────────────────────

# Prefix: Ctrl+a (mais fácil que Ctrl+b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Terminal com cores
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Escape time (importante para Neovim)
set -sg escape-time 0

# Histórico
set -g history-limit 50000

# Indexar janelas e painéis a partir de 1
set -g base-index 1
setw -g pane-base-index 1

# Renumerar janelas automaticamente
set -g renumber-windows on

# Mouse
set -g mouse on

# Vi mode
setw -g mode-keys vi

# ─────────────────────────────────────────────────────────────────────────────
# KEYBINDINGS
# ─────────────────────────────────────────────────────────────────────────────

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Split panes (mais intuitivo)
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Nova janela no diretório atual
bind c new-window -c "#{pane_current_path}"

# Navegação entre painéis (vim-style)
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize painéis
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Copy mode (vi-style)
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"

# ─────────────────────────────────────────────────────────────────────────────
# PLUGINS (TPM)
# ─────────────────────────────────────────────────────────────────────────────

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'catppuccin/tmux'

# ─────────────────────────────────────────────────────────────────────────────
# CATPPUCCIN THEME
# ─────────────────────────────────────────────────────────────────────────────

set -g @catppuccin_flavor 'mocha'
set -g @catppuccin_window_status_style "rounded"

set -g @catppuccin_window_left_separator ""
set -g @catppuccin_window_right_separator " "
set -g @catppuccin_window_middle_separator " █"
set -g @catppuccin_window_number_position "right"

set -g @catppuccin_window_default_fill "number"
set -g @catppuccin_window_default_text "#W"
set -g @catppuccin_window_current_fill "number"
set -g @catppuccin_window_current_text "#W"

set -g @catppuccin_status_modules_right "directory session"
set -g @catppuccin_status_left_separator  " "
set -g @catppuccin_status_right_separator ""
set -g @catppuccin_status_fill "icon"
set -g @catppuccin_status_connect_separator "no"

set -g @catppuccin_directory_text "#{pane_current_path}"

# ─────────────────────────────────────────────────────────────────────────────
# PLUGIN OPTIONS
# ─────────────────────────────────────────────────────────────────────────────

# Resurrect: salvar/restaurar sessões
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-nvim 'session'

# Continuum: auto-save e restore
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# ─────────────────────────────────────────────────────────────────────────────
# INICIALIZAR TPM
# ─────────────────────────────────────────────────────────────────────────────

run '~/.tmux/plugins/tpm/tpm'
CATPPUCCINEOF
}

create_tmux_dracula_config() {
  cat > "$HOME/.tmux.conf" << 'DRACULAEOF'
# ══════════════════════════════════════════════════════════════════════════════
# TMUX Configuration - Dracula Theme
# Gerado automaticamente pelo instalador de dotfiles
# ══════════════════════════════════════════════════════════════════════════════

# Prefix: Ctrl+a
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Terminal
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -sg escape-time 0
set -g history-limit 50000

# Indexing
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Mouse & Vi mode
set -g mouse on
setw -g mode-keys vi

# Keybindings
bind r source-file ~/.tmux.conf \; display "Config reloaded!"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'dracula/tmux'

# Dracula theme options
set -g @dracula-show-powerline true
set -g @dracula-fixed-location "São Paulo"
set -g @dracula-plugins "cpu-usage ram-usage time"
set -g @dracula-show-flags true
set -g @dracula-show-left-icon session
set -g @dracula-cpu-usage-colors "pink dark_gray"
set -g @dracula-ram-usage-colors "cyan dark_gray"
set -g @dracula-time-format "%H:%M"

# Resurrect & Continuum
set -g @resurrect-capture-pane-contents 'on'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

run '~/.tmux/plugins/tpm/tpm'
DRACULAEOF
}

install_oh_my_tmux() {
  msg "  📦 Instalando Oh My Tmux..."
  git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux" >/dev/null 2>&1 || {
    record_failure "optional" "Falha ao instalar Oh My Tmux"
    return 0
  }
  ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
  cp "$HOME/.tmux/.tmux.conf.local" "$HOME/.tmux.conf.local"
}

create_tmux_minimal_config() {
  cat > "$HOME/.tmux.conf" << 'MINIMALEOF'
# ══════════════════════════════════════════════════════════════════════════════
# TMUX Configuration - Minimal
# Gerado automaticamente pelo instalador de dotfiles
# ══════════════════════════════════════════════════════════════════════════════

# Prefix: Ctrl+a
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Terminal
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -sg escape-time 0
set -g history-limit 50000

# Indexing
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Mouse & Vi mode
set -g mouse on
setw -g mode-keys vi

# Keybindings
bind r source-file ~/.tmux.conf \; display "Config reloaded!"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Status bar simples
set -g status-style 'bg=#1e1e2e fg=#cdd6f4'
set -g status-left '[#S] '
set -g status-right '%H:%M %d/%m'
set -g status-left-length 20
set -g status-right-length 50

# Plugins (TPM)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'

run '~/.tmux/plugins/tpm/tpm'
MINIMALEOF
}
