#!/usr/bin/env bash
# Configuração Git multi-conta interativa
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Variáveis globais para configuração Git
# ═══════════════════════════════════════════════════════════

declare -a GIT_PERSONAL_DIRS=()
declare -a GIT_WORK_DIRS=()
GIT_PERSONAL_NAME=""
GIT_PERSONAL_EMAIL=""
GIT_PERSONAL_USER=""
GIT_PERSONAL_SSH_KEY=""
GIT_WORK_NAME=""
GIT_WORK_EMAIL=""
GIT_WORK_USER=""
GIT_WORK_SSH_KEY=""
GIT_EDITOR="nvim"
GIT_PAGER="delta"
GIT_CONFIGURE=0

# ═══════════════════════════════════════════════════════════
# Tela de informação sobre Git multi-conta
# ═══════════════════════════════════════════════════════════

show_git_multi_account_info() {
  show_section_header "🔐 GIT MULTI-CONTA - Configuração Automatizada"

  msg "O Git pode alternar automaticamente entre contas pessoal e trabalho"
  msg "baseado no diretório do projeto."
  msg ""
  msg "📝 Como funciona:"
  msg ""
  msg "  • Você define pastas para projetos pessoais (ex: ~/personal/, ~/projects/)"
  msg "  • Você define pastas para projetos de trabalho (ex: ~/work/, ~/workspace/)"
  msg "  • O Git usa includeIf para aplicar name/email correto automaticamente"
  msg "  • Cada commit terá o autor correto baseado na pasta do repo"
  msg "  • Chaves SSH diferentes para cada conta (pessoal vs trabalho)"
  msg ""
  msg "🎯 Benefícios:"
  msg ""
  msg "  • Sem necessidade de configurar git manualmente em cada repo"
  msg "  • Evita commits com autor errado (ex: email pessoal em repo do trabalho)"
  msg "  • Funciona automaticamente ao clonar novos repos"
  msg "  • Suporte para múltiplos usuários GitHub/GitLab"
  msg "  • Usa a chave SSH correta automaticamente por diretório"
  msg ""
  msg "⚙️  Configurações adicionais:"
  msg ""
  msg "  • Editor padrão (nvim, vim, nano, code, etc)"
  msg "  • Pager para diffs (delta, less, cat)"
  msg "  • Aliases úteis (st, co, lg, etc)"
  msg "  • Configurações avançadas de diff/merge"
  msg ""
}

# ═══════════════════════════════════════════════════════════
# Seleção de configuração Git
# ═══════════════════════════════════════════════════════════

ask_git_configuration() {
  GIT_CONFIGURE=0

  clear_screen
  show_git_multi_account_info

  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  🔧 CONFIGURAÇÃO GIT"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""

  if ! ask_yes_no "Deseja configurar Git multi-conta?"; then
    msg ""
    msg "  ⏭️  Pulando configuração Git"
    msg ""
    return 0
  fi

  GIT_CONFIGURE=1

  # Perguntar diretórios para conta pessoal
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  👤 CONTA PESSOAL - Diretórios"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""
  msg "Digite os diretórios onde você guarda projetos pessoais."
  msg "Separe múltiplos diretórios por espaço."
  msg ""
  msg "Exemplos:"
  msg "  • ~/personal"
  msg "  • ~/projects ~/personal ~/dev"
  msg "  • ~/code/personal ~/github"
  msg ""

  local personal_dirs_input=""
  read -r -p "  Diretórios pessoais (Enter para '~/personal ~/projects'): " personal_dirs_input

  if [[ -z "$personal_dirs_input" ]]; then
    GIT_PERSONAL_DIRS=("$HOME/personal" "$HOME/projects")
  else
    read -r -a GIT_PERSONAL_DIRS <<< "$personal_dirs_input"
  fi

  # Perguntar dados da conta pessoal
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  👤 CONTA PESSOAL - Dados"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""

  read -r -p "  Nome completo: " GIT_PERSONAL_NAME
  read -r -p "  Email: " GIT_PERSONAL_EMAIL
  read -r -p "  Usuário GitHub/GitLab (opcional): " GIT_PERSONAL_USER

  msg ""
  msg "🔑 Chave SSH para conta pessoal:"
  msg ""

  # Listar chaves SSH disponíveis (buscar em ~/.ssh e shared/.ssh)
  local ssh_keys=()

  # Buscar em ~/.ssh
  if [[ -d "$HOME/.ssh" ]]; then
    while IFS= read -r key; do
      ssh_keys+=("$key")
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" 2>/dev/null)
  fi

  # Buscar também em shared/.ssh (do repositório de config)
  if [[ -n "${SCRIPT_DIR:-}" ]] && [[ -d "$SCRIPT_DIR/shared/.ssh" ]]; then
    while IFS= read -r key; do
      # Evitar duplicatas (comparar basename)
      local key_basename
      key_basename="$(basename "$key")"
      local found=0
      for existing in "${ssh_keys[@]}"; do
        if [[ "$(basename "$existing")" == "$key_basename" ]]; then
          found=1
          break
        fi
      done
      [[ $found -eq 0 ]] && ssh_keys+=("$key")
    done < <(find "$SCRIPT_DIR/shared/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" 2>/dev/null)
  fi

  if [[ ${#ssh_keys[@]} -gt 0 ]]; then
    msg "  Chaves SSH encontradas:"
    local idx=1
    for key in "${ssh_keys[@]}"; do
      msg "    $idx) $(basename "$key")"
      idx=$((idx + 1))
    done
    msg ""

    local key_choice=""
    read -r -p "  Selecione uma chave (número) ou digite o caminho [1]: " key_choice
    key_choice="${key_choice:-1}"

    if [[ "$key_choice" =~ ^[0-9]+$ ]] && (( key_choice >= 1 )) && (( key_choice <= ${#ssh_keys[@]} )); then
      GIT_PERSONAL_SSH_KEY="${ssh_keys[key_choice-1]}"
    else
      GIT_PERSONAL_SSH_KEY="$key_choice"
    fi
  else
    msg "  ⚠️  Nenhuma chave SSH encontrada em ~/.ssh ou shared/.ssh"
    read -r -p "  Caminho da chave SSH (Enter para não configurar): " GIT_PERSONAL_SSH_KEY
  fi

  # Perguntar diretórios para conta de trabalho
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  💼 CONTA TRABALHO - Diretórios"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""
  msg "Digite os diretórios onde você guarda projetos de trabalho."
  msg "Separe múltiplos diretórios por espaço."
  msg ""
  msg "Exemplos:"
  msg "  • ~/work"
  msg "  • ~/work ~/workspace ~/company"
  msg "  • ~/work ~/humu ~/office"
  msg ""

  local work_dirs_input=""
  read -r -p "  Diretórios de trabalho (Enter para '~/work ~/workspace'): " work_dirs_input

  if [[ -z "$work_dirs_input" ]]; then
    GIT_WORK_DIRS=("$HOME/work" "$HOME/workspace")
  else
    read -r -a GIT_WORK_DIRS <<< "$work_dirs_input"
  fi

  # Perguntar dados da conta de trabalho
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  💼 CONTA TRABALHO - Dados"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""

  read -r -p "  Nome completo: " GIT_WORK_NAME
  read -r -p "  Email: " GIT_WORK_EMAIL
  read -r -p "  Usuário GitHub/GitLab (opcional): " GIT_WORK_USER

  msg ""
  msg "🔑 Chave SSH para conta de trabalho:"
  msg ""

  # Listar chaves SSH disponíveis (buscar em ~/.ssh e shared/.ssh)
  local ssh_keys=()

  # Buscar em ~/.ssh
  if [[ -d "$HOME/.ssh" ]]; then
    while IFS= read -r key; do
      ssh_keys+=("$key")
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" 2>/dev/null)
  fi

  # Buscar também em shared/.ssh (do repositório de config)
  if [[ -n "${SCRIPT_DIR:-}" ]] && [[ -d "$SCRIPT_DIR/shared/.ssh" ]]; then
    while IFS= read -r key; do
      # Evitar duplicatas (comparar basename)
      local key_basename
      key_basename="$(basename "$key")"
      local found=0
      for existing in "${ssh_keys[@]}"; do
        if [[ "$(basename "$existing")" == "$key_basename" ]]; then
          found=1
          break
        fi
      done
      [[ $found -eq 0 ]] && ssh_keys+=("$key")
    done < <(find "$SCRIPT_DIR/shared/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" 2>/dev/null)
  fi

  if [[ ${#ssh_keys[@]} -gt 0 ]]; then
    msg "  Chaves SSH encontradas:"
    local idx=1
    for key in "${ssh_keys[@]}"; do
      msg "    $idx) $(basename "$key")"
      idx=$((idx + 1))
    done
    msg ""

    local key_choice=""
    read -r -p "  Selecione uma chave (número) ou digite o caminho [2]: " key_choice
    key_choice="${key_choice:-2}"

    if [[ "$key_choice" =~ ^[0-9]+$ ]] && (( key_choice >= 1 )) && (( key_choice <= ${#ssh_keys[@]} )); then
      GIT_WORK_SSH_KEY="${ssh_keys[key_choice-1]}"
    else
      GIT_WORK_SSH_KEY="$key_choice"
    fi
  else
    msg "  ⚠️  Nenhuma chave SSH encontrada em ~/.ssh ou shared/.ssh"
    read -r -p "  Caminho da chave SSH (Enter para não configurar): " GIT_WORK_SSH_KEY
  fi

  # Perguntar preferências de editor e pager
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  ⚙️  PREFERÊNCIAS"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""

  local editor_input=""
  read -r -p "  Editor padrão (nvim/vim/nano/code) [nvim]: " editor_input
  GIT_EDITOR="${editor_input:-nvim}"

  local pager_input=""
  read -r -p "  Pager para diffs (delta/less/cat) [delta]: " pager_input
  GIT_PAGER="${pager_input:-delta}"

  # Resumo
  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  ✅ RESUMO DA CONFIGURAÇÃO GIT"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg ""
  msg "👤 CONTA PESSOAL:"
  msg "  • Nome: $GIT_PERSONAL_NAME"
  msg "  • Email: $GIT_PERSONAL_EMAIL"
  [[ -n "$GIT_PERSONAL_USER" ]] && msg "  • Usuário: $GIT_PERSONAL_USER"
  [[ -n "$GIT_PERSONAL_SSH_KEY" ]] && msg "  • Chave SSH: $GIT_PERSONAL_SSH_KEY"
  msg "  • Diretórios: ${GIT_PERSONAL_DIRS[*]}"
  msg ""
  msg "💼 CONTA TRABALHO:"
  msg "  • Nome: $GIT_WORK_NAME"
  msg "  • Email: $GIT_WORK_EMAIL"
  [[ -n "$GIT_WORK_USER" ]] && msg "  • Usuário: $GIT_WORK_USER"
  [[ -n "$GIT_WORK_SSH_KEY" ]] && msg "  • Chave SSH: $GIT_WORK_SSH_KEY"
  msg "  • Diretórios: ${GIT_WORK_DIRS[*]}"
  msg ""
  msg "⚙️  PREFERÊNCIAS:"
  msg "  • Editor: $GIT_EDITOR"
  msg "  • Pager: $GIT_PAGER"
  msg ""

  echo ""
  echo -e "  ${UI_CYAN}Enter${UI_RESET} para continuar  │  ${UI_YELLOW}B${UI_RESET} para voltar e alterar"
  echo ""

  local choice
  read -r -p "  → " choice

  case "${choice,,}" in
    b|back|voltar|v)
      clear_screen
      ask_git_configuration
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Instalação da configuração Git
# ═══════════════════════════════════════════════════════════

install_git_configuration() {
  [[ $GIT_CONFIGURE -eq 0 ]] && return 0

  msg "▶ Configurando Git multi-conta"
  msg ""

  # Criar .gitconfig-personal
  local gitconfig_personal="$HOME/.gitconfig-personal"
  cat > "$gitconfig_personal" << EOF
[user]
    name = $GIT_PERSONAL_NAME
    email = $GIT_PERSONAL_EMAIL
    useConfigOnly = true
EOF

  if [[ -n "$GIT_PERSONAL_USER" ]]; then
    cat >> "$gitconfig_personal" << EOF

[github]
    user = $GIT_PERSONAL_USER
EOF
  fi

  if [[ -n "$GIT_PERSONAL_SSH_KEY" ]]; then
    cat >> "$gitconfig_personal" << EOF

[core]
    sshCommand = ssh -i $GIT_PERSONAL_SSH_KEY -o IdentitiesOnly=yes
EOF
  fi

  msg "  ✅ Criado: ~/.gitconfig-personal"

  # Criar .gitconfig-work
  local gitconfig_work="$HOME/.gitconfig-work"
  cat > "$gitconfig_work" << EOF
[user]
    name = $GIT_WORK_NAME
    email = $GIT_WORK_EMAIL
    useConfigOnly = true
EOF

  if [[ -n "$GIT_WORK_USER" ]]; then
    cat >> "$gitconfig_work" << EOF

[github]
    user = $GIT_WORK_USER
EOF
  fi

  if [[ -n "$GIT_WORK_SSH_KEY" ]]; then
    cat >> "$gitconfig_work" << EOF

[core]
    sshCommand = ssh -i $GIT_WORK_SSH_KEY -o IdentitiesOnly=yes
EOF
  fi

  msg "  ✅ Criado: ~/.gitconfig-work"

  # Criar .gitconfig principal
  local gitconfig="$HOME/.gitconfig"
  cat > "$gitconfig" << 'EOF'
[color]
    status = auto
    branch = auto
    interactive = auto
    diff = auto

# ════════════════════════════════════════════════════════════════
# Alternar automaticamente entre contas pessoal e trabalho
# ════════════════════════════════════════════════════════════════

EOF

  # Adicionar includeIf para conta pessoal
  for dir in "${GIT_PERSONAL_DIRS[@]}"; do
    {
      echo "[includeIf \"gitdir:$dir/\"]"
      echo "    path = ~/.gitconfig-personal"
      echo ""
    } >> "$gitconfig"
  done

  # Adicionar includeIf para conta de trabalho
  for dir in "${GIT_WORK_DIRS[@]}"; do
    {
      echo "[includeIf \"gitdir:$dir/\"]"
      echo "    path = ~/.gitconfig-work"
      echo ""
    } >> "$gitconfig"
  done

  # Adicionar configurações gerais
  cat >> "$gitconfig" << EOF
# ════════════════════════════════════════════════════════════════
# Aliases úteis
# ════════════════════════════════════════════════════════════════
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline --graph --all --decorate
    last = log -1 HEAD
    unstage = reset HEAD --
    undo = reset --soft HEAD~1

# ════════════════════════════════════════════════════════════════
# Configurações de diff e merge
# ════════════════════════════════════════════════════════════════
[core]
    editor = $GIT_EDITOR
    pager = $GIT_PAGER

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    light = false
    side-by-side = true
    line-numbers = true

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default

# ════════════════════════════════════════════════════════════════
# Configurações de push e pull
# ════════════════════════════════════════════════════════════════
[push]
    default = current
    autoSetupRemote = true

[pull]
    rebase = false

# ════════════════════════════════════════════════════════════════
# Outras configurações úteis
# ════════════════════════════════════════════════════════════════
[init]
    defaultBranch = main

[credential]
    helper = cache --timeout=3600
EOF

  msg "  ✅ Criado: ~/.gitconfig"
  msg ""

  # Criar diretórios se não existirem
  msg "  📁 Criando diretórios configurados..."
  for dir in "${GIT_PERSONAL_DIRS[@]}" "${GIT_WORK_DIRS[@]}"; do
    # Expandir ~ para $HOME
    local expanded_dir="${dir/#\~/$HOME}"
    if [[ ! -d "$expanded_dir" ]]; then
      if mkdir -p "$expanded_dir" 2>/dev/null; then
        msg "    ✅ $dir"
      else
        warn "    ⚠️  Falha ao criar $dir"
      fi
    else
      msg "    ✅ $dir (já existe)"
    fi
  done

  msg ""
  msg "  ✅ Configuração Git multi-conta concluída!"
  msg ""

  INSTALLED_MISC+=("git: multi-conta configurada")
}
