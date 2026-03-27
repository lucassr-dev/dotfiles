# ═══════════════════════════════════════════════════════════
# SSH Agent — auto-load chaves de ~/.ssh/
# ═══════════════════════════════════════════════════════════

# Detectar socket do SSH agent existente
def --env ensure-ssh-agent [] {
  if ($env | get -i SSH_AUTH_SOCK | is-empty) or (not ($env.SSH_AUTH_SOCK | path exists)) {
    # Tentar sockets conhecidos (Linux systemd)
    let uid = (id -u | str trim)
    let candidates = [
      $"/run/user/($uid)/openssh_agent"
      $"/run/user/($uid)/ssh-agent.socket"
      $"/run/user/($uid)/gcr/ssh"
    ]

    mut found = false
    for sock in $candidates {
      if ($sock | path exists) {
        $env.SSH_AUTH_SOCK = $sock
        $found = true
        break
      }
    }

    # Fallback: iniciar ssh-agent
    if not $found {
      let agent_output = (ssh-agent -s | lines | where { $it =~ "=" } | each { |line|
        let parts = ($line | split row "=")
        if ($parts | length) >= 2 {
          let key = ($parts.0 | str trim)
          let val = ($parts.1 | str replace ";" "" | str trim)
          {key: $key, val: $val}
        }
      })
      for entry in $agent_output {
        if $entry.key == "SSH_AUTH_SOCK" { $env.SSH_AUTH_SOCK = $entry.val }
        if $entry.key == "SSH_AGENT_PID" { $env.SSH_AGENT_PID = $entry.val }
      }
    }
  }
}

# Auto-load chaves privadas
def load-ssh-keys [] {
  let ssh_dir = ($env.HOME | path join ".ssh")
  if not ($ssh_dir | path exists) { return }

  let loaded = (do { ssh-add -l } | complete | get stdout | default "")

  glob ($ssh_dir | path join "id_*") | where {
    not ($it | str ends-with ".pub")
  } | each { |key_path|
    let fp = (do { ssh-keygen -lf $key_path } | complete | get stdout | default "" | split row " " | get -i 1 | default "")
    if ($fp | is-not-empty) and not ($loaded | str contains $fp) {
      do { ssh-add $key_path } | complete | ignore
    }
  }
}

ensure-ssh-agent
load-ssh-keys
