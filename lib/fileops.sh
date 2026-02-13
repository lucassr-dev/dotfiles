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
    local backup_path="$BACKUP_DIR/$base_name"
    mkdir -p "$BACKUP_DIR"
    msg "  💾 Backup: $path -> $backup_path"
    if ! cp -a "$path" "$backup_path" 2>/dev/null && ! cp -R "$path" "$backup_path" 2>/dev/null; then
      record_failure "critical" "Falha ao fazer backup de: $path" "Verifique permissões e espaço em disco"
      return 1
    fi
  fi
}

copy_dir() {
  local src="$1"
  local dest="$2"
  [[ -d "$src" ]] || return
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) 📁 $src -> $dest"
    return
  fi
  msg "  📁 $src -> $dest"
  backup_if_exists "$dest"
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
  msg "  📄 $src -> $dest"
  backup_if_exists "$dest"
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

export_dir() {
  local src="$1"
  local dest="$2"
  [[ -d "$src" ]] || return
  msg "  📤 $src -> $dest"
  mkdir -p "$dest"
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) cp -R $src/. $dest/"
    return
  fi
  if ! cp -R "$src/." "$dest/"; then
    record_failure "optional" "Falha ao exportar diretório: $src -> $dest"
  fi
}

export_file() {
  local src="$1"
  local dest="$2"
  [[ -f "$src" ]] || return
  if _files_identical "$src" "$dest"; then
    msg "  ✅ $dest (inalterado)"
    return
  fi
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

  mkdir -p "$(dirname "$extensions_file")"
  code --list-extensions > "$extensions_file" 2>/dev/null || warn "Falha ao exportar extensões VS Code"
}

install_vscode_extensions() {
  local extensions_file="$CONFIG_SHARED/vscode/extensions.txt"

  if [[ ${COPY_VSCODE_SETTINGS:-1} -ne 1 ]]; then
    msg "  ⏭️  VS Code extensions: usuário optou por não copiar/instalar"
    return
  fi

  if ! has_cmd code; then
    warn "VS Code não encontrado; pulando instalação de extensões."
    return
  fi

  if [[ ! -f "$extensions_file" ]]; then
    return
  fi

  msg "▶ Instalando extensões VS Code"

  local installed_count=0

  local installed_extensions
  installed_extensions="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"

  while IFS= read -r extension; do
    [[ -z "$extension" ]] && continue
    [[ "$extension" =~ ^# ]] && continue

    local ext_lower
    ext_lower="$(echo "$extension" | tr '[:upper:]' '[:lower:]')"

    if echo "$installed_extensions" | grep -qi "^${ext_lower}$"; then
      continue
    fi

    msg "  🔌 Instalando: $extension"
    if ! code --install-extension "$extension" --force >/dev/null 2>&1; then
      warn "Falha ao instalar extensão: $extension"
    else
      installed_count=$((installed_count + 1))
    fi
  done < "$extensions_file"

  if [[ $installed_count -gt 0 ]]; then
    INSTALLED_MISC+=("vscode extensions: $installed_count")
  fi
}
