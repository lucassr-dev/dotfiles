if not status is-interactive
    return
end

set -l os (uname -s)

switch $os
    case Darwin
        set -l sock_candidates \
            "$SSH_AUTH_SOCK" \
            "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" \
            /run/user/(id -u)/openssh_agent

        for sock in $sock_candidates
            if test -S "$sock"
                set -gx SSH_AUTH_SOCK $sock
                break
            end
        end

    case Linux
        set -l sock_candidates \
            /run/user/(id -u)/openssh_agent \
            /run/user/(id -u)/ssh-agent.socket \
            "$SSH_AUTH_SOCK"

        for sock in $sock_candidates
            if test -S "$sock"
                set -gx SSH_AUTH_SOCK $sock
                break
            end
        end

        if type -q systemctl
            systemctl --user mask gcr-ssh-agent.socket gcr-ssh-agent.service 2>/dev/null
        end

    case '*'
        if test -n "$SSH_AUTH_SOCK"; and test -S "$SSH_AUTH_SOCK"
            return
        end
end

if not set -q SSH_AUTH_SOCK; or not test -S "$SSH_AUTH_SOCK"
    eval (ssh-agent -c 2>/dev/null) >/dev/null 2>&1
end

for key in ~/.ssh/*
    if test -f $key
        and not string match -q '*.pub' $key
        and not string match -q '*known_hosts*' $key
        and not string match -q '*config*' $key
        and not string match -q '*authorized_keys*' $key
        and not string match -q '*.broken*' $key
        and not string match -q '*agent*' $key
        and not string match -q '*environment*' $key

        set -l already_loaded 0
        for loaded in (ssh-add -l 2>/dev/null | awk '{print $3}')
            if test (realpath $key 2>/dev/null) = (realpath $loaded 2>/dev/null)
                set already_loaded 1
                break
            end
        end

        if test $already_loaded -eq 0
            ssh-add $key 2>/dev/null
        end
    end
end
