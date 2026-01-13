# SSH Keys - Como Configurar

Este diretório serve como **exemplo** para você configurar suas chaves SSH privadas.

## ⚠️ IMPORTANTE - Segurança

**NUNCA commite chaves SSH privadas em repositórios públicos!**

O `.gitignore` já está configurado para ignorar `shared/.ssh/`, mas sempre verifique:

```bash
git status
```

## 📁 Como Usar (Versão Privada - Seu Fork)

Se você quer ter suas chaves SSH sincronizadas entre máquinas via Git:

1. **Renomeie este diretório:**
   ```bash
   mv shared/.ssh.example shared/.ssh
   ```

2. **Adicione suas chaves:**
   ```bash
   # Copie suas chaves existentes
   cp ~/.ssh/id_rsa shared/.ssh/
   cp ~/.ssh/id_rsa.pub shared/.ssh/
   cp ~/.ssh/id_ed25519 shared/.ssh/
   cp ~/.ssh/id_ed25519.pub shared/.ssh/

   # Ou copie todo o diretório (cuidado com known_hosts grandes)
   cp -r ~/.ssh/* shared/.ssh/
   ```

3. **Adicione arquivos de configuração SSH** (opcional):
   ```bash
   # shared/.ssh/config
   Host github-personal
       HostName github.com
       User git
       IdentityFile ~/.ssh/id_ed25519_personal

   Host github-work
       HostName github.com
       User git
       IdentityFile ~/.ssh/id_ed25519_work
   ```

4. **Commit no seu fork PRIVADO:**
   ```bash
   # Certifique-se que o repo é PRIVADO!
   git add shared/.ssh/
   git commit -m "chore: add private SSH keys"
   git push origin main
   ```

## 🌐 Como Usar (Versão Pública - Sem Chaves)

Se você quer compartilhar seu dotfiles publicamente:

1. **NÃO renomeie este diretório** - mantenha como `.ssh.example`
2. **Gere chaves manualmente** após a instalação:
   ```bash
   ssh-keygen -t ed25519 -C "seu-email@exemplo.com"
   ```
3. Ou use suas chaves existentes normalmente em `~/.ssh/`

## 📂 Estrutura Recomendada

```
shared/.ssh/
├── config                 # Configuração de hosts SSH
├── id_ed25519            # Chave privada (NÃO COMMITAR em repos públicos!)
├── id_ed25519.pub        # Chave pública (pode commitar)
├── id_ed25519_personal   # Chave pessoal
├── id_ed25519_personal.pub
├── id_ed25519_work       # Chave trabalho
├── id_ed25519_work.pub
└── known_hosts           # (opcional - pode ficar grande)
```

## 🔄 Dual-Version Workflow

### Para Você (Mantenedor)

1. Tenha dois repositórios:
   - **Público**: `https://github.com/seu-usuario/dotfiles` (sem SSH keys)
   - **Privado**: `https://github.com/seu-usuario/dotfiles-private` (com SSH keys)

2. No repo privado:
   ```bash
   mv shared/.ssh.example shared/.ssh
   # Adicione suas chaves
   git add shared/.ssh/
   git commit -m "chore: add private SSH keys"
   ```

3. Para atualizar o público, remova dados sensíveis:
   ```bash
   git checkout main
   rm -rf shared/.ssh
   mv shared/.ssh shared/.ssh.example  # se necessário
   git add .
   git commit -m "chore: update dotfiles (public version)"
   git push public main
   ```

### Para Outros Usuários

1. Clone o repositório público
2. Adicione suas próprias chaves seguindo as instruções acima
3. Mantenha suas chaves em um fork privado ou localmente

## ✅ Verificação de Segurança

Antes de fazer push, sempre verifique:

```bash
# Ver o que será commitado
git status

# Ver conteúdo dos arquivos staged
git diff --cached

# Procurar por chaves privadas
grep -r "BEGIN.*PRIVATE KEY" .

# Verificar .gitignore
cat .gitignore | grep ssh
```

## 🔐 Permissões

O instalador automaticamente define:
- `700` para diretórios (drwx------)
- `600` para arquivos (-rw-------)

Isso é **obrigatório** para o SSH funcionar corretamente.
