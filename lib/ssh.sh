#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329,SC1091
#
# Gestao de chaves SSH: deteccao/preview de chaves existentes, copia para
# ~/.ssh/ com resolucao de conflito, permissoes (700/600), migracao do
# remote git de HTTPS para SSH e validacao pos-instalacao. Antes vivia
# espalhada em install.sh (10 funcoes contiguas + 5 dispersas mais adiante).
# Movimentacao pura: nenhum corpo de funcao mudou.

get_ssh_key_fingerprint() {
  local key_file="$1"
  if [[ -f "$key_file" ]]; then
    ssh-keygen -lf "$key_file" 2>/dev/null | awk '{print $2}' || echo "unknown"
  else
    echo "not_a_key"
  fi
}

get_ssh_key_comment() {
  local key_file="$1"
  if [[ -f "$key_file" ]] && [[ "$key_file" == *.pub ]]; then
    awk '{print $NF}' "$key_file" 2>/dev/null
    return
  elif [[ -f "${key_file}.pub" ]]; then
    awk '{print $NF}' "${key_file}.pub" 2>/dev/null
    return
  fi
  echo ""
}

_ssh_print_key_preview() {
  local label="$1" key_file="$2"
  if [[ -f "$key_file" ]]; then
    local fp comment key_type
    fp=$(get_ssh_key_fingerprint "$key_file")
    comment=$(get_ssh_key_comment "$key_file")
    key_type=$(ssh-keygen -lf "$key_file" 2>/dev/null | awk '{print $NF}' | tr -d '()')
    echo -e "    ${UI_MUTED}${label}:${UI_RESET}"
    echo -e "      ${UI_MUTED}Tipo:${UI_RESET}        ${UI_TEXT}${key_type:-desconhecido}${UI_RESET}"
    echo -e "      ${UI_MUTED}Fingerprint:${UI_RESET} ${UI_TEXT}${fp}${UI_RESET}"
    [[ -n "$comment" ]] && echo -e "      ${UI_MUTED}Comentário:${UI_RESET}  ${UI_TEXT}${comment}${UI_RESET}"
    if [[ "$key_file" == *.pub ]]; then
      local pub_content
      pub_content=$(head -c 80 "$key_file" 2>/dev/null)
      echo -e "      ${UI_MUTED}Pub:${UI_RESET}         ${UI_DIM}${pub_content}...${UI_RESET}"
    fi
  fi
}

_ssh_is_identity_file() {
  local key_file="$1"
  local key_name
  key_name=$(basename "$key_file")
  case "$key_name" in
    *.pub|config|known_hosts|known_hosts.*|authorized_keys|authorized_keys.*) return 1 ;;
  esac
  return 0
}

_ssh_key_kind() {
  local key_file="$1"
  [[ -f "$key_file" ]] || { echo "missing"; return 0; }

  local first_line
  first_line=$(head -n 1 "$key_file" 2>/dev/null)

  case "$first_line" in
    "-----BEGIN OPENSSH PRIVATE KEY-----"|"-----BEGIN RSA PRIVATE KEY-----"|"-----BEGIN EC PRIVATE KEY-----"|"-----BEGIN DSA PRIVATE KEY-----"|"-----BEGIN PRIVATE KEY-----"|"-----BEGIN ENCRYPTED PRIVATE KEY-----")
      echo "private"
      ;;
    ssh-*)
      echo "public"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

_ssh_sync_public_key() {
  local src_private="$1" dest_private="$2"
  local src_pub="${src_private}.pub"
  local dest_pub="${dest_private}.pub"
  local private_fp src_pub_fp dest_pub_fp

  private_fp=$(get_ssh_key_fingerprint "$src_private")

  # Se a .pub de origem existir e combinar com a privada, ela é preferida.
  if [[ -f "$src_pub" ]]; then
    src_pub_fp=$(get_ssh_key_fingerprint "$src_pub")
    if [[ "$private_fp" != "unknown" ]] && [[ "$private_fp" == "$src_pub_fp" ]]; then
      cp "$src_pub" "$dest_pub"
      return 0
    fi
    echo -e "  ${UI_WARNING}⚠ ${src_pub##*/} não corresponde à privada (${private_fp} != ${src_pub_fp}).${UI_RESET}"
  fi

  # Se o destino já possui .pub compatível com a privada, preserva.
  if [[ -f "$dest_pub" ]]; then
    dest_pub_fp=$(get_ssh_key_fingerprint "$dest_pub")
    if [[ "$private_fp" != "unknown" ]] && [[ "$private_fp" == "$dest_pub_fp" ]]; then
      return 0
    fi
  fi

  # Tentativa de regenerar .pub a partir da privada sem prompt interativo.
  local pub_tmp
  if pub_tmp="$(mktemp 2>/dev/null)"; then
    if ssh-keygen -y -f "$src_private" </dev/null > "$pub_tmp" 2>/dev/null; then
      mv "$pub_tmp" "$dest_pub"
      return 0
    fi
    rm -f "$pub_tmp" 2>/dev/null || true
  fi

  # Evita manter .pub incorreta quando não for possível regenerar.
  if [[ -f "$dest_pub" ]]; then
    rm -f "$dest_pub"
    echo -e "  ${UI_WARNING}⚠ ${dest_pub##*/} removida para evitar fingerprint divergente.${UI_RESET}"
  fi

  return 0
}

_ssh_copy_entry() {
  local src_path="$1" dest_path="$2"

  if _ssh_is_identity_file "$src_path"; then
    local key_kind
    key_kind=$(_ssh_key_kind "$src_path")
    if [[ "$key_kind" != "private" ]]; then
      echo -e "  ${UI_WARNING}⚠ ${src_path##*/} não é uma chave privada válida (${key_kind}); cópia ignorada.${UI_RESET}"
      return 1
    fi
  fi

  if ! cp "$src_path" "$dest_path"; then
    echo -e "  ${UI_WARNING}⚠ Falha ao copiar ${src_path##*/}.${UI_RESET}"
    return 1
  fi

  if _ssh_is_identity_file "$src_path"; then
    # chmod imediato (nao esperar o set_ssh_permissions do final do loop) --
    # fecha a janela onde uma chave privada recem-copiada fica com permissao
    # de umask (tipicamente 644) ate a proxima chave ser processada ou ate
    # um prompt de conflito bloquear esperando input do usuario.
    chmod 600 "$dest_path" 2>/dev/null || true
    _ssh_sync_public_key "$src_path" "$dest_path"
  fi

  return 0
}

_ssh_resolve_conflict() {
  local key_name="$1" src_path="$2" dest_path="$3" ssh_dest="$4"

  echo ""
  echo -e "  ${UI_WARNING}${UI_BOLD}Conflito:${UI_RESET} ${UI_TEXT}${key_name}${UI_RESET} ${UI_MUTED}já existe em ~/.ssh/${UI_RESET}"
  echo ""

  _ssh_print_key_preview "Backup (origem)" "$src_path"
  echo ""
  _ssh_print_key_preview "Sistema (destino)" "$dest_path"
  echo ""

  echo -e "  ${UI_PEACH}${UI_BOLD}S${UI_RESET} ${UI_TEXT}Substituir${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_SKY}${UI_BOLD}R${UI_RESET} ${UI_TEXT}Renomear${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_RED}${UI_BOLD}D${UI_RESET} ${UI_TEXT}Deletar existente${UI_RESET}  ${UI_MUTED}│${UI_RESET}  ${UI_DIM}P${UI_RESET} ${UI_TEXT}Pular${UI_RESET}"
  local ssh_choice
  read -r -p "  → " ssh_choice
  case "${ssh_choice,,}" in
    s|substituir)
      if _ssh_copy_entry "$src_path" "$dest_path"; then
        echo -e "  ${UI_GREEN}✓ Substituído: ${key_name}${UI_RESET}"
      fi
      ;;
    r|renomear)
      if [[ ! -t 0 ]]; then
        echo -e "  ${UI_MUTED}⏭ Entrada não interativa detectada. Mantido: ${key_name} (original preservado)${UI_RESET}"
      else
        local new_name=""
        while true; do
          read -r -p "  Novo nome (ex: id_ed25519_work): " new_name
          [[ -z "$new_name" ]] && { echo -e "  ${UI_WARNING}Nome não pode ser vazio.${UI_RESET}"; continue; }
          [[ -f "$ssh_dest/$new_name" ]] && { echo -e "  ${UI_WARNING}${new_name} já existe.${UI_RESET}"; continue; }
          break
        done
        if _ssh_copy_entry "$src_path" "$ssh_dest/$new_name"; then
          echo -e "  ${UI_GREEN}✓ Copiado como: ${new_name}${UI_RESET}"
        fi
      fi
      ;;
    d|deletar)
      if _ssh_is_identity_file "$dest_path"; then
        rm -f "$dest_path" "${dest_path}.pub"
      else
        rm -f "$dest_path"
      fi
      if _ssh_copy_entry "$src_path" "$dest_path"; then
        echo -e "  ${UI_GREEN}✓ Existente removido e substituído: ${key_name}${UI_RESET}"
      fi
      ;;
    *)
      echo -e "  ${UI_MUTED}⏭ Mantido: ${key_name} (original preservado)${UI_RESET}"
      ;;
  esac
}

manage_ssh_keys() {
  local ssh_source="$1"
  local ssh_dest="$HOME/.ssh"

  mkdir -p "$ssh_dest"

  # Coletar chaves privadas válidas + arquivos auxiliares esperados em ~/.ssh
  local source_keys=()
  while IFS= read -r -d '' key; do
    local key_name key_kind
    key_name=$(basename "$key")
    case "$key_name" in
      *.pub|authorized_keys|authorized_keys.*)
        continue
        ;;
      known_hosts|known_hosts.*|config)
        source_keys+=("$key")
        continue
        ;;
    esac

    key_kind=$(_ssh_key_kind "$key")
    [[ "$key_kind" == "private" ]] && source_keys+=("$key")
  done < <(find "$ssh_source" -maxdepth 1 -type f -print0 2>/dev/null)

  if [[ ${#source_keys[@]} -eq 0 ]]; then
    echo -e "  ${UI_INFO}ℹ Nenhuma chave SSH encontrada em ${ssh_source}${UI_RESET}"
    return
  fi

  # Mapear fingerprints existentes no destino
  declare -A dest_fingerprints
  if [[ -d "$ssh_dest" ]]; then
    while IFS= read -r -d '' existing_key; do
      local fp
      _ssh_is_identity_file "$existing_key" || continue
      fp=$(get_ssh_key_fingerprint "$existing_key")
      [[ "$fp" != "unknown" ]] && [[ "$fp" != "not_a_key" ]] && dest_fingerprints["$fp"]="$existing_key"
    done < <(find "$ssh_dest" -maxdepth 1 -type f -print0 2>/dev/null)
  fi

  # ── Exibir chaves encontradas ──
  echo ""
  echo -e "  ${UI_ACCENT}${UI_BOLD}▸ Chaves SSH${UI_RESET}"
  echo -e "  ${UI_BORDER}────────────────${UI_RESET}"
  echo ""

  local has_conflict=0
  for key_path in "${source_keys[@]}"; do
    local key_name
    key_name=$(basename "$key_path")
    local fp
    fp=$(get_ssh_key_fingerprint "$key_path")

    [[ "$fp" == "not_a_key" ]] && continue

    local comment
    comment=$(get_ssh_key_comment "$key_path")
    local status_icon="${UI_GREEN}●${UI_RESET}"
    local status_text=""
    local dest_path="$ssh_dest/$key_name"

    if [[ -f "$dest_path" ]]; then
      status_icon="${UI_WARNING}●${UI_RESET}"
      status_text=" ${UI_DIM}(conflito)${UI_RESET}"
      has_conflict=1
    elif [[ "$fp" != "unknown" ]] && [[ -n "${dest_fingerprints[$fp]:-}" ]]; then
      local existing_name
      existing_name=$(basename "${dest_fingerprints[$fp]}")
      status_icon="${UI_WARNING}●${UI_RESET}"
      status_text=" ${UI_DIM}(duplica ${existing_name})${UI_RESET}"
      has_conflict=1
    fi

    echo -e "  ${status_icon} ${UI_TEXT}${UI_BOLD}${key_name}${UI_RESET}${status_text}"
    [[ -n "$comment" ]] && echo -e "    ${UI_MUTED}${comment}${UI_RESET}"
    [[ "$fp" != "unknown" ]] && echo -e "    ${UI_DIM}${fp}${UI_RESET}"
  done

  echo ""
  [[ $has_conflict -eq 1 ]] && echo -e "  ${UI_WARNING}⚠ Chaves com conflito serão tratadas individualmente${UI_RESET}" && echo ""

  if ! ui_confirm "Deseja copiar as chaves SSH?"; then
    echo -e "  ${UI_MUTED}⏭ Cópia de chaves SSH cancelada${UI_RESET}"
    return 1
  fi

  echo ""

  # ── Copiar chaves ──
  for key_path in "${source_keys[@]}"; do
    local key_name
    key_name=$(basename "$key_path")
    local dest_path="$ssh_dest/$key_name"
    local fp
    fp=$(get_ssh_key_fingerprint "$key_path")

    [[ "$fp" == "not_a_key" ]] && continue

    # Conflito por fingerprint (nome diferente, mesma chave)
    if [[ "$fp" != "unknown" ]] && [[ -n "${dest_fingerprints[$fp]:-}" ]]; then
      local existing_path="${dest_fingerprints[$fp]}"
      local existing_name
      existing_name=$(basename "$existing_path")

      if [[ "$existing_name" != "$key_name" ]]; then
        echo -e "  ${UI_WARNING}${key_name} duplica ${existing_name}${UI_RESET} ${UI_DIM}(mesmo fingerprint)${UI_RESET}"
        _ssh_resolve_conflict "$existing_name" "$key_path" "$existing_path" "$ssh_dest"
        continue
      fi
    fi

    # Conflito por nome
    if [[ -f "$dest_path" ]]; then
      _ssh_resolve_conflict "$key_name" "$key_path" "$dest_path" "$ssh_dest"
      continue
    fi

    # Sem conflito — copiar diretamente
    if _ssh_copy_entry "$key_path" "$dest_path"; then
      echo -e "  ${UI_GREEN}✓ Copiado: ${key_name}${UI_RESET}"
    fi
  done
}

set_ssh_permissions() {
  if [[ -d "$HOME/.ssh" ]]; then
    chmod 700 "$HOME/.ssh"
    find "$HOME/.ssh" -type f -exec chmod 600 {} + 2>/dev/null || true
    find "$HOME/.ssh" -type d -exec chmod 700 {} + 2>/dev/null || true
  fi
}

_resolve_ssh_source() {
  if [[ -n "$PRIVATE_SHARED" ]] && [[ -d "$PRIVATE_SHARED/.ssh" ]]; then
    echo "$PRIVATE_SHARED/.ssh"
  elif [[ -d "$CONFIG_SHARED/.ssh" ]]; then
    echo "$CONFIG_SHARED/.ssh"
  fi
}

# Pergunta interativa (ETAPA 1) -- e a peça que faltava pra `manage_ssh_keys`/
# `_ssh_resolve_conflict` (já existentes, bem construídos) serem alcançáveis:
# sem isso, COPY_SSH_KEYS nunca saía de 0 (achado de auditoria: ~180 linhas de
# feature morta). Default seguro: não pergunta se não há fonte, e sob stdin
# não-interativo assume "não copiar" (mesmo espírito de _confirm_overwrite).
ask_ssh_keys() {
  COPY_SSH_KEYS=0
  local ssh_source=""
  ssh_source="$(_resolve_ssh_source)"
  [[ -z "$ssh_source" ]] && return 0
  [[ ! -t 0 ]] && return 0

  msg ""
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  🔐 CHAVES SSH"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "  Encontradas em: $ssh_source"
  msg "  Copiar pra ~/.ssh/ com permissões corretas (700/600)?"

  if confirm_action "copiar as chaves SSH detectadas"; then
    COPY_SSH_KEYS=1
  else
    msg ""
    msg "  ⏭️  Pulando cópia de chaves SSH"
  fi
}

# Chave cifrada no repo (.age) vira chave utilizavel no ~/.ssh. Roda depois
# de manage_ssh_keys porque o que esta em claro no repo ja foi copiado por ela;
# aqui so entra o que precisa de senha ou identidade.
_decifrar_chaves_do_repo() {
  local origem="$1"
  declare -F crypto_decifrar_diretorio >/dev/null 2>&1 || return 0

  local cifradas=0 arquivo
  for arquivo in "$origem"/*.age; do
    [[ -f "$arquivo" ]] && cifradas=$(( cifradas + 1 ))
  done
  (( cifradas > 0 )) || return 0

  if ! crypto_disponivel; then
    record_failure optional \
      "ha ${cifradas} chave(s) cifrada(s) no repositorio, mas o age nao esta instalado" \
      "instale o age e rode: bash install.sh --only=ssh"
    return 0
  fi

  msg ""
  msg "  ${UI_SKY:-}🔐 ${cifradas} chave(s) cifrada(s) no repositorio${UI_RESET:-}"
  if [[ -z "${CRYPTO_IDENTIDADE:-}" ]]; then
    msg "  ${UI_OVERLAY1:-}A senha e pedida uma vez por arquivo.${UI_RESET:-}"
  fi
  crypto_decifrar_diretorio "$origem" "$HOME/.ssh" || \
    record_failure optional "nao foi possivel decifrar as chaves SSH" \
      "confira a senha, ou use --ssh-identity=CAMINHO"
}

_apply_ssh_keys() {
  if [[ ${COPY_SSH_KEYS:-0} -ne 1 ]]; then
    msg "  ⏭️  SSH Keys: usuário optou por não copiar (padrão por segurança)"
    return 0
  fi

  local ssh_source=""
  ssh_source="$(_resolve_ssh_source)"

  if [[ -n "$ssh_source" ]]; then
    msg "▶ Gerenciando Chaves SSH"
    # set_ssh_permissions roda SEMPRE, independente do exit code de
    # manage_ssh_keys -- o retorno dela e so o do ultimo comando do loop, entao
    # uma falha na ULTIMA chave pulava a correcao de permissao das chaves
    # anteriores que copiaram com sucesso (achado de auditoria de seguranca).
    manage_ssh_keys "$ssh_source"
    _decifrar_chaves_do_repo "$ssh_source"
    set_ssh_permissions
    msg "  ✓ Chaves SSH configuradas com permissões corretas (700/600)"
    _validate_ssh_keys
    _migrate_remote_to_ssh
  fi
}

# Confirma na hora que a chave ficou utilizavel, em vez de deixar o dono
# descobrir no primeiro push. `ssh -T` contra o GitHub sempre sai com codigo 1
# mesmo quando da certo (nao ha shell para abrir), entao o que vale e a
# mensagem de boas-vindas, nao o codigo de saida.
_validate_ssh_keys() {
  has_cmd ssh || return 0
  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) ssh -T nos hosts do ~/.ssh/config"
    return 0
  fi

  local host resposta
  while IFS= read -r host; do
    # -n e obrigatorio aqui: sem ele o ssh consome o stdin do laco, que e a
    # propria lista de hosts, e so o primeiro seria verificado.
    resposta="$(ssh -n -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
                    -o ConnectTimeout=10 "$host" 2>&1)"
    if printf '%s' "$resposta" | grep -q "successfully authenticated"; then
      msg "  ✓ $host: chave aceita"
    else
      warn "$host: nao autenticou. Resposta: $(printf '%s' "$resposta" | head -1)"
    fi
  done < <(awk '/^Host github\.com-/ {print $2}' "$HOME/.ssh/config" 2>/dev/null)
}

# O README manda clonar por HTTPS com token na primeira instalacao, porque as
# chaves ainda nao existem — ovo e galinha resolvido. O efeito colateral e que o
# token fica gravado no .git/config do clone, em texto claro, para sempre.
#
# Agora que as chaves estao no lugar, o remote pode passar para SSH. Troca so
# quando o host do alias existe no ~/.ssh/config; senao avisa e nao mexe.
_migrate_remote_to_ssh() {
  has_cmd git || return 0
  [[ -d "$SCRIPT_DIR/.git" ]] || return 0

  local url
  url="$(git -C "$SCRIPT_DIR" config --get remote.origin.url 2>/dev/null)" || return 0
  [[ "$url" =~ ^https://[^@]+@github\.com/(.+)$ ]] || return 0

  local repo="${BASH_REMATCH[1]}"
  repo="${repo%.git}"
  local dono="${repo%%/*}"
  local alias_host="github.com-${dono}"

  if ! grep -q "^Host ${alias_host}\b" "$HOME/.ssh/config" 2>/dev/null; then
    warn "remote usa HTTPS com credencial embutida, mas nao achei '$alias_host' no ~/.ssh/config — deixando como esta"
    return 0
  fi

  if is_truthy "$DRY_RUN"; then
    msg "  🔎 (dry-run) git remote set-url origin git@${alias_host}:${repo}.git"
    return 0
  fi

  if git -C "$SCRIPT_DIR" remote set-url origin "git@${alias_host}:${repo}.git"; then
    msg "  🔐 remote migrado para SSH — o token deixou de ficar gravado em .git/config"
  else
    warn "falha ao migrar o remote para SSH"
  fi
}
