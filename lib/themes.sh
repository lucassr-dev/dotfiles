#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
# ─────────────────────────────────────────────────────────────────
# themes.sh — instalacao dos temas escolhidos (fase 4, tarefa C: split
# em tres arquivos — preview em lib/theme_preview.sh, selecao em
# lib/theme_select.sh — sem mudanca de comportamento).
#
# Le as globais populadas em lib/theme_select.sh: INSTALL_OH_MY_ZSH,
# INSTALL_POWERLEVEL10K, INSTALL_OH_MY_POSH, INSTALL_STARSHIP,
# SELECTED_OMZ_PLUGINS, SELECTED_OMZ_EXTERNAL_PLUGINS,
# SELECTED_FISH_PLUGINS, SELECTED_STARSHIP_PRESET, SELECTED_OMP_THEME
# e SELECTED_CATPPUCCIN_FLAVOR (esta ultima tambem recebe um default
# aqui, em install_starship, se o usuario nao tiver escolhido sabor).
#
# Le tambem INSTALL_ZSH/INSTALL_FISH/INSTALL_NUSHELL, TARGET_OS,
# ZSH_CUSTOM, DRY_RUN, REMOTE_SCRIPT_STRICT, REMOTE_SCRIPT_ALLOWLIST e
# FISHER_FUNCTION_SHA256 — todas externas, definidas em install.sh ou
# no ambiente. Escreve em INSTALLED_MISC (array externo, declarado em
# install.sh, consumido pelo relatorio pos-instalacao).
#
# Nao chama nenhuma funcao de lib/theme_preview.sh ou
# lib/theme_select.sh: as funcoes install_* sao autocontidas, chamadas
# so por install_selected_themes (neste mesmo arquivo) e por
# install.sh.
# ─────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════
# Instalação de Oh My Zsh
# ═══════════════════════════════════════════════════════════

install_oh_my_zsh() {
  [[ $INSTALL_OH_MY_ZSH -eq 0 ]] && return 0
  [[ $INSTALL_ZSH -eq 0 ]] && return 0

  local oh_my_zsh_dir="$HOME/.oh-my-zsh"
  local zshrc="$HOME/.zshrc"

  if [[ -d "$oh_my_zsh_dir" ]]; then
    msg "  ℹ️  Oh My Zsh já está instalado"
  else
    msg "  📦 Instalando Oh My Zsh..."
    if download_and_run_script "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "Oh My Zsh" "sh" "" "--unattended"; then
      INSTALLED_MISC+=("oh-my-zsh: framework")
      msg "  ✅ Oh My Zsh instalado"
    else
      record_failure "optional" "Falha ao instalar Oh My Zsh"
      return 1
    fi
  fi

  if [[ ${#SELECTED_OMZ_EXTERNAL_PLUGINS[@]} -gt 0 ]]; then
    msg "  📦 Instalando plugins externos..."

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    for plugin in "${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}"; do
      local plugin_dir="$zsh_custom/plugins/$plugin"

      if [[ -d "$plugin_dir" ]]; then
        msg "  ℹ️  Plugin $plugin já está instalado"
        continue
      fi

      case "$plugin" in
        zsh-autosuggestions)
          msg "  📥 Baixando zsh-autosuggestions..."
          if run_mutating "clonar zsh-autosuggestions" git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-autosuggestions instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-autosuggestions")
          else
            warn "Falha ao clonar zsh-autosuggestions"
          fi
          ;;
        zsh-syntax-highlighting)
          msg "  📥 Baixando zsh-syntax-highlighting..."
          if run_mutating "clonar zsh-syntax-highlighting" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-syntax-highlighting instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-syntax-highlighting")
          else
            warn "Falha ao clonar zsh-syntax-highlighting"
          fi
          ;;
        fast-syntax-highlighting)
          msg "  📥 Baixando fast-syntax-highlighting..."
          if run_mutating "clonar fast-syntax-highlighting" git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ fast-syntax-highlighting instalado"
            INSTALLED_MISC+=("omz-plugin: fast-syntax-highlighting")
          else
            warn "Falha ao clonar fast-syntax-highlighting"
          fi
          ;;
        zsh-autocomplete)
          msg "  📥 Baixando zsh-autocomplete..."
          if run_mutating "clonar zsh-autocomplete" git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-autocomplete instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-autocomplete")
          else
            warn "Falha ao clonar zsh-autocomplete"
          fi
          ;;
        zsh-completions)
          msg "  📥 Baixando zsh-completions..."
          if run_mutating "clonar zsh-completions" git clone https://github.com/zsh-users/zsh-completions.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ zsh-completions instalado"
            INSTALLED_MISC+=("omz-plugin: zsh-completions")
          else
            warn "Falha ao clonar zsh-completions"
          fi
          ;;
        you-should-use)
          msg "  📥 Baixando you-should-use..."
          if run_mutating "clonar you-should-use" git clone https://github.com/MichaelAquilina/zsh-you-should-use.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ you-should-use instalado"
            INSTALLED_MISC+=("omz-plugin: you-should-use")
          else
            warn "Falha ao clonar you-should-use"
          fi
          ;;
        fzf-tab)
          msg "  📥 Baixando fzf-tab..."
          if run_mutating "clonar fzf-tab" git clone https://github.com/Aloxaf/fzf-tab.git "$plugin_dir" 2>/dev/null; then
            msg "  ✅ fzf-tab instalado"
            INSTALLED_MISC+=("omz-plugin: fzf-tab")
          else
            warn "Falha ao clonar fzf-tab"
          fi
          ;;
      esac
    done
  fi

  local all_plugins=()
  all_plugins+=("${SELECTED_OMZ_PLUGINS[@]}")
  all_plugins+=("${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}")

  if [[ ${#all_plugins[@]} -gt 0 ]] && [[ -f "$zshrc" ]]; then
    local plugins_str="${all_plugins[*]}"

    if grep -q "^plugins=" "$zshrc"; then
      if is_truthy "$DRY_RUN"; then
        msg "  🔎 (dry-run) atualizaria plugins=($plugins_str) em $zshrc"
      else
        msg "  🔌 Configurando plugins no .zshrc..."
        sed -i.bak "s/^plugins=.*/plugins=($plugins_str)/" "$zshrc"
        rm -f "$zshrc.bak"
        msg "  ✅ Plugins configurados: $plugins_str"
      fi
    else
      append_block_to_file "$zshrc" "plugins=($plugins_str)"
      msg "  ✅ Plugins adicionados ao .zshrc"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Powerlevel10k
# ═══════════════════════════════════════════════════════════

install_powerlevel10k() {
  [[ $INSTALL_POWERLEVEL10K -eq 0 ]] && return 0
  [[ $INSTALL_ZSH -eq 0 ]] && return 0

  local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

  if [[ -d "$p10k_dir" ]]; then
    msg "  ℹ️  Powerlevel10k já está instalado"
    return 0
  fi

  msg "  📦 Instalando Powerlevel10k..."

  if has_cmd git; then
    if run_mutating "clonar powerlevel10k" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" 2>/dev/null; then
      INSTALLED_MISC+=("powerlevel10k: tema")
      msg "  ✅ Powerlevel10k instalado"
      msg "  💡 Execute 'p10k configure' para configurar o tema"
    else
      record_failure "optional" "Falha ao instalar Powerlevel10k"
    fi
  else
    record_failure "optional" "git não encontrado - necessário para instalar Powerlevel10k"
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Starship
# ═══════════════════════════════════════════════════════════

install_starship() {
  [[ $INSTALL_STARSHIP -eq 0 ]] && return 0

  local starship_installed=0

  if has_cmd starship; then
    msg "  ℹ️  Starship já está instalado"
    starship_installed=1
  else
    msg "  📦 Instalando Starship..."

    case "$TARGET_OS" in
      linux|wsl2)
        if download_and_run_script "https://starship.rs/install.sh" "Starship" "sh" "" "-y"; then
          INSTALLED_MISC+=("starship: prompt")
          msg "  ✅ Starship instalado"
          starship_installed=1
        else
          record_failure "optional" "Falha ao instalar Starship"
          return 1
        fi
        ;;
      macos)
        brew_install_formula starship optional && starship_installed=1
        ;;
      windows)
        winget_install starship optional && starship_installed=1
        ;;
    esac
  fi

  if [[ $starship_installed -eq 1 ]] && [[ -n "$SELECTED_STARSHIP_PRESET" ]]; then
    local config_dir="$HOME/.config"
    local starship_config="$config_dir/starship.toml"
    local preset="$SELECTED_STARSHIP_PRESET"

    if [[ "$preset" == "plain" ]]; then
      preset="plain-text-symbols"
    fi

    msg "  ✨ Configurando preset: $preset"

    if ! is_truthy "$DRY_RUN"; then
      mkdir -p "$config_dir"
    fi

    if run_mutating "gerar preset $preset do starship em $starship_config" starship preset "$preset" -o "$starship_config" 2>/dev/null; then
      msg "  ✅ Preset $preset aplicado"

      if [[ "$preset" == "catppuccin-powerline" ]] && [[ -n "${SELECTED_CATPPUCCIN_FLAVOR:-}" ]]; then
        if [[ -z "$SELECTED_CATPPUCCIN_FLAVOR" ]]; then
          warn "Sabor Catppuccin não selecionado, usando padrão (mocha)"
          SELECTED_CATPPUCCIN_FLAVOR="catppuccin_mocha"
        fi
        msg "  🎨 Aplicando sabor Catppuccin: ${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_}"
        if [[ -f "$starship_config" ]]; then
          sed -i.bak "s/palette = 'catppuccin_mocha'/palette = '$SELECTED_CATPPUCCIN_FLAVOR'/" "$starship_config" && rm -f "${starship_config}.bak"
          msg "  ✅ Sabor ${SELECTED_CATPPUCCIN_FLAVOR#catppuccin_} aplicado"
        fi
      fi

      msg "  📄 Configuração salva em: $starship_config"
    else
      warn "Preset $preset não encontrado"
      msg "  ℹ️  Usando preset 'nerd-font-symbols' como fallback"
      if run_mutating "gerar preset nerd-font-symbols do starship em $starship_config" starship preset nerd-font-symbols -o "$starship_config" 2>/dev/null; then
        msg "  ✅ Preset fallback aplicado"
      else
        msg "  💡 Você pode configurar manualmente editando $starship_config"
      fi
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Oh My Posh
# ═══════════════════════════════════════════════════════════

install_oh_my_posh() {
  [[ $INSTALL_OH_MY_POSH -eq 0 ]] && return 0

  local omp_installed=0

  if has_cmd oh-my-posh; then
    msg "  ℹ️  Oh My Posh já está instalado"
    omp_installed=1
  else
    msg "  📦 Instalando Oh My Posh..."

    case "$TARGET_OS" in
      linux|wsl2)
        if download_and_run_script "https://ohmyposh.dev/install.sh" "Oh My Posh" "bash"; then
          INSTALLED_MISC+=("oh-my-posh: prompt")
          msg "  ✅ Oh My Posh instalado"
          omp_installed=1
        else
          record_failure "optional" "Falha ao instalar Oh My Posh"
          return 1
        fi
        ;;
      macos)
        brew_install_formula oh-my-posh optional && omp_installed=1
        ;;
      windows)
        winget_install JanDeDobbeleer.OhMyPosh optional && omp_installed=1
        ;;
    esac
  fi

  if [[ $omp_installed -eq 1 ]] && [[ -n "$SELECTED_OMP_THEME" ]]; then
    msg "  🎭 Configurando tema: $SELECTED_OMP_THEME"

    local theme_file=""

    local possible_dirs=(
      "$HOME/.poshthemes"
      "$(brew --prefix oh-my-posh 2>/dev/null)/themes"
      "/usr/local/share/oh-my-posh/themes"
      "$HOME/.local/share/oh-my-posh/themes"
    )

    for dir in "${possible_dirs[@]}"; do
      if [[ -f "$dir/${SELECTED_OMP_THEME}.omp.json" ]]; then
        theme_file="$dir/${SELECTED_OMP_THEME}.omp.json"
        break
      fi
    done

    if [[ -n "$theme_file" ]]; then
      msg "  ✅ Tema encontrado: $theme_file"

      if [[ $INSTALL_ZSH -eq 1 ]] && [[ -f "$HOME/.zshrc" ]]; then
        local safe_theme_file="${theme_file//\'/\'\\\'\'}"
        local init_line="eval \"\$(oh-my-posh init zsh --config '${safe_theme_file}')\""
        if ! grep -q "oh-my-posh init zsh" "$HOME/.zshrc"; then
          append_block_to_file "$HOME/.zshrc" "" "# Oh My Posh" "$init_line"
          msg "  ✅ Oh My Posh configurado no .zshrc"
        fi
      fi

      if [[ $INSTALL_FISH -eq 1 ]] && [[ -d "$HOME/.config/fish" ]]; then
        local fish_config="$HOME/.config/fish/config.fish"
        mkdir -p "$HOME/.config/fish"
        local init_line="oh-my-posh init fish --config '$theme_file' | source"
        if ! grep -q "oh-my-posh init fish" "$fish_config" 2>/dev/null; then
          append_block_to_file "$fish_config" "" "# Oh My Posh" "$init_line"
          msg "  ✅ Oh My Posh configurado no config.fish"
        fi
      fi

      if [[ ${INSTALL_NUSHELL:-0} -eq 1 ]]; then
        local nu_config_dir="$HOME/.config/nushell"
        if is_truthy "$DRY_RUN"; then
          msg "  🔎 (dry-run) configuraria Oh My Posh para Nushell em $nu_config_dir"
        else
          mkdir -p "$nu_config_dir/scripts"
          cp "$theme_file" "$nu_config_dir/omp-theme.json"
          if has_cmd oh-my-posh; then
            oh-my-posh init nu --config "$nu_config_dir/omp-theme.json" > "$nu_config_dir/scripts/omp.nu" 2>/dev/null || true
            msg "  ✅ Oh My Posh init script gerado para Nushell"
          fi
          msg "  ✅ Oh My Posh configurado para Nushell ($nu_config_dir/omp-theme.json)"
        fi
      fi
    else
      warn "Tema $SELECTED_OMP_THEME não encontrado em diretórios conhecidos"
      msg "  💡 Configure manualmente: oh-my-posh init <shell> --config <tema>.omp.json"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de Fisher e plugins do Fish
# ═══════════════════════════════════════════════════════════

_install_fisher_secure() {
  local fisher_url="https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish"
  local expected_sha256="${FISHER_FUNCTION_SHA256:-}"

  if ! has_cmd curl; then
    warn "curl não encontrado - não foi possível instalar Fisher"
    return 1
  fi

  if declare -F _extract_url_host >/dev/null 2>&1 && declare -F _is_trusted_remote_host >/dev/null 2>&1; then
    local host=""
    host="$(_extract_url_host "$fisher_url")"
    if [[ -z "$host" ]]; then
      warn "URL inválida para instalação do Fisher"
      return 1
    fi

    if ! _is_trusted_remote_host "$host"; then
      local trust_msg="Host remoto não permitido para Fisher: $host (ajuste REMOTE_SCRIPT_ALLOWLIST)"
      if declare -F is_truthy >/dev/null 2>&1 && is_truthy "${REMOTE_SCRIPT_STRICT:-1}"; then
        warn "$trust_msg"
        return 1
      fi
      warn "$trust_msg"
    fi
  fi

  local temp_fisher=""
  temp_fisher="$(mktemp)" || {
    warn "Falha ao criar arquivo temporário para Fisher"
    return 1
  }

  local -a curl_args=(-fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_TIMEOUT_NORMAL")
  if ! curl "${curl_args[@]}" "$fisher_url" -o "$temp_fisher"; then
    rm -f "$temp_fisher" 2>/dev/null || true
    warn "Falha ao baixar Fisher"
    return 1
  fi
  chmod 600 "$temp_fisher" 2>/dev/null || true

  if declare -F _verify_remote_script_checksum >/dev/null 2>&1; then
    if ! _verify_remote_script_checksum "$temp_fisher" "Fisher" "$expected_sha256"; then
      rm -f "$temp_fisher" 2>/dev/null || true
      return 1
    fi
  fi

  if fish -c "source '$temp_fisher'; fisher install jorgebucaran/fisher" >/dev/null 2>&1; then
    rm -f "$temp_fisher" 2>/dev/null || true
    return 0
  fi

  rm -f "$temp_fisher" 2>/dev/null || true
  return 1
}

install_fish_plugins() {
  [[ $INSTALL_FISH -eq 0 ]] && return 0
  [[ ${#SELECTED_FISH_PLUGINS[@]} -eq 0 ]] && return 0

  if ! has_cmd fish; then
    warn "Fish não está instalado - pulando instalação de plugins"
    return 1
  fi

  msg "  🐟 Instalando Fisher e plugins do Fish..."

  local fisher_file="$HOME/.config/fish/functions/fisher.fish"
  if [[ ! -f "$fisher_file" ]]; then
    msg "  📦 Instalando Fisher (gerenciador de plugins)..."
    if run_mutating "instalar Fisher" _install_fisher_secure; then
      INSTALLED_MISC+=("fisher: gerenciador de plugins Fish")
      msg "  ✅ Fisher instalado"
    else
      warn "Falha ao instalar Fisher"
      return 1
    fi
  else
    msg "  ℹ️  Fisher já está instalado"
  fi

  local failed_plugins=()
  for plugin in "${SELECTED_FISH_PLUGINS[@]}"; do
    local plugin_repo=""
    local plugin_name=""

    case "$plugin" in
      z)
        plugin_repo="jethrokuan/z"
        plugin_name="z (navegação rápida)"
        ;;
      fzf.fish)
        plugin_repo="PatrickF1/fzf.fish"
        plugin_name="fzf.fish (integração fzf)"
        ;;
      done)
        plugin_repo="franciscolourenco/done"
        plugin_name="done (notificações)"
        ;;
      autopair.fish)
        plugin_repo="jorgebucaran/autopair.fish"
        plugin_name="autopair.fish (fechar parênteses)"
        ;;
      tide)
        plugin_repo="IlanCosman/tide@v6"
        plugin_name="tide (prompt)"
        ;;
    esac

    if [[ -n "$plugin_repo" ]]; then
      msg "  📥 Instalando $plugin_name..."

      if is_truthy "$DRY_RUN"; then
        msg "  🔎 (dry-run) fisher install $plugin_repo"
        INSTALLED_MISC+=("fish-plugin: $plugin")
        msg "  ✅ $plugin instalado"
        continue
      fi

      local fish_install_ok=0
      local fish_err=""
      fish_err=$(fish -c "fisher install $plugin_repo" 2>&1) && fish_install_ok=1

      if [[ $fish_install_ok -eq 0 ]] && echo "$fish_err" | grep -q "conflicting files"; then
        local conflict_file
        while IFS= read -r conflict_file; do
          conflict_file="${conflict_file#"${conflict_file%%[![:space:]]*}"}"
          [[ "$conflict_file" == /*.fish ]] && rm -f "$conflict_file"
        done <<< "$fish_err"
        fish -c "fisher install $plugin_repo" >/dev/null 2>&1 && fish_install_ok=1
      fi

      if [[ $fish_install_ok -eq 1 ]]; then
        INSTALLED_MISC+=("fish-plugin: $plugin")
        msg "  ✅ $plugin instalado"
      else
        failed_plugins+=("$plugin")
        record_failure "optional" "Falha ao instalar plugin Fish: $plugin"
        warn "Falha ao instalar $plugin"
      fi
    fi
  done

  if [[ ${#failed_plugins[@]} -eq 0 ]]; then
    msg "  ✅ Plugins Fish instalados com sucesso!"
  else
    warn "Plugins Fish com falhas: ${failed_plugins[*]}"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════
# Instalação de todos os temas selecionados
# ═══════════════════════════════════════════════════════════

install_selected_themes() {
  local any_theme=0
  [[ $INSTALL_OH_MY_ZSH -eq 1 ]] && any_theme=1
  [[ $INSTALL_STARSHIP -eq 1 ]] && any_theme=1
  [[ $INSTALL_OH_MY_POSH -eq 1 ]] && any_theme=1

  [[ $any_theme -eq 0 ]] && return 0

  msg "▶ Instalando temas selecionados"
  msg ""

  install_oh_my_zsh
  install_powerlevel10k
  install_starship
  install_oh_my_posh
  install_fish_plugins

  msg ""
  msg "  ✅ Temas instalados com sucesso!"
  msg ""

  if [[ $INSTALL_OH_MY_ZSH -eq 1 ]]; then
    local all_omz_plugins=()
    all_omz_plugins+=("${SELECTED_OMZ_PLUGINS[@]}")
    all_omz_plugins+=("${SELECTED_OMZ_EXTERNAL_PLUGINS[@]}")

    if [[ ${#all_omz_plugins[@]} -gt 0 ]]; then
      msg "  🔌 Plugins Oh My Zsh: ${all_omz_plugins[*]}"
    fi
  fi

  if [[ $INSTALL_FISH -eq 1 ]] && [[ ${#SELECTED_FISH_PLUGINS[@]} -gt 0 ]]; then
    msg "  🐟 Plugins Fish: ${SELECTED_FISH_PLUGINS[*]}"
  fi

  if [[ $INSTALL_STARSHIP -eq 1 ]] && [[ -n "$SELECTED_STARSHIP_PRESET" ]]; then
    msg "  ✨ Preset Starship aplicado: $SELECTED_STARSHIP_PRESET"
  fi

  if [[ $INSTALL_OH_MY_POSH -eq 1 ]] && [[ -n "$SELECTED_OMP_THEME" ]]; then
    msg "  🎭 Tema Oh My Posh configurado: $SELECTED_OMP_THEME"
  fi

  msg ""

  if [[ $INSTALL_POWERLEVEL10K -eq 1 ]]; then
    msg "  💡 Powerlevel10k: Execute 'p10k configure' para personalizar"
  fi

  if [[ $INSTALL_STARSHIP -eq 1 ]]; then
    msg "  💡 Starship: Edite ~/.config/starship.toml para personalizar"
    msg "     Presets: https://starship.rs/presets/"
  fi

  if [[ $INSTALL_OH_MY_POSH -eq 1 ]]; then
    msg "  💡 Oh My Posh: Veja temas disponíveis com 'oh-my-posh get shell'"
    msg "     Temas: https://ohmyposh.dev/docs/themes"
  fi

  msg ""
}
