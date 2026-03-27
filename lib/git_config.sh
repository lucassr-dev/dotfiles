#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091

# ═══════════════════════════════════════════════════════════
# Variáveis globais
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

# Sanitiza path de diretório para uso em gitdir includeIf
# Remove caracteres perigosos que poderiam injetar diretivas git config
_sanitize_gitdir() {
  local dir="$1"
  # Expandir ~ para $HOME
  dir="${dir/#\~/$HOME}"
  # Rejeitar paths com caracteres que quebram git config
  if [[ "$dir" =~ [\"\'\`\$\;\\] ]]; then
    warn "Diretório rejeitado (caracteres inválidos): $dir"
    return 1
  fi
  # Rejeitar paths que não começam com /
  if [[ "$dir" != /* ]]; then
    warn "Diretório deve ser absoluto ou começar com ~: $dir"
    return 1
  fi
  echo "$dir"
}

_find_ssh_keys() {
  local -n _out_keys="$1"
  _out_keys=()

  if [[ -d "$HOME/.ssh" ]]; then
    while IFS= read -r key; do
      _out_keys+=("$key")
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" 2>/dev/null)
  fi

  if [[ -n "${SCRIPT_DIR:-}" ]] && [[ -d "$SCRIPT_DIR/shared/.ssh" ]]; then
    while IFS= read -r key; do
      local key_basename
      key_basename="$(basename "$key")"
      local found=0
      for existing in "${_out_keys[@]}"; do
        if [[ "$(basename "$existing")" == "$key_basename" ]]; then
          found=1
          break
        fi
      done
      [[ $found -eq 0 ]] && _out_keys+=("$key")
    done < <(find "$SCRIPT_DIR/shared/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys*" 2>/dev/null)
  fi
}

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
  while true; do
    GIT_CONFIGURE=0

    clear_screen
    show_git_multi_account_info

    if ! confirm_action "configurar Git multi-conta"; then
      msg ""
      msg "  ⏭️  Pulando configuração Git"
      return 0
    fi

    GIT_CONFIGURE=1

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
    local -a _raw_dirs=()
    read -r -a _raw_dirs <<< "$personal_dirs_input"
    GIT_PERSONAL_DIRS=()
    for _d in "${_raw_dirs[@]}"; do
      _d="${_d/#\~/$HOME}"
      GIT_PERSONAL_DIRS+=("$_d")
    done
  fi

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

  local ssh_keys=()
  _find_ssh_keys ssh_keys

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
    local -a _raw_dirs=()
    read -r -a _raw_dirs <<< "$work_dirs_input"
    GIT_WORK_DIRS=()
    for _d in "${_raw_dirs[@]}"; do
      _d="${_d/#\~/$HOME}"
      GIT_WORK_DIRS+=("$_d")
    done
  fi

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

  local ssh_keys=()
  _find_ssh_keys ssh_keys

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

    local git_summary="$GIT_PERSONAL_NAME <$GIT_PERSONAL_EMAIL>"
    if confirm_selection "🔧 Git Config" "$git_summary"; then
      break
    fi
  done
}

# ═══════════════════════════════════════════════════════════
# Instalação da configuração Git
# ═══════════════════════════════════════════════════════════

install_git_configuration() {
  [[ $GIT_CONFIGURE -eq 0 ]] && return 0

  msg "▶ Configurando Git multi-conta"
  msg ""

  if is_truthy "${DRY_RUN:-0}"; then
    msg "  🔎 (dry-run) criaria ~/.gitconfig-personal e ~/.gitconfig-work"
    msg "  🔎 (dry-run) atualizaria ~/.gitconfig com includeIf para contas pessoal/trabalho"
    msg "  🔎 (dry-run) garantiria diretórios: ${GIT_PERSONAL_DIRS[*]} ${GIT_WORK_DIRS[*]}"
    return 0
  fi

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
    sshCommand = ssh -i "${GIT_PERSONAL_SSH_KEY}" -o IdentitiesOnly=yes
EOF
  fi

  msg "  ✅ Criado: ~/.gitconfig-personal"

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
    sshCommand = ssh -i "${GIT_WORK_SSH_KEY}" -o IdentitiesOnly=yes
EOF
  fi

  msg "  ✅ Criado: ~/.gitconfig-work"

  local gitconfig="$HOME/.gitconfig"
  backup_if_exists "$gitconfig"
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

  for dir in "${GIT_PERSONAL_DIRS[@]}"; do
    local safe_dir
    safe_dir="$(_sanitize_gitdir "$dir")" || continue
    {
      echo "[includeIf \"gitdir:${safe_dir}/\"]"
      echo "    path = ~/.gitconfig-personal"
      echo ""
    } >> "$gitconfig"
  done

  for dir in "${GIT_WORK_DIRS[@]}"; do
    local safe_dir
    safe_dir="$(_sanitize_gitdir "$dir")" || continue
    {
      echo "[includeIf \"gitdir:${safe_dir}/\"]"
      echo "    path = ~/.gitconfig-work"
      echo ""
    } >> "$gitconfig"
  done

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

  # Windows: adicionar credential manager-core (Git Credential Manager)
  if [[ "${TARGET_OS:-}" == "windows" ]]; then
    cat >> "$gitconfig" << 'EOF_WIN'

[credential]
    helper = manager-core
EOF_WIN
    msg "  ℹ️  Credential helper: manager-core (Windows)"
  fi

  msg "  ✅ Criado: ~/.gitconfig"
  msg ""

  msg "  📁 Criando diretórios configurados..."
  for dir in "${GIT_PERSONAL_DIRS[@]}" "${GIT_WORK_DIRS[@]}"; do
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

  # ── Gerar ~/.ssh/config com Host aliases para GitHub ──
  generate_ssh_config

  msg ""
  msg "  ✅ Configuração Git multi-conta concluída!"
  msg ""

  INSTALLED_MISC+=("git: multi-conta configurada")
}

# ═══════════════════════════════════════════════════════════
# Geração de ~/.ssh/config com Host aliases
# ═══════════════════════════════════════════════════════════
#
# Complementa o sshCommand do gitconfig. O sshCommand seleciona
# a chave por diretório (pós-clone), enquanto o Host alias
# permite clones com git@github.com-<user>:... (pré-clone).

generate_ssh_config() {
  local ssh_config="$HOME/.ssh/config"

  # Se manage_ssh_keys já copiou o config estático do repo, não sobrescrever
  if [[ -f "$ssh_config" ]] && grep -q "github.com-" "$ssh_config" 2>/dev/null; then
    msg "  ℹ️  SSH config já contém Host aliases (copiado do repo)"
    return 0
  fi

  local needs_write=0
  local entries=()

  # Coletar entradas a gerar (pessoal + trabalho)
  if [[ -n "$GIT_PERSONAL_USER" ]] && [[ -n "$GIT_PERSONAL_SSH_KEY" ]]; then
    local host_alias="github.com-${GIT_PERSONAL_USER}"
    entries+=("$host_alias|$GIT_PERSONAL_SSH_KEY")
  fi

  if [[ -n "$GIT_WORK_USER" ]] && [[ -n "$GIT_WORK_SSH_KEY" ]]; then
    local host_alias="github.com-${GIT_WORK_USER}"
    entries+=("$host_alias|$GIT_WORK_SSH_KEY")
  fi

  [[ ${#entries[@]} -eq 0 ]] && return 0

  mkdir -p "$HOME/.ssh"

  # Verificar quais entradas já existem
  local new_entries=()
  for entry in "${entries[@]}"; do
    local alias="${entry%%|*}"
    if [[ -f "$ssh_config" ]] && grep -q "^Host ${alias}$" "$ssh_config" 2>/dev/null; then
      msg "  ℹ️  SSH Host '$alias' já configurado"
    else
      new_entries+=("$entry")
      needs_write=1
    fi
  done

  [[ $needs_write -eq 0 ]] && return 0

  # Adicionar novas entradas ao config (append, preserva existente)
  {
    # Separador se o arquivo já existe e tem conteúdo
    if [[ -f "$ssh_config" ]] && [[ -s "$ssh_config" ]]; then
      echo ""
      echo "# ── Gerado por dotfiles installer ──"
    else
      echo "# ════════════════════════════════════════════════════════════════"
      echo "# SSH Config - Gerado pelo dotfiles installer"
      echo "# ════════════════════════════════════════════════════════════════"
    fi

    for entry in "${new_entries[@]}"; do
      local alias="${entry%%|*}"
      local key="${entry##*|}"
      echo ""
      echo "Host ${alias}"
      echo "    HostName github.com"
      echo "    User git"
      echo "    IdentityFile ${key}"
      echo "    IdentitiesOnly yes"
    done

    # Adicionar bloco global se o arquivo é novo
    if [[ ! -f "$ssh_config" ]] || [[ ! -s "$ssh_config" ]]; then
      echo ""
      echo "# ════════════════════════════════════════════════════════════════"
      echo "# Configurações Globais"
      echo "# ════════════════════════════════════════════════════════════════"
      echo "Host *"
      echo "    AddKeysToAgent yes"
      echo "    ServerAliveInterval 60"
      echo "    ServerAliveCountMax 3"
    fi
  } >> "$ssh_config"

  chmod 600 "$ssh_config"

  for entry in "${new_entries[@]}"; do
    local alias="${entry%%|*}"
    msg "  ✅ SSH Host '${alias}' configurado"
  done
}
