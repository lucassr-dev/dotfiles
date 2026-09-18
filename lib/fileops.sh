#!/usr/bin/env bash

_files_identical() {
  local file_a="$1"
  local file_b="$2"
  [[ -f "$file_a" ]] && [[ -f "$file_b" ]] || return 1
  cmp -s "$file_a" "$file_b"
}

_show_diff() {
  local src="$1"
  local dest="$2"
  [[ -f "$dest" ]] || { msg "  (arquivo novo)"; return; }
  if has_cmd diff; then
    local output
    output=$(diff -u "$dest" "$src" 2>/dev/null | head -n 30) || true
    if [[ -n "$output" ]]; then
      msg "$output"
    else
      msg "  (sem diferenças)"
    fi
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]] && [[ "$MODE" == "install" ]]; then
    local base_name=""
    base_name="$(basename "$path")"
    _ensure_backup_dir
    local backup_path="$BACKUP_DIR/$base_name"
    msg "  💾 Backup: $path -> $backup_path"
    if ! cp -a "$path" "$backup_path" 2>/dev/null && ! cp -R "$path" "$backup_path" 2>/dev/null; then
      record_failure "critical" "Falha ao fazer backup de: $path" "Verifique permissões e espaço em disco"
      return 1
    fi
  fi
}

# Pergunta ao usuário antes de sobrescrever arquivo/diretório existente.
# Ativo somente quando CONFIRM_OVERWRITE=1. Retorna 0=sobrescreve, 1=pula.
# Destinos que não existem são aprovados automaticamente.
_confirm_overwrite() {
  local dest="$1"
  local src="${2:-}"
  [[ ! -e "$dest" ]] && return 0
  [[ "${CONFIRM_OVERWRITE:-0}" != "1" ]] && return 0
  [[ "${DRY_RUN:-0}" == "1" ]] && return 0
  [[ ! -t 0 ]] && return 0  # stdin não é TTY, pula prompt

  local answer=""
  while true; do
    printf "  ❓ %s já existe. Sobrescrever? [s/N/d=diff] " "$dest" >&2
    read -r answer
    case "${answer,,}" in
      s|sim|y|yes)
        return 0
        ;;
      ""|n|nao|não|no)
        msg "  ⏭️  Pulado: $dest"
        return 1
        ;;
      d|diff)
        if [[ -n "$src" ]] && [[ -f "$src" ]] && [[ -f "$dest" ]]; then
          _show_diff "$src" "$dest"
        else
          msg "  (diff indisponível para diretórios ou arquivos ausentes)"
        fi
        ;;
      *)
        msg "  (responda s=sim, n=não, d=diff)"
        ;;
    esac
  done
}

copy_dir() {
  local src="$1"
  local dest="$2"
  [[ -d "$src" ]] || return
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) 📁 $src -> $dest"
    return
  fi
  _confirm_overwrite "$dest" || return 0
  msg "  📁 $src -> $dest"
  backup_if_exists "$dest" || return 1
  mkdir -p "$dest"
  if ! cp -R "$src/." "$dest/"; then
    record_failure "critical" "Falha ao copiar diretório: $src -> $dest"
  elif [[ ! -d "$dest" ]]; then
    record_failure "critical" "Destino ausente após copiar diretório: $dest"
  else
    COPIED_PATHS+=("$dest")
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"
  [[ -f "$src" ]] || return
  if _files_identical "$src" "$dest"; then
    msg "  ✅ $dest (inalterado)"
    return
  fi
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) 📄 $src -> $dest"
    _show_diff "$src" "$dest"
    return
  fi
  _confirm_overwrite "$dest" "$src" || return 0
  msg "  📄 $src -> $dest"
  backup_if_exists "$dest" || return 1
  mkdir -p "$(dirname "$dest")"
  if ! cp "$src" "$dest"; then
    record_failure "critical" "Falha ao copiar arquivo: $src -> $dest"
  elif [[ ! -f "$dest" ]]; then
    record_failure "critical" "Destino ausente após copiar arquivo: $dest"
  else
    case "$dest" in
      *.sh|*.zsh|*.bash|*.fish|.zshrc|.bashrc|.profile)
        normalize_crlf_to_lf "$dest"
        ;;
    esac
    COPIED_PATHS+=("$dest")
  fi
}

# Ponto de estrangulamento para os varios `{ echo ...; echo ...; } >> "$arquivo"`
# espalhados por lib/themes.sh e install.sh (plugins do zsh, init do Oh My
# Posh, configuracoes de PATH preservadas). Recebe o arquivo e uma ou mais
# linhas; cada argumento depois do arquivo se torna uma linha no bloco
# anexado, na ordem recebida. Em DRY_RUN, so mostra o que seria escrito.
append_block_to_file() {
  local file="$1"
  shift
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) escreveria em $file:"
    local line
    for line in "$@"; do
      msg "  🔎 (dry-run)   $line"
    done
    return 0
  fi
  printf '%s\n' "$@" >> "$file"
}

# ────────────────────────────────────────────────────────────────────────────
# Barreira de material secreto
#
# O modo export copia mais de 20 caminhos de $HOME para dentro do repositorio,
# e varios deles carregam credencial: ~/.ssh (chave privada), ~/.npmrc
# (_authToken de registry), ~/.aider.conf.yml (api-key em texto claro),
# ~/.docker/config.json (auths). Sem esta barreira, um unico `install.sh export`
# versiona tudo isso.
#
# Nao foi hipotese: as duas chaves ed25519 do dono, sem passphrase, entraram no
# repositorio por aqui no commit bb059ce (mar/2026) e foram enviadas ao remoto.
#
# A checagem e por CONTEUDO, nao por nome de arquivo, porque o nome nao e
# confiavel — uma chave chamada "config" continua sendo uma chave.
#
# O criterio NAO e "segredo nunca entra" — este repositorio e privado e guarda
# credencial de proposito (shared/.ssh e o cofre de chaves do dono). O criterio
# e: material secreto so pode cair em destino que o espelho publico exclui.
#
# SECRET_EXPORT_DESTS espelha a lista de --exclude de scripts/sync_public.sh.
# As duas precisam andar juntas; _check_secret_dests_match_public_sync verifica
# isso e e chamada pelos testes.
#
# Escape consciente: ALLOW_SECRET_EXPORT=1 libera qualquer destino.
_looks_like_secret() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  head -c 4096 "$file" 2>/dev/null | grep -qE -- "-----BEGIN ([A-Z]+ )?PRIVATE KEY-----" && return 0
  head -c 8192 "$file" 2>/dev/null | grep -qE "(_authToken|_auth|_password|api[-_]?key|password|secret|token)[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_./+-]{16,}" && return 0
  return 1
}

# Destinos, relativos a raiz do repositorio, que o espelho publico exclui e que
# portanto podem receber material secreto.
SECRET_EXPORT_DESTS=(
  "shared/.ssh"
  "shared/git/.gitconfig-personal"
  "shared/git/.gitconfig-work"
  "shared/npm"
  "shared/pnpm"
  "shared/yarn"
  "shared/pip"
  "shared/cargo"
  "shared/docker"
  "shared/aider"
)

_dest_excluded_from_public() {
  local dest="$1" rel prefix
  rel="${dest#"$SCRIPT_DIR"/}"
  for prefix in "${SECRET_EXPORT_DESTS[@]}"; do
    [[ "$rel" == "$prefix" || "$rel" == "$prefix"/* ]] && return 0
  done
  return 1
}

# Confere que todo destino da lista acima realmente tem --exclude no
# sync_public.sh. Se alguem acrescentar um destino aqui e esquecer la, o
# segredo passa a sair no espelho publico sem ninguem perceber.
_check_secret_dests_match_public_sync() {
  local sync="$SCRIPT_DIR/scripts/sync_public.sh" prefix faltando=0
  [[ -f "$sync" ]] || { echo "sync_public.sh nao encontrado" >&2; return 1; }

  # Le as entradas do array SYNC_EXCLUDES do outro script sem executa-lo.
  # Ate Set/2026 isto procurava a forma "--exclude 'caminho'", inline no
  # comando rsync; quando aquele script passou a declarar a lista num array,
  # esta checagem quebrou em voz alta — que e o comportamento desejado. Se o
  # formato mudar de novo, ela quebra de novo, em vez de passar por engano.
  local -a excluidos=()
  mapfile -t excluidos < <(
    awk '/^SYNC_EXCLUDES=\(/{dentro=1; next} dentro && /^\)/{exit} dentro' "$sync" |
    sed -nE "s/^[[:space:]]*['\"]([^'\"]+)['\"].*/\1/p"
  )

  if [[ "${#excluidos[@]}" -eq 0 ]]; then
    echo "nao consegui ler SYNC_EXCLUDES de $sync — o formato da lista mudou?" >&2
    return 1
  fi

  local e achou
  for prefix in "${SECRET_EXPORT_DESTS[@]}"; do
    achou=0
    for e in "${excluidos[@]}"; do [[ "$e" == "$prefix" ]] && achou=1 && break; done
    [[ "$achou" -eq 1 ]] || { echo "sem exclusao no espelho publico: $prefix" >&2; faltando=1; }
  done
  return "$faltando"
}

# Devolve 0 (pode exportar) ou 1 (recusado, ja avisou).
_secret_export_allowed() {
  local file="$1" dest="${2:-}"
  _looks_like_secret "$file" || return 0
  if is_truthy "${ALLOW_SECRET_EXPORT:-0}"; then
    msg "  ⚠️  $file tem credencial — exportando mesmo assim (ALLOW_SECRET_EXPORT=1)"
    return 0
  fi
  if [[ -n "$dest" ]] && _dest_excluded_from_public "$dest"; then
    return 0
  fi
  msg "  🔒 $file NAO exportado: tem credencial e o destino nao esta fora do espelho publico."
  msg "      Destino: ${dest:-?}. Para forcar: ALLOW_SECRET_EXPORT=1"
  return 1
}

export_dir() {
  local src="$1"
  local dest="$2"
  [[ -d "$src" ]] || return
  msg "  📤 $src -> $dest"
  mkdir -p "$dest"

  # Copia arquivo a arquivo em vez de `cp -R` para que a barreira de segredo
  # possa recusar itens individuais sem abortar o diretorio inteiro.
  local rel f_src f_dest
  while IFS= read -r -d '' f_src; do
    rel="${f_src#"$src"/}"
    f_dest="$dest/$rel"
    _secret_export_allowed "$f_src" "$f_dest" || continue
    if is_truthy "$DRY_RUN"; then
      msg "  🔎 (dry-run) cp $f_src $f_dest"
      continue
    fi
    mkdir -p "$(dirname "$f_dest")"
    if ! cp "$f_src" "$f_dest"; then
      record_failure "optional" "Falha ao exportar arquivo: $f_src -> $f_dest"
    fi
  done < <(find "$src" -type f -print0 2>/dev/null)
}

export_file() {
  local src="$1"
  local dest="$2"
  [[ -f "$src" ]] || return
  if _files_identical "$src" "$dest"; then
    msg "  ✅ $dest (inalterado)"
    return
  fi
  _secret_export_allowed "$src" "$dest" || return
  msg "  📤 $src -> $dest"
  mkdir -p "$(dirname "$dest")"
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) cp $src $dest"
    _show_diff "$src" "$dest"
    return
  fi
  if ! cp "$src" "$dest"; then
    record_failure "optional" "Falha ao exportar arquivo: $src -> $dest"
  fi
}

normalize_crlf_to_lf() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  [[ "${TARGET_OS:-}" == "windows" ]] && return 0

  if LC_ALL=C grep -q $'\r' "$file" 2>/dev/null; then
    local tmp
    if ! tmp="$(mktemp)"; then
      warn "Falha ao criar arquivo temporário para normalizar $file"
      return 1
    fi

    if tr -d '\r' <"$file" >"$tmp" && mv "$tmp" "$file"; then
      return 0
    else
      warn "Falha ao normalizar line endings em $file"
      rm -f "$tmp" 2>/dev/null || true
      return 1
    fi
  fi
  return 0
}

# ═══════════════════════════════════════════════════════════
# VS Code Settings — Copy/Export
# ═══════════════════════════════════════════════════════════

copy_vscode_settings() {
  local settings_file="$CONFIG_SHARED/vscode/settings.json"
  [[ -f "$settings_file" ]] || return

  local dest=""
  case "$TARGET_OS" in
    macos)
      dest="$HOME/Library/Application Support/Code/User/settings.json"
      if [[ -d "$(dirname "$dest")" ]] || has_cmd code; then
        copy_file "$settings_file" "$dest"
      else
        msg "  ⚠️ VS Code não encontrado em macOS, pulando settings."
      fi
      ;;
    linux)
      dest="$HOME/.config/Code/User/settings.json"
      if [[ -d "$(dirname "$dest")" ]] || has_cmd code; then
        copy_file "$settings_file" "$dest"
      else
        msg "  ⚠️ VS Code não encontrado em Linux, pulando settings."
      fi
      ;;
    windows)
      local base="${APPDATA:-}"
      if [[ -z "$base" ]]; then
        base="$HOME/AppData/Roaming"
      fi
      if [[ -n "$base" ]]; then
        copy_file "$settings_file" "$base/Code/User/settings.json"
        if [[ -d "$base/Code - Insiders/User" ]]; then
          copy_file "$settings_file" "$base/Code - Insiders/User/settings.json"
        fi
      else
        msg "  ⚠️ APPDATA não definido, não foi possível instalar settings do VS Code."
      fi
      ;;
  esac
}

export_vscode_settings() {
  local src=""
  case "$TARGET_OS" in
    macos)
      src="$HOME/Library/Application Support/Code/User/settings.json"
      ;;
    linux)
      src="$HOME/.config/Code/User/settings.json"
      ;;
    windows)
      local base="${APPDATA:-$HOME/AppData/Roaming}"
      src="$base/Code/User/settings.json"
      ;;
  esac

  if [[ -f "$src" ]]; then
    export_file "$src" "$CONFIG_SHARED/vscode/settings.json"
  fi
}

export_vscode_extensions() {
  if ! has_cmd code; then
    return
  fi

  local extensions_file="$CONFIG_SHARED/vscode/extensions.txt"
  msg "  📦 Exportando extensões VS Code..."

  # Esta funcao gera o arquivo em vez de copia-lo, entao nao passa por
  # export_file e precisa checar DRY_RUN por conta propria. Sem isso, uma
  # simulacao sobrescrevia a lista versionada com a da maquina atual — em
  # Set/2026 um `DRY_RUN=1 install.sh export` apagou 73 das 108 extensoes.
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) code --list-extensions > $extensions_file"
    return
  fi

  mkdir -p "$(dirname "$extensions_file")"
  code --list-extensions > "$extensions_file" 2>/dev/null || warn "Falha ao exportar extensões VS Code"
}

install_vscode_extensions() {
  local extensions_file="$CONFIG_SHARED/vscode/extensions.txt"
  # extensions-ai.txt e curada a mao (extensoes de IA) e nao passa pelo export
  # de extensions.txt (que sobrescreve o arquivo com `code --list-extensions`
  # a cada `install.sh export`). Duas listas, uma so fonte de instalacao.
  local extensions_ai_file="$CONFIG_SHARED/vscode/extensions-ai.txt"

  if [[ ${COPY_VSCODE_SETTINGS:-0} -ne 1 ]]; then
    msg "  ⏭️  VS Code extensions: usuário optou por não copiar/instalar"
    return
  fi

  if ! has_cmd code; then
    warn "VS Code não encontrado; pulando instalação de extensões."
    return
  fi

  if [[ ! -f "$extensions_file" && ! -f "$extensions_ai_file" ]]; then
    return
  fi

  msg "▶ Instalando extensões VS Code"

  local installed_count=0

  local installed_extensions
  installed_extensions="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"

  local seen_extensions="|"
  local extension ext_lower source_file

  for source_file in "$extensions_file" "$extensions_ai_file"; do
    [[ -f "$source_file" ]] || continue

    while IFS= read -r extension; do
      [[ -z "$extension" ]] && continue
      [[ "$extension" =~ ^# ]] && continue

      ext_lower="$(echo "$extension" | tr '[:upper:]' '[:lower:]')"

      if [[ "$seen_extensions" == *"|${ext_lower}|"* ]]; then
        continue
      fi
      seen_extensions+="${ext_lower}|"

      if echo "$installed_extensions" | grep -qi "^${ext_lower}$"; then
        continue
      fi

      if is_truthy "$DRY_RUN"; then
        msg "  🔎 (dry-run) code --install-extension $extension"
        continue
      fi

      msg "  🔌 Instalando: $extension"
      if ! code --install-extension "$extension" --force >/dev/null 2>&1; then
        warn "Falha ao instalar extensão: $extension"
      else
        installed_count=$((installed_count + 1))
      fi
    done < "$source_file"
  done

  if [[ $installed_count -gt 0 ]]; then
    INSTALLED_MISC+=("vscode extensions: $installed_count")
  fi
}
