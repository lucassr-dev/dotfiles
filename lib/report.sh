#!/usr/bin/env bash
# Relatório pós-instalação

# Função auxiliar para obter versão de forma limpa
get_version() {
  local cmd="$1"
  local version_output=""

  case "$cmd" in
    git)
      version_output="$(git --version 2>&1 | awk '{print $3}')"
      ;;
    zsh)
      version_output="$(zsh --version 2>&1 | awk '{print $2}')"
      ;;
    fish)
      version_output="$(fish --version 2>&1 | awk '{print $3}')"
      ;;
    tmux)
      version_output="$(tmux -V 2>&1 | awk '{print $2}')"
      ;;
    nvim)
      version_output="$(nvim --version 2>&1 | head -n 1 | awk '{print $2}')"
      ;;
    starship)
      version_output="$(starship --version 2>/dev/null | head -n 1 | awk '{print $2}')"
      ;;
    mise)
      version_output="$(mise --version 2>/dev/null | head -n 1 | awk '{print $1}')"
      ;;
    code)
      version_output="$(code --version 2>&1 | head -n 1)"
      ;;
    docker)
      version_output="$(docker --version 2>&1 | awk '{print $3}' | tr -d ',')"
      ;;
  esac

  version_output="${version_output//$'\r'/}"
  version_output="${version_output//$'\n'/ }"
  version_output="${version_output## }"
  version_output="${version_output%% }"

  echo "${version_output:-não instalado}"
}

print_post_install_report() {
  local verbose_report="${VERBOSE_REPORT:-0}"
  local username="${USER:-$(whoami)}"
  local hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo 'localhost')}"

  if [[ -t 1 ]]; then
    if declare -F clear_screen >/dev/null; then
      clear_screen
    else
      clear
    fi
  fi

  msg "✅ Instalação concluída"
  msg ""
  msg "Ambiente:"
  msg "  • OS: ${TARGET_OS:-desconhecido}"
  msg "  • Host: ${hostname}"
  msg "  • User: ${username}"
  msg ""

  msg "Versões instaladas:"
  local had_version=0
  if has_cmd git; then msg "  • git $(get_version git)"; had_version=1; fi
  if has_cmd zsh; then msg "  • zsh $(get_version zsh)"; had_version=1; fi
  if has_cmd fish; then msg "  • fish $(get_version fish)"; had_version=1; fi
  if has_cmd tmux; then msg "  • tmux $(get_version tmux)"; had_version=1; fi
  if has_cmd nvim; then msg "  • nvim $(get_version nvim)"; had_version=1; fi
  if has_cmd starship; then msg "  • starship $(get_version starship)"; had_version=1; fi
  if has_cmd code; then msg "  • vscode $(get_version code)"; had_version=1; fi
  if has_cmd docker; then msg "  • docker $(get_version docker)"; had_version=1; fi
  if has_cmd mise; then msg "  • mise $(get_version mise)"; had_version=1; fi
  if [[ $had_version -eq 0 ]]; then
    msg "  • (nenhum encontrado)"
  fi

  if [[ ${#SELECTED_RUNTIMES[@]} -gt 0 ]]; then
    msg ""
    msg "Runtimes:"
    local had_runtime=0
    for runtime in "${SELECTED_RUNTIMES[@]}"; do
      case "$runtime" in
        node)
          local v=""
          v="$(mise exec -- node --version 2>/dev/null | head -n 1)"
          [[ -z "$v" ]] && v="$(node --version 2>/dev/null)"
          [[ -n "$v" ]] && { msg "  • node $v"; had_runtime=1; }
          ;;
        python)
          local v=""
          v="$(mise exec -- python --version 2>/dev/null | head -n 1)"
          [[ -z "$v" ]] && v="$(python --version 2>/dev/null)"
          [[ -n "$v" ]] && { msg "  • python $v"; had_runtime=1; }
          ;;
        php)
          local v=""
          v="$(mise exec -- php --version 2>/dev/null | head -n 1 | awk '{print $2}')"
          [[ -z "$v" ]] && v="$(php --version 2>/dev/null | head -n 1 | awk '{print $2}')"
          [[ -n "$v" ]] && { msg "  • php $v"; had_runtime=1; }
          ;;
        rust)
          local v=""
          v="$(mise exec -- rustc --version 2>/dev/null | awk '{print $2}')"
          [[ -z "$v" ]] && v="$(rustc --version 2>/dev/null | awk '{print $2}')"
          [[ -n "$v" ]] && { msg "  • rustc $v"; had_runtime=1; }
          ;;
        go)
          local v=""
          v="$(mise exec -- go version 2>/dev/null | awk '{print $3}' | tr -d 'go')"
          [[ -z "$v" ]] && v="$(go version 2>/dev/null | awk '{print $3}' | tr -d 'go')"
          [[ -n "$v" ]] && { msg "  • go $v"; had_runtime=1; }
          ;;
        bun)
          local v=""
          v="$(mise exec -- bun --version 2>/dev/null | head -n 1)"
          [[ -z "$v" ]] && v="$(bun --version 2>/dev/null | head -n 1)"
          [[ -n "$v" ]] && { msg "  • bun $v"; had_runtime=1; }
          ;;
        deno)
          local v=""
          v="$(mise exec -- deno --version 2>/dev/null | head -n 1 | awk '{print $2}')"
          [[ -z "$v" ]] && v="$(deno --version 2>/dev/null | head -n 1 | awk '{print $2}')"
          [[ -n "$v" ]] && { msg "  • deno $v"; had_runtime=1; }
          ;;
        elixir)
          local v=""
          v="$(mise exec -- elixir --version 2>/dev/null | tail -n 1 | awk '{print $2}')"
          [[ -z "$v" ]] && v="$(elixir --version 2>/dev/null | tail -n 1 | awk '{print $2}')"
          [[ -n "$v" ]] && { msg "  • elixir $v"; had_runtime=1; }
          ;;
        java)
          local v=""
          v="$(mise exec -- java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')"
          [[ -z "$v" ]] && v="$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')"
          [[ -n "$v" ]] && { msg "  • java $v"; had_runtime=1; }
          ;;
        ruby)
          local v=""
          v="$(mise exec -- ruby --version 2>/dev/null | awk '{print $2}')"
          [[ -z "$v" ]] && v="$(ruby --version 2>/dev/null | awk '{print $2}')"
          [[ -n "$v" ]] && { msg "  • ruby $v"; had_runtime=1; }
          ;;
      esac
    done
    if [[ $had_runtime -eq 0 ]]; then
      msg "  • (nenhum encontrado)"
    fi
  fi

  if [[ -d "$BACKUP_DIR" ]]; then
    msg ""
    msg "Backup: $BACKUP_DIR"
  fi

  if ! is_truthy "$verbose_report"; then
    msg ""
    msg "Detalhes: VERBOSE_REPORT=1"
  fi

  if is_truthy "$verbose_report"; then
    msg ""
    msg "Detalhado:"
    if [[ ${#COPIED_PATHS[@]} -gt 0 ]]; then
      msg "  • Configs copiados (${#COPIED_PATHS[@]}):"
      for p in "${COPIED_PATHS[@]}"; do
        msg "    - $(basename "$p")"
      done
    fi

    if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
      msg "  • Pacotes instalados (${#INSTALLED_PACKAGES[@]}):"
      for p in "${INSTALLED_PACKAGES[@]}"; do
        msg "    - $p"
      done
    fi

    if [[ ${#INSTALLED_MISC[@]} -gt 0 ]]; then
      msg "  • Ferramentas extras (${#INSTALLED_MISC[@]}):"
      for p in "${INSTALLED_MISC[@]}"; do
        msg "    - $p"
      done
    fi
  fi

  msg ""
  msg "Próximos passos:"
  msg "  1) Reinicie seu terminal ou execute: exec \$SHELL"
  if has_cmd zsh && [[ "${SHELL##*/}" != "zsh" ]]; then
    msg "  2) Mude para Zsh: chsh -s \$(which zsh)"
  fi
  if has_cmd git && [[ ${GIT_CONFIGURE:-0} -eq 0 ]]; then
    msg "  3) Configure git: git config --global user.name \"Seu Nome\""
    msg "  4) Configure git: git config --global user.email \"seu@email.com\""
  fi

  msg ""
  msg "Dicas rápidas:"
  msg "  • Use 'bash config/install.sh export' para salvar mudanças"
  msg "  • Use 'bash config/install.sh sync' para sincronizar"
  msg ""
}
