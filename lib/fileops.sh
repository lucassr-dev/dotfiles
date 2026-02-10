#!/usr/bin/env bash

_files_identical() {
  local file_a="$1"
  local file_b="$2"
  [[ -f "$file_a" ]] && [[ -f "$file_b" ]] || return 1
  if has_cmd sha256sum; then
    local sum_a sum_b
    sum_a=$(sha256sum "$file_a" 2>/dev/null | awk '{print $1}')
    sum_b=$(sha256sum "$file_b" 2>/dev/null | awk '{print $1}')
    [[ "$sum_a" == "$sum_b" ]]
  elif has_cmd shasum; then
    local sum_a sum_b
    sum_a=$(shasum -a 256 "$file_a" 2>/dev/null | awk '{print $1}')
    sum_b=$(shasum -a 256 "$file_b" 2>/dev/null | awk '{print $1}')
    [[ "$sum_a" == "$sum_b" ]]
  else
    cmp -s "$file_a" "$file_b"
  fi
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
    cp -a "$path" "$backup_path" 2>/dev/null || cp -R "$path" "$backup_path" 2>/dev/null || true
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
  cp -R "$src/." "$dest/"
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
  cp "$src" "$dest"
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
